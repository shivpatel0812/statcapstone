cat("=== Running All Analysis Scripts ===\n\n")

cat("1. Reading data files...\n")
cat("   - DR1IFF data...\n")
source("read_dr1iff.R")
cat("\n   - PAQ data...\n")
source("read_paq.R")
cat("\n   - DBQ data...\n")
source("read_dbq.R")

cat("\n2. Running full analysis...\n")
source("run_dr1iff_analysis.R")

cat("\n3. Generating plots...\n")
source("generate_plots.R")

cat("\n=== All scripts completed! ===\n")
cat("Check the 'plots/' directory for visualization files.\n")


