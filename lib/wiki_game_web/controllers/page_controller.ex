defmodule WikiGameWeb.PageController do
  use WikiGameWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
