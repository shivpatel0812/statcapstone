import { useState } from "react";

// Vercel: set VITE_API_URL to your Railway URL, e.g. https://your-app.up.railway.app (no trailing slash)
const API_BASE = (import.meta.env.VITE_API_URL || "http://localhost:8000").replace(/\/$/, "");
const API_URL = `${API_BASE}/recommend`;

function Icon({ children, className = "section-icon", title, size = 20 }) {
  const decorative = title == null || title === "";
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden={decorative ? true : undefined}
      role={decorative ? "presentation" : undefined}
    >
      {!decorative ? <title>{title}</title> : null}
      {children}
    </svg>
  );
}

function SectionHeader({ icon, title }) {
  return (
    <div className="section-header">
      {icon}
      <h3>{title}</h3>
    </div>
  );
}

const INITIAL = {
  protein: 120,
  carbs: 220,
  fat: 70,
  sugar: 65,
  fiber: 18,
  sex: "male",
  weight_kg: 75,
  height_cm: 178,
  sleep_hours: 7,
  activity_min: 150,
  sedentary_min: 360,
  goal: "general_health",
  time_range: "general",
};

const GOALS = [
  { value: "general_health", label: "General Health", category: "Health" },
  { value: "lose_weight", label: "Lose Weight", category: "Body Composition" },
  { value: "gain_weight", label: "Gain Weight", category: "Body Composition" },
  { value: "build_muscle", label: "Build Muscle", category: "Body Composition" },
  { value: "reduce_bmi", label: "Reduce BMI", category: "Health Outcomes" },
  { value: "reduce_waist", label: "Reduce Waist Circumference", category: "Health Outcomes" },
  { value: "improve_cholesterol", label: "Improve Cholesterol", category: "Health Outcomes" },
  { value: "improve_glucose", label: "Improve Glucose Levels", category: "Health Outcomes" },
];

export default function App() {
  const [form, setForm] = useState(INITIAL);
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  function onChange(e) {
    const { name, value } = e.target;
    setForm((prev) => ({
      ...prev,
      [name]: ["goal", "sex", "time_range"].includes(name) ? value : Number(value),
    }));
  }

  async function onSubmit(e) {
    e.preventDefault();
    setLoading(true);
    setError("");
    setResult(null);

    try {
      const res = await fetch(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });

      const data = await res.json();
      if (!res.ok) {
        throw new Error(data?.detail?.message || data?.detail || "Request failed");
      }

      setResult(data);
    } catch (err) {
      setError(String(err.message || err));
    } finally {
      setLoading(false);
    }
  }

  const currentMacros = {
    protein: form.protein,
    carbs: form.carbs,
    fat: form.fat,
    sugar: form.sugar,
    fiber: form.fiber,
  };

  // Group goals by category
  const goalsByCategory = GOALS.reduce((acc, goal) => {
    if (!acc[goal.category]) acc[goal.category] = [];
    acc[goal.category].push(goal);
    return acc;
  }, {});

  return (
    <main className="container">
      <header className="header">
        <h1>NHANES Evidence-Based Macro Planner</h1>
        <p className="trust-line">Based on NHANES data</p>
        <p className="subtitle">
          Personalized nutrition recommendations based on NHANES 2021-2023 statistical models (n=6,751).
          Choose your health goal and receive evidence-based macro targets.
        </p>
      </header>

      <form onSubmit={onSubmit} className="form-stack">
        <section className="section-card form-section">
          <SectionHeader
            title="Your Profile"
            icon={
              <Icon title="Profile">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                <circle cx="12" cy="7" r="4" />
              </Icon>
            }
          />
          <div className="grid">
            <label>
              Sex
              <select name="sex" value={form.sex} onChange={onChange}>
                <option value="male">Male</option>
                <option value="female">Female</option>
                <option value="other">Other</option>
              </select>
            </label>
            <label>
              Weight (kg)
              <input type="number" name="weight_kg" value={form.weight_kg} onChange={onChange} min="1" />
            </label>
            <label>
              Height (cm)
              <input type="number" name="height_cm" value={form.height_cm} onChange={onChange} min="50" />
            </label>
          </div>
        </section>

        <section className="section-card form-section">
          <SectionHeader
            title="Current Diet (Daily Intake)"
            icon={
              <Icon title="Diet">
                <path d="M4 10h16M6 10v6a4 4 0 0 0 4 4h4a4 4 0 0 0 4-4v-6" />
                <path d="M4 10l2-5h12l2 5" />
              </Icon>
            }
          />
          <div className="grid">
            <label>
              Protein (g)
              <input type="number" name="protein" value={form.protein} onChange={onChange} min="0" />
            </label>
            <label>
              Carbs (g)
              <input type="number" name="carbs" value={form.carbs} onChange={onChange} min="0" />
            </label>
            <label>
              Fat (g)
              <input type="number" name="fat" value={form.fat} onChange={onChange} min="0" />
            </label>
            <label>
              Sugar (g)
              <input type="number" name="sugar" value={form.sugar} onChange={onChange} min="0" />
            </label>
            <label>
              Fiber (g)
              <input type="number" name="fiber" value={form.fiber} onChange={onChange} min="0" />
            </label>
          </div>
        </section>

        <section className="section-card form-section">
          <SectionHeader
            title="Lifestyle"
            icon={
              <Icon title="Lifestyle">
                <circle cx="12" cy="12" r="4" />
                <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
              </Icon>
            }
          />
          <div className="grid">
            <label className="label-with-icon">
              <span className="label-row">
                <Icon className="section-icon section-icon--inline" size={16}>
                  <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
                </Icon>
                Sleep (hours/night)
              </span>
              <input type="number" step="0.1" name="sleep_hours" value={form.sleep_hours} onChange={onChange} min="0" max="24" />
            </label>
            <label className="label-with-icon">
              <span className="label-row">
                <Icon className="section-icon section-icon--inline" size={16}>
                  <path d="M22 12h-4l-3 9L9 3l-3 9H2" />
                </Icon>
                Weekly Activity (min)
              </span>
              <input
                type="number"
                name="activity_min"
                value={form.activity_min}
                onChange={onChange}
                min="0"
                placeholder="WHO: 150 min/week"
              />
              <small>Moderate + 2×vigorous (WHO-weighted)</small>
            </label>
            <label className="label-with-icon">
              <span className="label-row">
                <Icon className="section-icon section-icon--inline" size={16}>
                  <rect x="2" y="7" width="20" height="14" rx="2" ry="2" />
                  <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
                </Icon>
                Daily Sedentary Time (min)
              </span>
              <input
                type="number"
                name="sedentary_min"
                value={form.sedentary_min}
                onChange={onChange}
                min="0"
                placeholder="e.g., 360 min (6 hrs)"
              />
              <small>Sitting, screen time, desk work</small>
            </label>
          </div>
        </section>

        <section className="section-card form-section goal-section">
          <SectionHeader
            title="Your Goal (Select One)"
            icon={
              <Icon title="Goal">
                <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z" />
                <line x1="4" y1="22" x2="4" y2="15" />
              </Icon>
            }
          />
          <label htmlFor="goal" className="goal-label">
            Choose the health outcome you want to optimize:
          </label>
          <select id="goal" name="goal" value={form.goal} onChange={onChange} className="goal-select">
            {Object.entries(goalsByCategory).map(([category, goals]) => (
              <optgroup key={category} label={category}>
                {goals.map((g) => (
                  <option key={g.value} value={g.value}>
                    {g.label}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
        </section>

        <section className="section-card form-section">
          <SectionHeader
            title="Time Range (Optional)"
            icon={
              <Icon title="Time range">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </Icon>
            }
          />
          <div className="time-range-grid">
            <label>
              <input
                type="radio"
                name="time_range"
                value="general"
                checked={form.time_range === "general"}
                onChange={onChange}
              />
              <span>General (no timeline)</span>
            </label>
            <label>
              <input
                type="radio"
                name="time_range"
                value="3_months"
                checked={form.time_range === "3_months"}
                onChange={onChange}
              />
              <span>3 months</span>
            </label>
            <label>
              <input
                type="radio"
                name="time_range"
                value="6_months"
                checked={form.time_range === "6_months"}
                onChange={onChange}
              />
              <span>6 months</span>
            </label>
            <label>
              <input
                type="radio"
                name="time_range"
                value="12_months"
                checked={form.time_range === "12_months"}
                onChange={onChange}
              />
              <span>12 months</span>
            </label>
          </div>
        </section>

        <button type="submit" disabled={loading} className="submit-btn">
          {loading ? "Generating your plan…" : "Generate Macro Plan"}
        </button>
      </form>

      {error && <div className="card error-card"><p className="error">{error}</p></div>}

      {result?.recommended && (
        <>
          <section className="card result-header">
            <h2>Your Plan: {result.goal_name}</h2>
            <p className="plan-subtitle">{result.time_range}</p>
            <div className="profile-grid">
              <div className="profile-item">
                <span className="profile-label">BMI</span>
                <span className="profile-value">{result.profile.bmi}</span>
              </div>
              <div className="profile-item">
                <span className="profile-label">Activity Level</span>
                <span className="profile-value">{result.profile.activity_level}</span>
              </div>
              <div className="profile-item">
                <span className="profile-label">Current Calories</span>
                <span className="profile-value">{result.profile.current_calories} kcal</span>
              </div>
              <div className="profile-item">
                <span className="profile-label">Target Calories</span>
                <span className="profile-value">
                  {result.profile.target_calories} kcal
                  {result.profile.calorie_change !== undefined && (
                    <span className={`change ${result.profile.calorie_change > 0 ? "positive" : "negative"}`}>
                      {result.profile.calorie_change > 0 ? "+" : ""}
                      {result.profile.calorie_change}
                    </span>
                  )}
                </span>
              </div>
            </div>
          </section>

          <section className="card">
            <h2>Recommended Daily Macros</h2>
            <div className="macro-comparison">
              <div className="macro-row header">
                <span>Nutrient</span>
                <span>Current</span>
                <span>Target</span>
                <span>Change</span>
              </div>
              {Object.keys(currentMacros).map((key) => {
                const current = currentMacros[key];
                const recommended = result.recommended[key];
                const change = recommended - current;
                const changePercent = current > 0 ? ((change / current) * 100).toFixed(0) : 0;
                const isSignificant = Math.abs(change) > 5;
                return (
                  <div key={key} className={`macro-row ${isSignificant ? "significant" : ""}`}>
                    <span className="macro-name">{key.charAt(0).toUpperCase() + key.slice(1)}</span>
                    <span className="current-value">{current}g</span>
                    <span className="recommended-value">{recommended}g</span>
                    <span className={`change-value ${change > 0 ? "positive" : change < 0 ? "negative" : "neutral"}`}>
                      {change > 0 ? "+" : ""}{change.toFixed(1)}g
                      {isSignificant && <span className="percent"> ({changePercent > 0 ? "+" : ""}{changePercent}%)</span>}
                    </span>
                  </div>
                );
              })}
            </div>
          </section>

          <section className="card benefits-card">
            <h2>Evidence from NHANES Models</h2>
            <p className="benefits-intro">
              These recommendations are based on statistical models from 6,751 participants:
            </p>
            <ul className="benefits-list">
              {result.health_benefits.split(" | ").map((benefit, idx) => (
                <li key={idx}>{benefit}</li>
              ))}
            </ul>
          </section>

          <section className="card note-card">
            <p className="note-text">{result.note}</p>
            <div className="citation">
              <strong>Data Source:</strong> National Health and Nutrition Examination Survey (NHANES) 2021-2023.
              Survey-weighted regression models account for complex sampling design.
              <br />
              <strong>Key Finding:</strong> Macro composition (fiber, protein×activity) matters more than total calorie intake alone.
            </div>
          </section>
        </>
      )}
    </main>
  );
}
