ExUnit.start(capture_log: true)

Supervisor.start_link([Rivet.Test.Repo], strategy: :one_for_one)

Ecto.Adapters.SQL.Sandbox.mode(Rivet.Test.Repo, :manual)
