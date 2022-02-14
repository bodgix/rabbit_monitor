defmodule RabbitMonitor.Monitor.Ponger do
  use GenServer
  alias RabbitMonitor.Monitor.Core

  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init({conn, queue_name} = state) do
    :ok = Core.subscribe_queue(conn, queue_name)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_exchange, _from, {conn, queue_name} = state) do
    {:reply, queue_name, state}
  end

  @impl true
  def handle_info({:basic_consume_ok, _msg}, state) do
    Logger.info("Ponger subscription confirmed")
    :ok = Core.register()
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, "ping " <> reply_exch, ctx}, {conn, _queue_name} = state) do
    Logger.info("Ponger got a Ping")
    Core.ack_message(conn, ctx)
    Core.send_pong(conn, reply_exch)
    {:noreply, state}
  end
end
