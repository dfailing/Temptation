################################################################################
# Aggregate Temptation 200 Ultras results for the Shiny app
#
# Inputs (run R/00_download-results.R first):
#   data-raw/race_ids.csv                  Race list; only `include = TRUE` rows
#                                          are used. `event`, `distance` and
#                                          `course_record_eligible` come from here.
#   data-raw/ultrasignup/*.csv             One file per race, as downloaded.
#   data-raw/participant_id_merges.csv     Optional. Maps duplicate UltraSignup
#                                          accounts (alias_id) onto the account
#                                          that should be used for aggregation
#                                          and display (canonical_id).
#
# Outputs (read by app.R):
#   data/course_records.csv                Top 3 times per event and gender.
#   data/mileage_totals.csv                Lifetime finishes and miles per runner.
#   data/all_results.csv                   Every finish, all years and events.
#   data/participant_registry.csv          Every UltraSignup ID with its runner
#                                          (after merges); `same_name_runners`
#                                          > 1 flags possible duplicate accounts.
#
# Only official finishes are counted: UltraSignup status 1 (finished) and
# status 6 (finished in a field of fewer than 10 runners, which is common here
# because the 200K and 150K fields are small). Runners are identified by
# UltraSignup `participant_id`, not by name.
#
# Every Temptation finish is credited at the distance achieved: all long-ultra
# runners start the 200K and may stop with an official finish at 50K, 100K or
# 150K, and UltraSignup lists each finish under that distance only. There is
# no separate drop-down event.
################################################################################

# Load required packages
library(dplyr)
library(here)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

# Create subdirectories in case they're missing
if (!dir.exists(here("data"))) dir.create(here("data"))

dir_ultrasignup <- here("data-raw", "ultrasignup")
path_merges <- here("data-raw", "participant_id_merges.csv")

gender_labels <- c(M = "Male", F = "Female", X = "Non-Binary")

# UltraSignup statuses that count as an official finish
finish_statuses <- c(1L, 6L)


# Helper functions -------------------------------------------------------------

# Format a duration in seconds as H:MM:SS (hours may exceed 24)
format_hms <- function(seconds) {
  seconds <- round(seconds)
  sprintf("%d:%02d:%02d", seconds %/% 3600, (seconds %% 3600) %/% 60, seconds %% 60)
}

# Replace empty strings with NA after trimming whitespace
clean_text <- function(x) {
  x <- str_squish(x)
  if_else(x == "", NA_character_, x)
}


# Race list --------------------------------------------------------------------

races <- read_csv(here("data-raw", "race_ids.csv"), show_col_types = FALSE) %>%
  filter(include) %>%
  select(year, race_id, event, distance, course_record_eligible)


# UltraSignup results ----------------------------------------------------------

# Read everything as character so no column type is guessed differently by file
results_raw <- list.files(dir_ultrasignup, pattern = "\\.csv$", full.names = TRUE) %>%
  map(\(file) read_csv(file, col_types = cols(.default = col_character()))) %>%
  bind_rows() %>%
  mutate(race_id = as.integer(race_id))

missing_races <- anti_join(races, distinct(results_raw, race_id), by = "race_id")
if (nrow(missing_races) > 0) {
  warning(
    "No downloaded results for included race_id(s): ",
    paste(missing_races$race_id, collapse = ", "),
    ". Run R/00_download-results.R first.",
    call. = FALSE
  )
}


# Participant ID merges --------------------------------------------------------

if (file.exists(path_merges)) {
  participant_merges <- read_csv(
    path_merges,
    col_types = cols(alias_id = col_integer(), canonical_id = col_integer(),
                     .default = col_character())
  ) %>%
    filter(!is.na(alias_id), !is.na(canonical_id)) %>%
    distinct(alias_id, .keep_all = TRUE)
} else {
  participant_merges <- tibble(alias_id = integer(), canonical_id = integer())
}

if (any(participant_merges$canonical_id %in% participant_merges$alias_id)) {
  warning("Some canonical_id values in participant_id_merges.csv are also ",
          "listed as alias_id values; chains are not followed.", call. = FALSE)
}


# Merged finisher data ---------------------------------------------------------

merged_data <- results_raw %>%
  select(-any_of(c("year", "event", "distance"))) %>%
  inner_join(races, by = "race_id") %>%
  mutate(
    participant_id = as.integer(participant_id),
    status = as.integer(status),
    place = as.integer(place),
    age = as.integer(age),
    time_seconds = as.numeric(time) / 1000
  ) %>%
  filter(status %in% finish_statuses) %>%
  left_join(participant_merges %>% select(alias_id, canonical_id),
            by = c("participant_id" = "alias_id")) %>%
  mutate(
    runner_id = coalesce(canonical_id, participant_id),
    First = clean_text(firstname),
    Last = clean_text(lastname),
    City = clean_text(city),
    State = str_to_upper(clean_text(state)),
    Gender = clean_text(gender),
    `Finish Time` = format_hms(time_seconds)
  ) %>%
  group_by(race_id, Gender) %>%
  # Matches UltraSignup's gender places: ties share a place, next place skips
  mutate(`Division Place` = min_rank(place)) %>%
  ungroup() %>%
  select(
    runner_id, participant_id, race_id, course_record_eligible,
    Year = year, Event = event, Distance = distance,
    `Overall Place` = place, `Division Place`, First, Last,
    `Finish Time`, time_seconds, Age = age, Gender, State, City
  )


# Participant registry ---------------------------------------------------------

# Most recent name, gender and location for each runner (after merges), using
# the latest non-missing value for each field
runner_details <- merged_data %>%
  arrange(runner_id, Year, desc(Distance)) %>%
  group_by(runner_id) %>%
  fill(First, Last, Gender, City, State, .direction = "downup") %>%
  summarize(across(c(First, Last, Gender, City, State), last), .groups = "drop")

participant_registry <- merged_data %>%
  group_by(participant_id, runner_id) %>%
  summarize(first_year = min(Year), last_year = max(Year), finishes = n(),
            .groups = "drop") %>%
  left_join(runner_details, by = "runner_id") %>%
  group_by(name_key = str_to_lower(paste(First, Last))) %>%
  mutate(same_name_runners = n_distinct(runner_id)) %>%
  ungroup() %>%
  select(participant_id, runner_id, First, Last, Gender, City, State,
         first_year, last_year, finishes, same_name_runners) %>%
  arrange(desc(same_name_runners), Last, First, runner_id)


# Course Records ---------------------------------------------------------------

course_records <- merged_data %>%
  filter(course_record_eligible, Gender %in% names(gender_labels)) %>%
  mutate(Gender = factor(gender_labels[Gender], levels = gender_labels)) %>%
  group_by(Event, Gender) %>%
  slice_min(time_seconds, n = 3) %>%
  mutate(Rank = min_rank(time_seconds)) %>%
  ungroup() %>%
  arrange(desc(Distance), Gender, time_seconds) %>%
  select(Event, Gender, Rank, First, Last, Age, Time = `Finish Time`, Year)


# Mileage Totals ---------------------------------------------------------------

year_columns <- as.character(sort(unique(merged_data$Year), decreasing = TRUE))

mileage_totals <- merged_data %>%
  group_by(runner_id) %>%
  summarize(Finishes = n(), `Total Miles` = round(sum(Distance), 1),
            .groups = "drop") %>%
  left_join(
    merged_data %>%
      # Sum in case a runner finished two events in the same year
      group_by(runner_id, Year) %>%
      summarize(Distance = round(sum(Distance), 1), .groups = "drop") %>%
      pivot_wider(names_from = Year, values_from = Distance),
    by = "runner_id"
  ) %>%
  left_join(runner_details, by = "runner_id") %>%
  mutate(Rank = min_rank(desc(`Total Miles`))) %>%
  arrange(Rank, Last, First) %>%
  select(Rank, First, Last, Gender, City, State, Finishes, `Total Miles`,
         all_of(year_columns))


# All Results ------------------------------------------------------------------

all_results <- merged_data %>%
  arrange(desc(Year), desc(Distance), Event, `Overall Place`, Last, First) %>%
  select(Year, Event, Place = `Overall Place`, First, Last, City, State,
         Age, Gender, DP = `Division Place`, Time = `Finish Time`)


# Export Data ------------------------------------------------------------------

write_csv(course_records, here("data", "course_records.csv"), na = "")
write_csv(mileage_totals, here("data", "mileage_totals.csv"), na = "")
write_csv(all_results, here("data", "all_results.csv"), na = "")
write_csv(participant_registry, here("data", "participant_registry.csv"), na = "")

message(
  "Finishes: ", nrow(all_results), " | Runners: ", nrow(mileage_totals),
  " | UltraSignup IDs: ", nrow(participant_registry),
  " | IDs merged: ", sum(participant_registry$participant_id != participant_registry$runner_id)
)
