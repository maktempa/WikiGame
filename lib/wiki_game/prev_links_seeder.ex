defmodule WikiGame.PrevLinksSeeder do
  @moduledoc false

  use GenServer

  alias WikiGame.Scraper

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  @spec init(any()) :: {:ok, any()}
  def init(arg) do
    Scraper.save_links2page(Scraper.get_target_prev_page())

    {:ok, arg}
  end
end

defmodule WikiGame.PrevLinksExtractor do
  @moduledoc false

  @spec get_links2page(binary()) :: list()
  def get_links2page(pages) do
    case pages do
      str when is_binary(str) -> String.split(str)
      _ -> []
    end
  end
end
