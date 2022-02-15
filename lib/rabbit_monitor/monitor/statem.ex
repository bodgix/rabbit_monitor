defmodule RabbitMonitor.Monitor.Statem do
  require Logger
  use AMQP

  @behaviour :gen_statem

  @connect_delay 1000
  @max_connect_delay 10_000
  @check_delay 10_000
  @pong_timeout 5000
  @drain_duration 1000

  alias RabbitMonitor.Monitor.{Core, Ponger}

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    :gen_statem.start_link(__MODULE__, opts, [])
  end

  @impl true
  def callback_mode(), do: :state_functions

  @impl true
  def init(init_arg) do
    {:ok, :disconnected, {init_arg, 0}, [{:state_timeout, 1, :connect}]}
  end

  def disconnected(:state_timeout, :connect, {init_arg, delay}) do
    Logger.debug("Trying to connect with #{inspect(init_arg)}")

    with {:ok, chan} <- Core.connect_link(init_arg) do
      {:next_state, :connected, chan,
       [
         {:next_event, :internal, :start_ponger},
         {:next_event, :internal, :subscribe_queue}
       ]}
    else
      err ->
        new_delay =
          (delay + @connect_delay > @max_connect_delay && delay + @connect_delay) ||
            @max_connect_delay

        {:keep_state, {init_arg, new_delay}, [{:state_timeout, new_delay, :connect}]}
    end
  end

  def connected(:internal, :start_ponger, chan) do
    {:ok, pid} = Ponger.start_link({chan, "#{Core.queue_name()}-ping"})
    :keep_state_and_data
  end

  def connected(:internal, :subscribe_queue, chan) do
    :ok = Core.subscribe_queue(chan, "#{Core.queue_name()}-pong")
    :keep_state_and_data
  end

  def connected(:info, {:basic_consume_ok, _msg}, chan) do
    Logger.debug(":basic_consume_ok")
    {:next_state, :drain_queue, chan, [{:state_timeout, @drain_duration, :drain}]}
  end

  def drain_queue(:info, {:basic_deliver, msg, ctx}, chan) do
    Logger.debug("Got an old message - discarding")
    Core.ack_message(chan, ctx)
    {:keep_state_and_data, [{:state_timeout, @drain_duration, :drain}]}
  end

  def drain_queue(:state_timeout, :drain, chan) do
    Logger.debug("Finished draining the queue.")
    {:next_state, :ready, chan, [{:state_timeout, @check_delay, :check}]}
  end

  def ready(:state_timeout, :check, chan) do
    Logger.debug("Timeout triggered - running a check")
    receivers = Core.get_receivers()
    {:next_state, :send_ping, {chan, receivers}, [{:next_event, :internal, :send_ping}]}
  end

  def ready(:info, {:basic_deliver, msg, ctx}, chan) do
    Logger.warn("Unexpected message #{inspect(msg)}")
    Core.ack_message(chan, ctx)
    :keep_state_and_data
  end

  def send_ping(:internal, :send_ping, {chan, [pid | rest]} = state) do
    from = Core.ping(chan, pid)
    t1 = :erlang.monotonic_time(:microsecond)

    {:next_state, :wait_pong, {chan, rest, t1},
     [{:state_timeout, @pong_timeout, {:pong_timeout, from}}]}
  end

  def send_ping(:internal, :send_ping, {chan, []} = _state) do
    Logger.debug("Sent all pings to all receivers")
    {:next_state, :ready, chan, [{:state_timeout, @check_delay, :check}]}
  end

  def wait_pong(:info, {:basic_deliver, "pong " <> from, ctx}, {chan, pids, t1} = state) do
    t2 = :erlang.monotonic_time(:microsecond)
    Logger.debug("Got PONG! from #{from}")
    Core.ack_message(chan, ctx)

    :telemetry.execute(
      [:rabbitmq, :ping, :done],
      %{rtt: t2 - t1},
      %{target: from}
    )

    {:next_state, :send_ping, {chan, pids}, [{:next_event, :internal, :send_ping}]}
  end

  def wait_pong(:state_timeout, {:pong_timeout, from}, {chan, pids, t1} = state) do
    t2 = :erlang.monotonic_time(:microsecond)
    Logger.error("Pong TIMEOUT!!")

    :telemetry.execute(
      [:rabbitmq, :ping, :timeout],
      %{rtt: t2 - t1},
      %{target: from}
    )

    {:next_state, :send_ping, {chan, pids}, [{:next_event, :internal, :send_ping}]}
  end
end
