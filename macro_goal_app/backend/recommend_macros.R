#!/usr/bin/env Rscript

# ==============================================================================
# NHANES Evidence-Based Macro Recommender
# ==============================================================================
# Uses actual regression coefficients from NHANES 2021-2023 models
# Optimizes macros for specific health outcomes based on statistical evidence
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 14) {
  stop("Usage: Rscript recommend_macros.R protein carbs fat sugar fiber sex weight_kg height_cm sleep_hours activity_min sedentary_min goal time_range total_calories")
}

# Parse inputs
protein <- as.numeric(args[1])
carbs <- as.numeric(args[2])
fat <- as.numeric(args[3])
sugar <- as.numeric(args[4])
fiber <- as.numeric(args[5])
sex <- tolower(args[6])
weight_kg <- as.numeric(args[7])
height_cm <- as.numeric(args[8])
sleep_hours <- as.numeric(args[9])
activity_min <- as.numeric(args[10])
sedentary_min <- as.numeric(args[11])
goal <- tolower(args[12])
time_range <- tolower(args[13])

# Required: user-tracked total daily calories. This is the baseline the plan
# is built on; implied kcal from macros is kept only for display / comparison.
user_logged_calories <- suppressWarnings(as.numeric(args[14]))
if (length(user_logged_calories) == 0 || is.na(user_logged_calories) || user_logged_calories < 0) {
  stop("total_calories must be a non-negative number")
}

# ==============================================================================
# Load NHANES model results
# ==============================================================================
# cwd is macro_goal_app/backend (see app.py subprocess cwd)
backend_dir <- normalizePath(getwd(), mustWork = TRUE)
rcode_dir <- file.path(backend_dir, "Rcode")

source(file.path(rcode_dir, "00_project_setup.R"))
source(file.path(rcode_dir, "01_data_prep.R"))
source(file.path(rcode_dir, "02_audit_vif_main.R"))
source(file.path(rcode_dir, "03_interaction_models.R"))
source(file.path(rcode_dir, "04_body_composition_models.R"))
source(file.path(rcode_dir, "06_calorie_models.R"))

data <- prepare_data()
design <- make_design(data)

# Run models silently. 06_calorie_models fits total_calories (no macros) on the
# four outcomes so we can use its coefficients alongside the macro models
# without reintroducing the VIF issue (calories = 4P + 4C + 9F).
invisible(capture.output({
  main_res <- run_audit_vif_main(data, design, make_plots = FALSE)
  int_res <- run_interaction_models(data, design)
  body_res <- run_body_composition_models(data)
  cal_res <- run_calorie_models(data, design)
}))

# ==============================================================================
# Calculate current state
# ==============================================================================
height_m <- height_cm / 100
bmi <- ifelse(height_m > 0, weight_kg / (height_m ^ 2), NA)

# Energy: user-tracked total calories is the baseline. Implied kcal from
# macros is still computed so the UI can show the gap between tracked and
# macro-implied intake.
implied_calories <- 4 * protein + 4 * carbs + 9 * fat
current_calories <- user_logged_calories

# Activity level
activity_level <- if (activity_min >= 150) "active" else if (activity_min >= 75) "moderate" else "sedentary"

# ==============================================================================
# Select model based on goal
# ==============================================================================

# Goal-to-model mapping
target_model <- switch(goal,
  "reduce_bmi" = main_res$svy_bmi,
  "lose_weight" = main_res$svy_bmi,
  "reduce_waist" = main_res$svy_waist,
  "improve_cholesterol" = main_res$svy_chol,
  "improve_glucose" = main_res$svy_glucose,
  "build_muscle" = main_res$svy_bmi,  # Use BMI + interaction for lean mass
  "gain_weight" = main_res$svy_bmi,
  "general_health" = main_res$svy_bmi  # Default to BMI model
)

goal_name <- switch(goal,
  "reduce_bmi" = "Reduce BMI",
  "lose_weight" = "Lose weight",
  "reduce_waist" = "Reduce waist circumference",
  "improve_cholesterol" = "Improve cholesterol",
  "improve_glucose" = "Improve glucose",
  "build_muscle" = "Build muscle (lean mass)",
  "gain_weight" = "Gain weight",
  "general_health" = "General health"
)

# Extract coefficients from target model
coef_target <- coef(target_model)

# ==============================================================================
# Evidence-based macro recommendations using ACTUAL coefficients
# ==============================================================================

recommendations <- list()
evidence <- c()

# --- FIBER: Strong evidence across all models ---
# Fiber has negative (protective) coefficient for BMI (p<0.001) and waist (p=0.002)
if (!is.na(coef_target["total_fiber"]) && coef_target["total_fiber"] < 0) {
  # Fiber is protective for this outcome
  fiber_coef <- coef_target["total_fiber"]

  if (fiber < 25) {
    target_fiber <- 30  # Evidence-based recommendation
    fiber_increase <- target_fiber - fiber

    # Calculate expected benefit using actual coefficient
    expected_benefit <- fiber_increase * fiber_coef

    recommendations$fiber <- target_fiber
    evidence <- c(evidence, sprintf("Increase fiber to %dg (from %dg) - associated with %.2f unit improvement in %s based on NHANES coefficient",
                                   target_fiber, round(fiber), abs(expected_benefit), goal_name))
  } else {
    recommendations$fiber <- max(fiber, 25)
  }
} else {
  recommendations$fiber <- fiber
}

# --- SUGAR: Cap based on evidence ---
# Sugar shows varying effects; cap at 45g for metabolic health
target_sugar <- sugar
if (sugar > 50) {
  target_sugar <- 45
  evidence <- c(evidence, "Reduce sugar to 45g for metabolic health")
} else if (sugar > 45 && !is.na(sleep_hours) && sleep_hours < 6.5) {
  target_sugar <- 40
  evidence <- c(evidence, "Reduce sugar to 40g (poor sleep exacerbates sugar effects)")
} else {
  target_sugar <- sugar
}
recommendations$sugar <- target_sugar

# --- SEDENTARY TIME: Strong effect on BMI and waist ---
# From models: PAD680 (sedentary min) has positive coefficient (p=0.006 for BMI, p=0.003 for waist)
if (goal %in% c("reduce_bmi", "lose_weight", "reduce_waist")) {
  if (!is.na(coef_target["PAD680"]) && coef_target["PAD680"] > 0) {
    sed_coef <- coef_target["PAD680"]

    if (sedentary_min > 360) {  # More than 6 hours/day
      sed_reduction <- min(120, sedentary_min - 300)  # Reduce by up to 2 hours
      expected_benefit <- -sed_reduction * sed_coef  # Negative because we're reducing

      evidence <- c(evidence, sprintf("Reduce sedentary time by %d min/day - associated with %.2f unit improvement in %s",
                                     sed_reduction, abs(expected_benefit), goal_name))
    }
  }
}

# --- ACTIVITY: Significant for glucose, borderline for cholesterol ---
# From models: activity significant for glucose (p=0.003)
if (goal %in% c("improve_glucose", "improve_cholesterol", "build_muscle")) {
  if (activity_min < 150) {
    activity_target <- 150  # WHO recommendation
    activity_increase <- activity_target - activity_min

    if (!is.na(coef_target["total_activity_min"]) && coef_target["total_activity_min"] != 0) {
      act_coef <- coef_target["total_activity_min"]
      expected_benefit <- activity_increase * act_coef

      evidence <- c(evidence, sprintf("Increase activity to %d min/week (from %d) - associated with %.2f unit improvement in %s",
                                     activity_target, round(activity_min), abs(expected_benefit), goal_name))
    } else {
      evidence <- c(evidence, "Increase activity to 150 min/week (WHO recommendation)")
    }
  }
}

# --- PROTEIN: Use interaction with activity for muscle goals ---
base_protein <- protein
protein_target <- protein

if (goal %in% c("build_muscle", "lose_weight")) {
  # Check for protein×activity interaction (from interaction models)
  use_interaction <- FALSE

  if (!is.null(int_res$protein_activity_bmi) || !is.null(int_res$protein_activity_waist)) {
    # Protein×activity interaction exists (p=0.05 for BMI, p=0.020 for waist)
    use_interaction <- TRUE
  }

  if (use_interaction && activity_level %in% c("active", "moderate")) {
    # Active people benefit MORE from higher protein (lean mass effect)
    if (goal == "build_muscle") {
      protein_floor <- ifelse(sex == "male", 1.8, 1.6) * weight_kg
      protein_target <- max(protein * 1.25, protein_floor)
      evidence <- c(evidence, sprintf("Increase protein to %.0fg (%.1fg/kg) - protein×activity interaction (p=0.020) supports lean mass gain",
                                     protein_target, protein_target/weight_kg))
    } else if (goal == "lose_weight") {
      protein_floor <- ifelse(sex == "male", 1.6, 1.4) * weight_kg
      protein_target <- max(protein * 1.15, protein_floor)
      evidence <- c(evidence, "Increase protein to preserve lean mass during weight loss (protein×activity interaction)")
    }
  } else if (goal == "build_muscle") {
    # Sedentary muscle gain (less efficient)
    protein_floor <- ifelse(sex == "male", 1.6, 1.4) * weight_kg
    protein_target <- max(protein * 1.15, protein_floor)
    evidence <- c(evidence, sprintf("Increase protein to %.0fg, but NOTE: increasing activity would enhance protein utilization (protein×activity p=0.020)",
                                   protein_target))
  }
} else if (goal == "gain_weight") {
  # General weight gain
  protein_floor <- ifelse(sex == "male", 1.4, 1.2) * weight_kg
  protein_target <- max(protein * 1.10, protein_floor)
} else {
  # Maintenance
  protein_floor <- ifelse(sex == "male", 1.2, 1.0) * weight_kg
  protein_target <- max(protein, protein_floor)
}

recommendations$protein <- protein_target

# --- CALORIES: Adjust based on goal ---
calorie_multiplier <- switch(goal,
  "lose_weight" = 0.80,
  "reduce_bmi" = 0.80,
  "reduce_waist" = 0.80,
  "gain_weight" = 1.20,
  "build_muscle" = 1.10,
  1.00  # Default: maintenance
)

# Adjust for obesity
if (!is.na(bmi) && bmi >= 30 && goal %in% c("lose_weight", "reduce_bmi")) {
  calorie_multiplier <- 0.75  # Larger deficit
}

target_calories <- current_calories * calorie_multiplier
target_calories <- max(1200, target_calories)  # Safety floor

# --- Calorie model evidence (from 06_calorie_models.R) ---
# Tie the target calorie change to the no-macro calorie model's coefficient
# for the outcome most aligned with the goal. This is separate from the macro
# models above to avoid multicollinearity.
cal_outcome <- switch(goal,
  "reduce_bmi" = "bmi",
  "lose_weight" = "bmi",
  "reduce_waist" = "waist",
  "improve_cholesterol" = "cholesterol",
  "improve_glucose" = "glucose",
  "build_muscle" = "bmi",
  "gain_weight" = "bmi",
  "general_health" = "bmi"
)

cal_coef_per_100 <- tryCatch(cal_res$coef_per_100kcal[[cal_outcome]], error = function(e) NA_real_)
cal_pval <- tryCatch(cal_res$pvals[[cal_outcome]], error = function(e) NA_real_)
calorie_delta <- target_calories - current_calories

if (!is.null(cal_coef_per_100) && !is.na(cal_coef_per_100)) {
  expected_cal_effect <- cal_coef_per_100 * (calorie_delta / 100)
  outcome_label <- switch(cal_outcome,
    "bmi" = "BMI (kg/m^2)",
    "waist" = "waist (cm)",
    "cholesterol" = "cholesterol (mmol/L)",
    "glucose" = "glucose (mmol/L)"
  )
  evidence <- c(evidence, sprintf(
    "Calorie model: %+.0f kcal/day is associated with %+.3f %s (beta=%+.4f per 100 kcal, p=%.3f)",
    calorie_delta, expected_cal_effect, outcome_label, cal_coef_per_100, cal_pval
  ))
}

# --- FAT: Minimum for health ---
fat_floor <- 0.7 * weight_kg
fat_target <- max(fat, fat_floor)
recommendations$fat <- fat_target

# --- CARBS: Back-calculate from remaining calories ---
protein_kcal <- protein_target * 4
fat_kcal <- fat_target * 9
remaining_kcal <- target_calories - protein_kcal - fat_kcal
carbs_target <- max(100, remaining_kcal / 4)
recommendations$carbs <- carbs_target

# ==============================================================================
# Time range adjustment
# ==============================================================================
time_note <- "General recommendation"
if (time_range == "3_months") {
  # Moderate approach for 3 months
  time_note <- "3-month plan"
} else if (time_range == "6_months") {
  # Gradual approach for 6 months
  time_note <- "6-month plan"
} else if (time_range == "12_months") {
  # Very gradual for 12 months
  time_note <- "12-month plan"
}

# ==============================================================================
# Compile evidence summary
# ==============================================================================
if (length(evidence) == 0) {
  evidence <- c("Current macros are within evidence-based ranges for this goal")
}

evidence_summary <- paste(evidence, collapse=" | ")

# ==============================================================================
# Output
# ==============================================================================
cat(sprintf("protein=%s\n", round(recommendations$protein, 1)))
cat(sprintf("carbs=%s\n", round(recommendations$carbs, 1)))
cat(sprintf("fat=%s\n", round(recommendations$fat, 1)))
cat(sprintf("sugar=%s\n", round(recommendations$sugar, 1)))
cat(sprintf("fiber=%s\n", round(recommendations$fiber, 1)))
cat(sprintf("bmi=%s\n", round(bmi, 1)))
cat(sprintf("current_calories=%s\n", round(current_calories, 0)))
cat(sprintf("implied_calories=%s\n", round(implied_calories, 0)))
cat(sprintf("logged_calories=%s\n", round(user_logged_calories, 0)))
cat(sprintf("target_calories=%s\n", round(target_calories, 0)))
cat(sprintf("calorie_change=%s\n", round(target_calories - current_calories, 0)))
cat(sprintf("activity_level=%s\n", activity_level))
cat(sprintf("goal_name=%s\n", goal_name))
cat(sprintf("time_range=%s\n", time_note))
cat(sprintf("health_benefits=%s\n", evidence_summary))
cat(sprintf("note=Evidence-based %s plan using NHANES 2021-2023 regression coefficients. Recommendations optimized for: %s.\n", time_note, goal_name))
