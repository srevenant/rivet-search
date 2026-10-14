import Config

config :logger, level: :info

config :rivet, repo: Rivet.Search.Test.Repo
config :rivet_search, ecto_repos: [Rivet.Search.Test.Repo]

config :mix_test_watch,
  exclude: [
    ~r{test/fixtures/},
    ~r{_build/},
    ~r{test/\.tmp/}
  ]

import_config "#{config_env()}.exs"
