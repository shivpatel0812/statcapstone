import { doc, serverTimestamp, setDoc } from "firebase/firestore";
import { lbsToKg } from "./weightUnits";

export function isLogSeedEnabled() {
  return import.meta.env.VITE_ENABLE_LOG_SEED === "true";
}

function localISODate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/** Simple deterministic jitter from date id + field name (no Math.random). */
function jitter(iso, field, spread) {
  let h = 0;
  const s = `${iso}:${field}`;
  for (let i = 0; i < s.length; i++) {
    h = (h << 5) - h + s.charCodeAt(i);
    h |= 0;
  }
  const u = Math.abs(h) % (spread * 2 + 1);
  return u - spread;
}

/**
 * Writes ~14 consecutive calendar days (today back) of plausible demo rows
 * under users/{userId}/dailyLogs/{YYYY-MM-DD}. Same field shape as the app save.
 */
export async function seedDemoLast14Days(db, userId, logForm) {
  const base = {
    protein: Number(logForm.protein) || 120,
    carbs: Number(logForm.carbs) || 220,
    fat: Number(logForm.fat) || 70,
    sugar: Number(logForm.sugar) || 65,
    fiber: Number(logForm.fiber) || 18,
    total_calories: Number(logForm.total_calories) || 2000,
    height_cm: Number(logForm.height_cm) || 178,
    sleep_hours: Number(logForm.sleep_hours) || 7,
    activity_min: Number(logForm.activity_min) || 150,
    sedentary_min: Number(logForm.sedentary_min) || 360,
  };
  const weightLbsBase =
    logForm.weight_lbs === "" || logForm.weight_lbs == null
      ? 165
      : Number(logForm.weight_lbs) || 165;

  const sex = String(logForm.sex || "male");
  const goal = String(logForm.goal || "general_health");
  const time_range = String(logForm.time_range || "general");

  for (let i = 0; i < 14; i++) {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() - i);
    const id = localISODate(d);

    const weight_lbs = Math.max(22, weightLbsBase + jitter(id, "wt", 6));
    const payload = {
      date: id,
      protein: Math.max(0, base.protein + jitter(id, "p", 18)),
      carbs: Math.max(0, base.carbs + jitter(id, "c", 35)),
      fat: Math.max(0, base.fat + jitter(id, "f", 12)),
      sugar: Math.max(0, base.sugar + jitter(id, "su", 14)),
      fiber: Math.max(0, base.fiber + jitter(id, "fi", 6)),
      total_calories: Math.max(800, base.total_calories + jitter(id, "kcal", 180)),
      sex,
      weight_kg: lbsToKg(weight_lbs),
      height_cm: Math.max(50, base.height_cm + jitter(id, "h", 2)),
      sleep_hours: Math.max(0, Math.min(24, base.sleep_hours + jitter(id, "sl", 8) * 0.25)),
      activity_min: Math.max(0, base.activity_min + jitter(id, "act", 60)),
      sedentary_min: Math.max(0, base.sedentary_min + jitter(id, "sed", 90)),
      goal,
      time_range,
      notes: "demo seed",
      updatedAt: serverTimestamp(),
    };

    await setDoc(doc(db, "users", userId, "dailyLogs", id), payload, { merge: true });
  }
}
