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
    File.mkdir_p!(Path.dirname(@fixture))

    File.write!(@fixture, """
    name,cuisine,rating,price,address,distance_miles,dietary_options,last_visited
    Mama Ricotta's,Italian,4.4,$$,"601 S Kings Dr",1.4,vegetarian,2026-06-15
    Portofino's,Italian,4.0,$$,"3124 Eastway Dr",4.1,vegetarian,2026-01-22
    Bird Pizzeria,Pizza,4.8,$$,"516 E 36th St",3.4,vegetarian,2026-04-01
    Optimist Hall,Food Hall,4.5,$$,"1115 N Brevard St",1.2,vegetarian;vegan;gluten-free,2026-08-28
    """)

    on_exit(fn -> File.rm(@fixture) end)
    :ok
  end

  test "prints a winner and runners-up for italian with closeness first" do
    TestIO.setup([
      "Italian",
      "1",
      "2",
      "10",
      "5",
      "2",
      "0",
      "0"
    ])

    CLI.run(io: TestIO, sleep_ms: 0, path: @fixture)
    out = TestIO.output()

    assert out =~ "TODAY'S WINNER: Mama Ricotta's"
    assert out =~ "Portofino's"
    assert out =~ "Runners-up"
    refute out =~ "Bird Pizzeria"
  end

  test "offers a retry when filters match nothing" do
    TestIO.setup([
      "Ethiopian",
      "",
      "",
      "",
      "5",
      "3",
      "2",
      "1",
      "n"
    ])

    CLI.run(io: TestIO, sleep_ms: 0, path: @fixture)
    out = TestIO.output()

    assert out =~ "Nothing matched"
    assert out =~ "Enjoy starving"
  end

  test "requires every selected dietary restriction" do
    TestIO.setup([
      "",
      "1,3",
      "",
      "",
      "5",
      "3",
      "2",
      "1"
    ])

    CLI.run(io: TestIO, sleep_ms: 0, path: @fixture)
    out = TestIO.output()

    assert out =~ "comma-separated"
    assert out =~ "TODAY'S WINNER: Optimist Hall"
    refute out =~ "Mama Ricotta's"
    refute out =~ "Bird Pizzeria"
  end

  test "treats blank weight as ignore and reprompts junk" do
    TestIO.setup([
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

    CLI.run(io: TestIO, sleep_ms: 0, path: @fixture)
    out = TestIO.output()

    assert out =~ "That's not an option. Pick 0-5."
    refute out =~ "Closeness ["
    assert out =~ "TODAY'S WINNER: Mama Ricotta's"
  end
end

defmodule WhatsForLunch.PickTest do
  use ExUnit.Case, async: true

  test "end-to-end pick on the office export" do
    restaurants = WhatsForLunch.restaurants()

    ranked =
      WhatsForLunch.pick(
        restaurants,
        %{cuisine: "bbq", dietary: nil, max_price: nil, max_miles: 5},
        %{distance: 5, rating: 3, price: 1, recency: 1},
        3
      )

    assert length(ranked) <= 3
    assert length(ranked) >= 1

    names = Enum.map(ranked, & &1.restaurant.name)
    assert Enum.all?(ranked, &WhatsForLunch.Filter.cuisine_matches?(&1.restaurant, "bbq"))
    refute "Hello, Sailor" in names
  end
end
