import { useEffect, useMemo, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { useAuth } from "./AuthContext";
import { getFirestoreDb } from "./firebase";
import { kgToLbs } from "./weightUnits";

const METRICS = [
  { key: "total_calories", label: "Calories", unit: "kcal" },
  { key: "sleep_hours", label: "Sleep", unit: "hrs" },
  { key: "weight_lbs", label: "Weight", unit: "lb", source: "weight_kg", transform: kgToLbs },
  { key: "activity_min", label: "Activity", unit: "min/wk" },
  { key: "sedentary_min", label: "Sedentary", unit: "min/day" },
  { key: "protein", label: "Protein", unit: "g" },
  { key: "carbs", label: "Carbs", unit: "g" },
  { key: "fat", label: "Fat", unit: "g" },
  { key: "sugar", label: "Sugar", unit: "g" },
  { key: "fiber", label: "Fiber", unit: "g" },
];

function isValidDateId(id) {
  return /^\d{4}-\d{2}-\d{2}$/.test(id);
}

function dateMs(id) {
  const [y, m, d] = id.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
}

function seriesFor(metric, rows) {
  const source = metric.source || metric.key;
  const transform = metric.transform || ((v) => v);
  return rows
    .map((r) => {
      const raw = r[source];
      const n = Number(raw);
      if (!Number.isFinite(n)) return null;
      return { date: r.id, t: dateMs(r.id), y: transform(n) };
    })
    .filter(Boolean);
}

function formatDate(id) {
  const [, m, d] = id.split("-");
  return `${Number(m)}/${Number(d)}`;
}

function LineChart({ points, unit, color = "var(--primary)" }) {
  const width = 640;
  const height = 220;
  const pad = { top: 16, right: 16, bottom: 28, left: 44 };

  if (points.length === 0) {
    return (
      <div className="trends-empty">No data for this metric yet. Save some daily logs first.</div>
    );
  }

  const xs = points.map((p) => p.t);
  const ys = points.map((p) => p.y);
  const xMin = Math.min(...xs);
  const xMax = Math.max(...xs);
  const yMinRaw = Math.min(...ys);
  const yMaxRaw = Math.max(...ys);
  const yPad = (yMaxRaw - yMinRaw) * 0.1 || Math.max(1, Math.abs(yMaxRaw) * 0.1);
  const yMin = yMinRaw - yPad;
  const yMax = yMaxRaw + yPad;

  const xSpan = Math.max(1, xMax - xMin);
  const ySpan = Math.max(1e-9, yMax - yMin);

  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;

  const sx = (t) =>
    points.length === 1
      ? pad.left + innerW / 2
      : pad.left + ((t - xMin) / xSpan) * innerW;
  const sy = (y) => pad.top + innerH - ((y - yMin) / ySpan) * innerH;

  const path = points
    .map((p, i) => `${i === 0 ? "M" : "L"} ${sx(p.t).toFixed(1)} ${sy(p.y).toFixed(1)}`)
    .join(" ");

  const yTicks = 4;
  const ticks = Array.from({ length: yTicks + 1 }, (_, i) => {
    const v = yMin + (ySpan * i) / yTicks;
    return { v, y: sy(v) };
  });

  const firstLabel = points[0];
  const lastLabel = points[points.length - 1];
  const midIdx = Math.floor(points.length / 2);
  const midLabel = points[midIdx];
  const xLabels = [firstLabel, midLabel, lastLabel].filter(
    (p, i, arr) => p && arr.indexOf(p) === i
  );

  return (
    <svg
      className="trends-chart"
      viewBox={`0 0 ${width} ${height}`}
      role="img"
      aria-label="Trend chart"
    >
      {ticks.map((t, i) => (
        <g key={i}>
          <line
            x1={pad.left}
            x2={width - pad.right}
            y1={t.y}
            y2={t.y}
            className="trends-grid"
          />
          <text x={pad.left - 6} y={t.y} className="trends-axis" textAnchor="end" dy="0.32em">
            {t.v.toFixed(t.v >= 100 ? 0 : 1)}
          </text>
        </g>
      ))}

      <path d={path} className="trends-line" fill="none" stroke={color} />

      {points.map((p, i) => (
        <circle key={i} cx={sx(p.t)} cy={sy(p.y)} r="2.5" className="trends-dot" fill={color}>
          <title>{`${p.date}: ${p.y.toFixed(1)} ${unit}`}</title>
        </circle>
      ))}

      {xLabels.map((p, i) => (
        <text
          key={i}
          x={sx(p.t)}
          y={height - 8}
          className="trends-axis"
          textAnchor="middle"
        >
          {formatDate(p.date)}
        </text>
      ))}
    </svg>
  );
}

export default function TrendsSection() {
  const { user, authReady } = useAuth();
  const db = getFirestoreDb();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [metricKey, setMetricKey] = useState(METRICS[0].key);

  useEffect(() => {
    if (!authReady || !user || !db) {
      setRows([]);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError("");
    (async () => {
      try {
        const col = collection(db, "users", user.uid, "dailyLogs");
        const snap = await getDocs(col);
        const out = [];
        snap.forEach((d) => {
          if (!isValidDateId(d.id)) return;
          out.push({ id: d.id, ...d.data() });
        });
        out.sort((a, b) => a.id.localeCompare(b.id));
        if (!cancelled) setRows(out);
      } catch (e) {
        if (!cancelled) setError(e?.message || String(e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [authReady, user, db]);

  const metric = useMemo(
    () => METRICS.find((m) => m.key === metricKey) || METRICS[0],
    [metricKey]
  );

  const getAvg = (metricKey) => {
    const m = METRICS.find((x) => x.key === metricKey);
    const s = seriesFor(m, rows.slice(-7));
    if (s.length === 0) return null;
    return s.reduce((a, b) => a + b.y, 0) / s.length;
  };

  const avgCals = getAvg("total_calories");
  const avgProtein = getAvg("protein");
  const avgWeight = getAvg("weight_lbs");

  const series = useMemo(() => seriesFor(metric, rows), [metric, rows]);

  const stats = useMemo(() => {
    if (series.length === 0) return null;
    const ys = series.map((p) => p.y);
    const mean = ys.reduce((a, b) => a + b, 0) / ys.length;
    return { n: ys.length, mean, last: ys[ys.length - 1] };
  }, [series]);

  const lineColorForMetric = (key) => {
    if (key === "total_calories") return "#3b82f6";
    if (key === "weight_lbs") return "#10b981";
    if (key === "protein") return "#f59e0b";
    return "var(--primary)";
  };

  if (!authReady) {
    return <p className="daily-log-muted">Loading account…</p>;
  }
  if (!user) {
    return (
      <p className="daily-log-muted">
        Sign in to see your trends. Your saved days will show up here.
      </p>
    );
  }

  return (
    <div className="trends-wrap">
      {loading ? (
        <p className="daily-log-muted">Loading your logs…</p>
      ) : error ? (
        <p className="daily-log-error">{error}</p>
      ) : (
        <>
          <div className="trends-summary-grid">
            <div className="trends-summary-card">
              <span className="trends-summary-title">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>
                7-Day Avg Calories
              </span>
              <div className="trends-summary-value">
                {avgCals !== null ? Math.round(avgCals) : "—"}
                <small>kcal/day</small>
              </div>
            </div>
            <div className="trends-summary-card">
              <span className="trends-summary-title">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>
                7-Day Avg Protein
              </span>
              <div className="trends-summary-value">
                {avgProtein !== null ? Math.round(avgProtein) : "—"}
                <small>grams/day</small>
              </div>
            </div>
            <div className="trends-summary-card">
              <span className="trends-summary-title">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>
                7-Day Avg Weight
              </span>
              <div className="trends-summary-value">
                {avgWeight !== null ? avgWeight.toFixed(1) : "—"}
                <small>lbs</small>
              </div>
            </div>
          </div>

          <div className="trends-metrics" role="tablist" aria-label="Choose metric to graph">
            {METRICS.map((m) => (
              <button
                key={m.key}
                type="button"
                role="tab"
                aria-selected={m.key === metricKey}
                className={`trends-metric-btn ${m.key === metricKey ? "active" : ""}`}
                onClick={() => setMetricKey(m.key)}
              >
                {m.label}
              </button>
            ))}
          </div>

          <div className="trends-chart-card">
            <div className="trends-title-row">
              <h3>{metric.label} over time</h3>
              {stats ? (
                <span className="trends-stats">
                  n={stats.n} • avg {stats.mean.toFixed(1)} {metric.unit} • last {stats.last.toFixed(1)}{" "}
                  {metric.unit}
                </span>
              ) : null}
            </div>
            <LineChart points={series} unit={metric.unit} color={lineColorForMetric(metric.key)} />
          </div>

          <div className="trends-table-wrap">
            <table className="trends-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>
                    {metric.label} ({metric.unit})
                  </th>
                </tr>
              </thead>
              <tbody>
                {series
                  .slice()
                  .reverse()
                  .slice(0, 30)
                  .map((p) => (
                    <tr key={p.date}>
                      <td>{p.date}</td>
                      <td>{p.y.toFixed(1)}</td>
                    </tr>
                  ))}
                {series.length === 0 ? (
                  <tr>
                    <td colSpan={2} className="trends-empty-row">
                      No saved entries contain this metric yet.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}
