import { useRef, useState } from "react";
import AuthBar from "./AuthBar";
import DailyLogSection from "./DailyLogSection";
import { GOALS } from "./healthGoals";
import { kgToLbs, lbsToKg } from "./weightUnits";

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
  total_calories: 2000,
  sex: "male",
  weight_lbs: Math.round(kgToLbs(75) * 10) / 10,
  height_cm: 178,
  sleep_hours: 7,
  activity_min: 150,
  sedentary_min: 360,
  goal: "general_health",
  time_range: "general",
};

const TEXT_FIELDS = new Set(["goal", "sex", "time_range"]);

export default function App() {
  const [form, setForm] = useState(INITIAL);
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [activeScreen, setActiveScreen] = useState("plan");
  const [planSource, setPlanSource] = useState("planner");
  const [planSourceMeta, setPlanSourceMeta] = useState(null);
  const [submittedInputs, setSubmittedInputs] = useState(null);
  const resultRef = useRef(null);

  const renderMacroDistribution = (macros, calories, title) => {
    const totalMacros = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9);
    const pPct = totalMacros > 0 ? ((macros.protein * 4) / totalMacros) * 100 : 0;
    const cPct = totalMacros > 0 ? ((macros.carbs * 4) / totalMacros) * 100 : 0;
    const fPct = totalMacros > 0 ? ((macros.fat * 9) / totalMacros) * 100 : 0;

    return (
      <section className="card">
        <h2>{title}</h2>
        <div className="donuts-grid">
          <div className="donut-item">
            <div className="donut-ring" style={{ "--color": "#3b82f6", "--pct": `${pPct}%` }}>
              <div className="donut-inner">{Math.round(pPct)}%</div>
            </div>
            <div className="donut-label">Protein</div>
          </div>
          <div className="donut-item">
            <div className="donut-ring" style={{ "--color": "#10b981", "--pct": `${cPct}%` }}>
              <div className="donut-inner">{Math.round(cPct)}%</div>
            </div>
            <div className="donut-label">Carbs</div>
          </div>
          <div className="donut-item">
            <div className="donut-ring" style={{ "--color": "#f59e0b", "--pct": `${fPct}%` }}>
              <div className="donut-inner">{Math.round(fPct)}%</div>
            </div>
            <div className="donut-label">Fat</div>
          </div>
        </div>
        <div className="bar-chart-wrap">
          <div className="bar-chart-row">
            <div className="bar-chart-label">Calories</div>
            <div className="bar-chart-track">
              <div className="bar-chart-fill" style={{ "--color": "#6366f1", width: `${Math.min(100, (calories / 3000) * 100)}%` }} />
            </div>
            <div className="bar-chart-value">{calories} kcal</div>
          </div>
        </div>
      </section>
    );
  };

  function onChange(e) {
    const { name, value } = e.target;
    setForm((prev) => {
      if (TEXT_FIELDS.has(name)) {
        return { ...prev, [name]: value };
      }
      // Let weight clear to "" so Number("") is never stored as 0 (avoids "01" while typing).
      if (name === "weight_lbs") {
        if (value === "") return { ...prev, weight_lbs: "" };
        const n = Number(value);
        return { ...prev, weight_lbs: Number.isFinite(n) ? n : prev.weight_lbs };
      }
      return { ...prev, [name]: Number(value) };
    });
  }

  async function runPrediction(input, sourceOrMeta = "planner") {
    const meta =
      typeof sourceOrMeta === "string" ? { source: sourceOrMeta } : sourceOrMeta || {};
    const source = meta.source || "planner";
    setLoading(true);
    setError("");
    setResult(null);
    setPlanSource(source);
    setPlanSourceMeta(meta);

    try {
      const { weight_lbs, weight_kg, notes: _n, ...rest } = input;
      const lbsNum =
        weight_lbs !== "" && weight_lbs != null && Number.isFinite(Number(weight_lbs))
          ? Number(weight_lbs)
          : null;
      const kgFallback =
        weight_kg != null && Number.isFinite(Number(weight_kg)) ? Number(weight_kg) : null;
      const resolvedKg = lbsNum != null ? lbsToKg(lbsNum) : kgFallback;

      if (resolvedKg == null || !Number.isFinite(resolvedKg) || resolvedKg <= 0) {
        setError("Please enter your weight in pounds before generating a plan.");
        return null;
      }

      // Snapshot the user-visible inputs so the result card can echo them back.
      setSubmittedInputs({
        weight_lbs: lbsNum ?? (resolvedKg != null ? kgToLbs(resolvedKg) : null),
        protein: Number(rest.protein),
        carbs: Number(rest.carbs),
        fat: Number(rest.fat),
        sugar: Number(rest.sugar),
        fiber: Number(rest.fiber),
        total_calories: Number(rest.total_calories),
        sleep_hours: Number(rest.sleep_hours),
        activity_min: Number(rest.activity_min),
        sedentary_min: Number(rest.sedentary_min),
        height_cm: Number(rest.height_cm),
        sex: rest.sex,
      });

      const payload = { ...rest, weight_kg: resolvedKg };

      const res = await fetch(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      const data = await res.json();
      if (!res.ok) {
        throw new Error(data?.detail?.message || data?.detail || "Request failed");
      }

      setResult(data);
      setTimeout(() => {
        resultRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
      }, 0);
      return data;
    } catch (err) {
      setError(String(err.message || err));
      return null;
    } finally {
      setLoading(false);
    }
  }

  async function onSubmitPlanner(e) {
    e.preventDefault();
    if (form.weight_lbs === "" || !Number.isFinite(Number(form.weight_lbs))) {
      setError("Please enter your weight in pounds before generating a plan.");
      return;
    }
    await runPrediction(form, "planner");
  }

  // Use the inputs that were actually sent to the API; falls back to the live
  // form if a plan hasn't been generated yet.
  const inputsForResult = submittedInputs ?? form;
  const currentMacros = {
    protein: inputsForResult.protein,
    carbs: inputsForResult.carbs,
    fat: inputsForResult.fat,
    sugar: inputsForResult.sugar,
    fiber: inputsForResult.fiber,
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
        <div className="header-top">
          <div className="header-titles">
            <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{color: "var(--primary)"}}><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>
              NHANES Evidence-Based Macro Planner
            </h1>
            <p className="trust-line" style={{ color: "var(--text-muted)", fontSize: "0.85rem", marginTop: "0.25rem" }}>
              Based on NHANES.usda | Personalized nutrition recommendations based on NHANES 2021-2023 statistical models (n=9,751)
            </p>
          </div>
          <AuthBar />
        </div>
      </header>

      <div className="app-view-switch" role="tablist" aria-label="Main app views">
        <button
          type="button"
          role="tab"
          aria-selected={activeScreen === "plan"}
          className={`app-view-btn ${activeScreen === "plan" ? "active" : ""}`}
          onClick={() => setActiveScreen("plan")}
        >
          Plan & Analyze
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeScreen === "log"}
          className={`app-view-btn ${activeScreen === "log" ? "active" : ""}`}
          onClick={() => setActiveScreen("log")}
        >
          Daily Log
        </button>
      </div>

      {activeScreen === "log" ? (
        <DailyLogSection
          onApplyToPlanner={(patch) => {
            setForm((prev) => {
              const next = { ...prev, ...patch };
              if (patch.weight_kg != null && patch.weight_lbs === undefined) {
                next.weight_lbs = kgToLbs(patch.weight_kg);
                delete next.weight_kg;
              }
              return next;
            });
            setActiveScreen("plan");
          }}
          onPredictFromLog={async (logValues, meta) => {
            const data = await runPrediction(logValues, { source: "logs", ...(meta || {}) });
            if (data) setActiveScreen("plan");
            return data;
          }}
          predictFromLogLoading={loading && planSource === "logs"}
        />
      ) : (
        <div className="layout-grid">
          <div className="layout-sidebar">
            <form onSubmit={onSubmitPlanner} className="form-stack">
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
              Weight (lb)
              <input
                type="number"
                name="weight_lbs"
                value={form.weight_lbs === "" ? "" : form.weight_lbs}
                onChange={onChange}
                min="22"
                step="0.1"
              />
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
            <label>
              Total Calories (kcal)
              <input
                type="number"
                name="total_calories"
                value={form.total_calories}
                onChange={onChange}
                min="0"
                required
              />
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
    </div>

    <div className={`layout-main ${!result?.recommended ? 'layout-main--sticky' : ''}`}>
      {error && <div className="card error-card"><p className="error">{error}</p></div>}

      {result?.recommended ? (
        <>
          <section className="card result-header" ref={resultRef}>
            <h2>Your Plan: {result.goal_name}</h2>
            <p className="plan-subtitle">
              {result.time_range}
              {planSource === "logs" ? (
                <span className="plan-source-tag">
                  {" "}
                  • from {planSourceMeta?.n ?? "all"} saved day
                  {planSourceMeta?.n === 1 ? "" : "s"} (median)
                </span>
              ) : null}
            </p>
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
                <span className="profile-label">
                  Current Calories
                  <small className="profile-hint"> (tracked)</small>
                </span>
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
            {result.profile.implied_calories !== undefined &&
              Math.abs(result.profile.current_calories - result.profile.implied_calories) >= 50 && (
                <p className="calorie-gap-note">
                  Tracked calories: {result.profile.current_calories} kcal •
                  Implied from macros (4P + 4C + 9F): {result.profile.implied_calories} kcal.
                  Plan uses tracked calories as the baseline.
                </p>
              )}

            {submittedInputs && (
              <div className="inputs-echo">
                <h4 className="inputs-echo-title">Your inputs used for this plan</h4>
                <div className="inputs-echo-grid">
                  <div className="inputs-echo-item">
                    <span>Weight</span>
                    <strong>
                      {submittedInputs.weight_lbs != null
                        ? `${submittedInputs.weight_lbs.toFixed(1)} lb`
                        : "—"}
                    </strong>
                  </div>
                  <div className="inputs-echo-item">
                    <span>Height</span>
                    <strong>{submittedInputs.height_cm} cm</strong>
                  </div>
                  <div className="inputs-echo-item">
                    <span>Sleep</span>
                    <strong>{submittedInputs.sleep_hours} hrs/night</strong>
                  </div>
                  <div className="inputs-echo-item">
                    <span>Activity</span>
                    <strong>{submittedInputs.activity_min} min/week</strong>
                  </div>
                  <div className="inputs-echo-item">
                    <span>Sedentary</span>
                    <strong>{submittedInputs.sedentary_min} min/day</strong>
                  </div>
                  <div className="inputs-echo-item">
                    <span>Calories (tracked)</span>
                    <strong>{submittedInputs.total_calories} kcal</strong>
                  </div>
                  <div className="inputs-echo-item">
                    <span>Sex</span>
                    <strong style={{ textTransform: "capitalize" }}>{submittedInputs.sex}</strong>
                  </div>
                </div>
              </div>
            )}
          </section>

          {renderMacroDistribution(currentMacros, result.profile.current_calories, "Your Current Macro Distribution")}
          {renderMacroDistribution(result.recommended, result.profile.target_calories, "Recommended Macro Distribution")}

          <section className="card">
            <h2>Recommended Daily Macros</h2>
            <div className="macro-comparison">
              <div className="macro-row header">
                <span>Nutrient</span>
                <span>Current</span>
                <span>Target</span>
                <span>Change</span>
              </div>
              {/* Calories row first */}
              {result.profile.current_calories != null && result.profile.target_calories != null && (() => {
                const current = result.profile.current_calories;
                const target = result.profile.target_calories;
                const change = target - current;
                const changePercent = current > 0 ? ((change / current) * 100).toFixed(0) : 0;
                const isSignificant = Math.abs(change) > 20;
                return (
                  <div className={`macro-row macro-row--calories ${isSignificant ? "significant" : ""}`}>
                    <span className="macro-name">Calories</span>
                    <span className="current-value">{current} kcal</span>
                    <span className="recommended-value">{target} kcal</span>
                    <span className={`change-value ${change > 0 ? "positive" : change < 0 ? "negative" : "neutral"}`}>
                      {change > 0 ? "+" : ""}{change.toFixed(0)} kcal
                      {isSignificant && <span className="percent"> ({changePercent > 0 ? "+" : ""}{changePercent}%)</span>}
                    </span>
                  </div>
                );
              })()}
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
      ) : (
        <>
          <section className="card empty-state-card">
            <div className="empty-state-icon">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21.21 15.89A10 10 0 1 1 8 2.83"></path>
                <path d="M22 12A10 10 0 0 0 12 2v10z"></path>
              </svg>
            </div>
            <h2>Ready to build your plan?</h2>
            <p className="text-muted" style={{ fontSize: "0.95rem", lineHeight: "1.6" }}>
              Fill out your profile and current diet on the left. As you type, your current macro distribution will update below. Click <strong>Generate Macro Plan</strong> when you're ready to see your personalized, evidence-based recommendations.
            </p>
          </section>
          {renderMacroDistribution(form, form.total_calories, "Your Current Macro Distribution")}
        </>
      )}
    </div>
  </div>
)}
    </main>
  );
}
