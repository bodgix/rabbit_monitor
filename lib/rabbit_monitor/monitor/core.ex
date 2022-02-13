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

  def subscribe_queue(chan) do
    Logger.info("Subscribing to #{queue_name()}")
    {:ok, _} = AMQP.Queue.declare(chan, queue_name(), durable: false)
    :ok = AMQP.Exchange.fanout(chan, queue_name(), durable: false)
    :ok = AMQP.Queue.bind(chan, queue_name(), queue_name())
    :ok
  end

  def register() do
    Logger.info("Registering in :pg2")
    :ok = :pg2.create(@pg2_group_name)
    :ok = :pg2.join(@pg2_group_name, self())
    :ok
  end

  def check() do
    receivers = :pg2.get_members(@pg2_group_name)
    Logger.info("Receivers are #{inspect(receivers)}")
  end

  def queue_name(), do: Node.self() |> Atom.to_string()
end
