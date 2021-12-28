defmodule UeberauthQuickbooks.MixProject do
  use Mix.Project

  @source_url "https://github.com/Kwame42/ueberauth_quickbooks"
  
  def project do
    [
      app: :ueberauth_quickbooks,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :oauth2, :ueberauth]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oauth2, "~> 1.0 or ~> 2.0"},
      {:ueberauth, "~> 0.7.0"}
    ]
  end
  
  defp package do
    [
      description: "An Uberauth strategy for Intuit Quickbooks authentication.",
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE"],
      maintainers: ["Kwame Yamgnane"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://hexdocs.pm/ueberauth_quickbooks/changelog.html",
        GitHub: @source_url
      }
    ]
  end

  defp docs do
    [
      extras: ["CHANGELOG.md", "CONTRIBUTING.md", "README.md"],
      main: "readme",
      source_url: @source_url,
      homepage_url: @source_url,
      formatters: ["html"]
    ]
  end
end
