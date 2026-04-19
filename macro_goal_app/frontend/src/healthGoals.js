export const GOALS = [
  { value: "general_health", label: "General Health", category: "Health" },
  { value: "lose_weight", label: "Lose Weight", category: "Body Composition" },
  { value: "gain_weight", label: "Gain Weight", category: "Body Composition" },
  { value: "build_muscle", label: "Build Muscle", category: "Body Composition" },
  { value: "reduce_bmi", label: "Reduce BMI", category: "Health Outcomes" },
  { value: "reduce_waist", label: "Reduce Waist Circumference", category: "Health Outcomes" },
  { value: "improve_cholesterol", label: "Improve Cholesterol", category: "Health Outcomes" },
  { value: "improve_glucose", label: "Improve Glucose Levels", category: "Health Outcomes" },
];

export function goalsByCategoryFrom(goals) {
  return goals.reduce((acc, goal) => {
    if (!acc[goal.category]) acc[goal.category] = [];
    acc[goal.category].push(goal);
    return acc;
  }, {});
}
