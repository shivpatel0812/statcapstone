options(survey.lonely.psu = "adjust")

suppressPackageStartupMessages({
  library(survey)
  library(car)
})

# Backend root = folder that contains both Rcode/ and python_code/combined_data.csv
# (macro_goal_app/backend). Works when getwd() is backend, backend/Rcode, repo root, etc.
find_project_root <- function() {
  candidates <- c(
    getwd(),
    file.path(getwd(), ".."),
    file.path(getwd(), "..", ".."),
    file.path(getwd(), "..", "..", ".."),
    file.path(getwd(), "macro_goal_app", "backend"),
    file.path(getwd(), "backend")
  )
  candidates <- unique(normalizePath(candidates, winslash = "/", mustWork = FALSE))

  for (p in candidates) {
    if (is.na(p) || !nzchar(p)) next
    has_rcode <- file.exists(file.path(p, "Rcode", "00_project_setup.R"))
    has_data <- file.exists(file.path(p, "python_code", "combined_data.csv"))
    if (has_rcode && has_data) {
      return(p)
    }
  }

  stop("Could not find backend root (need Rcode/ and python_code/combined_data.csv).")
}

ROOT <- find_project_root()
DATA_PATH <- file.path(ROOT, "python_code", "combined_data.csv")

cat("Project root:", ROOT, "\n")
cat("Data path:", DATA_PATH, "\n")
