source(file.path(ROOT, "Rcode", "00_project_setup.R"))
source(file.path(ROOT, "Rcode", "01_data_prep.R"))

run_audit_vif_main <- function(data, design, make_plots = TRUE) {
  key_vars <- c(
    "BMXBMI", "LBXTC", "BMXWAIST", "LBDGLUSI", "PAD680",
    "total_sugar", "total_fiber", "total_protein", "total_carbs",
    "total_fat", "total_cholesterol", "RIDAGEYR", "Female", "SLD012"
  )

  cat("=== Non-NA counts per variable ===\n")
  for (v in key_vars) {
    cat(sprintf("  %s: %d / %d\n", v, sum(!is.na(data[[v]])), nrow(data)))
  }

  ols_vars <- c(
    "BMXBMI", "LBXTC", "total_sugar", "total_fiber", "total_protein",
    "total_carbs", "total_fat", "total_cholesterol", "PAD680",
    "total_activity_min", "RIDAGEYR", "Female", "SLD012"
  )

  multi_vars <- c(
    "BMXBMI", "BMXWAIST", "LBDGLUSI", "LBXTC", "total_sugar",
    "total_protein", "total_fiber", "total_carbs", "total_fat",
    "total_cholesterol", "PAD680", "total_activity_min",
    "RIDAGEYR", "Female", "SLD012"
  )

  cat(sprintf("\nComplete cases for OLS models: %d / %d\n", sum(complete.cases(data[ols_vars])), nrow(data)))
  cat(sprintf("Complete cases for multivariate models: %d / %d\n", sum(complete.cases(data[multi_vars])), nrow(data)))

  lm_vif_full <- lm(
    BMXBMI ~ total_calories + total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    data = data
  )

  cat("\n=== VIF WITH total_calories ===\n")
  print(vif(lm_vif_full))

  lm_for_vif <- lm(
    BMXBMI ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    data = data
  )

  cat("\n=== VIF WITHOUT total_calories (final) ===\n")
  print(vif(lm_for_vif))

  if (isTRUE(make_plots)) {
    par(mfrow = c(2, 2))
    plot(lm_for_vif, main = "BMI Model Diagnostics")
  }

  svy_bmi <- svyglm(
    BMXBMI ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_chol <- svyglm(
    LBXTC ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_glucose_ols <- svyglm(
    LBDGLUSI ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_waist <- svyglm(
    BMXWAIST ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    design = design
  )

  cat("\n=== Main effects: BMI ===\n")
  print(summary(svy_bmi))
  cat("\n=== Main effects: Cholesterol ===\n")
  print(summary(svy_chol))
  cat("\n=== Main effects: Glucose ===\n")
  print(summary(svy_glucose_ols))
  cat("\n=== Main effects: Waist ===\n")
  print(summary(svy_waist))

  # ---- Multivariate Joint Tests (on main-effects models, no interactions) ----
  predictors <- c("total_fiber", "PAD680", "total_activity_min",
                   "total_protein", "total_sugar")
  outcomes <- list(BMI = svy_bmi, Cholesterol = svy_chol,
                   Waist = svy_waist, Glucose = svy_glucose_ols)

  cat("\n=== Multivariate Joint Tests (Main Effects Models) ===\n")
  for (pred in predictors) {
    cat(sprintf("\n--- %s ---\n", pred))
    for (nm in names(outcomes)) {
      cat(sprintf("  %s: ", nm))
      tt <- regTermTest(outcomes[[nm]], pred)
      cat(sprintf("F = %.3f, p = %.4f\n", tt$Ftest[1], tt$p[1]))
    }
  }

  list(
    lm_vif_full = lm_vif_full,
    lm_for_vif = lm_for_vif,
    svy_bmi = svy_bmi,
    svy_chol = svy_chol,
    svy_glucose_ols = svy_glucose_ols,
    svy_waist = svy_waist
  )
}
