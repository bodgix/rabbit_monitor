defmodule RabbitMonitorTest do
  use ExUnit.Case
  doctest RabbitMonitor

  test "greets the world" do
    assert RabbitMonitor.hello() == :world
  end
end
