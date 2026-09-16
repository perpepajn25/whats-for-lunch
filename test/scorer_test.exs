defmodule WhatsForLunch.ScorerTest do
  use ExUnit.Case, async: true

  alias WhatsForLunch.Fixtures
  alias WhatsForLunch.Scorer

  defp spot(overrides), do: Fixtures.restaurant(overrides)

  defp names(ranked), do: Enum.map(ranked, & &1.restaurant.name)

  test "empty pool ranks as empty" do
    assert Scorer.rank([], %{distance: 1, rating: 1, price: 1, recency: 1}) == []
  end

  test "parts are min-max normalized against this pool" do
    near = spot(%{name: "Near", distance_miles: 0.2, rating: 3.0, price_level: 1})
    mid = spot(%{name: "Mid", distance_miles: 2.6, rating: 4.0, price_level: 2})
    far = spot(%{name: "Far", distance_miles: 5.0, rating: 5.0, price_level: 3})

    ranked = Scorer.rank([near, mid, far], %{distance: 1, rating: 1, price: 1, recency: 0})
    by_name = Map.new(ranked, &{&1.restaurant.name, &1.parts})

    assert by_name["Near"].distance == 1.0
    assert by_name["Far"].distance == 0.0
    assert_in_delta by_name["Mid"].distance, 0.5, 0.0001

    assert by_name["Near"].rating == 0.0
    assert by_name["Far"].rating == 1.0
    assert_in_delta by_name["Mid"].rating, 0.5, 0.0001

    assert by_name["Near"].price == 1.0
    assert by_name["Far"].price == 0.0
    assert_in_delta by_name["Mid"].price, 0.5, 0.0001
  end

  test "score is the weighted sum of 0–1 parts" do
    cheap_close = spot(%{name: "A", distance_miles: 0.0, rating: 5.0, price_level: 1})
    spendy_far = spot(%{name: "B", distance_miles: 10.0, rating: 0.0, price_level: 3})
    weights = %{distance: 2, rating: 3, price: 1, recency: 0}

    [winner, loser] = Scorer.rank([cheap_close, spendy_far], weights)

    assert winner.restaurant.name == "A"
    assert winner.score == 2 * 1.0 + 3 * 1.0 + 1 * 1.0 + 0 * winner.parts.recency
    assert loser.score == 0.0
  end

  test "closeness can outweigh rating when its weight is higher" do
    close_ok = spot(%{name: "Close", distance_miles: 0.2, rating: 4.0})
    far_great = spot(%{name: "Far", distance_miles: 5.0, rating: 4.9})

    ranked = Scorer.rank([close_ok, far_great], %{distance: 5, rating: 1, price: 0, recency: 0})
    assert names(ranked) == ["Close", "Far"]
  end

  test "a slightly farther but much better-rated spot can win" do
    close_dud = spot(%{name: "Dud", distance_miles: 0.2, rating: 3.0})
    farther_star = spot(%{name: "Star", distance_miles: 0.5, rating: 4.9})

    ranked = Scorer.rank([close_dud, farther_star], %{distance: 3, rating: 5, price: 0, recency: 0})
    assert hd(ranked).restaurant.name == "Star"
  end

  test "cheaper wins when price is the only weight" do
    ranked =
      Scorer.rank(
        [spot(%{name: "Cheap", price_level: 1}), spot(%{name: "Spendy", price_level: 3})],
        %{distance: 0, rating: 0, price: 5, recency: 0}
      )

    assert hd(ranked).restaurant.name == "Cheap"
  end

  test "older last_visited scores higher; never-visited is missing, not oldest" do
    stale = spot(%{name: "Stale", last_visited: ~D[2025-01-01]})
    fresh = spot(%{name: "Fresh", last_visited: ~D[2026-08-01]})
    never = spot(%{name: "Never", last_visited: nil})

    recency_only = %{distance: 0, rating: 0, price: 0, recency: 5}

    assert names(Scorer.rank([stale, fresh], recency_only)) == ["Stale", "Fresh"]

    [winner, loser] = Scorer.rank([stale, never], recency_only)
    assert winner.restaurant.name == "Stale"
    assert winner.parts.recency == 1.0
    assert loser.parts.recency == 0.0
  end

  test "missing numeric fields score 0 on that part and never beat a known best" do
    known = spot(%{name: "Known", rating: 4.8, distance_miles: 0.3, price_level: 1})
    unknown = spot(%{name: "Unknown", rating: nil, distance_miles: nil, price_level: nil})

    [winner, other] =
      Scorer.rank([known, unknown], %{distance: 5, rating: 5, price: 5, recency: 0})

    assert winner.restaurant.name == "Known"
    assert other.parts.distance == 0.0
    assert other.parts.rating == 0.0
    assert other.parts.price == 0.0
  end

  test "when every known value in a part is the same, that part is 1.0" do
    a = spot(%{name: "A", distance_miles: 2.0, rating: 4.0})
    b = spot(%{name: "B", distance_miles: 2.0, rating: 4.0})

    [first, second] = Scorer.rank([a, b], %{distance: 1, rating: 1, price: 0, recency: 0})
    assert first.parts.distance == 1.0
    assert second.parts.distance == 1.0
    assert first.parts.rating == 1.0
  end

  test "a pool with only missing values stays at 0 for that part" do
    a = spot(%{name: "A", rating: nil, distance_miles: nil, price_level: nil, last_visited: nil})
    b = spot(%{name: "B", rating: nil, distance_miles: nil, price_level: nil, last_visited: nil})

    ranked = Scorer.rank([a, b], %{distance: 1, rating: 1, price: 1, recency: 1})
    assert Enum.all?(ranked, &(&1.parts == %{distance: 0.0, rating: 0.0, price: 0.0, recency: 0.0}))
    assert Enum.all?(ranked, &(&1.score == 0.0))
  end

  test "zero weights fall back to equal weights" do
    ranked =
      Scorer.rank(
        [spot(%{name: "A", rating: 5.0}), spot(%{name: "B", rating: 3.0})],
        %{distance: 0, rating: 0, price: 0, recency: 0}
      )

    assert hd(ranked).restaurant.name == "A"
    assert hd(ranked).weights == %{distance: 1, rating: 1, price: 1, recency: 1}
  end

  test "negative weights are treated as 0" do
    close = spot(%{name: "Close", distance_miles: 0.1, rating: 3.0})
    far = spot(%{name: "Far", distance_miles: 9.0, rating: 5.0})

    ranked = Scorer.rank([close, far], %{distance: -5, rating: 5, price: 0, recency: 0})
    assert hd(ranked).restaurant.name == "Far"
    assert hd(ranked).weights.distance == 0
  end

  test "string weight keys work the same as atoms" do
    close = spot(%{name: "Close", distance_miles: 0.1, rating: 3.0})
    far = spot(%{name: "Far", distance_miles: 9.0, rating: 5.0})

    ranked = Scorer.rank([close, far], %{"distance" => 5, "rating" => 0, "price" => 0, "recency" => 0})
    assert hd(ranked).restaurant.name == "Close"
  end

  test "equal scores break ties on rating, then top/n truncates" do
    low = spot(%{name: "Low", rating: 3.0, distance_miles: 1.0})
    high = spot(%{name: "High", rating: 4.9, distance_miles: 1.0})
    mid = spot(%{name: "Mid", rating: 4.0, distance_miles: 1.0})

    ranked = Scorer.rank([low, high, mid], %{distance: 5, rating: 0, price: 0, recency: 0})
    assert names(ranked) == ["High", "Mid", "Low"]
    assert Enum.map(Scorer.top(ranked, 2), & &1.restaurant.name) == ["High", "Mid"]
    assert length(Scorer.top(ranked, 10)) == 3
  end
end
