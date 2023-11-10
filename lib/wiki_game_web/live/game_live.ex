defmodule WikiGameWeb.GameLive do
  use WikiGameWeb, :live_view

  alias WikiGame.Scraper

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil, route: nil)}
  end

  @impl true
  def handle_event("start", %{"initial-link" => initial_link}, socket) do
    socket =
      case Scraper.parse_link(initial_link) do
        {:ok, path} ->
          Task.async(fn -> Scraper.find_path(path, Scraper.get_target_page()) end)
          socket

        {:error, error} ->
          assign(socket, [error: error, route: nil])
      end

    {:noreply, assign(socket, :route, nil)}
  end

  def handle_event("focus", _params, socket) do
    {:noreply, assign(socket, :error, nil)}
  end

  @impl true
  def handle_info({_ref, [_ | _] = route}, socket) do
    {:noreply, assign(socket, :route, route)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Input full inital wiki page address (english version), e.g.: https://en.wikipedia.org/wiki/Moscow </h1>

    <form phx-submit="start" >
      <div>
        <input
          id="initial-link"
          name="initial-link"
          autocomplete="initial-link"
          autofocus
          phx-focus="focus"
          phx-value-field="initial-link-val"
          required
          placeholder="Wiki address" />
        <div
            phx-click="login-clear-click">
        </div>
        <button type="submit">
            <div>Go!</div>
        </button>

        <div >
          <%= if (@route) do %>
            <%= for link <- @route do %>
              <a href={link} target="_blank"><%= link %></a> ->
            <% end %>
          <% end %>
        </div>

        <div style="color:red">
          <%= if (@error) do %>
            <%= @error%>
          <% end %>
        </div>
      </div>
      </form>
    """
  end
end
