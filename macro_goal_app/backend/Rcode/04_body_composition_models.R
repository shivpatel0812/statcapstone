source(file.path(ROOT, "Rcode", "00_project_setup.R"))
source(file.path(ROOT, "Rcode", "01_data_prep.R"))

run_body_composition_models <- function(data) {
  data$waist_bmi_ratio <- data$BMXWAIST / data$BMXBMI
  design <- make_design(data)

  svy_ratio_main <- svyglm(
    waist_bmi_ratio ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_ratio_prot_act <- svyglm(
    waist_bmi_ratio ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c +
      PAD680_c + Activity_c + Protein_c:PAD680_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_ratio_prot_gender <- svyglm(
    waist_bmi_ratio ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c +
      PAD680_c + Activity_c + Protein_c:Female + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_waist_main <- svyglm(
    BMXWAIST ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_waist_prot_act <- svyglm(
    BMXWAIST ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c +
      PAD680_c + Activity_c + Protein_c:PAD680_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_waist_prot_gender <- svyglm(
    BMXWAIST ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c +
      PAD680_c + Activity_c + Protein_c:Female + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_bmi_adj_waist <- svyglm(
    BMXBMI ~ BMXWAIST + total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_bmi_adj_prot_act <- svyglm(
    BMXBMI ~ BMXWAIST + total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c +
      PAD680_c + Activity_c + Protein_c:PAD680_c + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_bmi_adj_prot_gender <- svyglm(
    BMXBMI ~ BMXWAIST + total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c + Protein_c +
      PAD680_c + Activity_c + Protein_c:Female + RIDAGEYR + Female + SLD012,
    design = design
  )

  svy_bmi_plain <- svyglm(
    BMXBMI ~ total_sugar + total_fiber + total_protein + total_carbs + total_fat + total_cholesterol +
      PAD680 + total_activity_min + RIDAGEYR + Female + SLD012,
    design = design
  )

  cat("=== Protein Effect Comparison ===\n")
  cat(sprintf("Protein -> BMI (no control):         coef=%.5f, p=%.4f\n",
              coef(svy_bmi_plain)["total_protein"],
              summary(svy_bmi_plain)$coefficients["total_protein", 4]))
  cat(sprintf("Protein -> Waist:                    coef=%.5f, p=%.4f\n",
              coef(svy_waist_main)["total_protein"],
              summary(svy_waist_main)$coefficients["total_protein", 4]))
  cat(sprintf("Protein -> BMI (controlling waist):  coef=%.5f, p=%.4f\n",
              coef(svy_bmi_adj_waist)["total_protein"],
              summary(svy_bmi_adj_waist)$coefficients["total_protein", 4]))
  cat(sprintf("Protein -> Waist-to-BMI ratio:       coef=%.5f, p=%.4f\n",
              coef(svy_ratio_main)["total_protein"],
              summary(svy_ratio_main)$coefficients["total_protein", 4]))

  list(
    data = data,
    design = design,
    svy_ratio_main = svy_ratio_main,
    svy_ratio_prot_act = svy_ratio_prot_act,
    svy_ratio_prot_gender = svy_ratio_prot_gender,
    svy_waist_main = svy_waist_main,
    svy_waist_prot_act = svy_waist_prot_act,
    svy_waist_prot_gender = svy_waist_prot_gender,
    svy_bmi_adj_waist = svy_bmi_adj_waist,
    svy_bmi_adj_prot_act = svy_bmi_adj_prot_act,
    svy_bmi_adj_prot_gender = svy_bmi_adj_prot_gender,
    svy_bmi_plain = svy_bmi_plain
  )
}
