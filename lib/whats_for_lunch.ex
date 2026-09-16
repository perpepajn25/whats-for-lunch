defmodule WhatsForLunch do
  @moduledoc """
  Rank nearby lunch spots from the office restaurant export.
  """

  alias WhatsForLunch.Filter
  alias WhatsForLunch.Loader
  alias WhatsForLunch.Scorer

  def restaurants(path \\ Loader.default_path()) do
    Loader.load(path)
  end

  def pick(restaurants, criteria, weights, count \\ 3) do
    restaurants
    |> Filter.apply(criteria)
    |> Scorer.rank(weights)
    |> Scorer.top(count)
  end
end
