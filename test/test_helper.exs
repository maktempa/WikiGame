ExUnit.start()
# Ecto.Adapters.SQL.Sandbox.mode(WikiGame.Repo, :manual)

Mox.defmock(WikiGame.MockScraper, for: WikiGame.Scraper)
# Mox.defmock(FlokiMock, for: Floki)
# Mox.defmock(ScraperHelperMock, for: ScraperHelper)
Application.put_env(:wiki_game, :http_client, WikiGame.MockScraper)
