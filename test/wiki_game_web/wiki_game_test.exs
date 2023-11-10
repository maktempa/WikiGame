defmodule WikiGame.ScraperTest do
  use ExUnit.Case
  # use Mox
  import Mox

  alias WikiGame.Scraper

  setup :verify_on_exit!

  setup do
    expected_content = %{
      :ec1 => """
        <html>
          <body>
            <div id="bodyContent">
              <a href="/wiki/Page1">Page 1</a>
              <a href="/wiki/Page2">Page 2</a>
            </div>
          </body>
        </html>
      """,
      :ec2 => """
        <html>
          <body>
            <div id="bodyContent">
              <a href="/wiki/Page3">Page 3</a>
              <a href="/wiki/Page2">Page 2</a>
              <a href="/wiki/Page101">Page 101 (prelink - leads to target page. Can stop here)</a>
              ...
              <a href="/wiki/TargetPage">Target Page</a>
            </div>
          </body>
        </html>
      """,
      :ec3 => """
        <html>
          <body>
            <div id="bodyContent">
              <a href="/wiki/Page4">Page 4</a>
              <a href="/wiki/Page5">Page 5</a>
            </div>
          </body>
        </html>
      """,
      :ec4 => """
        <html>
          <body>
            <div id="bodyContent">
              <a href="/wiki/Page6">Page 6</a>
            </div>
          </body>
        </html>
      """,
      :ec5 => """
        <html>
          <body>
            <div id="bodyContent">
              <a href="/wiki/Page7">Page 7</a>
              <a href="/wiki/Page5">Page 5</a>
            </div>
          </body>
        </html>
      """,
      :ec6 => """
        <html>
          <body>
            <div id="bodyContent">
            <a href="/wiki/Page8">Page 8</a>
            <a href="somesite123.com/incorrect_path">External (non a wiki) page</a>
            </div>
          </body>
        </html>
      """,
      :ec7 => """
        <html>
          <body>
            <div id="bodyContent">
            </div>
          </body>
        </html>
      """,
      :ec8 => """
        <html>
          <body>
            <div id="bodyContent">
              <a href="/wiki/Page101">Page 101 (prelink - leads to target page. Can stop here)</a>
            </div>
          </body>
        </html>
      """
    }

    {:ok, ec: expected_content}
  end

  test "find_path returns correct path when target page is 1st page" do
    start_url = "/wiki/TargetPage"
    end_url = "/wiki/TargetPage"
    path = Scraper.find_path(start_url, end_url)

    assert path == ["https://en.wikipedia.org/wiki/TargetPage"]
  end

  test "find_path returns empty path when target page doesn't exist", context do
    # save_links2page() usualle take target wiki page as argument, but for testing - it's bevahaviour
    # is overwritten to take string consistnig of prelinks to target page, e.g. "/wiki/page1 wiki/page2"
    # prelinks = links leading to target page, e.g. /wiki/initial_page -> /wiki/prelink_page -> /wiki/target_page
    Scraper.save_links2page("/wiki/Page101 /wiki/Page102 /wiki/Page103")

    WikiGame.MockScraper
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec4}} end)
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec7}} end)

    start_url = "/wiki/Page1"
    end_url = "/wiki/NonExistentPage"
    path = Scraper.find_path(start_url, end_url)

    assert path == []
  end

  test "find_path returns correct path when target page is on 2nd level of link trees", context do
    # save_links2page() usualle take target wiki page as argument, but for testing it's bevahaviour
    # overwritten to take string consistnig of prelinks to target page, e.g. "/wiki/page1 wiki/page2"
    # prelinks = links leading to target page, e.g. /wiki/initial_page -> /wiki/prelink_page -> /wiki/target_page
    Scraper.save_links2page("/wiki/Page101 /wiki/Page102 /wiki/Page103")

    WikiGame.MockScraper
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec1}} end)
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec2}} end)

    start_url = "/wiki/Page0"
    end_url = "/wiki/TargetPage"
    path = Scraper.find_path(start_url, end_url)

    assert path ==
             [
               "https://en.wikipedia.org/wiki/Page0",
               "https://en.wikipedia.org/wiki/Page1",
               "https://en.wikipedia.org/wiki/Page101",
               "https://en.wikipedia.org/wiki/TargetPage"
             ]
  end

  test "find_path returns correct path when target page is on 3nd level of link trees", context do
    Scraper.save_links2page("/wiki/Page101 /wiki/Page102 /wiki/Page103")

    WikiGame.MockScraper
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec1}} end)
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec3}} end)
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec4}} end)
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec5}} end)
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec2}} end)

    start_url = "/wiki/Page0"
    end_url = "/wiki/TargetPage"
    path = Scraper.find_path(start_url, end_url)

    assert path ==
             [
               "https://en.wikipedia.org/wiki/Page0",
               "https://en.wikipedia.org/wiki/Page1",
               "https://en.wikipedia.org/wiki/Page5",
               "https://en.wikipedia.org/wiki/Page101",
               "https://en.wikipedia.org/wiki/TargetPage"
             ]
  end

  test "find_path returns empty path when target page belongs to non-wiki link", context do
    # Prelink Page101 is behind incorrect link: Page0 -> Page8 -> somesite123.com/incorrect_path -> Page101
    # Thus should return empty path
    Scraper.save_links2page("/wiki/Page101 /wiki/Page102 /wiki/Page103")

    WikiGame.MockScraper
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec4}} end)
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec6}} end)
    |> expect(:request, fn :get, _url -> {:ok, %Finch.Response{body: context.ec.ec7}} end)

    start_url = "/wiki/Page0"
    end_url = "/wiki/TargetPage"
    path = Scraper.find_path(start_url, end_url)

    assert path == []
  end
end
