library(haven)
library(dplyr)
library(ggplot2)
library(tidyr)

cat("=== DR1IFF Analysis Script ===\n\n")

data <- read_xpt("DR1IFF_L (1).xpt")
cat("Data loaded:", nrow(data), "rows,", ncol(data), "columns\n\n")

cat("=== 1. Energy Intake Summary ===\n")
calories_summary <- data %>%
  summarise(
    mean_kcal = mean(DR1IKCAL, na.rm = TRUE),
    median_kcal = median(DR1IKCAL, na.rm = TRUE),
    sd_kcal = sd(DR1IKCAL, na.rm = TRUE),
    min_kcal = min(DR1IKCAL, na.rm = TRUE),
    max_kcal = max(DR1IKCAL, na.rm = TRUE),
    q25 = quantile(DR1IKCAL, 0.25, na.rm = TRUE),
    q75 = quantile(DR1IKCAL, 0.75, na.rm = TRUE)
  )
print(calories_summary)

cat("\n=== 2. Macronutrient Summary ===\n")
macros <- data %>%
  select(SEQN, DR1IKCAL, DR1IPROT, DR1ICARB, DR1ITFAT, DR1ISUGR, DR1IFIBE) %>%
  na.omit() %>%
  mutate(
    protein_pct = (DR1IPROT * 4 / DR1IKCAL) * 100,
    carb_pct = (DR1ICARB * 4 / DR1IKCAL) * 100,
    fat_pct = (DR1ITFAT * 9 / DR1IKCAL) * 100
  )

macros_summary <- macros %>%
  summarise(
    mean_protein_g = mean(DR1IPROT, na.rm = TRUE),
    mean_carb_g = mean(DR1ICARB, na.rm = TRUE),
    mean_fat_g = mean(DR1ITFAT, na.rm = TRUE),
    mean_sugar_g = mean(DR1ISUGR, na.rm = TRUE),
    mean_fiber_g = mean(DR1IFIBE, na.rm = TRUE),
    mean_protein_pct = mean(protein_pct, na.rm = TRUE),
    mean_carb_pct = mean(carb_pct, na.rm = TRUE),
    mean_fat_pct = mean(fat_pct, na.rm = TRUE)
  )
print(macros_summary)

cat("\n=== 3. Fat Composition ===\n")
fat_analysis <- data %>%
  select(DR1ITFAT, DR1ISFAT, DR1IMFAT, DR1IPFAT) %>%
  na.omit() %>%
  summarise(
    mean_total_fat = mean(DR1ITFAT, na.rm = TRUE),
    mean_saturated = mean(DR1ISFAT, na.rm = TRUE),
    mean_monounsaturated = mean(DR1IMFAT, na.rm = TRUE),
    mean_polyunsaturated = mean(DR1IPFAT, na.rm = TRUE),
    sat_pct = mean(DR1ISFAT / DR1ITFAT * 100, na.rm = TRUE),
    mono_pct = mean(DR1IMFAT / DR1ITFAT * 100, na.rm = TRUE),
    poly_pct = mean(DR1IPFAT / DR1ITFAT * 100, na.rm = TRUE)
  )
print(fat_analysis)

cat("\n=== 4. Cholesterol ===\n")
if("DR1ICHOL" %in% names(data)) {
  chol_summary <- data %>%
    summarise(
      mean_chol = mean(DR1ICHOL, na.rm = TRUE),
      median_chol = median(DR1ICHOL, na.rm = TRUE),
      above_300mg = sum(DR1ICHOL > 300, na.rm = TRUE),
      pct_above_300 = mean(DR1ICHOL > 300, na.rm = TRUE) * 100
    )
  print(chol_summary)
}

cat("\n=== 5. Micronutrients ===\n")
micronutrient_vars <- c("DR1IRET", "DR1IVARA", "DR1IACAR", "DR1IBCAR", "DR1ICRYP", "DR1ILYCO")
micronutrients <- data %>%
  select(any_of(micronutrient_vars)) %>%
  summarise_all(~ mean(., na.rm = TRUE))
if(ncol(micronutrients) > 0) {
  print(micronutrients)
}

cat("\n=== 6. Missing Data (Top 10) ===\n")
missing_summary <- data %>%
  summarise_all(~ sum(is.na(.))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "missing_count") %>%
  filter(missing_count > 0) %>%
  arrange(desc(missing_count)) %>%
  mutate(missing_pct = (missing_count / nrow(data)) * 100) %>%
  head(10)
print(missing_summary)

cat("\n=== 7. Correlations ===\n")
if(nrow(macros) > 0) {
  cor_cal_prot <- cor(macros$DR1IKCAL, macros$DR1IPROT, use = "complete.obs")
  cor_cal_carb <- cor(macros$DR1IKCAL, macros$DR1ICARB, use = "complete.obs")
  cor_cal_fat <- cor(macros$DR1IKCAL, macros$DR1ITFAT, use = "complete.obs")
  cat("Correlation with Calories:\n")
  cat("  Protein:", round(cor_cal_prot, 3), "\n")
  cat("  Carbohydrates:", round(cor_cal_carb, 3), "\n")
  cat("  Fat:", round(cor_cal_fat, 3), "\n")
}

cat("\n=== 8. Dietary Recall Status ===\n")
if("DR1DRSTZ" %in% names(data)) {
  recall_status <- data %>%
    count(DR1DRSTZ) %>%
    mutate(pct = n / sum(n) * 100)
  print(recall_status)
}

cat("\n=== 9. Day of Week Analysis ===\n")
if("DR1DAY" %in% names(data)) {
  day_analysis <- data %>%
    group_by(DR1DAY) %>%
    summarise(
      mean_calories = mean(DR1IKCAL, na.rm = TRUE),
      n = n()
    ) %>%
    mutate(day_name = case_when(
      DR1DAY == 1 ~ "Sunday",
      DR1DAY == 2 ~ "Monday",
      DR1DAY == 3 ~ "Tuesday",
      DR1DAY == 4 ~ "Wednesday",
      DR1DAY == 5 ~ "Thursday",
      DR1DAY == 6 ~ "Friday",
      DR1DAY == 7 ~ "Saturday"
    ))
  print(day_analysis)
}

cat("\n=== 10. Outliers ===\n")
cal_q1 <- quantile(data$DR1IKCAL, 0.25, na.rm = TRUE)
cal_q3 <- quantile(data$DR1IKCAL, 0.75, na.rm = TRUE)
cal_iqr <- IQR(data$DR1IKCAL, na.rm = TRUE)
upper_bound <- cal_q3 + 1.5 * cal_iqr
lower_bound <- cal_q1 - 1.5 * cal_iqr

outlier_analysis <- data %>%
  summarise(
    calories_q1 = cal_q1,
    calories_q3 = cal_q3,
    calories_iqr = cal_iqr,
    upper_bound = upper_bound,
    lower_bound = lower_bound,
    calories_outliers = sum(DR1IKCAL > upper_bound | DR1IKCAL < lower_bound, na.rm = TRUE),
    pct_outliers = mean(DR1IKCAL > upper_bound | DR1IKCAL < lower_bound, na.rm = TRUE) * 100
  )
print(outlier_analysis)

cat("\n=== KEY INSIGHTS SUMMARY ===\n")
cat("1. Total Records:", nrow(data), "\n")
cat("2. Mean Daily Calories:", round(mean(data$DR1IKCAL, na.rm = TRUE), 2), "kcal\n")
cat("3. Mean Protein:", round(mean(data$DR1IPROT, na.rm = TRUE), 2), "g\n")
cat("4. Mean Carbohydrates:", round(mean(data$DR1ICARB, na.rm = TRUE), 2), "g\n")
cat("5. Mean Total Fat:", round(mean(data$DR1ITFAT, na.rm = TRUE), 2), "g\n")

cat("\n=== Analysis Complete ===\n")


