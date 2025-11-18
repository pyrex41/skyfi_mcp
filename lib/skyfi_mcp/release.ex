defmodule SkyfiMcp.Release do
  @moduledoc """
  Release tasks for production deployment.

  Used for running migrations on Fly.io or other production environments
  where we can't run `mix` commands.
  """

  @app :skyfi_mcp

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          # Run seed script
          seed_script = Path.join([Application.app_dir(@app, "priv"), "repo", "seeds.exs"])

          if File.exists?(seed_script) do
            Code.eval_file(seed_script)
          else
            IO.puts("No seeds file found at #{seed_script}")
          end
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
