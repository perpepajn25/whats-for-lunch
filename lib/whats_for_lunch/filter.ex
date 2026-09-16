defmodule WhatsForLunch.Filter do
  @moduledoc false

  @type criteria :: %{
          optional(:cuisine) => String.t() | nil,
          optional(:dietary) => String.t() | [String.t()] | nil,
          optional(:max_price) => 1..3 | nil,
          optional(:max_miles) => number() | nil
        }

  @dietary_order ["vegetarian", "vegan", "gluten-free"]

  @cuisine_aliases %{
    "barbeque" => "bbq",
    "barbecue" => "bbq",
    "bbq" => "bbq",
    "mexican" => "mexican",
    "tex-mex" => "mexican",
    "tex mex" => "mexican"
  }

  def apply(restaurants, criteria) when is_map(criteria) do
    restaurants
    |> Enum.filter(&matches?(&1, criteria))
  end

  def cuisine_choices(restaurants) do
    restaurants
    |> Enum.flat_map(& &1.cuisines)
    |> Enum.uniq_by(&canonical_cuisine/1)
    |> Enum.sort()
  end

  def dietary_choices(restaurants) do
    present =
      restaurants
      |> Enum.flat_map(& &1.dietary_options)
      |> MapSet.new()

    known = Enum.filter(@dietary_order, &MapSet.member?(present, &1))

    extras =
      present
      |> MapSet.difference(MapSet.new(@dietary_order))
      |> Enum.sort()

    known ++ extras
  end

  def cuisine_matches?(restaurant, wanted) when is_binary(wanted) do
    wanted_key = canonical_cuisine(wanted)

    Enum.any?(restaurant.cuisines, fn cuisine ->
      canonical_cuisine(cuisine) == wanted_key
    end)
  end

  defp canonical_cuisine(cuisine) when is_binary(cuisine) do
    key =
      cuisine
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/\s+/, " ")

    Map.get(@cuisine_aliases, key, key)
  end

  defp matches?(restaurant, criteria) do
    cuisine_ok?(restaurant, criteria[:cuisine]) and
      dietary_ok?(restaurant, criteria[:dietary]) and
      price_ok?(restaurant, criteria[:max_price]) and
      distance_ok?(restaurant, criteria[:max_miles])
  end

  defp cuisine_ok?(_restaurant, cuisine) when cuisine in [nil, "", "all"], do: true
  defp cuisine_ok?(restaurant, cuisine), do: cuisine_matches?(restaurant, cuisine)

  defp dietary_ok?(_restaurant, dietary) when dietary in [nil, "", "none", []], do: true

  defp dietary_ok?(restaurant, dietary) when is_binary(dietary) do
    dietary_ok?(restaurant, [dietary])
  end

  defp dietary_ok?(restaurant, dietary) when is_list(dietary) do
    wanted =
      dietary
      |> Enum.map(&String.downcase(String.trim(&1)))
      |> Enum.reject(&(&1 in ["", "none"]))

    wanted == [] or Enum.all?(wanted, &(&1 in restaurant.dietary_options))
  end

  defp price_ok?(_restaurant, nil), do: true
  defp price_ok?(%{price_level: nil}, _max), do: true
  defp price_ok?(%{price_level: level}, max) when is_integer(max), do: level <= max

  defp distance_ok?(_restaurant, nil), do: true
  defp distance_ok?(%{distance_miles: nil}, _max), do: true
  defp distance_ok?(%{distance_miles: miles}, max) when is_number(max), do: miles <= max
end
