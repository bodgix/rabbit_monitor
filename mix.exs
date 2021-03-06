defmodule RabbitMonitor.MixProject do
  use Mix.Project

  def project do
    [
      app: :rabbit_monitor,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RabbitMonitor.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.0"},
      {:libcluster, "~> 3.3.1"},
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics_prometheus, "~> 1.0"}
    ]
  end
end
