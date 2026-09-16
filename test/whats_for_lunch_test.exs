defmodule WhatsForLunch.LoaderTest do
  use ExUnit.Case, async: true

  alias WhatsForLunch.Loader
  alias WhatsForLunch.Restaurant

  @fixture Path.join(__DIR__, "fixtures/dirty.csv")

  setup do
    File.mkdir_p!(Path.dirname(@fixture))

    File.write!(@fixture, """
    name,cuisine,rating,price,address,distance_miles,dietary_options,last_visited
    Mert's Heart and Soul,Soul Food,4.6,$$,"214 N College St",0.3,vegetarian,2026-07-18
    Salsarita's,Tex-Mex,3.9,$,"435 S Tryon St",812,,2026-08-12
    Charlotte Cafe,American,47,$,"801 S Mint St",0.9,,2026-06-20
    Fin & Fino,,4.5,$$$,"135 Levine Ave",0.5,gluten-free,2026-05-02
    Rooster's,American,4.4,$$$,"150 N College St",,vegetarian,2026-03-29
    Futo Buta,Ramen,4.4,$$,"222 E Bland St",1.1,vegetarian,2026-05-19
    Futo Buta,Japanese,3.9,$$,"222 E Bland St",1.1,,2026-08-11
    Thai Taste,  Thai ,4.1,$,"324 East Blvd",1.5,vegetarian;vegan,2026-06-05
    JJ's Red Hots,Hot Dogs,,$,"1514 East Blvd",1.8,,2026-05-15
    Kid Cashew,Mediterranean,4.3,$$,"1608 East Blvd",1.9,vegetarian;gluten-free,2099-03-14
    Common Market,Deli,N/A,$,"1515 S Tryon St",1.5,vegetarian;vegan,2026-08-07
    Dish,Southern,4.3,$$,"1220 Thomas Ave",-3.4,vegetarian,2026-05-09
      Haberdish,Southern,4.6,$$,"3106 N Davidson St",3.2,vegetarian,2026-08-19
    Letty's,Southern,"4,2",$,"3122 Shamrock Dr",4.5,vegetarian,06/15/2026
    Sweet Lew's BBQ,barbeque,4.6,$,"923 Belmont Ave",2.1,,2026-07-04
    Noble Smoke,Barbecue,4.5,$$,"2216 Freedom Dr",2.9,gluten-free,2026-08-16
    Brooks',Burgers,4.7,cheap,"2710 N Brevard St",2.8,,2026-06-27
    Papi Queso,Sandwiches,4.6,$,"1115 N Brevard St"
    "Hello, Sailor",Seafood,4.4,$$$,"20210 Henderson Rd, Cornelius, NC 28031",19.8,gluten-free,2026-05-25
    Viva Chicken,Peruvian,4.4,$$,"1617 Elizabeth Ave",1.6,gluten-free,2026-08-14
    Viva Chicken,Peruvian,4.4,$$,"1617 Elizabeth Ave",1.6,gluten-free,2026-08-14
    """)

    on_exit(fn -> File.rm(@fixture) end)
    %{restaurants: Loader.load(@fixture)}
  end

  test "drops implausible ratings and distances", %{restaurants: restaurants} do
    cafe = Enum.find(restaurants, &(&1.name == "Charlotte Cafe"))
    salsa = Enum.find(restaurants, &(&1.name == "Salsarita's"))
    dish = Enum.find(restaurants, &(&1.name == "Dish"))

    assert cafe.rating == nil
    assert salsa.distance_miles == nil
    assert dish.distance_miles == nil
  end

  test "parses european ratings, cheap price, and mm/dd/yyyy", %{restaurants: restaurants} do
    letty = Enum.find(restaurants, &(&1.name == "Letty's"))
    brooks = Enum.find(restaurants, &(&1.name == "Brooks'"))

    assert letty.rating == 4.2
    assert letty.last_visited == ~D[2026-06-15]
    assert brooks.price_level == 1
    assert brooks.price_label == "$"
  end

  test "trims names and cuisines; missing cuisine stays eligible", %{restaurants: restaurants} do
    haberdish = Enum.find(restaurants, &(&1.name == "Haberdish"))
    fin = Enum.find(restaurants, &(&1.name == "Fin & Fino"))
    thai = Enum.find(restaurants, &(&1.name == "Thai Taste"))

    assert haberdish.cuisines == ["Southern"]
    assert fin.cuisines == []
    assert thai.cuisines == ["Thai"]
  end

  test "ignores N/A, blank ratings, and future dates", %{restaurants: restaurants} do
    common = Enum.find(restaurants, &(&1.name == "Common Market"))
    jjs = Enum.find(restaurants, &(&1.name == "JJ's Red Hots"))
    kid = Enum.find(restaurants, &(&1.name == "Kid Cashew"))

    assert common.rating == nil
    assert jjs.rating == nil
    assert kid.last_visited == nil
  end

  test "merges same name and address", %{restaurants: restaurants} do
    futo = Enum.find(restaurants, &(&1.name == "Futo Buta"))
    viva_count = Enum.count(restaurants, &(&1.name == "Viva Chicken"))

    assert viva_count == 1
    assert Enum.sort(futo.cuisines) == ["Japanese", "Ramen"]
    assert futo.rating == 4.4
    assert "vegetarian" in futo.dietary_options
    assert futo.last_visited == ~D[2026-08-11]
  end

  test "keeps short rows and quoted commas", %{restaurants: restaurants} do
    papi = Enum.find(restaurants, &(&1.name == "Papi Queso"))
    sailor = Enum.find(restaurants, &(&1.name == "Hello, Sailor"))

    assert %Restaurant{distance_miles: nil, last_visited: nil} = papi
    assert sailor.address =~ "Cornelius"
  end

  test "loads the real priv export" do
    restaurants = Loader.load()
    assert length(restaurants) >= 40
    refute Enum.any?(restaurants, &(&1.rating == 47))
    refute Enum.any?(restaurants, &(&1.distance_miles == 812))
  end
end
