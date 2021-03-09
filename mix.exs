defmodule Ruler.MixProject do
  use Mix.Project

  @source_url "https://github.com/jamesmacaulay/ruler"
  @version "0.1.0"

  def project do
    [
      app: :ruler,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Ruler",
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description() do
    "A forward-chaining rules engine built on an immutable version of the Rete algorithm."
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    []
  end
end
