defmodule WhatsForLunch.TestIO do
  @moduledoc false

  def setup(lines) do
    Process.put({__MODULE__, :lines}, lines)
    Process.put({__MODULE__, :out}, [])
    :ok
  end

  def gets(_prompt) do
    case Process.get({__MODULE__, :lines}, []) do
      [head | tail] ->
        Process.put({__MODULE__, :lines}, tail)
        head <> "\n"

      [] ->
        :eof
    end
  end

  def puts(msg) do
    append(to_string(msg) <> "\n")
  end

  def write(msg) do
    append(to_string(msg))
  end

  def output do
    Process.get({__MODULE__, :out}, [])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp append(chunk) do
    Process.put({__MODULE__, :out}, [chunk | Process.get({__MODULE__, :out}, [])])
    :ok
  end
end

defmodule WhatsForLunch.CLITest do
  use ExUnit.Case

  alias WhatsForLunch.CLI
  alias WhatsForLunch.TestIO

  @fixture Path.join(__DIR__, "fixtures/cli.csv")

  setup do
    WhatsForLunch.Fixtures.write_csv!(@fixture, """
    name,cuisine,rating,price,address,distance_miles,dietary_options,last_visited
    Mama Ricotta's,Italian,4.4,$$,"601 S Kings Dr",1.4,vegetarian,2026-06-15
    Portofino's,Italian,4.0,$$,"3124 Eastway Dr",4.1,vegetarian,2026-01-22
    Bird Pizzeria,Pizza,4.8,$$,"516 E 36th St",3.4,vegetarian,2026-04-01
    Optimist Hall,Food Hall,4.5,$$,"1115 N Brevard St",1.2,vegetarian;vegan;gluten-free,2026-08-28
    La Belle Helene,French,4.5,$$$,"300 S Tryon St",0.3,,2026-03-08
    Cheap Eats,American,3.5,$,"1 Main St",5.0,,2026-01-01
    """)

    on_exit(fn -> File.rm(@fixture) end)
    :ok
  end

  defp run(lines) do
    TestIO.setup(lines)
    CLI.run(io: TestIO, sleep_ms: 0, path: @fixture)
    TestIO.output()
  end

  # cuisine, dietary, max price, max miles, closeness, rating, cheapness, recency
  defp answers(overrides) do
    defaults = %{
      cuisine: "Italian",
      dietary: "",
      price: "",
      miles: "",
      closeness: "5",
      rating: "3",
      cheapness: "2",
      recency: "1"
    }

    taken = Map.merge(defaults, overrides)

    [
      taken.cuisine,
      taken.dietary,
      taken.price,
      taken.miles,
      taken.closeness,
      taken.rating,
      taken.cheapness,
      taken.recency
    ]
  end

  test "Italian + closeness first picks the nearer Italian, not pizza" do
    out = run(answers(%{cuisine: "Italian", closeness: "5", rating: "2", cheapness: "0", recency: "0"}))

    assert out =~ "TODAY'S WINNER: Mama Ricotta's"
    assert out =~ "Portofino's"
    refute out =~ "Bird Pizzeria"
  end

  test "cuisine number maps onto the sorted choice list" do
    # American, Food Hall, French, Italian, Pizza
    out = run(answers(%{cuisine: "4", closeness: "5", rating: "0", cheapness: "0", recency: "0"}))
    assert out =~ "TODAY'S WINNER: Mama Ricotta's"
  end

  test "recency-only among Italians prefers the older visit" do
    out =
      run(
        answers(%{
          cuisine: "Italian",
          closeness: "0",
          rating: "0",
          cheapness: "0",
          recency: "5"
        })
      )

    assert out =~ "TODAY'S WINNER: Portofino's"
  end

  test "max $ drops $$$ even when that spot is closest" do
    out =
      run(
        answers(%{
          cuisine: "",
          price: "1",
          closeness: "5",
          rating: "0",
          cheapness: "0",
          recency: "0"
        })
      )

    refute out =~ "La Belle Helene"
    assert out =~ "TODAY'S WINNER: Cheap Eats"
  end

  test "requires every selected dietary restriction" do
    out = run(answers(%{cuisine: "", dietary: "1,3"}))

    assert out =~ "TODAY'S WINNER: Optimist Hall"
    refute out =~ "Mama Ricotta's"
    refute out =~ "Bird Pizzeria"
  end

  test "blank weights are 0 (ignored); junk is reprompted" do
    out =
      run([
        "Italian",
        "",
        "",
        "",
        "",
        "nope",
        "2",
        "0",
        "0"
      ])

    assert out =~ "That's not an option. Pick 0-5."
    assert out =~ "TODAY'S WINNER: Mama Ricotta's"
  end

  test "offers a retry when filters match nothing, then can succeed" do
    miss = answers(%{cuisine: "Ethiopian"})
    hit = answers(%{cuisine: "Pizza"})

    out = run(miss ++ ["y"] ++ hit)

    assert out =~ "Nothing matched"
    assert out =~ "TODAY'S WINNER: Bird Pizzeria"
  end

  test "declining a retry after an empty pool stops" do
    out = run(answers(%{cuisine: "Ethiopian"}) ++ ["n"])

    assert out =~ "Nothing matched"
    assert out =~ "Enjoy starving"
    refute out =~ "TODAY'S WINNER"
  end
end
