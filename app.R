# Load required packages
library(dplyr)
library(DT)
library(here)
library(readr)
library(shiny)
library(shinydashboard)
library(tidyr)

# Define UI for the app
ui <- dashboardPage(
  title = "Temptation 200 Ultras",
  dashboardHeader(
    title = tags$a("Temptation 200", titleWidth = "auto", href = "https://www.temptation200.com/", style = "color: white;")
  ),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Start Here", tabName = "start", icon = icon("list")),
      menuItem("Course Records", tabName = "course_records", icon = icon("trophy")),
      menuItem("Mileage Totals", tabName = "mileage_totals", icon = icon("table")),
      menuItem("All Results", tabName = "all_results", icon = icon("table")),
      menuItem("Register @ Ultrasignup", href = "https://ultrasignup.com/register.aspx?did=129819", icon = icon("clipboard"))
    )
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML('
        .skin-blue .main-header .logo {
          background-color: #3c8dbc;
        }
        .skin-blue .main-header .logo:hover {
          background-color: #3c8dbc;
        }
      ')),
      # BErad Racing theme (colors, fonts); remove this line to revert to the default look
      tags$link(rel = "stylesheet", type = "text/css", href = "berad.css"),
      tags$script(
        '
      $(document).ready(function() {
        $("a[href^=\'http\'],a[href^=\'https\']").not("[href*=\'http://127.0.0.1\'], [href*=\'http://localhost\']").attr("target", "_blank");
      });
      '
      )
    ),
    tags$style(type="text/css",
               ".dataTables_wrapper .dataTables_filter {
        float:left;
    }
    .dataTables_wrapper .dataTables_length {
        float:right;
    }"
    ),
    tabItems(
      tabItem(
        tabName = "start",
        fluidRow(
          box(
            width = 12,
            title = NULL,
            p(HTML("<b>Getting Started</b><br>
              <ul>
                <li><b>Course Records</b> lists the three fastest finishing times at each race distance (200K, 150K, 100K, 50K, and 10K) for male, female, and non-binary runners. Every long-ultra runner starts the 200K and may stop with an official finish at 50K, 100K, or 150K; each finish is credited at the distance completed.</li>
                <li><b>Mileage Totals</b> for all finishers are given, along with their completed distance each year. Distances are converted to miles: 200K = 124.3, 150K = 93.2, 100K = 62.1, 50K = 31.1, and 10K = 6.2. Type a runner's name into the search box to see their lifetime results. By default, the table is sorted by total mileage.</li>
                <li><b>All Results</b> is a merged table of all events for all years. Type a runner's name into the search box to see their lifetime results. You can also search by any combination of other fields. Try '2021 100K' to pull up results for that year and event. By default, the table is sorted by year and event.</li>
                <li><b>Register</b> for the next race so that you don't miss out on the fun!
                <li><b>Course Information</b> below links to the official course description, course photos, and the start/finish area.
              </ul><br>
              If you notice any errors, discrepancies, or have suggestions for improvements, please contact <a href='mailto:david.failing@gmail.com'>David Failing</a>.<br><br>
              <b>Current Course</b><br>
              <ul>
                <li>200K, 150K, 100K, 50K - Loops of an approximately 15.6 mile sandy trail course in Sand Ridge State Forest near Forest City, IL (2 loops per 50K)</li>
                <li>10K - Out and back on the main course to the Purgatory Aid Station</li>
              </ul><br>
              <b>Course Information</b><br>
              <ul>
                <li>Course Description - <a href='https://www.temptation200.com/about-the-course/' target='_blank'>Temptation 200 Ultras</a></li>
                <li>Course Photos - <a href='https://www.temptation200.com/about-the-course/course-photos/' target='_blank'>Temptation 200 Ultras</a></li>
                <li>Camping and Start/Finish Area - <a href='https://goo.gl/maps/c6GaaGVjhhL2' target='_blank'>Google Maps</a></li>
                <li>Official Results and Records - <a href='https://www.temptation200.com/results/' target='_blank'>Temptation 200 Ultras</a></li>
              </ul><br>
              <b>Results Sources</b><br>
              <ul>
                <li>2019 - <a href='https://ultrasignup.com/results_event.aspx?did=61867'>Ultrasignup</a></li>
                <li>2020 - <a href='https://ultrasignup.com/results_event.aspx?did=70941'>Ultrasignup</a></li>
                <li>2021 - <a href='https://ultrasignup.com/results_event.aspx?did=79305'>Ultrasignup</a></li>
                <li>2022 - <a href='https://ultrasignup.com/results_event.aspx?did=91973'>Ultrasignup</a></li>
                <li>2023 - <a href='https://ultrasignup.com/results_event.aspx?did=97518'>Ultrasignup</a></li>
                <li>2024 - <a href='https://ultrasignup.com/results_event.aspx?did=108942'>Ultrasignup</a></li>
                <li>2025 - <a href='https://ultrasignup.com/results_event.aspx?did=121099'>Ultrasignup</a></li>
                <li>2026 - Canceled</li>
              </ul>"))
          )
        )
      ),
      
      tabItem(tabName = "course_records",
              fluidRow(
                box(
                  width = 12,
                  uiOutput("course_records_ui")
                )
              )
      ),
      tabItem(
        tabName = "mileage_totals",
        fluidRow(
          box(
            width = 12,
            DTOutput("mileage_table")
          )
        )
      ),
      tabItem(
        tabName = "all_results",
        fluidRow(
          box(
            width = 12,
            DTOutput("all_results_table")
          )
        )
      )
    )
  )
)

# Define server logic
server <- function(input, output, session) {
  course_records_data <- reactive({
    read_csv(here("data", "course_records.csv")) %>%
      mutate(Rank = paste0(Rank, ".")) %>%
      unite(Ranked_Name, Rank, First, Last, sep = " ") %>% 
      mutate(Record = paste0(Ranked_Name, " (", Age, "), ", Time, ", ", Year)) %>%
      select(Event, Gender, Record)
  })
  
  output$course_records_ui <- renderUI({
    course_records <- course_records_data()
    events <- unique(course_records$Event)
    # Only genders with at least one record are shown (no empty tables)
    genders <- unique(course_records$Gender)
    
    lapply(events, function(event) {
      fluidRow(lapply(genders, function(gender) {
        sub_table_name <- paste0(event, " - ", gender)
        column(
          width = 6,
          course_records %>%
            filter(Event == event, Gender == gender) %>%
            select(Record) %>%
            rename(!!sub_table_name := Record) %>%
            datatable(
              options = list(
                dom = 't',
                pageLength = 10,
                searching = FALSE,
                columnDefs = list(
                  list(targets = 0, visible = FALSE),
                  list(targets = "_all", orderable = FALSE)
                )
              )
            )
        )
      }))
    })
  })
  
  mileage_data <- reactive({
    read_csv(here("data", "mileage_totals.csv")) %>%
      datatable(options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = TRUE,
        columnDefs = list(list(targets = 0, visible = FALSE))
      ))
  })
  
  output$mileage_table <- renderDT({
    mileage_data()
  })
  
  all_results_data <- reactive({
    read_csv(here("data", "all_results.csv")) %>%
      datatable(options = list(
        pageLength = 25,
        scrollX = TRUE,
        scrollY = TRUE,
        columnDefs = list(list(targets = 0, visible = FALSE))
      ))
  })
  
  output$all_results_table <- renderDT({
    all_results_data()
  })
}

# Run the app
shinyApp(ui = ui, server = server)