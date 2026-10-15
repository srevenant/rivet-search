ExUnit.start(capture_log: true)

Supervisor.start_link([Rivet.Search.Test.Repo], strategy: :one_for_one)

Ecto.Adapters.SQL.Sandbox.mode(Rivet.Search.Test.Repo, :manual)
