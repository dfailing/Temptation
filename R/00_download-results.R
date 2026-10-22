################################################################################
# Download Temptation 200 Ultras results from UltraSignup
#
# Reads the race list in data-raw/race_ids.csv and saves the full results of
# every race marked `include = TRUE` (all statuses: finished, DNF, DNS, small-field
# finish) to
# data-raw/ultrasignup/, one CSV per race. Races already saved are skipped, so
# the local copies remain usable even if UltraSignup changes or removes access.
#
# To add a new year (e.g. 2027 once results post): set `include` to TRUE for
# its rows in data-raw/race_ids.csv (adding any new race IDs, such as a
# new distance), then source this script.
#
# To re-download races that are already saved (e.g. after UltraSignup corrects
# a result), set `overwrite <- TRUE` below.
################################################################################

# Load required packages
library(dplyr)
library(here)
library(httr)
library(jsonlite)
library(purrr)
library(readr)
library(stringr)

# Settings
overwrite <- FALSE
pause_seconds <- 1 # Pause between requests to be polite to UltraSignup

# Create subdirectories in case they're missing
dir_ultrasignup <- here("data-raw", "ultrasignup")
if (!dir.exists(dir_ultrasignup)) dir.create(dir_ultrasignup, recursive = TRUE)


# Functions --------------------------------------------------------------------

# Fetch one race's results from UltraSignup's results service. Returns a tibble,
# with zero rows if the race has no results or the request/parsing fails.
get_race_results <- function(race_id) {
  event_url <- paste0(
    "https://ultrasignup.com/service/events.svc/results/", race_id,
    "/1/json?_search=false&rows=2000&page=1"
  )

  response <- tryCatch(
    GET(event_url),
    error = function(e) {
      warning("Request failed for race_id ", race_id, ": ", conditionMessage(e),
              call. = FALSE)
      NULL
    }
  )
  if (is.null(response)) return(tibble())

  if (status_code(response) != 200) {
    warning("HTTP ", status_code(response), " for race_id ", race_id,
            call. = FALSE)
    return(tibble())
  }

  results_raw <- tryCatch(
    fromJSON(content(response, as = "text", encoding = "UTF-8"), flatten = TRUE),
    error = function(e) {
      warning("JSON parsing failed for race_id ", race_id, call. = FALSE)
      NULL
    }
  )

  # An empty JSON array (no results posted) parses to an empty list
  if (is.null(results_raw) || length(results_raw) == 0) return(tibble())

  if (!is.data.frame(results_raw)) {
    warning("Unexpected response format for race_id ", race_id, call. = FALSE)
    return(tibble())
  }

  as_tibble(results_raw)
}

# File path for one race's saved results, e.g.
# data-raw/ultrasignup/2025-200k-121099.csv
race_file <- function(year, event, race_id) {
  event_slug <- event %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "-") %>%
    str_remove_all("^-|-$")

  file.path(dir_ultrasignup, paste0(year, "-", event_slug, "-", race_id, ".csv"))
}

# Download and save one race, returning a one-row log of what happened
download_race <- function(year, event, distance, race_id, overwrite = FALSE) {
  path <- race_file(year, event, race_id)
  log_row <- function(outcome, rows = NA_integer_, finishers = NA_integer_) {
    tibble(year, event, race_id, outcome, rows, finishers, file = basename(path))
  }

  if (file.exists(path) && !overwrite) {
    return(log_row("skipped (already saved)"))
  }

  results <- get_race_results(race_id)
  Sys.sleep(pause_seconds)

  # Nothing is written for an empty race, so the next run tries it again
  if (nrow(results) == 0) {
    return(log_row("no results returned", 0L, 0L))
  }

  results %>%
    mutate(year = year, race_id = race_id, event = event, distance = distance,
           .before = everything()) %>%
    write_csv(path, na = "")

  # Finishers: status 1 (finished) or 6 (finished in a field of fewer than 10)
  log_row("downloaded", nrow(results), sum(results$status %in% c(1, 6)))
}


# Download ---------------------------------------------------------------------

races <- read_csv(here("data-raw", "race_ids.csv"), show_col_types = FALSE) %>%
  filter(include)

download_log <- races %>%
  select(year, event, distance, race_id) %>%
  pmap(download_race, overwrite = overwrite) %>%
  bind_rows()

print(download_log, n = Inf)

message(
  "Downloaded: ", sum(download_log$outcome == "downloaded"), " | ",
  "Skipped (already saved): ", sum(download_log$outcome == "skipped (already saved)"), " | ",
  "No results returned: ", sum(download_log$outcome == "no results returned")
)

if (any(download_log$outcome == "no results returned")) {
  warning(
    "These included races returned no results: ",
    paste(download_log$race_id[download_log$outcome == "no results returned"],
          collapse = ", "),
    call. = FALSE
  )
}
