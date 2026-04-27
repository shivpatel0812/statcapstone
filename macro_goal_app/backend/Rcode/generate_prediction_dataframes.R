# Generate prediction and coefficient dataframes for analysis
# Run from backend/Rcode directory

if (!exists("ROOT")) {
  source("00_project_setup.R")
}

# Load data and models
source(file.path(ROOT, "Rcode", "01_data_prep.R"))
source(file.path(ROOT, "Rcode", "02_audit_vif_main.R"))
source(file.path(ROOT, "Rcode", "04_body_composition_models.R"))
source(file.path(ROOT, "Rcode", "05_race_income_models_modular.R"))

# Prepare data
cat("Preparing data and models...\n")
data <- prepare_data()
design <- make_design(data)
main_res <- run_audit_vif_main(data, design, make_plots = FALSE)
body_comp_res <- run_body_composition_models(data)
race_income_res <- run_race_income_models(data, design)

# ============================================================================
# 1. FIBER EFFECT ON BMI AND WAIST
# ============================================================================
cat("\n1. Creating fiber_pred dataframe...\n")

# Get fiber range (10th to 90th percentile)
fiber_range <- quantile(data$total_fiber, probs = c(0.10, 0.90), na.rm = TRUE)
fiber_seq <- seq(fiber_range[1], fiber_range[2], length.out = 50)

# Reference values (sample means for other covariates)
ref_sugar <- mean(data$total_sugar, na.rm = TRUE)
ref_carbs <- mean(data$total_carbs, na.rm = TRUE)
ref_fat <- mean(data$total_fat, na.rm = TRUE)
ref_chol <- mean(data$total_cholesterol, na.rm = TRUE)
ref_protein <- mean(data$total_protein, na.rm = TRUE)
ref_pad <- mean(data$PAD680, na.rm = TRUE)
ref_activity <- mean(data$total_activity_min, na.rm = TRUE)
ref_age <- mean(data$RIDAGEYR, na.rm = TRUE)
ref_female <- mean(data$Female, na.rm = TRUE)
ref_sleep <- mean(data$SLD012, na.rm = TRUE)

# Create prediction grid
fiber_grid <- data.frame(
  total_fiber = fiber_seq,
  total_sugar = ref_sugar,
  total_carbs = ref_carbs,
  total_fat = ref_fat,
  total_cholesterol = ref_chol,
  total_protein = ref_protein,
  PAD680 = ref_pad,
  total_activity_min = ref_activity,
  RIDAGEYR = ref_age,
  Female = ref_female,
  SLD012 = ref_sleep
)

# Get predictions with SE for BMI
pred_bmi <- predict(main_res$svy_bmi, newdata = fiber_grid, type = "response", se.fit = TRUE)
# Get predictions with SE for waist
pred_waist <- predict(main_res$svy_waist, newdata = fiber_grid, type = "response", se.fit = TRUE)

# Extract values and SEs
if (is.list(pred_bmi) && "link" %in% names(pred_bmi)) {
  # If predict returns a list with link and SE
  bmi_fit <- as.numeric(pred_bmi$link)
  bmi_se <- as.numeric(pred_bmi$SE)
} else {
  # If predict returns a vector, try to get SE from attributes
  bmi_fit <- as.numeric(pred_bmi)
  bmi_se <- sqrt(as.numeric(attr(pred_bmi, "var")))
  if (is.null(bmi_se) || all(is.na(bmi_se))) {
    # If no SE available, use SE function
    bmi_se <- as.numeric(SE(pred_bmi))
  }
}

if (is.list(pred_waist) && "link" %in% names(pred_waist)) {
  waist_fit <- as.numeric(pred_waist$link)
  waist_se <- as.numeric(pred_waist$SE)
} else {
  waist_fit <- as.numeric(pred_waist)
  waist_se <- sqrt(as.numeric(attr(pred_waist, "var")))
  if (is.null(waist_se) || all(is.na(waist_se))) {
    waist_se <- as.numeric(SE(pred_waist))
  }
}

# Create dataframe
fiber_pred <- data.frame(
  fiber_value = fiber_seq,
  predicted_BMI = bmi_fit,
  predicted_waist = waist_fit,
  se_BMI = bmi_se,
  se_waist = waist_se
)

# ============================================================================
# 2. PROTEIN × ACTIVITY INTERACTION ON WAIST
# ============================================================================
cat("2. Creating protein_activity_pred dataframe...\n")

# Get protein range (10th to 90th percentile)
protein_range <- quantile(data$total_protein, probs = c(0.10, 0.90), na.rm = TRUE)
protein_seq <- seq(protein_range[1], protein_range[2], length.out = 50)

# Get activity levels (25th and 75th percentile)
act_low <- quantile(data$total_activity_min, probs = 0.25, na.rm = TRUE)
act_high <- quantile(data$total_activity_min, probs = 0.75, na.rm = TRUE)

# Calculate centered values
mu_protein <- mean(data$total_protein, na.rm = TRUE)
mu_activity <- mean(data$total_activity_min, na.rm = TRUE)
mu_fiber <- mean(data$total_fiber, na.rm = TRUE)
mu_pad <- mean(data$PAD680, na.rm = TRUE)

# Fit the interaction model (centered version)
waist_prot_act <- svyglm(
  BMXWAIST ~ total_sugar + total_carbs + total_fat + total_cholesterol +
    Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:Activity_c +
    RIDAGEYR + Female + SLD012,
  design = design
)

# Create prediction grids
ref_fiber <- mean(data$total_fiber, na.rm = TRUE)
grid_low <- data.frame(
  total_protein = protein_seq,
  total_activity_min = act_low,
  total_sugar = ref_sugar,
  total_carbs = ref_carbs,
  total_fat = ref_fat,
  total_cholesterol = ref_chol,
  total_fiber = ref_fiber,
  PAD680 = ref_pad,
  RIDAGEYR = ref_age,
  Female = ref_female,
  SLD012 = ref_sleep
)
grid_low$Protein_c <- grid_low$total_protein - mu_protein
grid_low$Activity_c <- grid_low$total_activity_min - mu_activity
grid_low$Fiber_c <- grid_low$total_fiber - mu_fiber
grid_low$PAD680_c <- grid_low$PAD680 - mu_pad

grid_high <- grid_low
grid_high$total_activity_min <- act_high
grid_high$Activity_c <- grid_high$total_activity_min - mu_activity

# Get predictions
pred_low <- predict(waist_prot_act, newdata = grid_low, type = "response", se.fit = TRUE)
pred_high <- predict(waist_prot_act, newdata = grid_high, type = "response", se.fit = TRUE)

# Extract values and SEs for low activity
if (is.list(pred_low) && "link" %in% names(pred_low)) {
  low_fit <- as.numeric(pred_low$link)
  low_se <- as.numeric(pred_low$SE)
} else {
  low_fit <- as.numeric(pred_low)
  low_se <- sqrt(as.numeric(attr(pred_low, "var")))
  if (is.null(low_se) || all(is.na(low_se))) {
    low_se <- as.numeric(SE(pred_low))
  }
}

# Extract values and SEs for high activity
if (is.list(pred_high) && "link" %in% names(pred_high)) {
  high_fit <- as.numeric(pred_high$link)
  high_se <- as.numeric(pred_high$SE)
} else {
  high_fit <- as.numeric(pred_high)
  high_se <- sqrt(as.numeric(attr(pred_high, "var")))
  if (is.null(high_se) || all(is.na(high_se))) {
    high_se <- as.numeric(SE(pred_high))
  }
}

# Create dataframe
protein_activity_pred <- data.frame(
  protein_value = protein_seq,
  predicted_waist_lowact = low_fit,
  predicted_waist_highact = high_fit,
  se_lowact = low_se,
  se_highact = high_se
)

# ============================================================================
# 3. RACE/INCOME ADJUSTED MODEL COEFFICIENTS
# ============================================================================
cat("3. Creating race_coefs and income_coefs dataframes...\n")

# Helper function to extract coefficients
extract_race_income_coefs <- function(model_list) {
  outcomes <- c("BMI", "Waist", "Glucose", "Cholesterol")
  model_names <- c("svy_bmi_adj", "svy_waist_adj", "svy_glu_adj", "svy_chol_adj")

  race_rows <- list()
  income_rows <- list()

  for (i in seq_along(outcomes)) {
    mod <- model_list[[model_names[i]]]
    sm <- summary(mod)$coefficients
    coef_names <- rownames(sm)

    # Extract race coefficients (all coefficients starting with "race_eth")
    race_coefs <- grep("^race_eth", coef_names, value = TRUE)
    for (race_coef in race_coefs) {
      pcol <- if ("Pr(>|t|)" %in% colnames(sm)) "Pr(>|t|)" else "Pr(>|z|)"
      race_rows[[length(race_rows) + 1]] <- data.frame(
        outcome = outcomes[i],
        race_ethnicity = race_coef,
        coefficient = sm[race_coef, "Estimate"],
        std_error = sm[race_coef, "Std. Error"],
        p_value = sm[race_coef, pcol],
        stringsAsFactors = FALSE
      )
    }

    # Extract income coefficient
    if ("INDFMPIR" %in% coef_names) {
      pcol <- if ("Pr(>|t|)" %in% colnames(sm)) "Pr(>|t|)" else "Pr(>|z|)"
      income_rows[[length(income_rows) + 1]] <- data.frame(
        outcome = outcomes[i],
        coefficient = sm["INDFMPIR", "Estimate"],
        std_error = sm["INDFMPIR", "Std. Error"],
        p_value = sm["INDFMPIR", pcol],
        stringsAsFactors = FALSE
      )
    }
  }

  list(
    race = if (length(race_rows) > 0) do.call(rbind, race_rows) else data.frame(),
    income = if (length(income_rows) > 0) do.call(rbind, income_rows) else data.frame()
  )
}

coefs_list <- extract_race_income_coefs(race_income_res)
race_coefs <- coefs_list$race
income_coefs <- coefs_list$income

# ============================================================================
# 4. SLEEP COEFFICIENTS ACROSS OUTCOMES
# ============================================================================
cat("4. Creating sleep_coefs dataframe...\n")

outcomes <- c("BMI", "Waist", "Glucose", "Cholesterol")
baseline_models <- list(
  race_income_res$svy_bmi_base,
  race_income_res$svy_waist_base,
  race_income_res$svy_glu_base,
  race_income_res$svy_chol_base
)
adjusted_models <- list(
  race_income_res$svy_bmi_adj,
  race_income_res$svy_waist_adj,
  race_income_res$svy_glu_adj,
  race_income_res$svy_chol_adj
)

sleep_rows <- list()
for (i in seq_along(outcomes)) {
  base_sm <- summary(baseline_models[[i]])$coefficients
  adj_sm <- summary(adjusted_models[[i]])$coefficients

  sleep_rows[[i]] <- data.frame(
    outcome = outcomes[i],
    sleep_coef_baseline = if ("SLD012" %in% rownames(base_sm)) base_sm["SLD012", "Estimate"] else NA,
    sleep_se_baseline = if ("SLD012" %in% rownames(base_sm)) base_sm["SLD012", "Std. Error"] else NA,
    sleep_coef_adjusted = if ("SLD012" %in% rownames(adj_sm)) adj_sm["SLD012", "Estimate"] else NA,
    sleep_se_adjusted = if ("SLD012" %in% rownames(adj_sm)) adj_sm["SLD012", "Std. Error"] else NA,
    stringsAsFactors = FALSE
  )
}

sleep_coefs <- do.call(rbind, sleep_rows)

# ============================================================================
# 5. PROTEIN LEAN MASS COMPARISON
# ============================================================================
cat("5. Creating protein_lean dataframe...\n")

# The models we need are already in body_comp_res
models_for_protein <- list(
  "Protein → BMI (no waist control)" = body_comp_res$svy_bmi_plain,
  "Protein → Waist" = body_comp_res$svy_waist_main,
  "Protein → BMI (controlling for waist)" = body_comp_res$svy_bmi_adj_waist,
  "Protein → Waist-to-BMI ratio" = body_comp_res$svy_ratio_main
)

protein_rows <- list()
for (model_name in names(models_for_protein)) {
  mod <- models_for_protein[[model_name]]
  sm <- summary(mod)$coefficients

  if ("total_protein" %in% rownames(sm)) {
    protein_rows[[length(protein_rows) + 1]] <- data.frame(
      model_name = model_name,
      protein_coef = sm["total_protein", "Estimate"],
      protein_se = sm["total_protein", "Std. Error"],
      p_value = sm["total_protein", if ("Pr(>|t|)" %in% colnames(sm)) "Pr(>|t|)" else "Pr(>|z|)"],
      stringsAsFactors = FALSE
    )
  }
}

protein_lean <- do.call(rbind, protein_rows)
rownames(protein_lean) <- NULL

# ============================================================================
# 6. RAW BMI AND WAIST VALUES
# ============================================================================
cat("6. Creating bmi_waist_sample dataframe...\n")

# Get complete cases for BMI and waist
complete_idx <- complete.cases(data[, c("BMXBMI", "BMXWAIST")])
data_complete <- data[complete_idx, ]

# Sample 1000 observations
set.seed(42)  # For reproducibility
sample_size <- min(1000, nrow(data_complete))
sample_idx <- sample(1:nrow(data_complete), sample_size, replace = FALSE)

bmi_waist_sample <- data_complete[sample_idx, c("BMXBMI", "BMXWAIST")]
rownames(bmi_waist_sample) <- NULL

# ============================================================================
# PRINT HEADS OF ALL DATAFRAMES
# ============================================================================
cat("\n\n========== DATAFRAME SUMMARIES ==========\n\n")

cat("1. fiber_pred (fiber effect on BMI and waist):\n")
print(head(fiber_pred))
cat(sprintf("   Dimensions: %d rows × %d columns\n\n", nrow(fiber_pred), ncol(fiber_pred)))

cat("2. protein_activity_pred (protein × activity on waist):\n")
print(head(protein_activity_pred))
cat(sprintf("   Dimensions: %d rows × %d columns\n\n", nrow(protein_activity_pred), ncol(protein_activity_pred)))

cat("3. race_coefs (race/ethnicity coefficients from adjusted models):\n")
print(head(race_coefs))
cat(sprintf("   Dimensions: %d rows × %d columns\n\n", nrow(race_coefs), ncol(race_coefs)))

cat("4. income_coefs (income-to-poverty ratio coefficients):\n")
print(head(income_coefs))
cat(sprintf("   Dimensions: %d rows × %d columns\n\n", nrow(income_coefs), ncol(income_coefs)))

cat("5. sleep_coefs (sleep coefficients baseline vs adjusted):\n")
print(head(sleep_coefs))
cat(sprintf("   Dimensions: %d rows × %d columns\n\n", nrow(sleep_coefs), ncol(sleep_coefs)))

cat("6. protein_lean (protein coefficients for lean mass comparison):\n")
print(protein_lean)
cat(sprintf("   Dimensions: %d rows × %d columns\n\n", nrow(protein_lean), ncol(protein_lean)))

cat("7. bmi_waist_sample (random sample of BMI and waist):\n")
print(head(bmi_waist_sample))
cat(sprintf("   Dimensions: %d rows × %d columns\n\n", nrow(bmi_waist_sample), ncol(bmi_waist_sample)))

cat("\n========== ALL DATAFRAMES CREATED SUCCESSFULLY ==========\n")
cat("Dataframes saved in R environment:\n")
cat("  - fiber_pred\n")
cat("  - protein_activity_pred\n")
cat("  - race_coefs\n")
cat("  - income_coefs\n")
cat("  - sleep_coefs\n")
cat("  - protein_lean\n")
cat("  - bmi_waist_sample\n")
