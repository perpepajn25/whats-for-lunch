defmodule WhatsForLunch.Restaurant do
  @moduledoc false

  defstruct [
    :name,
    :address,
    :cuisines,
    :rating,
    :price_level,
    :price_label,
    :distance_miles,
    :dietary_options,
    :last_visited
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          address: String.t() | nil,
          cuisines: [String.t()],
          rating: float() | nil,
          price_level: 1..3 | nil,
          price_label: String.t() | nil,
          distance_miles: float() | nil,
          dietary_options: [String.t()],
          last_visited: Date.t() | nil
        }

  def display_cuisine(%__MODULE__{cuisines: []}), do: "Unknown"
  def display_cuisine(%__MODULE__{cuisines: cuisines}), do: Enum.join(cuisines, " / ")

  def display_price(%__MODULE__{price_label: nil}), do: "?"
  def display_price(%__MODULE__{price_label: label}), do: label

  def display_rating(%__MODULE__{rating: nil}), do: "unrated"

  def display_rating(%__MODULE__{rating: rating}),
    do: :erlang.float_to_binary(rating, decimals: 1)

  def display_distance(%__MODULE__{distance_miles: nil}), do: "distance unknown"

  def display_distance(%__MODULE__{distance_miles: miles}) do
    :erlang.float_to_binary(miles, decimals: 1) <> " mi"
  end
end
