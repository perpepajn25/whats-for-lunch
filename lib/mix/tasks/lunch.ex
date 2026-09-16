defmodule Mix.Tasks.Lunch do
  @shortdoc "Ask what's for lunch"
  @moduledoc """
  Interactive lunch picker over priv/restaurants.csv.

      mix lunch
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    WhatsForLunch.CLI.run()
  end
end
