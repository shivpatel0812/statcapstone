# Compile all graphs into a single comprehensive PDF
# Run from backend/Rcode directory

suppressPackageStartupMessages({
  library(png)
  library(grid)
})

# Output PDF path - save to project root
OUTPUT_PDF <- "/Users/shivpatel/STATCapstone_FinalProject/all_capstone_graphs.pdf"

cat("Creating comprehensive PDF of all graphs...\n")
cat("Output location:", OUTPUT_PDF, "\n\n")

# Define all graph locations
POSTER_DIR <- file.path(getwd(), "poster_output")
# Python code is in project root, not in backend
PYTHON_OLS_DIR <- "/Users/shivpatel/STATCapstone_FinalProject/python_code/ols_output"
PYTHON_INT_DIR <- "/Users/shivpatel/STATCapstone_FinalProject/python_code/interaction_output"

# Helper function to add a PNG to PDF
add_png_page <- function(png_path, title = NULL) {
  if (!file.exists(png_path)) {
    cat("  ⚠ File not found:", png_path, "\n")
    return(NULL)
  }

  tryCatch({
    img <- readPNG(png_path)
    grid.newpage()

    # Add title if provided
    if (!is.null(title)) {
      grid.text(title, x = 0.5, y = 0.98,
                gp = gpar(fontsize = 16, fontface = "bold"))
      vp_y <- 0.93
      vp_height <- 0.86
    } else {
      vp_y <- 0.5
      vp_height <- 1
    }

    # Add image
    pushViewport(viewport(x = 0.5, y = vp_y,
                          width = 0.95, height = vp_height,
                          just = c("center", "top")))
    grid.raster(img)
    popViewport()

    cat("  ✓ Added:", basename(png_path), "\n")
    return(TRUE)
  }, error = function(e) {
    cat("  ✗ Error loading", basename(png_path), ":", e$message, "\n")
    return(NULL)
  })
}

# Helper function to add a text page (section divider)
add_section_page <- function(section_title, description = NULL) {
  grid.newpage()

  # Title
  grid.text(section_title, x = 0.5, y = 0.6,
            gp = gpar(fontsize = 24, fontface = "bold", col = "#2166AC"))

  # Description
  if (!is.null(description)) {
    grid.text(description, x = 0.5, y = 0.4,
              gp = gpar(fontsize = 14, col = "gray30"))
  }

  cat("\n=== SECTION:", section_title, "===\n")
}

# Start PDF
pdf(OUTPUT_PDF, width = 11, height = 8.5)

# ============================================================================
# TITLE PAGE
# ============================================================================
grid.newpage()
grid.text("NHANES 2021-2023 Capstone Analysis",
          x = 0.5, y = 0.7,
          gp = gpar(fontsize = 28, fontface = "bold", col = "#2166AC"))
grid.text("Diet, Physical Activity, and Health Outcomes",
          x = 0.5, y = 0.6,
          gp = gpar(fontsize = 18, col = "gray30"))
grid.text("Complete Visualization Compendium",
          x = 0.5, y = 0.5,
          gp = gpar(fontsize = 16, col = "gray50"))
grid.text(paste("Generated:", Sys.Date()),
          x = 0.5, y = 0.3,
          gp = gpar(fontsize = 12, col = "gray60"))

# ============================================================================
# SECTION 1: MAIN RESULTS (R POSTER PLOTS)
# ============================================================================
add_section_page("Main Results", "Survey-weighted regression models")

# Coefficient plot
add_png_page(
  file.path(POSTER_DIR, "coefficient_plot.png"),
  "Key Predictors Across Outcomes (Survey-Weighted)"
)

# Main regression tables
if (file.exists(file.path(POSTER_DIR, "main_regression_table.pdf"))) {
  cat("  ℹ Including main_regression_table.pdf (separate file)\n")
}
if (file.exists(file.path(POSTER_DIR, "main_regression_table_pvalues.pdf"))) {
  cat("  ℹ Including main_regression_table_pvalues.pdf (separate file)\n")
}

# ============================================================================
# SECTION 2: INTERACTION EFFECTS
# ============================================================================
add_section_page("Interaction Effects", "Protein × Activity on Waist Circumference")

add_png_page(
  file.path(POSTER_DIR, "interaction_protein_activity_waist.png"),
  "Protein × Activity Interaction on Waist"
)

# ============================================================================
# SECTION 3: BODY COMPOSITION
# ============================================================================
add_section_page("Body Composition Analysis", "BMI vs Waist Circumference")

add_png_page(
  file.path(POSTER_DIR, "bodycomp_bmi_waist_scatter.png"),
  "Body Composition: Waist vs BMI"
)

# ============================================================================
# SECTION 4: MODEL DIAGNOSTICS - OLS MODELS
# ============================================================================
add_section_page("Model Diagnostics: OLS Models",
                 "Residual plots for baseline regression models")

# OLS diagnostic plots
ols_plots <- c(
  "diagnostics_BMI.png",
  "diagnostics_Waist_Circumference_(cm).png",
  "diagnostics_Fasting_Glucose_(mmol_L).png",
  "diagnostics_Total_Cholesterol_(mg_dL).png"
)

for (plot in ols_plots) {
  outcome_name <- gsub("diagnostics_", "", gsub("\\.png$", "", plot))
  outcome_name <- gsub("_", " ", outcome_name)
  outcome_name <- gsub("\\(", "(", outcome_name)
  add_png_page(
    file.path(PYTHON_OLS_DIR, plot),
    paste("OLS Diagnostics:", outcome_name)
  )
}

# ============================================================================
# SECTION 5: MODEL DIAGNOSTICS - OLS REFINED
# ============================================================================
add_section_page("Model Diagnostics: OLS Refined Models",
                 "Residual plots after model refinement")

ols_refined_plots <- c(
  "diagnostics_BMI_(refined).png",
  "diagnostics_Waist_Circumference_(cm)_(refined).png",
  "diagnostics_Fasting_Glucose_(mmol_L)_(refined).png",
  "diagnostics_Total_Cholesterol_(mg_dL)_(refined).png"
)

for (plot in ols_refined_plots) {
  outcome_name <- gsub("diagnostics_", "", gsub("\\.png$", "", plot))
  outcome_name <- gsub("_\\(refined\\)", " (Refined)", outcome_name)
  outcome_name <- gsub("_", " ", outcome_name)
  add_png_page(
    file.path(PYTHON_OLS_DIR, plot),
    paste("OLS Diagnostics:", outcome_name)
  )
}

# ============================================================================
# SECTION 6: INTERACTION MODEL DIAGNOSTICS
# ============================================================================
add_section_page("Interaction Model Diagnostics",
                 "Fiber × Activity and Sugar × Activity interactions")

# Interaction diagnostic plots
int_plots <- list.files(PYTHON_INT_DIR, pattern = "^diagnostics_.*\\.png$", full.names = FALSE)

if (length(int_plots) > 0) {
  # Sort plots by outcome
  int_plots <- sort(int_plots)

  for (plot in int_plots) {
    outcome_name <- gsub("diagnostics_", "", gsub("\\.png$", "", plot))
    outcome_name <- gsub("___", ": ", outcome_name)
    outcome_name <- gsub("_x_", " × ", outcome_name)
    outcome_name <- gsub("_\\(refined\\)", " (Refined)", outcome_name)
    outcome_name <- gsub("_", " ", outcome_name)
    add_png_page(
      file.path(PYTHON_INT_DIR, plot),
      paste("Interaction Diagnostics:", outcome_name)
    )
  }
} else {
  cat("  ℹ No interaction diagnostic plots found\n")
}

# Close PDF
dev.off()

cat("\n========== PDF COMPILATION COMPLETE ==========\n")
cat("Output saved to:", OUTPUT_PDF, "\n")
cat("Open with: open", shQuote(OUTPUT_PDF), "\n")
