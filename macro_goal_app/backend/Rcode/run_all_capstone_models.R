# Run all modular capstone analyses
source("00_project_setup.R")
source("01_data_prep.R")
source("02_audit_vif_main.R")
source("03_interaction_models.R")
source("04_body_composition_models.R")
source("05_race_income_models_modular.R")
source("06_calorie_models.R")

data <- prepare_data()
design <- make_design(data)

cat("\n============================\n")
cat("1) Audit + VIF + Main Effects\n")
cat("============================\n")
main_res <- run_audit_vif_main(data, design, make_plots = TRUE)

cat("\n============================\n")
cat("2) Interaction Models\n")
cat("============================\n")
int_res <- run_interaction_models(data, design)

cat("\n============================\n")
cat("3) Body Composition Models\n")
cat("============================\n")
body_res <- run_body_composition_models(data)

cat("\n============================\n")
cat("4) Race + Income Adjusted Models\n")
cat("============================\n")
race_income_res <- run_race_income_models(data, design)

cat("\n============================\n")
cat("5) Calorie-Only Models (for App)\n")
cat("============================\n")
cal_res <- run_calorie_models(data, design)

cat("\nAll modular analyses complete.\n")
