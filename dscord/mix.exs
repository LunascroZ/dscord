defmodule Dscord.MixProject do
  use Mix.Project

  def project do
    [app: :dscord, version: "0.1.0", elixir: "~> 1.14"]
  end

  def application do
    [mod: {Dscord, []}, extra_applications: [:logger]]
  end
end
