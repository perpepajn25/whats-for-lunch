defmodule WhatsForLunch.Art do
  @moduledoc false

  def banner do
    """
     ============================================================
      __        ___           _   _
      \\ \\      / / |__   __ _| |_( )___
       \\ \\ /\\ / /| '_ \\ / _` | __|// __/
        \\ V  V / | | | | (_| | |_  \\__ \\
         \\_/\\_/  |_| |_|\\__,_|\\__| |___/
                    F O R   L U N C H
     ============================================================
    """
  end

  def for_cuisine(cuisines) when is_list(cuisines) do
    key =
      cuisines
      |> Enum.map(&String.downcase/1)
      |> Enum.join(" ")

    cond do
      String.contains?(key, "pizza") ->
        pizza()

      String.contains?(key, "sushi") or String.contains?(key, "ramen") or
          String.contains?(key, "japanese") ->
        sushi()

      String.contains?(key, "bbq") or String.contains?(key, "barbeque") or
          String.contains?(key, "barbecue") ->
        bbq()

      String.contains?(key, "burger") ->
        burger()

      String.contains?(key, "taco") or String.contains?(key, "mexican") or
          String.contains?(key, "tex") ->
        taco()

      String.contains?(key, "italian") ->
        pasta()

      String.contains?(key, "bakery") or String.contains?(key, "sandwich") ->
        bakery()

      String.contains?(key, "chicken") ->
        chicken()

      true ->
        plate()
    end
  end

  defp pizza do
    """
              /\\
             /  \\
            / o  \\
           /  . o \\
          / o  .   \\
         /______.o__\\
    """
  end

  defp sushi do
    """
         .------------------.
        |  (o) ==== (o) ==== |
        |____________________|
           '=============='
    """
  end

  defp bbq do
    """
            )   )   )
           (   (   (
          .-----------.
          | | | | | | |
          |___________|
            |       |
    """
  end

  defp burger do
    """
         .-----------.
        /  ~~~~~~~~~  \\
       |   =========   |
       |   ~~~~~~~~~   |
        \\_____________/
    """
  end

  defp taco do
    """
           .---------.
          /  *  *  *  \\
         | *  *  *  *  |
          \\   \\___/   /
           `---------'
    """
  end

  defp pasta do
    """
         ~  ~~   ~~  ~
        ~~  ~ ~~  ~ ~~
       |  ~ ~~  ~~ ~  |
        \\____________/
    """
  end

  defp bakery do
    """
           .---.  .--.
          /     \\/    \\
         |             |
          \\____________/
    """
  end

  defp chicken do
    """
               ,~
              ( o>
               ) )____
              /  ~  ~  \\
             (          )
              \\________/
                ||  ||
    """
  end

  defp plate do
    """
         | | |                    /|
         | | |     .--------.    | |
         |_|_|    /  ~  ~~   \\   | |
           |     |  *  __  *  |  |_|
           |     |    /  \\    |   |
           |      \\   \\__/   /    |
           |       `--------'     |
    """
  end
end
