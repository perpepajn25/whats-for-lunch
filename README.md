# What's for Lunch

Interactive Mix CLI that picks lunch from the office restaurant export (`priv/restaurants.csv`). You set **hard filters** (must-match), then **weights** (how much closeness vs rating vs cheapness vs “haven’t been in a while” should matter). It prints a winner, two runners-up, and a bit of ASCII.

## How to use

Needs [Elixir](https://elixir-lang.org/install.html) (see `mix.exs` for the version constraint).

```bash
mix deps.get
mix lunch
```

The prompts:

1. **Cuisine** — number from the list, a name, or `0` / blank for any cuisine.
2. **Dietary** — comma-separated numbers or names (`vegetarian`, `vegan`, `gluten-free`, plus anything else in the CSV). Blank or `0` means no dietary filter. If you pick more than one, a spot must offer **all** of them.
3. **Max price** — any, `$`, `$$`, `$$$`, or `$$$$`.
4. **Max miles** — number, or blank for any distance.
5. **Weights (0–5)** — closeness, rating, cheapness, recency. `0` means that factor is ignored. Defaults: closeness 5, rating 3, cheapness 2, recency 1.

If no results return from the filters, you can relax them and try again.

Tests:

```bash
mix test
```

The data file is `priv/restaurants.csv`. Same columns as the office export: `name`, `cuisine`, `rating`, `price`, `address`, `distance_miles`, `dietary_options`, `last_visited`.

## How a pick is decided

Pipeline:

```
CSV → clean + merge dupes → hard filters → weighted score → top 3
```

### Hard filters (in or out)

These never contribute to the score. A restaurant either stays in the pool or it does not.

| Filter | Match rule |
| --- | --- |
| Cuisine | Canonical match, including aliases (`barbeque` / `barbecue` / `BBQ`; `Tex-Mex` / `mexican`). Blank / “all” skips the filter. |
| Dietary | Every selected option must appear on the restaurant. Blank / “none” skips. |
| Max price | Known `price_level` must be ≤ the cap. |
| Max miles | Known `distance_miles` must be ≤ the cap. |

Unknown price or distance **still pass** a cap. The assumption is “don’t drop a place because the spreadsheet is incomplete.” Missing cuisine only fails if you asked for a specific cuisine.

### Ranking (among survivors)

Each remaining spot gets a score from four parts, min–max normalized against **this filtered pool** (not the whole CSV):

- **Closeness** — shorter miles scores higher.
- **Rating** — higher stars score higher.
- **Cheapness** — lower `$` level scores higher.
- **Recency** — older `last_visited` scores higher (“haven’t been in a while”). Never-visited / unknown date is treated as missing, not as infinitely overdue.

Weights you typed (0–5) multiply those 0–1 parts. Displayed “score /100” is the weighted sum as a percent of the weight total.

A slightly farther, much better-rated place can beat a close dud **if** rating’s weight is high enough. If every weight is 0, the scorer falls back to equal weights. Ties break on rating.

Missing numeric fields score **neutral (0)** on that part: they stay eligible, they just don’t get credit for closeness / rating / cheapness / recency.

## Features

- `mix lunch` interactive picker with banner, drumroll, cuisine ASCII, winner + runners-up.
- Hard filters for cuisine, dietary (AND), max price, max miles.
- User-set weights for closeness, rating, cheapness, recency.
- Cuisine aliases so BBQ / barbecue / barbeque (and Tex-Mex / Mexican) don’t split the list.
- Dietary prompt lists options actually present in the data (known ones first, extras after).
- Retry loop when filters match nothing.
- CSV ingest via NimbleCSV (quoted commas, short rows).
- Dirty-cell cleanup at load time (see assumptions below).
- Duplicate merge on same name + address.
- Tests covering load, filters, scoring, and scripted CLI runs.

## Assumptions (questions that needed an answer)

These are the product calls baked into the code. Change the code if you change your mind.

### Messy data

The export is not clean. Load-time rules:

| Mess | What we do |
| --- | --- |
| Blank name | Drop the row. |
| Short row (missing trailing columns) | Keep the place; missing fields are `nil` / `[]`. |
| Quoted commas in name/address (`Hello, Sailor`) | Parse as CSV, not split-on-comma. |
| Rating `N/A`, blank, or unparseable | Treat as unrated (`nil`). |
| Rating `47` (or anything outside 0–5) | Treat as unrated. |
| European-style `4,2` | Parse as `4.2`. |
| Distance `812` or other > 50 miles | Treat as unknown (typo / units). |
| Negative miles | Treat as unknown. |
| Blank distance | Unknown. |
| Price `cheap` / `inexpensive` | `$`. |
| Price `$$$$` | Same cap as `$$$` (level 3). Unrecognized price strings → unknown. |
| Dates `YYYY-MM-DD` or `M/D/YYYY` | Parsed; anything else ignored. |
| Future `last_visited` | Ignored (not a visit yet). |
| Extra spaces (`  Thai `, `  Haberdish`) | Trimmed. |
| Dietary `vegetarian;vegan` or comma-separated | Split, downcased, uniqued. |
| Duplicate **same name + same address** (Futo Buta ramen + Japanese, Viva Chicken twice) | Merge: union cuisines and dietary, keep higher rating, later visit, first non-blank price/distance/address. |
| Same name, **different address** (two Sabor locations) | Two restaurants. |

Unknown fields after cleanup stay in the dataset. They are not deleted just because rating or miles is missing.

### Filters vs ranking

Question: should “Italian that’s closest, but rating still matters, and closeness can beat rating” be a strict sort (first criterion always wins) or a score?

**Answer we shipped:** cuisine / dietary / price cap / mile cap are **hard filters**. Distance, rating, price, and recency are a **weighted score** on whoever is left. You set the weights so closeness can outweigh rating, or a slightly farther star can win.

Not shipped: weighting cuisine match itself (no “80% Italian”). Not shipped: strict cascade where the 2nd factor is only a tiebreaker.

Other filter calls:

- **Dietary AND, not OR.** Vegetarian + gluten-free means both, not either.
- **Unknown price/distance pass hard caps.** They only fail if the value is known and over the limit.
- **Empty filter result is allowed.** The CLI offers a retry instead of silently loosening filters.
- **Always one winner + up to two runners-up** (fewer if the pool is tiny).

### Scoring details that were easy to get wrong

- Normalize against the **filtered** set, so “closest” means closest among matches, not among the whole city.
- Missing values are **neutral**, not imputed as average, and not treated as best/worst.
- Recency rewards **staleness**, not “went recently.”
- If you zero every weight, equal weights — otherwise the math is a divide-by-zero shrug.

## Out of Scope
- Persistence Layer
- Group voting

## Future Features

- Write today’s winner back to `last_visited` so recency updates.
- Hard-exclude “visited in the last N days” instead of only weighting recency.
- Toggle: treat unknown price/distance as **fail** a cap instead of pass.
- Hours / closed today; walk vs drive; weather.
- Random among top N when the office is split.
- Group vote / Slack command / web UI.
- Maps link; multiple CSV sources.
