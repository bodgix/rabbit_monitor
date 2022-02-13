defmodule RabbitMonitor.Monitor do
  alias RabbitMonitor.Monitor.Supervisor

  defdelegate start_link(init_arg), to: Supervisor
  defdelegate child_spec(opts), to: Supervisor
end
