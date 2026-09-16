defmodule WhatsForLunch.CLI do
  @moduledoc false

  alias WhatsForLunch.Art
  alias WhatsForLunch.Filter
  alias WhatsForLunch.Loader
  alias WhatsForLunch.Restaurant

  def run(opts \\ []) do
    io = Keyword.get(opts, :io, IO)
    sleep_ms = Keyword.get(opts, :sleep_ms, 400)
    path = Keyword.get(opts, :path, Loader.default_path())
    restaurants = WhatsForLunch.restaurants(path)

    io.puts(Art.banner())
    io.puts("  #{length(restaurants)} spots loaded (messy rows cleaned, dupes merged).\n")

    prompt_until_pick(io, sleep_ms, restaurants)
  end

  defp prompt_until_pick(io, sleep_ms, restaurants) do
    cuisine = ask_cuisine(io, restaurants)
    dietary = ask_dietary(io, restaurants)
    max_price = ask_price(io)
    max_miles = ask_miles(io)
    weights = ask_weights(io)

    criteria = %{
      cuisine: cuisine,
      dietary: dietary,
      max_price: max_price,
      max_miles: max_miles
    }

    case WhatsForLunch.pick(restaurants, criteria, weights) do
      [] ->
        io.puts("\n  Nothing matched those filters.")

        if yes?(io, "Relax filters and try again? [Y/n] ") do
          io.puts("")
          prompt_until_pick(io, sleep_ms, restaurants)
        else
          io.puts("  Enjoy starving, I guess.")
        end

      [winner | runners] ->
        drumroll(io, sleep_ms)
        print_winner(io, winner)
        print_runners(io, runners)
    end
  end

  defp ask_cuisine(io, restaurants) do
    choices = Filter.cuisine_choices(restaurants)

    io.puts("Cuisines we know about:")

    choices
    |> Enum.with_index(1)
    |> Enum.each(fn {name, i} -> io.puts("  #{pad(i)}. #{name}") end)

    answer = prompt(io, "Cuisine number or name (blank = any): ")

    case Integer.parse(answer) do
      _ when answer in ["", "all"] ->
        nil

      {n, ""} when n == 0 ->
        nil

      {n, ""} when n >= 1 and n <= length(choices) ->
        Enum.at(choices, n - 1)

      _ ->
        blank_to_nil(answer)
    end
  end

  defp ask_dietary(io, restaurants) do
    choices = Filter.dietary_choices(restaurants)

    io.puts("\nDietary restrictions (comma-separated, blank = none):")

    choices
    |> Enum.with_index(1)
    |> Enum.each(fn {name, i} -> io.puts("  #{i}. #{name}") end)

    answer = prompt(io, "Pick (blank = none): ")
    parse_dietary_picks(answer, choices)
  end

  defp parse_dietary_picks(answer, choices) do
    tokens =
      answer
      |> String.downcase()
      |> String.split([",", ";", " "], trim: true)

    cond do
      tokens == [] ->
        nil

      Enum.all?(tokens, &(&1 in ["0", "none"])) ->
        nil

      true ->
        tokens
        |> Enum.reject(&(&1 in ["0", "none"]))
        |> Enum.map(&dietary_token(&1, choices))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> case do
          [] -> nil
          list -> list
        end
    end
  end

  defp dietary_token(token, choices) do
    case Integer.parse(token) do
      {n, ""} when n >= 1 and n <= length(choices) ->
        Enum.at(choices, n - 1)

      _ ->
        blank_to_nil(token)
    end
  end

  defp ask_price(io) do
    io.puts("\nMax price: blank = any  1) $  2) $$  3) $$$  4) $$$$")
    answer = prompt(io, "Pick (blank = any): ")

    case answer do
      n when n in ["", "any"] -> nil
      "1" -> 1
      "2" -> 2
      "3" -> 3
      "4" -> 4
      "$" -> 1
      "$$" -> 2
      "$$$" -> 3
      "$$$$" -> 4
      _ -> nil
    end
  end

  defp ask_miles(io) do
    answer = prompt(io, "\nMax miles from the office (blank = any): ")

    case Float.parse(answer) do
      {miles, _} when miles >= 0 -> miles
      _ -> nil
    end
  end

  defp ask_weights(io) do
    io.puts("\nHow much does each matter? 0 = ignore, 5 = must-have.")
    io.puts("Closer + higher-rated can beat a slightly closer mediocre option if rating has weight.\n")

    %{
      distance: ask_weight(io, "Closeness"),
      rating: ask_weight(io, "Rating"),
      price: ask_weight(io, "Cheapness"),
      recency: ask_weight(io, "Haven't been in a while")
    }
  end

  defp ask_weight(io, label) do
    answer = prompt(io, "  #{label} (0-5): ")

    case answer do
      "" ->
        0

      _ ->
        case Integer.parse(answer) do
          {n, ""} when n >= 0 and n <= 5 ->
            n

          _ ->
            io.puts("  That's not an option. Pick 0-5.")
            ask_weight(io, label)
        end
    end
  end

  defp drumroll(io, sleep_ms) do
    io.puts("\n  consulting the lunch council")

    Enum.each([".", ".", "."], fn dot ->
      io.write(dot)
      if sleep_ms > 0, do: Process.sleep(sleep_ms)
    end)

    io.puts("\n")
  end

  defp print_winner(io, %{restaurant: r} = pick) do
    io.puts(Art.for_cuisine(r.cuisines))
    io.puts("  TODAY'S WINNER: #{r.name}")
    io.puts("  #{why(r)}")
    io.puts("  score #{format_score(pick)}  ·  #{why_weights(pick)}")
    io.puts("")
  end

  defp print_runners(io, []) do
    io.puts("  No runners-up — this was the only match.")
  end

  defp print_runners(io, runners) do
    io.puts("  Runners-up (still respectable):")

    runners
    |> Enum.with_index(2)
    |> Enum.each(fn {%{restaurant: r} = pick, n} ->
      io.puts("    #{n}. #{r.name}  —  #{why(r)}  (#{format_score(pick)})")
    end)
  end

  defp why(r) do
    [
      Restaurant.display_cuisine(r),
      Restaurant.display_rating(r) <> "★",
      Restaurant.display_price(r),
      Restaurant.display_distance(r),
      dietary_bit(r)
    ]
    |> Enum.reject(&(&1 in ["", nil]))
    |> Enum.join(" · ")
  end

  defp dietary_bit(%Restaurant{dietary_options: []}), do: nil
  defp dietary_bit(%Restaurant{dietary_options: opts}), do: Enum.join(opts, ", ")

  defp why_weights(%{parts: parts, weights: weights}) do
    [
      weighted_bit("close", weights.distance, parts.distance),
      weighted_bit("rated", weights.rating, parts.rating),
      weighted_bit("cheap", weights.price, parts.price),
      weighted_bit("overdue", weights.recency, parts.recency)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp weighted_bit(_label, weight, _part) when weight == 0, do: nil

  defp weighted_bit(label, _weight, part) do
    "#{label} #{round(part * 100)}%"
  end

  defp format_score(%{score: score, weights: weights}) do
    denom = weights.distance + weights.rating + weights.price + weights.recency
    pct = if denom == 0, do: 0.0, else: score / denom * 100
    :erlang.float_to_binary(pct, decimals: 0) <> "/100"
  end

  defp prompt(io, label) do
    case io.gets(label) do
      :eof -> ""
      nil -> ""
      line -> String.trim(line)
    end
  end

  defp yes?(io, label) do
    answer = prompt(io, label) |> String.downcase()
    answer in ["", "y", "yes"]
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp pad(n) when n < 10, do: " #{n}"
  defp pad(n), do: Integer.to_string(n)
end
