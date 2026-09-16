defmodule WhatsForLunch.FilterTest do
  use ExUnit.Case, async: true

  alias WhatsForLunch.Filter
  alias WhatsForLunch.Restaurant

  defp spot(overrides) do
    struct(
      %Restaurant{
        name: "Spot",
        address: "1 Main",
        cuisines: ["Italian"],
        rating: 4.4,
        price_level: 2,
        price_label: "$$",
        distance_miles: 1.4,
        dietary_options: ["vegetarian"],
        last_visited: ~D[2026-01-01]
      },
      overrides
    )
  end

  test "cuisine is a hard filter with aliases" do
    italian = spot(%{name: "Mama", cuisines: ["Italian"]})
    mexican = spot(%{name: "Salsa", cuisines: ["Tex-Mex"]})
    bbq = spot(%{name: "Smoke", cuisines: ["barbeque"]})

    assert Filter.apply([italian, mexican], %{cuisine: "italian"}) == [italian]
    assert Filter.apply([italian, mexican], %{cuisine: "mexican"}) == [mexican]
    assert Filter.apply([italian, mexican], %{cuisine: "all"}) == [italian, mexican]
    assert Filter.cuisine_matches?(bbq, "BBQ")
    refute Filter.cuisine_matches?(bbq, "mexican")
    assert Filter.cuisine_matches?(%Restaurant{cuisines: ["Tex-Mex"]}, "mexican")
  end

  test "cuisine_choices collapses aliases" do
    spots = [
      spot(%{cuisines: ["BBQ"]}),
      spot(%{cuisines: ["barbecue"]}),
      spot(%{cuisines: ["Tex-Mex"]})
    ]

    assert Filter.cuisine_choices(spots) == ["BBQ", "Tex-Mex"]
  end

  test "dietary requires every selected option" do
    veg = spot(%{dietary_options: ["vegetarian", "vegan"]})
    gf = spot(%{name: "GF", dietary_options: ["vegetarian", "gluten-free"]})
    none = spot(%{name: "Meat", dietary_options: []})

    assert Filter.apply([veg, gf, none], %{dietary: "vegan"}) == [veg]
    assert Filter.apply([veg, gf, none], %{dietary: ["vegetarian", "gluten-free"]}) == [gf]
    assert Filter.apply([veg, gf, none], %{dietary: "none"}) == [veg, gf, none]
    assert Filter.apply([veg, gf, none], %{dietary: []}) == [veg, gf, none]
  end

  test "dietary_choices keeps a stable order" do
    spots = [
      spot(%{dietary_options: ["gluten-free", "vegan"]}),
      spot(%{dietary_options: ["vegetarian", "halal"]})
    ]

    assert Filter.dietary_choices(spots) == ["vegetarian", "vegan", "gluten-free", "halal"]
  end

  test "unknown price and distance still pass hard caps" do
    mystery =
      spot(%{
        name: "Mystery",
        price_level: nil,
        distance_miles: nil
      })

    assert Filter.apply([mystery], %{max_price: 1, max_miles: 0.5}) == [mystery]
  end

  test "known values are capped" do
    pricey = spot(%{price_level: 3, distance_miles: 8.0})
    cheap = spot(%{name: "Cheap", price_level: 1, distance_miles: 0.4})

    assert Filter.apply([pricey, cheap], %{max_price: 1, max_miles: 1}) == [cheap]
  end

  test "empty result when nothing matches" do
    assert Filter.apply([spot(%{})], %{cuisine: "Ethiopian"}) == []
  end
end

defmodule WhatsForLunch.ScorerTest do
  use ExUnit.Case, async: true

  alias WhatsForLunch.Restaurant
  alias WhatsForLunch.Scorer

  defp spot(overrides) do
    struct(
      %Restaurant{
        name: "Spot",
        address: "1 Main",
        cuisines: ["Italian"],
        rating: 4.0,
        price_level: 2,
        price_label: "$$",
        distance_miles: 1.0,
        dietary_options: [],
        last_visited: ~D[2026-06-01]
      },
      overrides
    )
  end

  test "closeness can outweigh rating when weighted higher" do
    close_ok = spot(%{name: "Close", distance_miles: 0.2, rating: 4.0})
    far_great = spot(%{name: "Far", distance_miles: 5.0, rating: 4.9})

    [winner | _] =
      Scorer.rank([close_ok, far_great], %{distance: 5, rating: 1, price: 0, recency: 0})

    assert winner.restaurant.name == "Close"
  end

  test "a slightly farther but much better rated spot can win" do
    close_dud = spot(%{name: "Dud", distance_miles: 0.2, rating: 3.0})
    farther_star = spot(%{name: "Star", distance_miles: 0.5, rating: 4.9})

    [winner | _] =
      Scorer.rank([close_dud, farther_star], %{distance: 3, rating: 5, price: 0, recency: 0})

    assert winner.restaurant.name == "Star"
  end

  test "unknown fields are neutral and do not help" do
    known = spot(%{name: "Known", rating: 4.8, distance_miles: 0.3})
    unknown = spot(%{name: "Unknown", rating: nil, distance_miles: nil})

    [winner, _] =
      Scorer.rank([known, unknown], %{distance: 5, rating: 5, price: 0, recency: 0})

    assert winner.restaurant.name == "Known"

    assert hd(tl(Scorer.rank([known, unknown], %{distance: 5, rating: 5, price: 0, recency: 0}))).parts.rating ==
             0.0
  end

  test "older last_visited scores higher for recency" do
    stale = spot(%{name: "Stale", last_visited: ~D[2025-01-01]})
    fresh = spot(%{name: "Fresh", last_visited: ~D[2026-08-01]})

    [winner | _] =
      Scorer.rank([stale, fresh], %{distance: 0, rating: 0, price: 0, recency: 5})

    assert winner.restaurant.name == "Stale"
  end

  test "cheaper wins when price is the only weight" do
    cheap = spot(%{name: "Cheap", price_level: 1})
    spendy = spot(%{name: "Spendy", price_level: 3})

    [winner | _] =
      Scorer.rank([cheap, spendy], %{distance: 0, rating: 0, price: 5, recency: 0})

    assert winner.restaurant.name == "Cheap"
  end

  test "zero weights fall back to equal weights and top/n" do
    ranked =
      Scorer.rank(
        [spot(%{name: "A", rating: 5.0}), spot(%{name: "B", rating: 3.0})],
        %{distance: 0, rating: 0, price: 0, recency: 0}
      )

    assert length(Scorer.top(ranked, 1)) == 1
    assert hd(ranked).restaurant.name == "A"
  end

  test "rank of empty list is empty" do
    assert Scorer.rank([], %{distance: 1, rating: 1, price: 1, recency: 1}) == []
  end
end
