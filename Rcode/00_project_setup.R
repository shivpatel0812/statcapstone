options(survey.lonely.psu = "adjust")

suppressPackageStartupMessages({
  library(survey)
  library(car)
})

find_project_root <- function() {
  candidates <- unique(c(
    normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), "../.."), winslash = "/", mustWork = FALSE)
  ))

  for (p in candidates) {
    if (file.exists(file.path(p, "python_code", "combined_data.csv"))) {
      return(p)
    }
  }

  stop("Could not find project root containing python_code/combined_data.csv")
}

ROOT <- find_project_root()
DATA_PATH <- file.path(ROOT, "python_code", "combined_data.csv")

cat("Project root:", ROOT, "\n")
cat("Data path:", DATA_PATH, "\n")
