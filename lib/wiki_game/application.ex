defmodule WikiGame.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      # WikiGame.Repo,
      # Start the Telemetry supervisor
      WikiGameWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: WikiGame.PubSub},
      # Start the Endpoint (http/https)
      WikiGameWeb.Endpoint,
      # Start a worker by calling: WikiGame.Worker.start_link(arg)
      # {WikiGame.Worker, arg}

      {Finch, name: MyFinch},
      WikiGame.PrevLinksSeeder
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WikiGame.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WikiGameWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
