defmodule RabbitMonitor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: RabbitMonitor.Worker.start_link(arg)
      # {RabbitMonitor.Worker, arg}
      {RabbitMonitor.Monitor, [host: "localhost", user: "guest", password: "guest", port: 5672]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RabbitMonitor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
