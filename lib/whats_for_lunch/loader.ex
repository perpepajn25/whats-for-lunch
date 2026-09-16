defmodule WhatsForLunch.Loader do
  @moduledoc false

  alias WhatsForLunch.Restaurant

  @default_path Path.expand("../../priv/restaurants.csv", __DIR__)
  @max_plausible_rating 5.0
  @min_plausible_rating 0.0
  @max_plausible_miles 50.0

  def default_path, do: @default_path

  def load(path \\ @default_path) do
    path
    |> File.read!()
    |> parse_rows()
    |> Enum.map(&row_to_restaurant/1)
    |> Enum.reject(&is_nil/1)
    |> merge_duplicates()
    |> Enum.sort_by(& &1.name)
  end

  defp parse_rows(content) do
    case NimbleCSV.RFC4180.parse_string(content, skip_headers: false) do
      [headers | rows] ->
        headers = Enum.map(headers, &String.trim/1)

        Enum.map(rows, fn fields ->
          headers
          |> Enum.zip(fields)
          |> Map.new()
        end)

      _ ->
        []
    end
  end

  defp row_to_restaurant(row) do
    name = blank_to_nil(row["name"])

    if is_nil(name) do
      nil
    else
      %Restaurant{
        name: String.trim(name),
        address: blank_to_nil(row["address"]),
        cuisines: parse_cuisines(row["cuisine"]),
        rating: parse_rating(row["rating"]),
        price_level: parse_price_level(row["price"]),
        price_label: parse_price_label(row["price"]),
        distance_miles: parse_distance(row["distance_miles"]),
        dietary_options: parse_dietary(row["dietary_options"]),
        last_visited: parse_date(row["last_visited"])
      }
    end
  end

  defp parse_cuisines(nil), do: []
  defp parse_cuisines(""), do: []

  defp parse_cuisines(value) do
    case String.trim(value) do
      "" -> []
      trimmed -> [trimmed]
    end
  end

  defp parse_rating(nil), do: nil
  defp parse_rating(""), do: nil

  defp parse_rating(value) do
    normalized =
      value
      |> String.trim()
      |> String.replace(",", ".")

    cond do
      normalized == "" ->
        nil

      String.downcase(normalized) in ["n/a", "na", "none"] ->
        nil

      true ->
        case Float.parse(normalized) do
          {rating, ""} when rating >= @min_plausible_rating and rating <= @max_plausible_rating ->
            rating

          _ ->
            nil
        end
    end
  end

  defp parse_price_level(nil), do: nil
  defp parse_price_level(""), do: nil

  defp parse_price_level(value) do
    case String.trim(value) |> String.downcase() do
      "$" -> 1
      "$$" -> 2
      "$$$" -> 3
      "$$$$" -> 3
      "cheap" -> 1
      "inexpensive" -> 1
      _ -> nil
    end
  end

  defp parse_price_label(nil), do: nil
  defp parse_price_label(""), do: nil

  defp parse_price_label(value) do
    case parse_price_level(value) do
      1 -> "$"
      2 -> "$$"
      3 -> "$$$"
      nil -> nil
    end
  end

  defp parse_distance(nil), do: nil
  defp parse_distance(""), do: nil

  defp parse_distance(value) do
    case Float.parse(String.trim(value)) do
      {miles, ""} when miles >= 0.0 and miles <= @max_plausible_miles -> miles
      _ -> nil
    end
  end

  defp parse_dietary(nil), do: []
  defp parse_dietary(""), do: []

  defp parse_dietary(value) do
    value
    |> String.split([";", ","], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) do
    trimmed = String.trim(value)

    cond do
      match = Regex.run(~r/^(\d{4})-(\d{2})-(\d{2})$/, trimmed) ->
        to_date(match)

      match = Regex.run(~r/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/, trimmed) ->
        [_, month, day, year] = match
        to_date([nil, year, month, day])

      true ->
        nil
    end
  end

  defp to_date([_, year, month, day]) do
    with {y, ""} <- Integer.parse(year),
         {m, ""} <- Integer.parse(month),
         {d, ""} <- Integer.parse(day),
         {:ok, date} <- Date.new(y, m, d) do
      if Date.compare(date, Date.utc_today()) == :gt, do: nil, else: date
    else
      _ -> nil
    end
  end

  defp merge_duplicates(restaurants) do
    restaurants
    |> Enum.group_by(&{String.downcase(&1.name), normalize_address(&1.address)})
    |> Enum.map(fn {_key, group} -> merge_group(group) end)
  end

  defp normalize_address(nil), do: ""
  defp normalize_address(address), do: String.downcase(String.trim(address))

  defp merge_group([restaurant]), do: restaurant

  defp merge_group(group) do
    Enum.reduce(group, fn next, acc ->
      %Restaurant{
        name: acc.name,
        address: acc.address || next.address,
        cuisines: Enum.uniq(acc.cuisines ++ next.cuisines),
        rating: prefer_number(acc.rating, next.rating, :max),
        price_level: acc.price_level || next.price_level,
        price_label: acc.price_label || next.price_label,
        distance_miles: acc.distance_miles || next.distance_miles,
        dietary_options: Enum.uniq(acc.dietary_options ++ next.dietary_options),
        last_visited: later_date(acc.last_visited, next.last_visited)
      }
    end)
  end

  defp prefer_number(nil, other, _), do: other
  defp prefer_number(first, nil, _), do: first
  defp prefer_number(a, b, :max), do: max(a, b)

  defp later_date(nil, other), do: other
  defp later_date(first, nil), do: first
  defp later_date(a, b), do: Enum.max([a, b], Date)

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
