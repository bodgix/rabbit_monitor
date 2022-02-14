defmodule RabbitMonitor.Monitor.Core do
  @moduledoc """
  Functional core for the RMQ monitor
  """

  require Logger
  @pg2_group_name :monitors

  @doc """
  Connects to RMQ and opens a channel.

  Links to the connection and the channel.
  """
  @spec connect_link(list()) :: {:ok, term()} | {:error, term()}
  def connect_link(rmq_opts) do
    Logger.info("Trying to connect with #{inspect(rmq_opts)}")

    with {:ok, conn} <- AMQP.Connection.open(rmq_opts),
         {:ok, chan} <- AMQP.Channel.open(conn) do
      Process.link(conn.pid)
      Process.link(chan.pid)
      {:ok, chan}
    else
      err ->
        Logger.error("Error connecting to RMQ: #{inspect(err)}")
        err
    end
  end

  def subscribe_queue(chan, queue_name) do
    Logger.info("Subscribing to #{queue_name}")
    {:ok, _} = AMQP.Queue.declare(chan, queue_name, durable: false)
    :ok = AMQP.Exchange.fanout(chan, queue_name, durable: false)
    :ok = AMQP.Queue.bind(chan, queue_name, queue_name)
    {:ok, _consumer_tag} = AMQP.Basic.consume(chan, queue_name)
    :ok
  end

  def register() do
    Logger.info("Registering in :pg2")
    :ok = :pg2.create(@pg2_group_name)
    :ok = :pg2.join(@pg2_group_name, self())
    :ok
  end

  def get_receivers() do
    receivers = :pg2.get_members(@pg2_group_name)
    Logger.debug("Receivers are #{inspect(receivers)}")
    receivers
  end

  def ping(chan, pid) do
    exch = RabbitMonitor.Monitor.get_exchange(pid)
    Logger.info("Exchange is #{exch}")
    :ok = AMQP.Basic.publish(chan, exch, exch, "ping #{queue_name()}-pong")
    exch
  end

  def check(chan) do
    receivers = :pg2.get_members(@pg2_group_name)
    Logger.info("Receivers are #{inspect(receivers)}")
    exch = RabbitMonitor.Monitor.get_exchange(List.first(receivers))
    # exch =
    Logger.info("Exchange is #{exch}")

    :ok = AMQP.Basic.publish(chan, exch, exch, "ping #{queue_name()}-pong")
  end

  def ack_message(chan, %{delivery_tag: tag}) do
    Logger.debug("Acking message #{tag}")
    AMQP.Basic.ack(chan, tag)
  end

  def send_pong(chan, exch) do
    Logger.info("Sending :pong to #{exch}")
    AMQP.Basic.publish(chan, exch, exch, "pong #{queue_name()}")
  end

  def queue_name(), do: Node.self() |> Atom.to_string()
end
