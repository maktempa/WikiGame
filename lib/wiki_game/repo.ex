defmodule WikiGame.Repo do
  use Ecto.Repo,
    otp_app: :wiki_game,
    adapter: Ecto.Adapters.Postgres
end
