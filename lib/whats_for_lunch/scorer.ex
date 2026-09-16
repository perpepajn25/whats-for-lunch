defmodule WhatsForLunch.Scorer do
  @moduledoc false

  alias WhatsForLunch.Restaurant

  @type weights :: %{
          distance: number(),
          rating: number(),
          price: number(),
          recency: number()
        }

  @type ranked :: %{
          restaurant: Restaurant.t(),
          score: float(),
          parts: map()
        }

  @neutral 0.0

  def rank(restaurants, weights) when restaurants == [] do
    _ = weights
    []
  end

  def rank(restaurants, weights) do
    weights = normalize_weights(weights)

    stats = %{
      distance: extrema(restaurants, & &1.distance_miles),
      rating: extrema(restaurants, & &1.rating),
      price: extrema(restaurants, & &1.price_level),
      recency: extrema(restaurants, &date_to_int/1)
    }

    restaurants
    |> Enum.map(&scored(&1, weights, stats))
    |> Enum.sort_by(&{&1.score, rating_or_zero(&1.restaurant)}, :desc)
  end

  def top(ranked, n) when n > 0, do: Enum.take(ranked, n)

  defp scored(restaurant, weights, stats) do
    parts = %{
      distance: closeness(restaurant.distance_miles, stats.distance),
      rating: higher_better(restaurant.rating, stats.rating),
      price: lower_better(restaurant.price_level, stats.price),
      recency: lower_better(date_to_int(restaurant), stats.recency)
    }

    score =
      weights.distance * parts.distance +
        weights.rating * parts.rating +
        weights.price * parts.price +
        weights.recency * parts.recency

    %{restaurant: restaurant, score: score, parts: parts, weights: weights}
  end

  defp closeness(nil, _stats), do: @neutral
  defp closeness(value, stats), do: lower_better(value, stats)

  defp higher_better(nil, _stats), do: @neutral

  defp higher_better(_value, {nil, nil}), do: @neutral

  defp higher_better(_value, {min, max}) when min == max, do: 1.0

  defp higher_better(value, {min, max}) do
    (value - min) / (max - min)
  end

  defp lower_better(nil, _stats), do: @neutral
  defp lower_better(_value, {nil, nil}), do: @neutral
  defp lower_better(_value, {min, max}) when min == max, do: 1.0

  defp lower_better(value, {min, max}) do
    (max - value) / (max - min)
  end

  defp extrema(restaurants, fun) do
    values =
      restaurants
      |> Enum.map(fun)
      |> Enum.reject(&is_nil/1)

    case values do
      [] -> {nil, nil}
      values -> {Enum.min(values), Enum.max(values)}
    end
  end

  defp date_to_int(%Restaurant{last_visited: nil}), do: nil
  defp date_to_int(%Restaurant{last_visited: date}), do: Date.to_gregorian_days(date)

  defp rating_or_zero(%Restaurant{rating: nil}), do: 0.0
  defp rating_or_zero(%Restaurant{rating: rating}), do: rating

  defp normalize_weights(weights) do
    map = %{
      distance: to_number(weights[:distance] || weights["distance"]),
      rating: to_number(weights[:rating] || weights["rating"]),
      price: to_number(weights[:price] || weights["price"]),
      recency: to_number(weights[:recency] || weights["recency"])
    }

    if map.distance + map.rating + map.price + map.recency == 0 do
      %{distance: 1, rating: 1, price: 1, recency: 1}
    else
      map
    end
  end

  defp to_number(nil), do: 0
  defp to_number(n) when is_number(n), do: max(n, 0)
end
