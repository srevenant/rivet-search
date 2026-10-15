defmodule Rivet.Search.Test.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :rivet_search,
    adapter: Ecto.Adapters.Postgres,
    migration_primary_key: [name: :uuid, type: :binary_id]
end
