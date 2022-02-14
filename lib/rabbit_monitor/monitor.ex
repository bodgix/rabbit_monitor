defmodule RabbitMonitor.Monitor do
  alias RabbitMonitor.Monitor.Supervisor

  defdelegate start_link(init_arg), to: Supervisor
  defdelegate child_spec(opts), to: Supervisor

  def get_exchange(pid) do
    :gen_statem.call(pid, :get_exchange)
  end
end
