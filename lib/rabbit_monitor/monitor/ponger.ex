defmodule RabbitMonitor.Monitor.Ponger do
  @behaviour :gen_statem
  @subscribe_timeout 1000
  @drain_duration 5000

  alias RabbitMonitor.Monitor.Core

  require Logger

  def start_link(init_arg) do
    :gen_statem.start_link(__MODULE__, init_arg, [])
  end

  @impl true
  def callback_mode(), do: :state_functions

  @impl true
  def init({conn, queue_name} = state) do
    {:ok, :unsubscribed, state, [{:next_event, :internal, :subscribe}]}
  end

  def unsubscribed(:internal, :subscribe, {conn, queue_name} = state) do
    :ok = Core.subscribe_queue(conn, queue_name)
    {:keep_state_and_data, [{:state_timeout, @subscribe_timeout, :subscribe}]}
  end

  def unsubscribed(:info, {:basic_consume_ok, _msg}, state) do
    Logger.debug("Got subscription confirmation for ponger.")
    {:next_state, :drain, state, [{:state_timeout, @drain_duration, :drain}]}
  end

  def unsubscribed(:state_timeout, :subscribe, state) do
    {:stop, {:error, :subscribe_timeout}}
  end

  def drain(:info, {:basic_deliver, _msg, ctx}, {conn, _queue_name} = _state) do
    Logger.debug("Ponger draining an old message")
    Core.ack_message(conn, ctx)
    {:keep_state_and_data, [{:state_timeout, @drain_duration, :drain}]}
  end

  def drain(:state_timeout, :drain, state) do
    Logger.debug("Ponger finished draining old messages")
    {:next_state, :subscribed, state, [{:next_event, :internal, :register}]}
  end

  def subscribed(:internal, :register, _state) do
    :ok = Core.register()
    :keep_state_and_data
  end

  def subscribed({:call, from}, :get_exchange, {_conn, queue_name} = _state) do
    {:keep_state_and_data, [{:reply, from, queue_name}]}
  end

  def subscribed(:info, {:basic_deliver, "ping " <> reply_exch, ctx}, {conn, _queue_name} = state) do
    Logger.debug("Ponger got a Ping")
    Core.ack_message(conn, ctx)
    Core.send_pong(conn, reply_exch)
    :keep_state_and_data
  end
end
