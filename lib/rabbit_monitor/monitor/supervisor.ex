defmodule RabbitMonitor.Monitor.Supervisor do
  use Supervisor

  alias RabbitMonitor.Monitor.Statem

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    children = [
      {Statem, init_arg}
      # {DynamicSupervisor,
      #  [name: RabbitMonitor.Monitor.ListenerSupervisor, strategy: :one_for_one]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
