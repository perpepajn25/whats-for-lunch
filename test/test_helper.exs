ExUnit.start()

defmodule WhatsForLunch.Fixtures do
  @moduledoc false

  alias WhatsForLunch.Restaurant

  def restaurant(overrides \\ %{}) do
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

  def write_csv!(path, body) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, body)
    path
  end
end
