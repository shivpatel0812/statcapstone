# ==============================================================================
# Module 06: Calorie-Only Models (No Macros - Avoids VIF)
# ==============================================================================
# Purpose: Model total_calories effect on health outcomes WITHOUT including
#          individual macronutrients (protein, carbs, fat, etc.)
#          This avoids multicollinearity since calories = 4*protein + 4*carbs + 9*fat
#
# Models: svyglm for BMI, waist, cholesterol, glucose
# Predictors: total_calories + sedentary + activity + age + sex
# Output: Coefficients for app's calorie recommendation system
# ==============================================================================

library(survey)

run_calorie_models <- function(data, design) {

  cat("\n--- Running Calorie-Only Models (No Macros) ---\n")

  # Check if total_calories exists in data
  if (!"total_calories" %in% names(data)) {
    cat("\nCreating total_calories variable...\n")
    data$total_calories <- 4 * data$total_protein +
                           4 * data$total_carbs +
                           9 * data$total_fat

    # Update survey design with new variable
    design <- svydesign(
      id = ~SDMVPSU,
      strata = ~SDMVSTRA,
      weights = ~WTMEC2YR,
      nest = TRUE,
      data = data
    )
  }

  # Create centered calorie variable for interpretability
  cal_mean <- mean(data$total_calories, na.rm = TRUE)
  data$calories_c <- data$total_calories - cal_mean

  # Update design again with centered variable
  design <- svydesign(
    id = ~SDMVPSU,
    strata = ~SDMVSTRA,
    weights = ~WTMEC2YR,
    nest = TRUE,
    data = data
  )

  cat(sprintf("Mean total calories: %.1f kcal (used for centering)\n", cal_mean))
  cat(sprintf("Range: %.0f - %.0f kcal\n",
              min(data$total_calories, na.rm=TRUE),
              max(data$total_calories, na.rm=TRUE)))

  # ============================================================================
  # Model 1: BMI ~ total_calories + controls
  # ============================================================================
  cat("\n[1] BMI ~ total_calories + PAD680 + total_activity_min + RIDAGEYR + RIAGENDR\n")

  svy_bmi_cal <- svyglm(
    BMXBMI ~ calories_c + PAD680 + total_activity_min + RIDAGEYR + RIAGENDR,
    design = design,
    family = gaussian()
  )

  print(summary(svy_bmi_cal))

  # Test calorie effect
  cal_test_bmi <- regTermTest(svy_bmi_cal, ~ calories_c)
  cat(sprintf("\nCalorie effect on BMI: F=%.3f, p=%.4f\n",
              cal_test_bmi$Ftest[1], cal_test_bmi$p))

  # ============================================================================
  # Model 2: Waist ~ total_calories + controls
  # ============================================================================
  cat("\n[2] Waist ~ total_calories + PAD680 + total_activity_min + RIDAGEYR + RIAGENDR\n")

  svy_waist_cal <- svyglm(
    BMXWAIST ~ calories_c + PAD680 + total_activity_min + RIDAGEYR + RIAGENDR,
    design = design,
    family = gaussian()
  )

  print(summary(svy_waist_cal))

  cal_test_waist <- regTermTest(svy_waist_cal, ~ calories_c)
  cat(sprintf("\nCalorie effect on Waist: F=%.3f, p=%.4f\n",
              cal_test_waist$Ftest[1], cal_test_waist$p))

  # ============================================================================
  # Model 3: Cholesterol ~ total_calories + controls
  # ============================================================================
  cat("\n[3] Cholesterol ~ total_calories + PAD680 + total_activity_min + RIDAGEYR + RIAGENDR\n")

  svy_chol_cal <- svyglm(
    LBDTCSI ~ calories_c + PAD680 + total_activity_min + RIDAGEYR + RIAGENDR,
    design = design,
    family = gaussian()
  )

  print(summary(svy_chol_cal))

  cal_test_chol <- regTermTest(svy_chol_cal, ~ calories_c)
  cat(sprintf("\nCalorie effect on Cholesterol: F=%.3f, p=%.4f\n",
              cal_test_chol$Ftest[1], cal_test_chol$p))

  # ============================================================================
  # Model 4: Glucose ~ total_calories + controls
  # ============================================================================
  cat("\n[4] Glucose ~ total_calories + PAD680 + total_activity_min + RIDAGEYR + RIAGENDR\n")

  svy_glucose_cal <- svyglm(
    LBXGLU ~ calories_c + PAD680 + total_activity_min + RIDAGEYR + RIAGENDR,
    design = design,
    family = gaussian()
  )

  print(summary(svy_glucose_cal))

  cal_test_glucose <- regTermTest(svy_glucose_cal, ~ calories_c)
  cat(sprintf("\nCalorie effect on Glucose: F=%.3f, p=%.4f\n",
              cal_test_glucose$Ftest[1], cal_test_glucose$p))

  # ============================================================================
  # Extract coefficients for app use
  # ============================================================================
  cat("\n\n=== COEFFICIENTS FOR APP ===\n")
  cat("(Per 100 kcal increase from mean)\n\n")

  # Extract calorie coefficients and scale to per-100-kcal
  coef_bmi <- coef(svy_bmi_cal)["calories_c"] * 100
  coef_waist <- coef(svy_waist_cal)["calories_c"] * 100
  coef_chol <- coef(svy_chol_cal)["calories_c"] * 100
  coef_glucose <- coef(svy_glucose_cal)["calories_c"] * 100

  cat(sprintf("BMI:         %+.4f kg/m² per 100 kcal (p=%.4f)\n",
              coef_bmi, cal_test_bmi$p))
  cat(sprintf("Waist:       %+.4f cm per 100 kcal (p=%.4f)\n",
              coef_waist, cal_test_waist$p))
  cat(sprintf("Cholesterol: %+.4f mmol/L per 100 kcal (p=%.4f)\n",
              coef_chol, cal_test_chol$p))
  cat(sprintf("Glucose:     %+.4f mmol/L per 100 kcal (p=%.4f)\n",
              coef_glucose, cal_test_glucose$p))

  cat("\nMean baseline calories:", cal_mean, "kcal\n")

  # ============================================================================
  # Return results (doesn't overwrite any existing results)
  # ============================================================================
  return(list(
    svy_bmi_cal = svy_bmi_cal,
    svy_waist_cal = svy_waist_cal,
    svy_chol_cal = svy_chol_cal,
    svy_glucose_cal = svy_glucose_cal,

    # Test results
    test_bmi = cal_test_bmi,
    test_waist = cal_test_waist,
    test_chol = cal_test_chol,
    test_glucose = cal_test_glucose,

    # Coefficients for app (per 100 kcal)
    coef_per_100kcal = list(
      bmi = as.numeric(coef_bmi),
      waist = as.numeric(coef_waist),
      cholesterol = as.numeric(coef_chol),
      glucose = as.numeric(coef_glucose),
      mean_calories = cal_mean
    ),

    # P-values for app
    pvals = list(
      bmi = cal_test_bmi$p,
      waist = cal_test_waist$p,
      cholesterol = cal_test_chol$p,
      glucose = cal_test_glucose$p
    )
  ))
}
