# Temptation 200 Ultras Results App

R Shiny app showing course records, lifetime mileage totals, and all results for the Temptation 200 Ultras (200K, 150K, 100K, 50K, 10K; looped trail course in Sand Ridge State Forest near Forest City, IL; Labor Day weekend). Built 2026-10-22 by copying David's Hennepin Hundred app (`../Hennepin`) and following the Project doc `claude/race-app-playbook.md`. Deployed target: shinyapps.io account `runphd` (not yet deployed).

## Working agreement
- **Write only inside this Temptation folder.** Everything else under `Races/` (Hennepin, CMAR, Chillbilly, Cowboy, Potawatomi, Ultrasignup) is read-only reference.
- **Don't change interface elements without explicit approval:** layout, menus, tables, CSS, and server code in `app.R`. Text content can be changed.
- David is fluent in R and the tidyverse. Prefer maintainable, reproducible code: explicit `library()` calls (not `library(tidyverse)`), `here()` paths, and settings driven by CSV rather than hard-coded values.
- Working style for this app (2026-10-22 build): investigate fully, present one plan, then run end to end, stopping only for the download script, irreversible decisions the plan didn't cover, and the final test.

## Environment constraints (Claude sessions)
- **ultrasignup.com is blocked** from Claude's cloud workspace and from the sandbox on David's computer (proxy 403). David runs `R/00_download-results.R` in RStudio himself. Claude reads UltraSignup through the Claude in Chrome extension: on an ultrasignup.com tab, page JS can `fetch()` `/service/events.svc/results/{race_id}/1/json?_search=false&rows=2000&page=1`. Keep results in `window._x` and print compact summaries; tool output truncates near 1,000 characters and is blocked if it looks like query-string data (replace `?&=` in printed URLs).
- CRAN is blocked, but R installs via apt in the cloud workspace: `apt-get install r-base-core r-cran-dplyr r-cran-tidyr r-cran-readr r-cran-purrr r-cran-stringr r-cran-here r-cran-httr r-cran-jsonlite r-cran-shiny r-cran-shinydashboard r-cran-dt` (about 10 minutes).
- Python Playwright and Chromium are preinstalled in the cloud workspace for headless app testing (`shiny::runApp(port = 7788)`, then drive each sidebar tab).
- The sandbox shell on David's computer has Python but no R; `cp`/`mv` work there, deleting needs his permission. Bring files to the cloud with `device_stage_files`; send them back with `device_commit_files`.

## Layout
```
app.R                          Shiny dashboard; reads data/*.csv (column names below are load-bearing)
R/00_download-results.R        UltraSignup -> data-raw/ultrasignup/ (David runs locally)
R/01_data-load.R               data-raw -> data/*.csv (aggregation)
data-raw/race_ids.csv          Every UltraSignup race ID by year/event; include, course_record_eligible, note
data-raw/ultrasignup/          One CSV per race, all statuses: {year}-{event-slug}-{race_id}.csv
data-raw/participant_id_merges.csv  alias_id -> canonical_id for duplicate accounts (header only so far)
data/                          course_records, mileage_totals, all_results, participant_registry
www/GPX/                       Empty (no Temptation GPX files)
.rscignore                     data-raw/, R/, data-export/ excluded from deploys
```

## Pipeline
1. `race_ids.csv`: only `include = TRUE` rows are used. `event`, `distance` (miles) and `course_record_eligible` come from here, not from the downloaded files.
2. `00_download-results.R`: GET the results service URL above. Skips races already saved unless `overwrite <- TRUE`; writes nothing for an empty race, so it retries next run. Its log counts finishers as status 1 or 6.
3. `01_data-load.R`: keeps finishers (`finish_statuses <- c(1L, 6L)`) and maps participant IDs through the merges file, then writes:
   - `course_records.csv`: Event, Gender, Rank, First, Last, Age, Time, Year (top 3 per event and gender; ties kept)
   - `mileage_totals.csv`: Rank, First, Last, Gender, City, State, Finishes, Total Miles, then one column per year (descending)
   - `all_results.csv`: Year, Event, Place, First, Last, City, State, Age, Gender, DP, Time
   - `participant_registry.csv`: participant_id, runner_id, names, years, finishes, same_name_runners (>1 = possible duplicate account)

## UltraSignup data facts
- `status`: 1 = finished, 2 = DNF, 3 = DNS, **6 = finished in a field of fewer than 10**. Status 6 is common here and inconsistently applied (every 2023 ultra and 10K finish is status 6; the 2024 200K with two finishers is status 1). 35 of the 338 finishes are status 6, including the official women's 150K record. No status 4 or 5 occurs.
- Non-finishers have `time = 0`. `time` is milliseconds as a string; finish times are derived from it, not from `formattime`.
- `participant_id` is per person and stable across years. `gender` is only M or F in this data (no X yet; the app shows X as "Non-Binary").
- Ties share `place`; division place uses `min_rank`, which matches UltraSignup `gender_place`. Tied places: 2021 100K p19 (x3), 2023 50K p12, 2025 150K p6, 2025 50K p4.
- **City and State are blank for 106 finishes**: all of 2019 150K/100K/50K and 2020 150K/100K, plus 12 of 23 in 2020 50K. The registry back-fills from later years where a runner returned.
- Each year's results page (`results_event.aspx?did={200K id}`) links to that year's other distances. UltraSignup's event labels vary ("150k", "Not at all Tempted 10k", "Not Tempted 10k"); the 2026 lineup called the 100K "Dirt Circus 100k" and listed no 150K.
- The official site publishes records at https://www.temptation200.com/results/ and links a Google Sheet of all results. As of 2026-10-22 all ten computed #1 records match that page.

## Counting rules (decided by David, 2026-10-22)
- Finishers are status 1 and 6.
- **No drop-down event.** All long-ultra runners start the 200K and may stop with an official finish at 50K, 100K or 150K; UltraSignup lists each finish under the distance achieved only (no runner appears in two events in one year). Every finish is course-record eligible. The 200K DNF/DNS rows are runners with no finish at any distance.
- Distances in miles: 200K = 124.3, 150K = 93.2, 100K = 62.1, 50K = 31.1, 10K = 6.2. Event labels are "200K", "150K", "100K", "50K", "10K".
- The 10K is included and course-record eligible.
- Team relays are excluded (2023's 97523 has no results anyway). 2026 was canceled (listed with `include = FALSE`).
- Two finishes in one year would both count (none so far).
- **Merged accounts:** Matt Hajny (1582444, 10K 2024) is merged into Matthew Hajny (1135125) via `participant_id_merges.csv` (same city, ages line up). Mileage Totals and the registry use the canonical runner; Course Records and All Results keep the name as listed on that result ("Matt" for the 2024 10K). `same_name_runners` only catches exact name matches, so look for first-name variants by hand after each new year.
- Course records: Male, Female and Non-Binary tables, but only genders with at least one record render (`genders <- unique(course_records$Gender)`, as in Hennepin). David chose this (2026-10-22) over empty "No data available" tables on the public site; a Non-Binary table appears automatically once an X runner finishes.
- Register link points at the latest UltraSignup event page (`did=129819`, the canceled 2026 race) until a 2027 page exists.

## Theme (BErad Racing)
- Temptation is now organized by BErad Racing (https://www.beradracing.com/, also CMAR and Localz 50K). The app matches their site: mustard page `#EDD286`, charcoal `#2D2D2A` header/sidebar/table headers, cream `#EAE6DD` rows, Anton (uppercase display) and Epilogue (body) from Google Fonts, 10px rounded controls, flat content with no panels, and a "BE YOU ~ BE RAD" footer line.
- Everything lives in `www/berad.css`, loaded by one `tags$link()` line in `app.R`'s `tags$head`. Remove that line to revert to the stock shinydashboard look. The CSS is self-contained and can be dropped into the CMAR app the same way.
- The start-page headings are the `<b>` elements directly inside `.box-body` (the `<ul>` auto-closes the `<p>`), styled as big Anton headings. The footer is `.content-wrapper::after` (pure CSS, no markup).
- Google Fonts are unreachable from the cloud workspace, so headless screenshots show fallback fonts (and the header may truncate there); check real rendering on David's machine.
- Git: `dfailing/Temptation`. `main` = unstyled baseline (12c5df9); `berad-style` = theme branch. David's folder is a clone with both branches; edits from Claude sessions go through the repo (push a branch, David pulls in RStudio).

## Verification habits
- After a download, compare each file's row and finisher counts with UltraSignup (fetch the results service through Chrome). As of 2026-10-22: 31 races, 384 rows, 338 finishers (303 status 1 + 35 status 6), 238 UltraSignup IDs, 237 runners after the Hajny merge.
- After aggregation: the sum of Mileage Totals' Total Miles equals the sum of its year columns (18,746.0 miles), and All Results row count equals finishers (338).
- Re-running `01_data-load.R` on unchanged inputs reproduces `data/` byte-for-byte (verified 2026-10-22).
- Playwright test 2026-10-22: 10 course-record tables (5 events x Male/Female; Non-Binary appears when data exists), Mileage Totals 237 rows, All Results 338 rows, searches "Hajny" (1), "2021 100K" (24) and "Delheimer" (3) work, no console errors.

## Open tasks
**Before deploying**
- Merge `berad-style` into `main` once David approves the look.
- There's no `rsconnect/` folder, so the first deploy creates a new app. Give it its own name (e.g. "Temptation") so it can't overwrite the live CMAR or Hennepin apps.
- Optional: add `CLAUDE.md` to `.rscignore`.
- After deploying, add the app link to `README.md`.

**When 2027 results post** (the same steps apply to any later year; this file plus `README.md` is the whole procedure, no chat history needed)
1. Open https://ultrasignup.com/results_event.aspx?did=129819 and click the 2027 year link. Note the `did=` of every event listed (200K, 150K, 100K, 50K, 10K, and anything new or renamed). Relay pages live at `relay/teams.aspx`; list them with `include = FALSE`.
2. Add one row per event to `data-raw/race_ids.csv`: `year, race_id, event_ultrasignup (as UltraSignup names it), event ("200K" etc.), distance (miles: 124.3 / 93.2 / 62.1 / 31.1 / 6.2), include = TRUE, course_record_eligible = TRUE, note`.
3. In RStudio, open `Temptation.Rproj` and run `source(here::here("R", "00_download-results.R"))`. Only the new races download; the log prints rows and finishers per race. Compare with the counts shown on each UltraSignup results page.
4. Run `source(here::here("R", "01_data-load.R"))`. Check the message line (finishes, runners, IDs merged) and that `data/` changed only as expected. Look in `data/participant_registry.csv` for `same_name_runners > 1` and for first-name variants (Matt/Matthew style); add merges to `data-raw/participant_id_merges.csv` and re-run if needed.
5. In `app.R` (text only), add a 2027 line under Results Sources (`results_event.aspx?did=<2027 200K id>`) and update the Register link once 2028 registration opens.
6. Run the app locally (`shiny::runApp()`), check every tab, then redeploy to shinyapps.io.
7. Or hand this folder to a Claude session: it should read this file first, then `claude/race-app-playbook.md` in the "Apps - Race Results" Project, and follow the steps above (it cannot reach ultrasignup.com from the workspace; David runs step 3).
