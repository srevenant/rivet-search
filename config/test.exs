import Config

config :rivet, app: :rivet_search

config :rivet_search, Rivet.Search.Test.Repo,
  pool_size: 20,
  username: "postgres",
  password: "",
  database: "rivet_search_#{config_env()}",
  hostname: "localhost",
  log: false,
  pool: Ecto.Adapters.SQL.Sandbox
