source(file.path(ROOT, "Rcode", "00_project_setup.R"))
source(file.path(ROOT, "Rcode", "01_data_prep.R"))

run_interaction_models <- function(data, design) {
  svy_int_bmi <- svyglm(
    BMXBMI ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol +
      Fiber_c + PAD680_c + Activity_c + Fiber_c:PAD680_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_int_chol <- svyglm(
    LBXTC ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol +
      Fiber_c + PAD680_c + Activity_c + Fiber_c:PAD680_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_int_bmi_base <- svyglm(
    BMXBMI ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol +
      Fiber_c + PAD680_c + Activity_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_int_chol_base <- svyglm(
    LBXTC ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol +
      Fiber_c + PAD680_c + Activity_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_waist <- svyglm(
    BMXWAIST ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol +
      Fiber_c + PAD680_c + Activity_c + Fiber_c:PAD680_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_glucose <- svyglm(
    LBDGLUSI ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol +
      Fiber_c + PAD680_c + Activity_c + Fiber_c:PAD680_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  cat("=== Interaction Test for BMI ===\n")
  print(anova(svy_int_bmi_base, svy_int_bmi))
  cat("=== Interaction Test for Cholesterol ===\n")
  print(anova(svy_int_chol_base, svy_int_chol))

  # Joint tests on INTERACTION models (Fiber_c:PAD680_c included)
  # For clean main-effects joint tests, see 02_audit_vif_main.R
  cat("\n=== Joint Significance of Fiber (interaction models) ===\n")
  print(regTermTest(svy_int_bmi, "Fiber_c"))
  print(regTermTest(svy_int_chol, "Fiber_c"))
  print(regTermTest(svy_waist, "Fiber_c"))
  print(regTermTest(svy_glucose, "Fiber_c"))

  cat("\n=== Joint Significance of PAD680 (interaction models) ===\n")
  print(regTermTest(svy_int_bmi, "PAD680_c"))
  print(regTermTest(svy_int_chol, "PAD680_c"))
  print(regTermTest(svy_waist, "PAD680_c"))
  print(regTermTest(svy_glucose, "PAD680_c"))

  cat("\n=== Joint Significance of Fiber x PAD680 (interaction models) ===\n")
  print(regTermTest(svy_int_bmi, "Fiber_c:PAD680_c"))
  print(regTermTest(svy_int_chol, "Fiber_c:PAD680_c"))
  print(regTermTest(svy_waist, "Fiber_c:PAD680_c"))
  print(regTermTest(svy_glucose, "Fiber_c:PAD680_c"))

  # Additional interaction families used in your Rmd
  sugar_act <- list(
    bmi = svyglm(BMXBMI ~ total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + Sugar_c + PAD680_c + Activity_c + Sugar_c:PAD680_c + RIDAGEYR + Female + SLD012, design = design),
    chol = svyglm(LBXTC ~ total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + Sugar_c + PAD680_c + Activity_c + Sugar_c:PAD680_c + RIDAGEYR + Female + SLD012, design = design),
    waist = svyglm(BMXWAIST ~ total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + Sugar_c + PAD680_c + Activity_c + Sugar_c:PAD680_c + RIDAGEYR + Female + SLD012, design = design),
    glu = svyglm(LBDGLUSI ~ total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + Sugar_c + PAD680_c + Activity_c + Sugar_c:PAD680_c + RIDAGEYR + Female + SLD012, design = design)
  )

  prot_act <- list(
    bmi = svyglm(BMXBMI ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:PAD680_c + RIDAGEYR + Female + SLD012, design = design),
    chol = svyglm(LBXTC ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:PAD680_c + RIDAGEYR + Female + SLD012, design = design),
    waist = svyglm(BMXWAIST ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:PAD680_c + RIDAGEYR + Female + SLD012, design = design),
    glu = svyglm(LBDGLUSI ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:PAD680_c + RIDAGEYR + Female + SLD012, design = design)
  )

  fiber_age <- list(
    bmi = svyglm(BMXBMI ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + PAD680_c + Activity_c + Fiber_c:RIDAGEYR + RIDAGEYR + Female + SLD012, design = design),
    chol = svyglm(LBXTC ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + PAD680_c + Activity_c + Fiber_c:RIDAGEYR + RIDAGEYR + Female + SLD012, design = design),
    waist = svyglm(BMXWAIST ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + PAD680_c + Activity_c + Fiber_c:RIDAGEYR + RIDAGEYR + Female + SLD012, design = design),
    glu = svyglm(LBDGLUSI ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + PAD680_c + Activity_c + Fiber_c:RIDAGEYR + RIDAGEYR + Female + SLD012, design = design)
  )

  fiber_lact <- list(
    bmi = svyglm(BMXBMI ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + PAD680_c + Activity_c + Fiber_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    chol = svyglm(LBXTC ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + PAD680_c + Activity_c + Fiber_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    waist = svyglm(BMXWAIST ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + PAD680_c + Activity_c + Fiber_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    glu = svyglm(LBDGLUSI ~ total_sugar + total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + PAD680_c + Activity_c + Fiber_c:Activity_c + RIDAGEYR + Female + SLD012, design = design)
  )

  sugar_lact <- list(
    bmi = svyglm(BMXBMI ~ total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + Sugar_c + PAD680_c + Activity_c + Sugar_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    chol = svyglm(LBXTC ~ total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + Sugar_c + PAD680_c + Activity_c + Sugar_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    waist = svyglm(BMXWAIST ~ total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + Sugar_c + PAD680_c + Activity_c + Sugar_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    glu = svyglm(LBDGLUSI ~ total_protein + total_carbs + total_fat + total_cholesterol + Fiber_c + Sugar_c + PAD680_c + Activity_c + Sugar_c:Activity_c + RIDAGEYR + Female + SLD012, design = design)
  )

  prot_lact <- list(
    bmi = svyglm(BMXBMI ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    chol = svyglm(LBXTC ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    waist = svyglm(BMXWAIST ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:Activity_c + RIDAGEYR + Female + SLD012, design = design),
    glu = svyglm(LBDGLUSI ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c + PAD680_c + Activity_c + Protein_c:Activity_c + RIDAGEYR + Female + SLD012, design = design)
  )

  cat("\n=== Example output (sugar x activity BMI) ===\n")
  print(summary(sugar_act$bmi))

  list(
    primary = list(
      svy_int_bmi = svy_int_bmi,
      svy_int_chol = svy_int_chol,
      svy_waist = svy_waist,
      svy_glucose = svy_glucose
    ),
    sugar_act = sugar_act,
    prot_act = prot_act,
    fiber_age = fiber_age,
    fiber_lact = fiber_lact,
    sugar_lact = sugar_lact,
    prot_lact = prot_lact
  )
}
