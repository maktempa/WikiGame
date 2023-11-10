defmodule WikiGame.Scraper do
  @moduledoc """
    Scrapper helpers
  """
  @callback request(atom(), binary()) :: {:ok, map()} | {:error, any()}

  @queue :queue
  @visited :visited
  @previous_links :prevlinks
  @scheme "https://"
  @host "en.wikipedia.org"
  @target_page "/wiki/Adolf_Hitler"
  @target_prev_page "/w/index.php?title=Special:WhatLinksHere/Adolf_Hitler&limit=5000"

  @spec get_target_page() :: binary()
  def get_target_page, do: @target_page

  @spec get_target_prev_page() :: binary()
  def get_target_prev_page, do: @target_prev_page

  @spec get_prev_links_table_name() :: atom()
  def get_prev_links_table_name, do: @previous_links

  @spec start_cache(
          atom(),
          :bag
          | :compressed
          | :duplicate_bag
          | :named_table
          | :ordered_set
          | :private
          | :protected
          | :public
          | :set
          | {:decentralized_counters, boolean()}
          | {:heir, :none}
          | {:keypos, pos_integer()}
          | {:read_concurrency, boolean()}
          | {:write_concurrency, :auto | false | true}
          | {:heir, pid(), any()}
        ) :: atom() | :ets.tid()
  def start_cache(name, type) do
    if name in :ets.all(), do: :ets.delete(name)
    :ets.new(name, [:named_table, type, :public])
  end

  @spec request(atom(), binary()) :: {:ok, map()} | {:error, any()}
  def request(type, url) do
    type |> Finch.build(url) |> Finch.request(MyFinch)
  end

  def save_links2page(page) do
    start_cache(@previous_links, :set)

    page
    |> prev_links_extractor().get_links2page()
    |> Enum.each(&:ets.insert(@previous_links, {&1}))
  end

  # Gathering wiki links leading to target wiki page. Page should in format:
  # "w/index.php?title=Special:WhatLinksHere/Adolf_Hitler&limit=5000"
  @spec get_links2page(binary(), list()) :: list()
  def get_links2page(page, prevlinks \\ []) do
    doc = get_page(page)

    next_link =
      doc
      |> Floki.find(".mw-nextlink")
      |> List.first()
      |> case do
        {_, _, _} = next -> Floki.attribute(next, "href")
        _ -> []
      end

    links = Floki.find(doc, "#mw-whatlinkshere-list a")

    urls =
      links
      |> Enum.map(&List.first(Floki.attribute(&1, "href")))
      |> Enum.uniq()
      |> Enum.filter(fn
        href when is_binary(href) -> String.contains?(href, "/wiki/")
        _ -> false
      end)

    all_urls = List.flatten(urls, prevlinks)

    case next_link do
      [next | _] -> get_links2page(next, all_urls)
      _ -> all_urls
    end
  end

  @spec get_page(binary()) ::
          [
            binary()
            | {:comment, binary()}
            | {:pi | binary(), binary() | list() | map(), list() | map()}
            | {:doctype, binary(), binary(), binary()}
          ]
          | {:error, %{:__exception__ => true, :__struct__ => atom(), optional(atom()) => any()}}
  def get_page(path) do
    url = "#{@scheme}#{@host}#{path}"

    http_client().request(:get, url)
    |> handle_response()
  end

  @spec find_path(binary(), binary()) :: list()
  def find_path(start_url, end_url) do
    start_cache(@queue, :ordered_set)
    start_cache(@visited, :set)
    path = find_path_helper(start_url, end_url, [])
    Enum.map(path, &String.replace_prefix(&1, "", "#{@scheme}#{@host}"))
  end

  defp find_path_helper(url, url, _path), do: [url]

  defp find_path_helper(url, end_url, path) do
    doc = get_page(url)
    links = Floki.find(doc, "#bodyContent a")

    urls =
      links
      |> Enum.map(&List.first(Floki.attribute(&1, "href")))
      |> Enum.uniq()
      |> Enum.filter(fn
        href when is_binary(href) -> String.contains?(href, "/wiki/")
        _ -> false
      end)

    process_urls(url, urls, end_url, path)
  end

  @spec parse_link(binary() | URI.t()) :: {:error, binary()} | {:ok, nil | binary()}
  def parse_link(link) do
    case URI.parse(link) do
      %URI{:host => @host, :path => path} -> {:ok, path}
      _rest -> {:error, "incorrect url!"}
    end
  end

  defp process_urls(url, urls, end_url, path) do
    cond do
      :ets.lookup(@previous_links, url) != [] ->
        Enum.reverse([end_url, url | path])

      found = Enum.find(urls, fn u -> :ets.lookup(@previous_links, u) != [] end) ->
        Enum.reverse([end_url, found, url | path])

      true ->
        :ets.insert(@visited, {url})
        urls = Enum.reject(urls, &(:ets.lookup(@visited, &1) != []))

        last_url_num =
          case :ets.last(@queue) do
            num when is_number(num) -> num
            _ -> 0
          end

        Enum.reduce(urls, last_url_num + 1, fn link, last ->
          :ets.insert(@queue, {last, {link, [url | path]}})
          last + 1
        end)

        case :ets.last(@queue) do
          :"$end_of_table" ->
            []

          _ ->
            first_url_num = :ets.first(@queue)
            [{_, {first_url, path}}] = :ets.take(@queue, first_url_num)
            find_path_helper(first_url, end_url, path)
        end
    end
  end

  defp http_client, do: Application.get_env(:wiki_game, :http_client, WikiGame.Scraper)

  defp prev_links_extractor,
    do: Application.get_env(:wiki_game, :prev_link_extractor, WikiGame.Scraper)

  defp handle_response({:ok, %Finch.Response{body: body}}) do
    {:ok, doc} = Floki.parse_document(body)
    doc
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end
end
