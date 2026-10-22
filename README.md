# Temptation 200 Ultras Race Results - Shiny App
I developed an application using R Shiny that displays results, course records, and lifetime mileage totals for the [Temptation 200 Ultras](https://www.temptation200.com/) (200K, 150K, 100K, 50K, and 10K) in Sand Ridge State Forest near Forest City, Illinois.

All results come from [UltraSignup](https://ultrasignup.com/results_event.aspx?did=121099). Runners are identified by their UltraSignup participant ID rather than by name.

## Updating the data
1. **Race list** - `data-raw/race_ids.csv` lists every UltraSignup race ID by year and event. Only rows with `include = TRUE` are used. Add a new year's IDs (and set `include` to `TRUE`) once its results are posted.
2. **Download** - `R/00_download-results.R` saves each included race's full results to `data-raw/ultrasignup/`, one CSV per race. Races already saved are skipped unless `overwrite <- TRUE`.
3. **Aggregate** - `R/01_data-load.R` counts official finishes only and writes the tables the app reads to `data/` (course records, mileage totals, all results), plus `data/participant_registry.csv`.

If a runner has more than one UltraSignup account, add a row to `data-raw/participant_id_merges.csv` mapping the duplicate ID (`alias_id`) to the ID that should be used (`canonical_id`), then re-run `R/01_data-load.R`. Rows in `data/participant_registry.csv` with `same_name_runners` greater than 1 are possible duplicates (first-name variants such as Matt/Matthew are not flagged automatically). See `CLAUDE.md` for the full year-to-year update procedure.

## Counting rules
- Official finishes are UltraSignup status 1 (finished) and status 6 (finished in a field of fewer than 10 runners). Small fields are common in the 200K and 150K, so status 6 finishes are real finishes.
- Every long-ultra runner starts the 200K and may stop with an official finish at 50K, 100K, or 150K. Each finish is credited at the distance completed and is eligible for that distance's course records.
- Distances are converted to miles for Mileage Totals: 200K = 124.3, 150K = 93.2, 100K = 62.1, 50K = 31.1, and 10K = 6.2.
- Team relays are not included. 2026 was canceled.
- Course records are listed separately for male, female, and non-binary runners.

If you believe there is an error in the data, feel free to send me an email at david.failing@gmail.com.
