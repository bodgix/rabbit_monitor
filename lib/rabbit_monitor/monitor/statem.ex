defmodule RabbitMonitor.Monitor.Statem do
  require Logger
  use AMQP

  @behaviour :gen_statem

  @check_delay 1000

  alias RabbitMonitor.Monitor.Core

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

  @impl :gen_statem
  def callback_mode(), do: :state_functions

  @impl :gen_statem
  def init(init_arg) do
    {:ok, :disconnected, {init_arg, 0}, [{:state_timeout, 1000, :connect}]}
  end

  def disconnected(:state_timeout, :connect, {init_arg, delay}) do
    Logger.info("Trying to connect with #{inspect(init_arg)}")

    with {:ok, chan} <- Core.connect_link(init_arg) do
      {:next_state, :connected, chan,
       [
         {:next_event, :internal, :subscribe_queue},
         {:next_event, :internal, :register}
       ]}
    else
      err ->
        {:keep_state, {init_arg, delay + 1000}, [{:state_timeout, delay, :connect}]}
    end
  end

  def connected(:internal, :subscribe_queue, chan) do
    :ok = Core.subscribe_queue(chan)
    :keep_state_and_data
  end

  def connected(:internal, :register, _chan) do
    :ok = Core.register()
    {:keep_state_and_data, [{:state_timeout, @check_delay, :check}]}
  end

  def connected(:state_timeout, :check, chan) do
    Logger.info("Timeout triggered")
    Core.check()
    {:keep_state_and_data, [{:state_timeout, @check_delay, :check}]}
  end
end
