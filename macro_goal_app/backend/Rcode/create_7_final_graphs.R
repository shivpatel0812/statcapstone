# Create 7 Final Publication-Quality Graphs for NHANES Capstone
# Run from backend/Rcode directory

if (!exists("ROOT")) {
  source("00_project_setup.R")
}

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(grid)
})

# Create output directory
OUTPUT_DIR <- "/Users/shivpatel/STATCapstone_FinalProject/final_graphs"
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

cat("Creating 7 final graphs for NHANES capstone...\n")
cat("Output directory:", OUTPUT_DIR, "\n\n")

# Load data and models
source(file.path(ROOT, "Rcode", "01_data_prep.R"))
source(file.path(ROOT, "Rcode", "02_audit_vif_main.R"))
source(file.path(ROOT, "Rcode", "generate_prediction_dataframes.R"))

# Prepare data (if not already loaded)
if (!exists("data")) data <- prepare_data()
if (!exists("design")) design <- make_design(data)
if (!exists("main_res")) main_res <- run_audit_vif_main(data, design, make_plots = FALSE)

# Common theme for all plots
theme_final <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
      plot.subtitle = element_text(hjust = 0.5, size = 10, color = "gray30"),
      axis.title = element_text(face = "bold", size = 11),
      panel.grid.minor = element_blank(),
      legend.position = "right"
    )
}

# ============================================================================
# GRAPH 1: HEATMAP (SIGNIFICANCE-COLORED MAIN EFFECTS)
# ============================================================================
cat("1. Creating heatmap of main effects...\n")

# Extract coefficients and p-values for heatmap
predictors <- c("total_fiber", "PAD680", "total_activity_min", "total_protein", "SLD012")
predictor_labels <- c("Fiber", "Sedentary time", "Activity", "Protein", "Sleep")
outcomes <- list(
  BMI = main_res$svy_bmi,
  Waist = main_res$svy_waist,
  Glucose = main_res$svy_glucose_ols,
  Cholesterol = main_res$svy_chol
)

heatmap_data <- data.frame()
for (outcome_name in names(outcomes)) {
  mod <- outcomes[[outcome_name]]
  sm <- summary(mod)$coefficients
  pcol <- if ("Pr(>|t|)" %in% colnames(sm)) "Pr(>|t|)" else "Pr(>|z|)"

  for (i in seq_along(predictors)) {
    pred <- predictors[i]
    if (pred %in% rownames(sm)) {
      heatmap_data <- rbind(heatmap_data, data.frame(
        predictor = predictor_labels[i],
        outcome = outcome_name,
        estimate = sm[pred, "Estimate"],
        p_value = sm[pred, pcol],
        stringsAsFactors = FALSE
      ))
    }
  }
}

# Create significance categories
heatmap_data <- heatmap_data %>%
  mutate(
    sig_category = case_when(
      p_value < 0.05 & estimate < 0 ~ "Sig. negative",
      p_value < 0.05 & estimate > 0 ~ "Sig. positive",
      p_value >= 0.05 & p_value < 0.10 ~ "Borderline",
      TRUE ~ "Not significant"
    ),
    label = sprintf("%.3f", estimate),
    predictor = factor(predictor, levels = rev(predictor_labels)),
    outcome = factor(outcome, levels = c("BMI", "Waist", "Glucose", "Cholesterol"))
  )

# Create heatmap (no coefficient text, let color tell the story)
p1_heatmap <- ggplot(heatmap_data, aes(x = outcome, y = predictor, fill = sig_category)) +
  geom_tile(color = "white", linewidth = 1.5) +
  scale_fill_manual(
    values = c(
      "Sig. negative" = "#1B7837",
      "Sig. positive" = "#B2182B",
      "Borderline" = "#FDB863",
      "Not significant" = "#E0E0E0"
    ),
    guide = "none"
  ) +
  labs(
    title = "Main Effects: Diet and Activity on Health Outcomes",
    subtitle = "Survey-weighted regression analysis",
    x = NULL,
    y = NULL
  ) +
  theme_final() +
  theme(
    panel.grid = element_blank(),
    axis.text = element_text(face = "bold", color = "black", size = 12)
  )

ggsave(file.path(OUTPUT_DIR, "1_heatmap_main_effects.png"),
       p1_heatmap, width = 8, height = 5, dpi = 300)
cat("  ✓ Saved: 1_heatmap_main_effects.png\n")

# ============================================================================
# GRAPH 2: FIBER EFFECT PLOT (TWO SEPARATE PANELS)
# ============================================================================
cat("2. Creating fiber effect plot...\n")

# Prepare data for BMI panel
fiber_bmi <- fiber_pred %>%
  mutate(
    lower = predicted_BMI - 1.96 * se_BMI,
    upper = predicted_BMI + 1.96 * se_BMI,
    outcome = "BMI"
  )

# Prepare data for waist panel
fiber_waist <- fiber_pred %>%
  mutate(
    lower = predicted_waist - 1.96 * se_waist,
    upper = predicted_waist + 1.96 * se_waist,
    outcome = "Waist"
  )

# Create BMI panel
p2_bmi <- ggplot(fiber_bmi, aes(x = fiber_value, y = predicted_BMI)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2, fill = "#2166AC") +
  geom_line(linewidth = 1.2, color = "#2166AC") +
  labs(
    title = "BMI",
    x = "Total fiber (g/day)",
    y = "Predicted BMI (kg/m²)"
  ) +
  theme_final() +
  theme(plot.title = element_text(size = 12, face = "bold", hjust = 0.5))

# Create waist panel
p2_waist <- ggplot(fiber_waist, aes(x = fiber_value, y = predicted_waist)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2, fill = "#B2182B") +
  geom_line(linewidth = 1.2, color = "#B2182B") +
  labs(
    title = "Waist Circumference",
    x = "Total fiber (g/day)",
    y = "Predicted waist (cm)"
  ) +
  theme_final() +
  theme(plot.title = element_text(size = 12, face = "bold", hjust = 0.5))

# Combine panels
if (requireNamespace("patchwork", quietly = TRUE)) {
  library(patchwork)
  p2_fiber <- p2_bmi + p2_waist +
    plot_annotation(
      title = "Fiber Intake and Metabolic Health",
      subtitle = "Predicted BMI and waist circumference across fiber intake range (shaded areas: 95% CI)",
      theme = theme(plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
                    plot.subtitle = element_text(hjust = 0.5, size = 10, color = "gray30"))
    )
} else {
  # Fallback: use gridExtra
  suppressPackageStartupMessages(library(gridExtra))
  p2_fiber <- grid.arrange(p2_bmi, p2_waist, ncol = 2,
                          top = textGrob("Fiber Intake and Metabolic Health",
                                       gp = gpar(fontface = "bold", fontsize = 14)))
}

ggsave(file.path(OUTPUT_DIR, "2_fiber_effect_bmi_waist.png"),
       p2_fiber, width = 11, height = 5, dpi = 300)
cat("  ✓ Saved: 2_fiber_effect_bmi_waist.png\n")

# ============================================================================
# GRAPH 3: WAIST VS BMI SCATTER (CLEAN UP)
# ============================================================================
cat("3. Creating waist vs BMI scatter plot...\n")

p3_scatter <- ggplot(bmi_waist_sample, aes(x = BMXBMI, y = BMXWAIST)) +
  geom_point(alpha = 0.3, size = 1.2, color = "gray40") +
  geom_smooth(method = "loess", se = TRUE, linewidth = 1, color = "#1B7837", fill = "#1B7837") +
  labs(
    title = "Body Composition: Waist Circumference vs BMI",
    subtitle = "Random sample of 1,000 NHANES participants (2021-2023)",
    x = "BMI (kg/m²)",
    y = "Waist circumference (cm)"
  ) +
  theme_final()

ggsave(file.path(OUTPUT_DIR, "3_waist_vs_bmi_scatter.png"),
       p3_scatter, width = 9, height = 6, dpi = 300)
cat("  ✓ Saved: 3_waist_vs_bmi_scatter.png\n")

# ============================================================================
# GRAPH 4: PROTEIN LEAN MASS COMPARISON (DOT PLOT)
# ============================================================================
cat("4. Creating protein lean mass comparison...\n")

# Filter to 3 key models and create clean labels
protein_lean_subset <- protein_lean %>%
  filter(!grepl("controlling for waist", model_name)) %>%
  mutate(
    model_short = case_when(
      grepl("no waist", model_name) ~ "BMI (unadjusted)",
      grepl("Waist-to-BMI", model_name) ~ "Waist-to-BMI ratio",
      TRUE ~ "Waist"
    ),
    model_short = factor(model_short, levels = c("BMI (unadjusted)", "Waist", "Waist-to-BMI ratio")),
    significant = p_value < 0.05,
    ci_lower = protein_coef - 1.96 * protein_se,
    ci_upper = protein_coef + 1.96 * protein_se
  )

p4_protein <- ggplot(protein_lean_subset, aes(x = protein_coef, y = model_short, color = significant)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.8) +
  geom_pointrange(aes(xmin = ci_lower, xmax = ci_upper), size = 0.8, linewidth = 1) +
  scale_color_manual(values = c("TRUE" = "#B2182B", "FALSE" = "gray60"),
                     labels = c("TRUE" = "p < 0.05", "FALSE" = "p ≥ 0.05"),
                     name = "Significance") +
  labs(
    title = "Protein's Lean Mass Signal",
    subtitle = "Protein coefficient across body composition models",
    x = "Coefficient (per g/day protein)",
    y = NULL
  ) +
  theme_final() +
  theme(axis.text.y = element_text(size = 11, face = "bold"))

ggsave(file.path(OUTPUT_DIR, "4_protein_lean_mass.png"),
       p4_protein, width = 9, height = 6, dpi = 300)
cat("  ✓ Saved: 4_protein_lean_mass.png\n")

# ============================================================================
# GRAPH 5: PROTEIN × ACTIVITY INTERACTION (TWO LINES, HONEST Y-AXIS)
# ============================================================================
cat("5. Creating protein × activity interaction plot...\n")

# Reshape protein_activity_pred to long format
protein_act_long <- protein_activity_pred %>%
  mutate(
    low_lower = predicted_waist_lowact - 1.96 * se_lowact,
    low_upper = predicted_waist_lowact + 1.96 * se_lowact,
    high_lower = predicted_waist_highact - 1.96 * se_highact,
    high_upper = predicted_waist_highact + 1.96 * se_highact
  ) %>%
  pivot_longer(
    cols = c(predicted_waist_lowact, predicted_waist_highact),
    names_to = "activity_level",
    values_to = "predicted_waist"
  ) %>%
  mutate(
    activity = if_else(grepl("lowact", activity_level), "Low activity (25th pct)", "High activity (75th pct)"),
    lower = if_else(grepl("lowact", activity_level), low_lower, high_lower),
    upper = if_else(grepl("lowact", activity_level), low_upper, high_upper)
  )

# Set honest y-axis limits
y_min <- min(protein_act_long$lower, na.rm = TRUE) - 1
y_max <- max(protein_act_long$upper, na.rm = TRUE) + 1

p5_interaction <- ggplot(protein_act_long, aes(x = protein_value, y = predicted_waist,
                                                color = activity, fill = activity)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2, color = NA) +
  geom_line(linewidth = 1.2) +
  scale_color_manual(values = c("Low activity (25th pct)" = "#2166AC",
                                "High activity (75th pct)" = "#B2182B"),
                     name = NULL) +
  scale_fill_manual(values = c("Low activity (25th pct)" = "#2166AC",
                               "High activity (75th pct)" = "#B2182B"),
                    name = NULL) +
  scale_y_continuous(limits = c(y_min, y_max)) +
  labs(
    title = "Protein × Activity Interaction on Waist Circumference",
    subtitle = "Predicted waist at low (25th pct) vs high (75th pct) physical activity",
    x = "Total protein (g/day)",
    y = "Predicted waist circumference (cm)"
  ) +
  theme_final()

ggsave(file.path(OUTPUT_DIR, "5_protein_activity_interaction.png"),
       p5_interaction, width = 9, height = 6, dpi = 300)
cat("  ✓ Saved: 5_protein_activity_interaction.png\n")

# ============================================================================
# GRAPH 6: SLEEP EFFECTS (DOT PLOT, BASELINE VS ADJUSTED)
# ============================================================================
cat("6. Creating sleep effects comparison plot...\n")

# Reshape sleep_coefs to long format
sleep_long <- sleep_coefs %>%
  pivot_longer(
    cols = c(sleep_coef_baseline, sleep_coef_adjusted),
    names_to = "model_type",
    values_to = "coefficient"
  ) %>%
  mutate(
    se = if_else(grepl("baseline", model_type), sleep_se_baseline, sleep_se_adjusted),
    model = if_else(grepl("baseline", model_type), "Baseline", "Race/income adjusted"),
    model = factor(model, levels = c("Baseline", "Race/income adjusted")),
    outcome = factor(outcome, levels = c("BMI", "Waist", "Glucose", "Cholesterol")),
    ci_lower = coefficient - 1.96 * se,
    ci_upper = coefficient + 1.96 * se
  )

p6_sleep <- ggplot(sleep_long, aes(x = coefficient, y = outcome, color = model)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.8) +
  geom_pointrange(aes(xmin = ci_lower, xmax = ci_upper),
                  position = position_dodge(width = 0.4),
                  size = 0.8, linewidth = 1) +
  scale_color_manual(values = c("Baseline" = "#2166AC", "Race/income adjusted" = "#B2182B"),
                     name = "Model") +
  labs(
    title = "Sleep Duration Effects on Health Outcomes",
    subtitle = "Baseline model vs race/income adjusted model",
    x = "Coefficient (per hour of sleep)",
    y = NULL
  ) +
  theme_final() +
  theme(axis.text.y = element_text(size = 11, face = "bold"))

ggsave(file.path(OUTPUT_DIR, "6_sleep_baseline_vs_adjusted.png"),
       p6_sleep, width = 9, height = 6, dpi = 300)
cat("  ✓ Saved: 6_sleep_baseline_vs_adjusted.png\n")

# ============================================================================
# GRAPH 7: RACE AND INCOME COMBINED (TWO PANEL PLOT)
# ============================================================================
cat("7. Creating race and income disparities plot...\n")

# Prepare race data with shortened labels (avoid duplicate "Other")
race_plot_data <- race_coefs %>%
  mutate(
    race_short = case_when(
      grepl("race_eth1", race_ethnicity) ~ "NH Black",
      grepl("race_eth2", race_ethnicity) ~ "NH White",
      grepl("race_eth4", race_ethnicity) ~ "Asian",
      grepl("race_eth6", race_ethnicity) ~ "Multiracial/Other",
      grepl("race_eth7", race_ethnicity) ~ "Other Hispanic",
      TRUE ~ race_ethnicity
    ),
    outcome = factor(outcome, levels = c("BMI", "Waist", "Glucose", "Cholesterol")),
    ci_lower = coefficient - 1.96 * std_error,
    ci_upper = coefficient + 1.96 * std_error
  )

# Create race panel
p7_race <- ggplot(race_plot_data, aes(x = coefficient, y = race_short, color = outcome)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.8) +
  geom_pointrange(aes(xmin = ci_lower, xmax = ci_upper),
                  position = position_dodge(width = 0.6),
                  size = 0.6, linewidth = 0.8) +
  scale_color_brewer(palette = "Set2", name = "Outcome") +
  labs(
    title = "Race/Ethnicity Effects",
    x = "Coefficient",
    y = NULL
  ) +
  theme_final() +
  theme(
    axis.text.y = element_text(size = 10, face = "bold"),
    plot.title = element_text(size = 12)
  )

# Prepare income data
income_plot_data <- income_coefs %>%
  mutate(
    outcome = factor(outcome, levels = c("BMI", "Waist", "Glucose", "Cholesterol")),
    ci_lower = coefficient - 1.96 * std_error,
    ci_upper = coefficient + 1.96 * std_error
  )

# Create income panel
p7_income <- ggplot(income_plot_data, aes(x = coefficient, y = outcome, color = outcome)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.8) +
  geom_pointrange(aes(xmin = ci_lower, xmax = ci_upper),
                  size = 0.8, linewidth = 1) +
  scale_color_brewer(palette = "Set2", name = "Outcome") +
  labs(
    title = "Income-to-Poverty Ratio Effects",
    x = "Coefficient",
    y = NULL
  ) +
  theme_final() +
  theme(
    axis.text.y = element_text(size = 10, face = "bold"),
    plot.title = element_text(size = 12),
    legend.position = "none"
  )

# Combine panels using gridExtra or patchwork (try patchwork first)
if (requireNamespace("patchwork", quietly = TRUE)) {
  library(patchwork)
  p7_combined <- p7_race + p7_income +
    plot_annotation(
      title = "Socioeconomic and Racial Disparities in Health Outcomes",
      subtitle = "Race/ethnicity effects (left) and income-to-poverty ratio effects (right)",
      theme = theme(plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
                    plot.subtitle = element_text(hjust = 0.5, size = 10, color = "gray30"))
    )
} else {
  # Fallback: save separately and note for user
  cat("  ℹ patchwork not available, saving race and income as separate plots\n")
  ggsave(file.path(OUTPUT_DIR, "7a_race_disparities.png"),
         p7_race, width = 8, height = 5, dpi = 300)
  ggsave(file.path(OUTPUT_DIR, "7b_income_disparities.png"),
         p7_income, width = 6, height = 5, dpi = 300)

  # Create combined manually using grid
  p7_combined <- grid.arrange(p7_race, p7_income, ncol = 2,
                              top = textGrob("Socioeconomic and Racial Disparities in Health Outcomes",
                                           gp = gpar(fontface = "bold", fontsize = 14)))
}

ggsave(file.path(OUTPUT_DIR, "7_race_income_disparities.png"),
       p7_combined, width = 12, height = 6, dpi = 300)
cat("  ✓ Saved: 7_race_income_disparities.png\n")

# ============================================================================
# CREATE COMBINED PDF
# ============================================================================
cat("\n8. Creating combined PDF with all 7 graphs...\n")

pdf_path <- file.path(OUTPUT_DIR, "all_7_graphs.pdf")
pdf(pdf_path, width = 11, height = 8.5)

print(p1_heatmap)
print(p2_fiber)
print(p3_scatter)
print(p4_protein)
print(p5_interaction)
print(p6_sleep)
print(p7_combined)

dev.off()

cat("  ✓ Saved: all_7_graphs.pdf\n")

# ============================================================================
# SUMMARY
# ============================================================================
cat("\n========== ALL 7 GRAPHS CREATED SUCCESSFULLY ==========\n")
cat("Output directory:", OUTPUT_DIR, "\n\n")
cat("Individual PNG files:\n")
cat("  1. 1_heatmap_main_effects.png\n")
cat("  2. 2_fiber_effect_bmi_waist.png\n")
cat("  3. 3_waist_vs_bmi_scatter.png\n")
cat("  4. 4_protein_lean_mass.png\n")
cat("  5. 5_protein_activity_interaction.png\n")
cat("  6. 6_sleep_baseline_vs_adjusted.png\n")
cat("  7. 7_race_income_disparities.png\n")
cat("\nCombined PDF:\n")
cat("  - all_7_graphs.pdf\n")
cat("\nOpen with:\n")
cat("  open", shQuote(pdf_path), "\n")
