source(file.path(ROOT, "Rcode", "00_project_setup.R"))
source(file.path(ROOT, "Rcode", "01_data_prep.R"))

run_race_income_models <- function(data, design) {
  form_base <- BMXBMI ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat +
    total_cholesterol + PAD680 + total_activity_min + RIDAGEYR + Female + SLD012

  form_adj <- update(form_base, . ~ . + INDFMPIR + race_eth)

  cat("=== Design degrees of freedom (PSU-based) ===\n")
  cat("degf(design) =", degf(design), "\n\n")
  cat("=== Formulas ===\n")
  cat("Baseline:\n  ", paste(deparse(form_base), collapse = " "), "\n")
  cat("Adjusted (+ INDFMPIR + race_eth):\n  ", paste(deparse(form_adj), collapse = " "), "\n\n")

  cat("=== Non-missing counts (key) ===\n")
  cat(sprintf("  INDFMPIR: %d / %d\n", sum(!is.na(data$INDFMPIR)), nrow(data)))
  cat(sprintf("  Complete cases (adjusted model predictors + BMI): %d\n\n",
              sum(complete.cases(data[c("BMXBMI", all.vars(form_adj))]))))

  svy_bmi_base <- svyglm(form_base, design = design)
  svy_bmi_adj <- svyglm(form_adj, design = design)

  form_waist <- update(form_base, BMXWAIST ~ .)
  form_waist_adj <- update(form_adj, BMXWAIST ~ .)
  form_chol <- update(form_base, LBXTC ~ .)
  form_chol_adj <- update(form_adj, LBXTC ~ .)
  form_glu <- update(form_base, LBDGLUSI ~ .)
  form_glu_adj <- update(form_adj, LBDGLUSI ~ .)

  svy_waist_base <- svyglm(form_waist, design = design)
  svy_waist_adj <- svyglm(form_waist_adj, design = design)
  svy_chol_base <- svyglm(form_chol, design = design)
  svy_chol_adj <- svyglm(form_chol_adj, design = design)
  svy_glu_base <- svyglm(form_glu, design = design)
  svy_glu_adj <- svyglm(form_glu_adj, design = design)

  cat("========== BMI: baseline (no race / income) ==========\n")
  print(summary(svy_bmi_base))
  cat("\n========== BMI: adjusted — asymptotic p-values (df = Inf) ==========\n")
  print(summary(svy_bmi_adj, df = Inf))

  cat("\n========== Waist circumference (BMXWAIST): baseline ==========\n")
  print(summary(svy_waist_base))
  cat("\n========== BMXWAIST: adjusted (df = Inf) ==========\n")
  print(summary(svy_waist_adj, df = Inf))

  cat("\n========== Total cholesterol (LBXTC): baseline ==========\n")
  print(summary(svy_chol_base))
  cat("\n========== LBXTC: adjusted (df = Inf) ==========\n")
  print(summary(svy_chol_adj, df = Inf))

  cat("\n========== Glucose (LBDGLUSI): baseline ==========\n")
  print(summary(svy_glu_base))
  cat("\n========== LBDGLUSI: adjusted (df = Inf) ==========\n")
  print(summary(svy_glu_adj, df = Inf))

  cat("\n--- df.residual (adjusted BMI model; if <= 0, rely on df = Inf summaries above) ---\n")
  cat(sprintf("df.residual = %s\n", svy_bmi_adj$df.residual))

  list(
    svy_bmi_base = svy_bmi_base,
    svy_bmi_adj = svy_bmi_adj,
    svy_waist_base = svy_waist_base,
    svy_waist_adj = svy_waist_adj,
    svy_chol_base = svy_chol_base,
    svy_chol_adj = svy_chol_adj,
    svy_glu_base = svy_glu_base,
    svy_glu_adj = svy_glu_adj
  )
}
