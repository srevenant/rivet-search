defmodule Rivet.Search.MixProject do
  use Mix.Project

  @source_url "https://github.com/srevenant/rivet-search"
  def project do
    [
      app: :rivet_search,
      version: "1.0.0-rc.1",
      elixir: "~> 1.18",
      description: "Search columns(filters) on tables with a dynamic ecto query builder system.",
      source_url: @source_url,
      docs: docs(),
      package: package(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        dialyzer: :test
      ],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      compilers: [:es6_maps | Mix.compilers()]
    ]
  end

  def application do
    [
      env: [rivet: [app: :rivet_search] ++ rivet_env(Mix.env())],
      extra_applications: [:logger]
    ]
  end

  defp rivet_env(:test),
    do: [
      lib_dir: "deps/rivet/test/fixtures/rivet/lib",
      priv_dir: "deps/rivet/test/fixtures/rivet/priv"
    ]

  defp rivet_env(_), do: []

  defp elixirc_paths(:test),
    do: ["lib", "test/support", "deps/rivet/test/fixtures/rivet", "test/fixtures/rivet"]

  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "rivet migrate", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      # keystrokes of life
      c: ["compile"]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:es6_maps, "~> 1.0.2"},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.4", only: [:dev, :test], runtime: false},
      {:rivet,
       git: "https://github.com/srevenant/rivet/", branch: "mailer-updates", override: true}
    ]
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs() do
    [
      main: "Rivet.Search",
      extras: ["README.md"],
      groups_for_modules: [
        Base: [Rivet.Search, Rivet.Search.Result, Rivet.Search.Tools],
        Authenticated: [Rivet.Search.MixedAuth],
        Future: [Rivet.Search.Pagination],
        Internals: [~r/^Rivet\.Search\.Filter/, Rivet.Search.Validate]
      ]
    ]
  end
end
