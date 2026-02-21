library(haven)
library(dplyr)
library(ggplot2)
library(tidyr)

cat("Generating plots...\n")

data <- read_xpt("DR1IFF_L (1).xpt")

if (!dir.exists("plots")) {
  dir.create("plots")
}

cat("1. Creating calories histogram...\n")
p1 <- ggplot(data, aes(x = DR1IKCAL)) +
  geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7) +
  geom_vline(aes(xintercept = mean(DR1IKCAL, na.rm = TRUE)), 
             color = "red", linetype = "dashed", size = 1) +
  labs(title = "Distribution of Daily Caloric Intake",
       x = "Calories (kcal)",
       y = "Frequency") +
  theme_minimal()
ggsave("plots/01_calories_histogram.png", p1, width = 10, height = 6, dpi = 300)

cat("2. Creating macronutrient boxplot...\n")
macros <- data %>%
  select(SEQN, DR1IKCAL, DR1IPROT, DR1ICARB, DR1ITFAT, DR1ISUGR, DR1IFIBE) %>%
  na.omit() %>%
  mutate(
    protein_pct = (DR1IPROT * 4 / DR1IKCAL) * 100,
    carb_pct = (DR1ICARB * 4 / DR1IKCAL) * 100,
    fat_pct = (DR1ITFAT * 9 / DR1IKCAL) * 100
  )

macros_long <- macros %>%
  select(protein_pct, carb_pct, fat_pct) %>%
  pivot_longer(everything(), names_to = "macronutrient", values_to = "percentage") %>%
  mutate(macronutrient = case_when(
    macronutrient == "protein_pct" ~ "Protein",
    macronutrient == "carb_pct" ~ "Carbohydrates",
    macronutrient == "fat_pct" ~ "Fat"
  ))

p2 <- ggplot(macros_long, aes(x = macronutrient, y = percentage)) +
  geom_boxplot(fill = "steelblue", alpha = 0.7) +
  labs(title = "Distribution of Macronutrient Percentages",
       x = "Macronutrient",
       y = "Percentage of Total Calories (%)") +
  theme_minimal()
ggsave("plots/02_macronutrient_boxplot.png", p2, width = 10, height = 6, dpi = 300)

cat("3. Creating calories vs protein scatter plot...\n")
p3 <- ggplot(macros, aes(x = DR1IKCAL, y = DR1IPROT)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", color = "red") +
  labs(title = "Relationship: Calories vs Protein Intake",
       x = "Calories (kcal)",
       y = "Protein (g)") +
  theme_minimal()
ggsave("plots/03_calories_vs_protein.png", p3, width = 10, height = 6, dpi = 300)

cat("4. Creating recall status bar chart...\n")
if("DR1DRSTZ" %in% names(data)) {
  recall_status <- data %>%
    count(DR1DRSTZ) %>%
    mutate(pct = n / sum(n) * 100)
  
  p4 <- ggplot(recall_status, aes(x = factor(DR1DRSTZ), y = n)) +
    geom_bar(stat = "identity", fill = "steelblue", alpha = 0.7) +
    labs(title = "Distribution of Dietary Recall Status",
         x = "Recall Status Code",
         y = "Count") +
    theme_minimal()
  ggsave("plots/04_recall_status.png", p4, width = 10, height = 6, dpi = 300)
}

cat("5. Creating day of week bar chart...\n")
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
  
  p5 <- ggplot(day_analysis, aes(x = reorder(day_name, DR1DAY), y = mean_calories)) +
    geom_bar(stat = "identity", fill = "steelblue", alpha = 0.7) +
    labs(title = "Average Caloric Intake by Day of Week",
         x = "Day of Week",
         y = "Mean Calories (kcal)") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  ggsave("plots/05_day_of_week.png", p5, width = 10, height = 6, dpi = 300)
}

cat("\n=== All plots saved to 'plots/' directory ===\n")
cat("You can now open the PNG files to view the graphs!\n")
cat("Files created:\n")
cat("  - plots/01_calories_histogram.png\n")
cat("  - plots/02_macronutrient_boxplot.png\n")
cat("  - plots/03_calories_vs_protein.png\n")
if("DR1DRSTZ" %in% names(data)) cat("  - plots/04_recall_status.png\n")
if("DR1DAY" %in% names(data)) cat("  - plots/05_day_of_week.png\n")


