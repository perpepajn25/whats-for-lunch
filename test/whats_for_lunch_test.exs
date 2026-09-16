defmodule WhatsForLunchTest do
  use ExUnit.Case, async: true

  alias WhatsForLunch.Filter
  alias WhatsForLunch.Fixtures
  alias WhatsForLunch.Loader
  alias WhatsForLunch.Scorer

  defp spot(overrides), do: Fixtures.restaurant(overrides)

  test "restaurants/1 is the loaded, cleaned export" do
    assert WhatsForLunch.restaurants() == Loader.load()
  end

  test "pick filters first, then ranks only the survivors" do
    near_italian =
      spot(%{name: "Near Pasta", cuisines: ["Italian"], distance_miles: 1.0, rating: 4.0})

    far_italian =
      spot(%{name: "Far Pasta", cuisines: ["Italian"], distance_miles: 5.0, rating: 4.0})

    nearer_mexican =
      spot(%{name: "Tacos", cuisines: ["Mexican"], distance_miles: 0.1, rating: 4.0})

    weights = %{distance: 5, rating: 0, price: 0, recency: 0}
    criteria = %{cuisine: "italian"}

    [winner, runner] =
      WhatsForLunch.pick([near_italian, far_italian, nearer_mexican], criteria, weights, 3)

    assert winner.restaurant.name == "Near Pasta"
    assert runner.restaurant.name == "Far Pasta"
    assert winner.parts.distance == 1.0
    refute Enum.any?([winner, runner], &(&1.restaurant.name == "Tacos"))
  end

  test "pick is Filter then Scorer.top" do
    spots = [
      spot(%{name: "A", cuisines: ["Italian"], rating: 4.8, distance_miles: 2.0}),
      spot(%{name: "B", cuisines: ["Italian"], rating: 4.1, distance_miles: 0.4}),
      spot(%{name: "C", cuisines: ["BBQ"], rating: 5.0, distance_miles: 0.1})
    ]

    criteria = %{cuisine: "italian", max_miles: 10}
    weights = %{distance: 2, rating: 5, price: 0, recency: 0}

    expected =
      spots
      |> Filter.apply(criteria)
      |> Scorer.rank(weights)
      |> Scorer.top(2)

    assert WhatsForLunch.pick(spots, criteria, weights, 2) == expected
  end

  test "pick returns [] when filters match nothing" do
    assert WhatsForLunch.pick([spot(%{})], %{cuisine: "Ethiopian"}, %{distance: 1}, 3) == []
  end

  test "office export: BBQ within 5 miles yields at most 3 aliased matches" do
    ranked =
      WhatsForLunch.pick(
        WhatsForLunch.restaurants(),
        %{cuisine: "bbq", dietary: nil, max_price: nil, max_miles: 5},
        %{distance: 5, rating: 3, price: 1, recency: 1},
        3
      )

    assert length(ranked) in 1..3
    assert Enum.all?(ranked, &Filter.cuisine_matches?(&1.restaurant, "bbq"))
    refute "Hello, Sailor" in Enum.map(ranked, & &1.restaurant.name)
    assert ranked == Enum.sort_by(ranked, &{&1.score, &1.restaurant.rating || 0.0}, :desc)
  end
end
