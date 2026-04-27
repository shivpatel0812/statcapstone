# Poster / capstone summary outputs (tables + key plots)
# Run from backend/Rcode:  setwd(.../macro_goal_app/backend/Rcode); source("07_poster_tables_plots.R")

if (!exists("ROOT")) {
  source("00_project_setup.R")
}
source(file.path(ROOT, "Rcode", "01_data_prep.R"))
source(file.path(ROOT, "Rcode", "02_audit_vif_main.R"))
source(file.path(ROOT, "Rcode", "03_interaction_models.R"))

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

OUT_DIR <- file.path(ROOT, "Rcode", "poster_output")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- Main-effects report table (svyglm only; matches 02_audit_vif_main.R) ----
REPORT_MAIN_VARS <- c(
  "total_fiber", "PAD680", "total_activity_min", "total_protein",
  "SLD012", "RIDAGEYR", "Female"
)

# Row labels for poster-style tables (maps REPORT_MAIN_VARS)
REPORT_MAIN_VAR_LABELS <- c(
  total_fiber = "Fiber intake",
  PAD680 = "Sedentary time",
  total_activity_min = "Physical activity",
  total_protein = "Protein intake",
  SLD012 = "Sleep duration",
  RIDAGEYR = "Age",
  Female = "Female (vs male)"
)

fmt_p_cell <- function(p) {
  if (is.na(p)) return("—")
  if (p < 1e-4) return(format(signif(p, 2), scientific = TRUE, digits = 2))
  sprintf("%.3f", p)
}

stars_report <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.01) return("***")
  if (p < 0.05) return("**")
  if (p < 0.10) return("*")
  ""
}

build_main_regression_report_table <- function(main_res) {
  mods <- list(
    BMI = main_res$svy_bmi,
    Waist = main_res$svy_waist,
    Glucose = main_res$svy_glucose_ols,
    Cholesterol = main_res$svy_chol
  )
  out <- data.frame(Variable = REPORT_MAIN_VARS, stringsAsFactors = FALSE)
  for (mn in names(mods)) {
    sm <- summary(mods[[mn]])$coefficients
    rn <- rownames(sm)
    pcol <- if ("Pr(>|t|)" %in% colnames(sm)) "Pr(>|t|)" else "Pr(>|z|)"
    cells <- vapply(REPORT_MAIN_VARS, function(pred) {
      if (!pred %in% rn) return("—")
      est <- sm[pred, "Estimate"]
      se <- sm[pred, "Std. Error"]
      p <- sm[pred, pcol]
      paste0(sprintf("%.4g", est), " (", sprintf("%.4g", se), ")", stars_report(p))
    }, character(1))
    out[[mn]] <- cells
  }
  out
}

# Same models as build_main_regression_report_table(); cells show estimate (SE) and p (no stars).
# for_pdf = TRUE: two lines per cell (for ggplot). FALSE: one line (better for CSV/Excel).
build_main_regression_report_table_pvalues <- function(main_res, for_pdf = TRUE) {
  mods <- list(
    BMI = main_res$svy_bmi,
    Waist = main_res$svy_waist,
    Glucose = main_res$svy_glucose_ols,
    Cholesterol = main_res$svy_chol
  )
  out <- data.frame(Variable = REPORT_MAIN_VARS, stringsAsFactors = FALSE)
  out$Variable_label <- unname(REPORT_MAIN_VAR_LABELS[REPORT_MAIN_VARS])
  sep <- if (for_pdf) "\n" else " "
  for (mn in names(mods)) {
    sm <- summary(mods[[mn]])$coefficients
    rn <- rownames(sm)
    pcol <- if ("Pr(>|t|)" %in% colnames(sm)) "Pr(>|t|)" else "Pr(>|z|)"
    cells <- vapply(REPORT_MAIN_VARS, function(pred) {
      if (!pred %in% rn) return("—")
      est <- sm[pred, "Estimate"]
      se <- sm[pred, "Std. Error"]
      p <- sm[pred, pcol]
      paste0(
        sprintf("%.4g (", est), sprintf("%.4g", se), ")", sep,
        "p = ", fmt_p_cell(p)
      )
    }, character(1))
    out[[mn]] <- cells
  }
  out
}

plot_main_regression_table_pdf <- function(report_df, path) {
  dfl <- tidyr::pivot_longer(
    report_df,
    cols = -Variable,
    names_to = "Outcome",
    values_to = "cell"
  )
  dfl$Outcome <- factor(dfl$Outcome, levels = c("BMI", "Waist", "Glucose", "Cholesterol"))
  dfl$Variable <- factor(dfl$Variable, levels = rev(REPORT_MAIN_VARS))
  p_tab <- ggplot(dfl, aes(x = Outcome, y = Variable, label = cell)) +
    geom_text(size = 2.85, family = "mono", lineheight = 0.98) +
    labs(
      title = "Survey-weighted main effects (svyglm)",
      subtitle = "Cell format: estimate (standard error); stars: *** p<0.01, ** p<0.05, * p<0.10",
      caption = "Models: BMI, Waist, Glucose, Cholesterol; same specification as 02_audit_vif_main.R (main effects only).",
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5, size = 9, color = "gray30"),
      plot.caption = element_text(hjust = 0.5, size = 8, color = "gray45"),
      panel.grid = element_blank(),
      axis.text = element_text(face = "bold", color = "black")
    )
  ggsave(path, p_tab, width = 12, height = 4.5, dpi = 200, device = "pdf")
  invisible(p_tab)
}

# Two-line cells: β (SE) and p = … (survey design–based tests; no star threshold ambiguity).
plot_main_regression_table_pvalues_pdf <- function(report_df, path) {
  plot_df <- report_df
  if ("Variable_label" %in% names(plot_df)) {
    plot_df$Variable <- plot_df$Variable_label
    plot_df$Variable_label <- NULL
  }
  dfl <- tidyr::pivot_longer(
    plot_df,
    cols = -Variable,
    names_to = "Outcome",
    values_to = "cell"
  )
  dfl$Outcome <- factor(dfl$Outcome, levels = c("BMI", "Waist", "Glucose", "Cholesterol"))
  dfl$Variable <- factor(dfl$Variable, levels = rev(unique(plot_df$Variable)))
  p_tab <- ggplot(dfl, aes(x = Outcome, y = Variable, label = cell)) +
    geom_text(size = 2.45, family = "mono", lineheight = 0.92) +
    labs(
      title = "Survey-weighted main effects (svyglm)",
      subtitle = "Each cell: estimate (standard error) and design-based p-value (no significance stars).",
      caption = "Models match 02_audit_vif_main.R (main effects only).",
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5, size = 9, color = "gray30"),
      plot.caption = element_text(hjust = 0.5, size = 8, color = "gray45"),
      panel.grid = element_blank(),
      axis.text = element_text(face = "bold", color = "black")
    )
  ggsave(path, p_tab, width = 12, height = 5.2, dpi = 200, device = "pdf")
  invisible(p_tab)
}

p_stars <- function(p) {
  ifelse(is.na(p), "",
    ifelse(p < 0.001, "***",
      ifelse(p < 0.01, "**",
        ifelse(p < 0.05, "*",
          ifelse(p < 0.1, ".", "")))))
}

extract_key_coefs <- function(mod, pred_names, pred_labels) {
  sm <- summary(mod)$coefficients
  rn <- rownames(sm)
  out <- data.frame(
    term = pred_labels,
    estimate = NA_real_,
    std_error = NA_real_,
    p_value = NA_real_,
    stringsAsFactors = FALSE
  )
  for (i in seq_along(pred_names)) {
    nm <- pred_names[i]
    if (!nm %in% rn) next
    out$estimate[i] <- sm[nm, "Estimate"]
    out$std_error[i] <- sm[nm, "Std. Error"]
    pcol <- if ("Pr(>|t|)" %in% colnames(sm)) "Pr(>|t|)" else "Pr(>|z|)"
    out$p_value[i] <- sm[nm, pcol]
  }
  out
}

build_main_results_table <- function(main_list) {
  preds <- c(
    "total_fiber", "PAD680", "total_activity_min", "total_protein",
    "SLD012", "RIDAGEYR", "Female"
  )
  labs <- c(
    "Fiber", "Sedentary time", "Activity", "Protein",
    "Sleep", "Age", "Female"
  )
  outcomes <- list(
    BMI = main_list$svy_bmi,
    Waist = main_list$svy_waist,
    Glucose = main_list$svy_glucose_ols,
    Cholesterol = main_list$svy_chol
  )

  pieces <- list()
  for (onm in names(outcomes)) {
    df <- extract_key_coefs(outcomes[[onm]], preds, labs)
    df$outcome <- onm
    pieces[[onm]] <- df
  }
  long <- bind_rows(pieces)

  wide <- long %>%
    select(outcome, term, estimate, p_value) %>%
    pivot_wider(
      names_from = outcome,
      values_from = c(estimate, p_value),
      names_sep = "__"
    )

  # Human-readable columns: BMI_coef, BMI_p, ...
  tbl <- long %>%
    mutate(
      coef_fmt = sprintf("%.4g", estimate),
      p_fmt = ifelse(p_value < 0.001, "<0.001", sprintf("%.3f", p_value)),
      stars = p_stars(p_value),
      cell = paste0(coef_fmt, stars, " (p=", p_fmt, ")")
    ) %>%
    select(outcome, term, estimate, p_value, stars, cell)

  list(long = long, wide = wide, display = tbl)
}

coef_plot_data <- function(main_list) {
  preds <- c(
    "total_fiber", "PAD680", "total_activity_min", "total_protein",
    "SLD012", "RIDAGEYR", "Female"
  )
  labs <- c(
    "Fiber", "Sedentary time", "Activity", "Protein",
    "Sleep", "Age", "Female"
  )
  outcomes <- list(
    BMI = main_list$svy_bmi,
    Waist = main_list$svy_waist,
    Glucose = main_list$svy_glucose_ols,
    Cholesterol = main_list$svy_chol
  )
  bind_rows(lapply(names(outcomes), function(onm) {
    extract_key_coefs(outcomes[[onm]], preds, labs) %>%
      mutate(outcome = onm)
  })) %>%
    mutate(
      term = factor(term, levels = rev(labs)),
      outcome = factor(outcome, levels = c("BMI", "Waist", "Glucose", "Cholesterol"))
    )
}

fit_waist_protein_activity <- function(data, design) {
  svyglm(
    BMXWAIST ~ total_sugar + total_carbs + total_fat + total_cholesterol + Fiber_c +
      Protein_c + PAD680_c + Activity_c + Protein_c:Activity_c +
      RIDAGEYR + Female + SLD012,
    design = design
  )
}

reference_row_for_prediction <- function(data) {
  num_means <- function(v) mean(data[[v]], na.rm = TRUE)
  data.frame(
    total_sugar = num_means("total_sugar"),
    total_carbs = num_means("total_carbs"),
    total_fat = num_means("total_fat"),
    total_cholesterol = num_means("total_cholesterol"),
    total_fiber = num_means("total_fiber"),
    PAD680 = num_means("PAD680"),
    RIDAGEYR = num_means("RIDAGEYR"),
    Female = num_means("Female"),
    SLD012 = num_means("SLD012"),
    stringsAsFactors = FALSE
  )
}

build_interaction_prediction_grid <- function(data, n = 80) {
  ref <- reference_row_for_prediction(data)
  mu_p <- mean(data$total_protein, na.rm = TRUE)
  mu_a <- mean(data$total_activity_min, na.rm = TRUE)
  mu_fiber <- mean(data$total_fiber, na.rm = TRUE)
  mu_pad <- mean(data$PAD680, na.rm = TRUE)

  p_seq <- seq(
    quantile(data$total_protein, 0.05, na.rm = TRUE),
    quantile(data$total_protein, 0.95, na.rm = TRUE),
    length.out = n
  )
  act_low <- as.numeric(quantile(data$total_activity_min, 0.25, na.rm = TRUE))
  act_high <- as.numeric(quantile(data$total_activity_min, 0.75, na.rm = TRUE))

  low_df <- data.frame(
    total_protein = p_seq,
    total_activity_min = act_low,
    activity_group = "Low activity (25th pct)",
    stringsAsFactors = FALSE
  )
  high_df <- data.frame(
    total_protein = p_seq,
    total_activity_min = act_high,
    activity_group = "High activity (75th pct)",
    stringsAsFactors = FALSE
  )
  nd <- bind_rows(low_df, high_df)
  for (nm in names(ref)) {
    nd[[nm]] <- ref[[nm]][1]
  }
  nd$Fiber_c <- nd$total_fiber - mu_fiber
  nd$Protein_c <- nd$total_protein - mu_p
  nd$PAD680_c <- nd$PAD680 - mu_pad
  nd$Activity_c <- nd$total_activity_min - mu_a
  nd
}

run_poster_outputs <- function(data = NULL, design = NULL, main_res = NULL) {
  if (is.null(data)) data <- prepare_data()
  if (is.null(design)) design <- make_design(data)
  if (is.null(main_res)) {
    main_res <- run_audit_vif_main(data, design, make_plots = FALSE)
  }

  # ---- 1) Main results table ----
  tab <- build_main_results_table(main_res)
  write.csv(tab$long, file.path(OUT_DIR, "main_results_long.csv"), row.names = FALSE)
  write.csv(tab$display, file.path(OUT_DIR, "main_results_table.csv"), row.names = FALSE)

  # Wide sheet for slides (coef and p separate columns per outcome)
  wide_slides <- tab$long %>%
    mutate(
      coef_label = sprintf("%.4g%s", estimate, p_stars(p_value)),
      p_label = sprintf("%.4f", p_value)
    ) %>%
    select(outcome, term, estimate, std_error, p_value, coef_label, p_label) %>%
    pivot_wider(
      id_cols = term,
      names_from = outcome,
      values_from = c(estimate, p_value, coef_label, p_label),
      names_sep = "___"
    )
  write.csv(wide_slides, file.path(OUT_DIR, "main_results_wide.csv"), row.names = FALSE)

  # ---- 1b) Report regression table (main svyglm only; separate PDF for paste / print) ----
  report_df <- build_main_regression_report_table(main_res)
  report_pdf <- file.path(OUT_DIR, "main_regression_table.pdf")
  write.csv(report_df, file.path(OUT_DIR, "main_regression_table_report.csv"), row.names = FALSE)
  utils::write.table(
    report_df,
    file.path(OUT_DIR, "main_regression_table_report.txt"),
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )
  if (requireNamespace("knitr", quietly = TRUE)) {
    km <- knitr::kable(
      report_df,
      format = "pipe",
      caption = "Survey-weighted main effects (svyglm); stars: *** p<0.01, ** p<0.05, * p<0.10"
    )
    writeLines(as.character(km), file.path(OUT_DIR, "main_regression_table_report.md"))
  }
  plot_main_regression_table_pdf(report_df, report_pdf)

  report_df_p <- build_main_regression_report_table_pvalues(main_res, for_pdf = TRUE)
  report_pdf_p <- file.path(OUT_DIR, "main_regression_table_pvalues.pdf")
  report_df_p_csv <- build_main_regression_report_table_pvalues(main_res, for_pdf = FALSE)
  write.csv(
    report_df_p_csv,
    file.path(OUT_DIR, "main_regression_table_pvalues_report.csv"),
    row.names = FALSE
  )
  plot_main_regression_table_pvalues_pdf(report_df_p, report_pdf_p)

  # ---- 2) Coefficient plot ----
  cp <- coef_plot_data(main_res)
  p_coef <- ggplot(cp, aes(x = estimate, y = term, color = outcome)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_pointrange(
      aes(xmin = estimate - 1.96 * std_error, xmax = estimate + 1.96 * std_error),
      position = position_dodge(width = 0.35),
      size = 0.35
    ) +
    scale_color_brewer(palette = "Set2", name = "Outcome") +
    labs(
      title = "Key predictors across outcomes (survey-weighted)",
      subtitle = "Error bars: approximate 95% CI (estimate ± 1.96 × SE)",
      x = "Coefficient (same units as outcome per day or per unit predictor)",
      y = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "right", plot.title = element_text(face = "bold"))

  ggsave(file.path(OUT_DIR, "coefficient_plot.png"), p_coef, width = 9, height = 5, dpi = 150)

  # ---- 3) Protein × Activity on waist (interaction model from 03_interaction_models.R) ----
  mod_waist_pa <- fit_waist_protein_activity(data, design)
  grid <- build_interaction_prediction_grid(data, n = 80)
  grid$fitted <- as.numeric(predict(mod_waist_pa, newdata = grid, type = "response"))

  p_int <- ggplot(grid, aes(x = total_protein, y = fitted, color = activity_group)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c("#2166AC", "#B2182B"), name = NULL) +
    labs(
      title = "Waist circumference: protein × activity",
      subtitle = "Other covariates held at sample means; activity at 25th vs 75th percentile",
      x = "Total protein (g/day, as in NHANES)",
      y = "Predicted waist (cm)"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(OUT_DIR, "interaction_protein_activity_waist.png"), p_int, width = 8, height = 5, dpi = 150)

  # ---- 4) Optional body composition: BMI vs waist ----
  dc <- data[complete.cases(data[c("BMXBMI", "BMXWAIST")]), ]
  p_body <- ggplot(dc, aes(x = BMXBMI, y = BMXWAIST)) +
    geom_point(alpha = 0.25, size = 0.8) +
    geom_smooth(method = "loess", se = TRUE, linewidth = 0.8, color = "#1B7837") +
    labs(
      title = "Body composition: waist vs BMI",
      x = "BMI (kg/m²)",
      y = "Waist circumference (cm)"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(OUT_DIR, "bodycomp_bmi_waist_scatter.png"), p_body, width = 7, height = 5, dpi = 150)

  # ---- Combined PDF (one figure per page) ----
  pdf_path <- file.path(OUT_DIR, "poster_figures.pdf")
  grDevices::pdf(pdf_path, width = 9, height = 5.5)
  print(p_coef)
  print(p_int)
  print(p_body)
  grDevices::dev.off()

  cat("\nPoster outputs written to:\n  ", OUT_DIR, "\n", sep = "")
  cat("  - main_results_long.csv\n")
  cat("  - main_results_table.csv\n")
  cat("  - main_results_wide.csv\n")
  cat("  - coefficient_plot.png\n")
  cat("  - interaction_protein_activity_waist.png\n")
  cat("  - bodycomp_bmi_waist_scatter.png\n")
  cat("  - poster_figures.pdf\n")
  cat("  - main_regression_table.pdf (main-effects table only)\n")
  cat("  - main_regression_table_report.csv / .txt / .md (if knitr)\n")
  cat("  - main_regression_table_pvalues.pdf / main_regression_table_pvalues_report.csv\n")

  invisible(list(
    main_table = tab,
    report_table = report_df,
    coef_plot = p_coef,
    interaction_plot = p_int,
    body_plot = p_body,
    waist_prot_act_model = mod_waist_pa,
    out_dir = OUT_DIR,
    poster_pdf = pdf_path,
    main_regression_table_pdf = report_pdf,
    main_regression_table_pvalues_pdf = report_pdf_p
  ))
}

# Auto-run when sourced: uses global `data`, `design`, `main_res` if present (e.g. after run_all)
if (exists("ROOT")) {
  e <- .GlobalEnv
  data_p <- if (exists("data", envir = e, inherits = FALSE)) get("data", envir = e) else prepare_data()
  design_p <- if (exists("design", envir = e, inherits = FALSE)) get("design", envir = e) else make_design(data_p)
  main_p <- if (exists("main_res", envir = e, inherits = FALSE)) get("main_res", envir = e) else NULL
  poster_res <- run_poster_outputs(data_p, design_p, main_res = main_p)
}
