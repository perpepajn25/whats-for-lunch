defmodule WhatsForLunch.FilterTest do
  use ExUnit.Case, async: true

  alias WhatsForLunch.Filter
  alias WhatsForLunch.Fixtures
  alias WhatsForLunch.Restaurant

  defp spot(overrides), do: Fixtures.restaurant(overrides)
  defp names(list), do: Enum.map(list, & &1.name)

  test "cuisine is a hard match, including aliases and extra spaces" do
    italian = spot(%{name: "Mama", cuisines: ["Italian"]})
    mexican = spot(%{name: "Salsa", cuisines: ["Tex-Mex"]})
    bbq = spot(%{name: "Smoke", cuisines: ["barbeque"]})

    assert names(Filter.apply([italian, mexican, bbq], %{cuisine: "italian"})) == ["Mama"]
    assert names(Filter.apply([italian, mexican, bbq], %{cuisine: " mexican "})) == ["Salsa"]
    assert Filter.apply([italian, mexican], %{cuisine: "all"}) == [italian, mexican]
    assert Filter.apply([italian, mexican], %{cuisine: nil}) == [italian, mexican]
    assert Filter.apply([italian, mexican], %{cuisine: ""}) == [italian, mexican]

    assert Filter.cuisine_matches?(bbq, "BBQ")
    assert Filter.cuisine_matches?(bbq, "barbecue")
    assert Filter.cuisine_matches?(%Restaurant{cuisines: ["Tex-Mex"]}, "mexican")
    refute Filter.cuisine_matches?(bbq, "mexican")
  end

  test "cuisine_choices is unique by alias and sorted by original label" do
    spots = [
      spot(%{cuisines: ["BBQ"]}),
      spot(%{cuisines: ["barbecue"]}),
      spot(%{cuisines: ["Tex-Mex"]}),
      spot(%{cuisines: []})
    ]

    assert Filter.cuisine_choices(spots) == ["BBQ", "Tex-Mex"]
  end

  test "dietary is AND: every selected option must be present" do
    veg = spot(%{name: "Veg", dietary_options: ["vegetarian", "vegan"]})
    gf = spot(%{name: "GF", dietary_options: ["vegetarian", "gluten-free"]})
    none = spot(%{name: "Meat", dietary_options: []})

    assert names(Filter.apply([veg, gf, none], %{dietary: "vegan"})) == ["Veg"]
    assert names(Filter.apply([veg, gf, none], %{dietary: ["vegetarian", "gluten-free"]})) == ["GF"]
    assert names(Filter.apply([veg, gf, none], %{dietary: " Vegetarian "})) == ["Veg", "GF"]
    assert Filter.apply([veg, gf, none], %{dietary: "none"}) == [veg, gf, none]
    assert Filter.apply([veg, gf, none], %{dietary: []}) == [veg, gf, none]
    assert Filter.apply([veg, gf, none], %{dietary: nil}) == [veg, gf, none]
  end

  test "dietary_choices lists known options first, then extras alphabetically" do
    spots = [
      spot(%{dietary_options: ["gluten-free", "vegan"]}),
      spot(%{dietary_options: ["vegetarian", "halal"]})
    ]

    assert Filter.dietary_choices(spots) == ["vegetarian", "vegan", "gluten-free", "halal"]
  end

  test "unknown price and distance still pass a cap" do
    mystery = spot(%{name: "Mystery", price_level: nil, distance_miles: nil})
    assert Filter.apply([mystery], %{max_price: 1, max_miles: 0.5}) == [mystery]
  end

  test "known price and miles must be <= the cap, including equality" do
    pricey = spot(%{name: "Pricey", price_level: 3, distance_miles: 8.0})
    cheap = spot(%{name: "Cheap", price_level: 1, distance_miles: 0.4})
    on_cap = spot(%{name: "OnCap", price_level: 1, distance_miles: 1.0})

    assert names(Filter.apply([pricey, cheap, on_cap], %{max_price: 1, max_miles: 1})) ==
             ["Cheap", "OnCap"]
  end

  test "all criteria apply together; empty pool is allowed" do
    keep =
      spot(%{
        name: "Keep",
        cuisines: ["Italian"],
        dietary_options: ["vegetarian"],
        price_level: 2,
        distance_miles: 1.0
      })

    drop =
      spot(%{
        name: "Drop",
        cuisines: ["Italian"],
        dietary_options: ["vegetarian"],
        price_level: 3,
        distance_miles: 1.0
      })

    criteria = %{cuisine: "Italian", dietary: "vegetarian", max_price: 2, max_miles: 2}
    assert names(Filter.apply([keep, drop], criteria)) == ["Keep"]
    assert Filter.apply([keep], %{cuisine: "Ethiopian"}) == []
  end
end
