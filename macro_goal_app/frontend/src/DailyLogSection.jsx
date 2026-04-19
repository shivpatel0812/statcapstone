import { useCallback, useEffect, useState } from "react";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
} from "firebase/firestore";
import { useAuth } from "./AuthContext";
import { getFirestoreDb, isFirebaseConfigured } from "./firebase";
import { GOALS, goalsByCategoryFrom } from "./healthGoals";
import { kgToLbs, lbsToKg } from "./weightUnits";
import TrendsSection from "./TrendsSection";
import { isLogSeedEnabled, seedDemoLast14Days } from "./seedDemoDailyLogs";

const LOG_DEFAULT = {
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
  notes: "",
};

function todayLocalISODate() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function normalizeFromFirestore(data) {
  const next = { ...LOG_DEFAULT };
  if (!data || typeof data !== "object") return next;
  const keys = Object.keys(LOG_DEFAULT);
  for (const k of keys) {
    if (data[k] === undefined || data[k] === null) continue;
    if (k === "notes") {
      next.notes = String(data.notes);
      continue;
    }
    if (["goal", "sex", "time_range"].includes(k)) {
      next[k] = String(data[k]);
      continue;
    }
    const n = Number(data[k]);
    if (!Number.isFinite(n)) continue;
    next[k] = n;
  }
  // Firestore stores kg; UI edits lb
  if (Number.isFinite(Number(data.weight_kg))) {
    next.weight_lbs = kgToLbs(Number(data.weight_kg));
  }
  return next;
}

function payloadForFirestore(logForm, logDate) {
  const {
    protein,
    carbs,
    fat,
    sugar,
    fiber,
    total_calories,
    sex,
    weight_lbs,
    height_cm,
    sleep_hours,
    activity_min,
    sedentary_min,
    goal,
    time_range,
    notes,
  } = logForm;
  return {
    date: logDate,
    protein: Number(protein),
    carbs: Number(carbs),
    fat: Number(fat),
    sugar: Number(sugar),
    fiber: Number(fiber),
    total_calories: Number(total_calories),
    sex: String(sex),
    weight_kg: lbsToKg(weight_lbs),
    height_cm: Number(height_cm),
    sleep_hours: Number(sleep_hours),
    activity_min: Number(activity_min),
    sedentary_min: Number(sedentary_min),
    goal: String(goal),
    time_range: String(time_range),
    notes: String(notes || "").slice(0, 2000),
    updatedAt: serverTimestamp(),
  };
}

export default function DailyLogSection({ onApplyToPlanner, onPredictFromLog, predictFromLogLoading }) {
  const { user, authReady, firebaseConfigured } = useAuth();
  const [logDate, setLogDate] = useState(todayLocalISODate);
  const [logForm, setLogForm] = useState(LOG_DEFAULT);
  const [loadingDoc, setLoadingDoc] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [recentIds, setRecentIds] = useState([]);
  const [seedingDemo, setSeedingDemo] = useState(false);

  const db = getFirestoreDb();
  const goalsByCategory = goalsByCategoryFrom(GOALS);

  const refreshRecent = useCallback(async () => {
    if (!user || !db) return;
    try {
      const col = collection(db, "users", user.uid, "dailyLogs");
      const snap = await getDocs(col);
      const ids = snap.docs.map((d) => d.id).sort((a, b) => b.localeCompare(a));
      setRecentIds(ids.slice(0, 14));
    } catch {
      setRecentIds([]);
    }
  }, [user, db]);

  useEffect(() => {
    if (!authReady || !user || !db) {
      setLogForm(LOG_DEFAULT);
      return;
    }
    let cancelled = false;
    setLoadingDoc(true);
    setError("");
    (async () => {
      try {
        const ref = doc(db, "users", user.uid, "dailyLogs", logDate);
        const snap = await getDoc(ref);
        if (cancelled) return;
        if (snap.exists()) setLogForm(normalizeFromFirestore(snap.data()));
        else setLogForm({ ...LOG_DEFAULT });
      } catch (e) {
        if (!cancelled) setError(e?.message || String(e));
      } finally {
        if (!cancelled) setLoadingDoc(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [authReady, user, db, logDate]);

  useEffect(() => {
    if (!user || !db) {
      setRecentIds([]);
      return;
    }
    void refreshRecent();
  }, [user, db, refreshRecent]);

  function onChange(e) {
    const { name, value } = e.target;
    setLogForm((prev) => {
      if (["goal", "sex", "time_range", "notes"].includes(name)) {
        return { ...prev, [name]: value };
      }
      if (name === "weight_lbs") {
        if (value === "") return { ...prev, weight_lbs: "" };
        const n = Number(value);
        return { ...prev, weight_lbs: Number.isFinite(n) ? n : prev.weight_lbs };
      }
      return { ...prev, [name]: Number(value) };
    });
  }

  async function onSave(e) {
    e.preventDefault();
    setMessage("");
    setError("");
    if (logForm.weight_lbs === "" || !Number.isFinite(Number(logForm.weight_lbs))) {
      setError("Please enter your weight in pounds before saving.");
      return;
    }
    if (!user || !db) return;
    setSaving(true);
    try {
      const ref = doc(db, "users", user.uid, "dailyLogs", logDate);
      await setDoc(ref, payloadForFirestore(logForm, logDate), { merge: true });
      setMessage(`Saved log for ${logDate}.`);
      await refreshRecent();
    } catch (err) {
      setError(err?.message || String(err));
    } finally {
      setSaving(false);
    }
  }

  function applyToPlanner() {
    if (!onApplyToPlanner) return;
    const { notes: _n, ...rest } = logForm;
    onApplyToPlanner(rest);
    setMessage("Values copied into the macro planner form below.");
  }

  function median(values) {
    const nums = values
      .map((v) => Number(v))
      .filter((n) => Number.isFinite(n));
    if (nums.length === 0) return null;
    nums.sort((a, b) => a - b);
    const mid = Math.floor(nums.length / 2);
    return nums.length % 2 === 0 ? (nums[mid - 1] + nums[mid]) / 2 : nums[mid];
  }

  async function onSeedDemoLogs() {
    if (!user || !db || !isLogSeedEnabled()) return;
    setMessage("");
    setError("");
    setSeedingDemo(true);
    try {
      await seedDemoLast14Days(db, user.uid, logForm);
      setMessage("Wrote 14 days of demo logs (today back). Refresh Trends or generate plan from logs.");
      await refreshRecent();
    } catch (err) {
      setError(err?.message || String(err));
    } finally {
      setSeedingDemo(false);
    }
  }

  async function predictFromLog() {
    if (!onPredictFromLog || !user || !db) return;
    setMessage("");
    setError("");
    try {
      const col = collection(db, "users", user.uid, "dailyLogs");
      const snap = await getDocs(col);
      const docs = [];
      snap.forEach((d) => {
        if (/^\d{4}-\d{2}-\d{2}$/.test(d.id)) docs.push(d.data());
      });
      if (docs.length === 0) {
        setError("No saved logs yet. Save at least one day first.");
        return;
      }

      const numericKeys = [
        "protein",
        "carbs",
        "fat",
        "sugar",
        "fiber",
        "total_calories",
        "weight_kg",
        "height_cm",
        "sleep_hours",
        "activity_min",
        "sedentary_min",
      ];
      const aggregated = {};
      for (const k of numericKeys) {
        const m = median(docs.map((d) => d[k]));
        if (m != null) aggregated[k] = m;
      }

      const payload = {
        ...aggregated,
        weight_lbs: kgToLbs(aggregated.weight_kg ?? lbsToKg(logForm.weight_lbs || 0)),
        sex: String(logForm.sex),
        goal: String(logForm.goal),
        time_range: String(logForm.time_range),
      };
      delete payload.weight_kg;

      const result = await onPredictFromLog(payload, { source: "logs", n: docs.length });
      if (result) {
        setMessage(
          `Plan generated from ${docs.length} saved day${docs.length === 1 ? "" : "s"} (median values).`
        );
      }
    } catch (err) {
      setError(err?.message || String(err));
    }
  }

  if (!firebaseConfigured) {
    return (
      <section className="section-card daily-log-section daily-log-section--muted" aria-labelledby="daily-log-heading">
        <h2 id="daily-log-heading" className="daily-log-title">
          Daily log (Firebase)
        </h2>
        <p className="daily-log-muted">
          Add Firebase keys to <code className="inline-code">.env</code> to enable sign-in and saved daily logs.
        </p>
      </section>
    );
  }

  if (!authReady) {
    return (
      <section className="section-card daily-log-section" aria-labelledby="daily-log-heading">
        <h2 id="daily-log-heading" className="daily-log-title">
          Daily log
        </h2>
        <p className="daily-log-muted">Loading account…</p>
      </section>
    );
  }

  if (!user) {
    return (
      <section className="section-card daily-log-section" aria-labelledby="daily-log-heading">
        <h2 id="daily-log-heading" className="daily-log-title">
          Daily log
        </h2>
        <p className="daily-log-muted">
          Sign in with Google (top right) to save your sleep, activity, macros, and profile day by day. Data is stored in
          your own Firestore document.
        </p>
      </section>
    );
  }

  return (
    <div className="layout-grid layout-grid--flipped">
      <div className="layout-main">
        <TrendsSection />
      </div>

      <div className="layout-sidebar">
        <section className="section-card daily-log-section" aria-labelledby="daily-log-heading">
          <div className="daily-log-header" style={{ marginBottom: "1rem" }}>
            <div>
              <h2 id="daily-log-heading" className="daily-log-title" style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{color: "var(--primary)"}}><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                Log Today's Entry
              </h2>
            </div>
          </div>

          {loadingDoc ? <p className="daily-log-muted">Loading entry…</p> : null}

          <form onSubmit={onSave} className="form-stack daily-log-form">
            <label>
              Date
              <input type="date" value={logDate} onChange={(e) => setLogDate(e.target.value)} max="2099-12-31" />
            </label>

            <div className="grid-2-col">
              <label>
                Sex
                <select name="sex" value={logForm.sex} onChange={onChange}>
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
                  value={logForm.weight_lbs === "" ? "" : logForm.weight_lbs}
                  onChange={onChange}
                  min="22"
                  step="0.1"
                />
              </label>
            </div>

            <label>
              Height (cm)
              <input type="number" name="height_cm" value={logForm.height_cm} onChange={onChange} min="50" />
            </label>

            <div className="grid-3-col">
              <label>
                Protein (g)
                <input type="number" name="protein" value={logForm.protein} onChange={onChange} min="0" />
              </label>
              <label>
                Carbs (g)
                <input type="number" name="carbs" value={logForm.carbs} onChange={onChange} min="0" />
              </label>
              <label>
                Fat (g)
                <input type="number" name="fat" value={logForm.fat} onChange={onChange} min="0" />
              </label>
            </div>

            <div className="grid-3-col">
              <label>
                Sugar (g)
                <input type="number" name="sugar" value={logForm.sugar} onChange={onChange} min="0" />
              </label>
              <label>
                Fiber (g)
                <input type="number" name="fiber" value={logForm.fiber} onChange={onChange} min="0" />
              </label>
              <label>
                Calories
                <input type="number" name="total_calories" value={logForm.total_calories} onChange={onChange} min="0" />
              </label>
            </div>

            <div className="grid-3-col">
              <label>
                Sleep (h)
                <input type="number" step="0.1" name="sleep_hours" value={logForm.sleep_hours} onChange={onChange} min="0" max="24" />
              </label>
              <label>
                Activity (min)
                <input type="number" name="activity_min" value={logForm.activity_min} onChange={onChange} min="0" />
              </label>
              <label>
                Sedentary (min)
                <input type="number" name="sedentary_min" value={logForm.sedentary_min} onChange={onChange} min="0" />
              </label>
            </div>

            <label htmlFor="daily-log-goal">Goal</label>
            <select id="daily-log-goal" name="goal" value={logForm.goal} onChange={onChange} className="goal-select">
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

            <div className="time-range-grid">
              <span className="daily-log-inline-label">Time range</span>
              {["general", "3_months", "6_months", "12_months"].map((v) => (
                <label key={v}>
                  <input type="radio" name="time_range" value={v} checked={logForm.time_range === v} onChange={onChange} />
                  <span>
                    {v === "general" ? "General" : v === "3_months" ? "3 months" : v === "6_months" ? "6 months" : "12 months"}
                  </span>
                </label>
              ))}
            </div>

            <label>
              Notes (optional)
              <textarea name="notes" value={logForm.notes} onChange={onChange} rows={3} className="daily-log-notes" maxLength={2000} />
            </label>

            <div className="daily-log-actions">
          <button type="submit" className="submit-btn" disabled={saving || loadingDoc}>
            {saving ? "Saving…" : "Save this day"}
          </button>
          {onPredictFromLog ? (
            <button
              type="button"
              className="submit-btn"
              onClick={predictFromLog}
              disabled={loadingDoc || predictFromLogLoading}
            >
              {predictFromLogLoading ? "Generating plan…" : "Generate plan from all my logs"}
            </button>
          ) : null}
          {onApplyToPlanner ? (
            <button type="button" className="submit-btn submit-btn--secondary" onClick={applyToPlanner} disabled={loadingDoc}>
              Use in planner below
            </button>
          ) : null}
        </div>
        {isLogSeedEnabled() && user && db ? (
          <p className="daily-log-seed-wrap">
            <button
              type="button"
              className="submit-btn submit-btn--secondary daily-log-seed-btn"
              onClick={onSeedDemoLogs}
              disabled={seedingDemo || loadingDoc}
            >
              {seedingDemo ? "Writing demo logs…" : "Dev: seed last 14 days of demo logs"}
            </button>
            <small className="daily-log-seed-hint">
              Set <code className="inline-code">VITE_ENABLE_LOG_SEED=true</code> in <code className="inline-code">.env</code> and
              restart Vite. Uses your signed-in account only.
            </small>
          </p>
        ) : null}
      </form>

      {message ? <p className="daily-log-success">{message}</p> : null}
      {error ? <p className="daily-log-error">{error}</p> : null}

      {recentIds.length > 0 ? (
        <div className="daily-log-recent">
          <h3 className="daily-log-recent-title">Saved days</h3>
          <ul className="daily-log-recent-list">
            {recentIds.map((id) => (
              <li key={id}>
                <button type="button" className="daily-log-chip" onClick={() => setLogDate(id)}>
                  {id}
                </button>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
        </section>
      </div>
    </div>
  );
}
