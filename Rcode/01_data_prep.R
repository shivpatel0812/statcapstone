source(file.path(ROOT, "Rcode", "00_project_setup.R"))

freq_to_weekly <- function(freq, unit) {
  ifelse(is.na(freq) | freq >= 9999, NA,
  ifelse(unit == "b'D'", freq * 7,
  ifelse(unit == "b'W'", freq,
  ifelse(unit == "b'M'", freq / 4.33,
  ifelse(unit == "b'Y'", freq / 52, 0)))))
}

prepare_data <- function(path = DATA_PATH) {
  data <- read.csv(path, stringsAsFactors = FALSE)

  numeric_cols <- sapply(data, is.numeric)
  data[numeric_cols] <- lapply(data[numeric_cols], function(x) {
    x[abs(x) < 1e-10 & x != 0] <- NA
    x
  })

  data$Female <- ifelse(data$RIAGENDR == 2, 1, 0)

  data$Fiber_c <- scale(data$total_fiber, center = TRUE, scale = FALSE)
  data$PAD680_c <- scale(data$PAD680, center = TRUE, scale = FALSE)
  data$Sugar_c <- scale(data$total_sugar, center = TRUE, scale = FALSE)
  data$Protein_c <- scale(data$total_protein, center = TRUE, scale = FALSE)

  data$mod_weekly_freq <- freq_to_weekly(data$PAD790Q, data$PAD790U)
  data$PAD800_clean <- ifelse(data$PAD800 >= 9999, NA, data$PAD800)
  data$mod_weekly_min <- data$mod_weekly_freq * data$PAD800_clean

  data$vig_weekly_freq <- freq_to_weekly(data$PAD810Q, data$PAD810U)
  data$PAD820_clean <- ifelse(data$PAD820 >= 9999, NA, data$PAD820)
  data$vig_weekly_min <- data$vig_weekly_freq * data$PAD820_clean

  data$mod_weekly_min[data$PAD790U %in% c("b''", "")] <- 0
  data$vig_weekly_min[data$PAD810U %in% c("b''", "")] <- 0

  data$total_activity_min <- ifelse(
    !is.na(data$mod_weekly_min) & !is.na(data$vig_weekly_min),
    data$mod_weekly_min + 2 * data$vig_weekly_min,
    NA
  )

  data$total_activity_min <- ifelse(
    is.na(data$total_activity_min) & !is.na(data$mod_weekly_min),
    data$mod_weekly_min,
    data$total_activity_min
  )

  data$total_activity_min <- ifelse(
    is.na(data$total_activity_min) & !is.na(data$vig_weekly_min),
    2 * data$vig_weekly_min,
    data$total_activity_min
  )

  data$Activity_c <- scale(data$total_activity_min, center = TRUE, scale = FALSE)
  data$race_eth <- relevel(factor(data$RIDRETH3), ref = "3")

  data
}

make_design <- function(data) {
  svydesign(
    id = ~SDMVPSU,
    strata = ~SDMVSTRA,
    weights = ~WTMEC2YR,
    data = data,
    nest = TRUE
  )
}
