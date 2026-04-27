/**
 * Trend analysis utilities for daily log data
 * Calculates slopes, recent averages, and trajectory patterns
 */

/**
 * Parse date string (YYYY-MM-DD) to timestamp
 */
function parseLogDate(dateStr) {
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d).getTime();
}

/**
 * Calculate days ago from a date string
 */
function daysAgo(dateStr) {
  const logTime = parseLogDate(dateStr);
  const now = Date.now();
  return Math.floor((now - logTime) / (1000 * 60 * 60 * 24));
}

/**
 * Linear regression: returns slope (rate of change per day)
 */
function linearRegression(points) {
  if (points.length < 2) return 0;

  const n = points.length;
  let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

  points.forEach((p) => {
    sumX += p.x;
    sumY += p.y;
    sumXY += p.x * p.y;
    sumX2 += p.x * p.x;
  });

  const denominator = n * sumX2 - sumX * sumX;
  if (Math.abs(denominator) < 1e-10) return 0;

  const slope = (n * sumXY - sumX * sumY) / denominator;
  return slope;
}

/**
 * Calculate exponentially weighted moving average
 * More recent values have higher weight
 */
function exponentialSmoothing(values, alpha = 0.3) {
  if (values.length === 0) return null;
  if (values.length === 1) return values[0];

  let ema = values[0];
  for (let i = 1; i < values.length; i++) {
    ema = alpha * values[i] + (1 - alpha) * ema;
  }
  return ema;
}

/**
 * Calculate variance of values
 */
function variance(values) {
  if (values.length < 2) return 0;
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  const squaredDiffs = values.map(v => Math.pow(v - mean, 2));
  return squaredDiffs.reduce((a, b) => a + b, 0) / values.length;
}

/**
 * Main trend analysis function
 * @param {Array} logs - Array of daily log objects with date field
 * @param {string} metric - The metric to analyze (e.g., 'protein', 'weight_kg')
 * @param {number} recentDays - Number of days to consider "recent" (default 30)
 * @returns {Object} Trend analysis results
 */
export function analyzeTrend(logs, metric, recentDays = 30) {
  if (!logs || logs.length === 0) {
    return {
      slope: 0,
      direction: "stable",
      recent_avg: null,
      overall_avg: null,
      variance: 0,
      data_points: 0,
      recent_data_points: 0,
    };
  }

  // Filter and sort logs by date
  const validLogs = logs
    .filter((log) => log.date && Number.isFinite(Number(log[metric])))
    .sort((a, b) => parseLogDate(a.date) - parseLogDate(b.date));

  if (validLogs.length === 0) {
    return {
      slope: 0,
      direction: "stable",
      recent_avg: null,
      overall_avg: null,
      variance: 0,
      data_points: 0,
      recent_data_points: 0,
    };
  }

  // Prepare data points for regression (x = day index, y = value)
  const allPoints = validLogs.map((log, idx) => ({
    x: idx,
    y: Number(log[metric]),
    date: log.date,
  }));

  // Calculate overall metrics
  const allValues = allPoints.map((p) => p.y);
  const overall_avg = allValues.reduce((a, b) => a + b, 0) / allValues.length;
  const overall_variance = variance(allValues);

  // Filter recent data (last N days)
  const recentLogs = validLogs.filter((log) => daysAgo(log.date) <= recentDays);
  const recentValues = recentLogs.map((log) => Number(log[metric]));
  const recent_avg = recentValues.length > 0
    ? recentValues.reduce((a, b) => a + b, 0) / recentValues.length
    : overall_avg;

  // Calculate exponentially weighted average (recent data weighted more)
  const ema = exponentialSmoothing(allValues, 0.3);

  // Calculate slope (rate of change per day)
  const slope = linearRegression(allPoints);

  // Determine direction with metric-specific thresholds
  let direction = "stable";
  let threshold;

  // Use appropriate thresholds for different metrics
  if (metric === "weight_kg") {
    threshold = 0.03; // 0.03 kg/day = ~0.2 kg/week (realistic weight change)
  } else if (metric === "total_calories") {
    threshold = 20; // 20 kcal/day
  } else if (metric === "activity_min") {
    threshold = 5; // 5 min/week change
  } else if (metric === "sedentary_min") {
    threshold = 5; // 5 min/day change
  } else {
    // For macros (protein, carbs, fat, sugar, fiber), use 1% of mean or 0.5g minimum
    threshold = Math.max(0.5, Math.abs(overall_avg) * 0.01);
  }

  if (slope > threshold) {
    direction = "increasing";
  } else if (slope < -threshold) {
    direction = "decreasing";
  }

  // Calculate baseline (30 days ago avg vs recent avg)
  const oldLogs = validLogs.filter(
    (log) => daysAgo(log.date) > recentDays && daysAgo(log.date) <= recentDays * 2
  );
  const baseline_avg = oldLogs.length > 0
    ? oldLogs.map((log) => Number(log[metric])).reduce((a, b) => a + b, 0) / oldLogs.length
    : overall_avg;

  const change_from_baseline = recent_avg - baseline_avg;

  return {
    slope: slope,
    direction: direction,
    recent_avg: recent_avg,
    overall_avg: overall_avg,
    ema: ema,
    variance: overall_variance,
    data_points: validLogs.length,
    recent_data_points: recentLogs.length,
    baseline_avg: baseline_avg,
    change_from_baseline: change_from_baseline,
  };
}

/**
 * Analyze trends for all key metrics
 * @param {Array} logs - Daily log data
 * @returns {Object} Trends for all metrics
 */
export function analyzeAllTrends(logs) {
  const metrics = [
    "protein",
    "carbs",
    "fat",
    "sugar",
    "fiber",
    "total_calories",
    "weight_kg",
    "activity_min",
    "sedentary_min",
    "sleep_hours",
  ];

  const trends = {};
  metrics.forEach((metric) => {
    trends[metric] = analyzeTrend(logs, metric, 30);
  });

  return trends;
}

/**
 * Determine if user is already improving toward their goal
 * @param {Object} trends - Trend analysis results
 * @param {string} goal - User's health goal
 * @returns {boolean} True if already trending in right direction
 */
export function isAlreadyImproving(trends, goal) {
  const weightTrend = trends.weight_kg?.direction;
  const proteinTrend = trends.protein?.direction;
  const fiberTrend = trends.fiber?.direction;
  const sugarTrend = trends.sugar?.direction;

  switch (goal) {
    case "lose_weight":
    case "reduce_bmi":
    case "reduce_waist":
      return weightTrend === "decreasing";

    case "gain_weight":
      return weightTrend === "increasing";

    case "build_muscle":
      return proteinTrend === "increasing" || weightTrend === "increasing";

    case "improve_glucose":
    case "improve_cholesterol":
      return sugarTrend === "decreasing" && fiberTrend === "increasing";

    case "general_health":
      return fiberTrend === "increasing" && sugarTrend === "decreasing";

    default:
      return false;
  }
}
