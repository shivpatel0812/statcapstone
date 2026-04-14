# Macro Goal App

- **Frontend:** `macro_goal_app/frontend` — React (Vite)
- **Backend:** `macro_goal_app/backend` — FastAPI + R (`recommend_macros.R`)
- **R analysis:** `macro_goal_app/backend/Rcode` — same NHANES modules as the capstone (`00`–`06`)
- **Data:** `macro_goal_app/backend/python_code/combined_data.csv` — copy used so the backend folder is self-contained for deploy (e.g. Railway)

## Layout

```
macro_goal_app/
  frontend/          # UI — deploy to Vercel etc.
  backend/
    app.py
    recommend_macros.R
    requirements.txt
    Rcode/             # R sources (survey models)
    python_code/
      combined_data.csv
```

## What it does

User enters current macro intake and a workout goal:
- fat_loss
- maintenance
- muscle_gain
- endurance

Backend runs `backend/recommend_macros.R`, which:
1. Sources R modules from `backend/Rcode` (`00`, `01`, `02`, …),
2. Fits the main model stack,
3. Applies simple goal multipliers + light guardrails (fiber floor, sugar cap),
4. Returns adjusted macros.

## Run backend

```bash
cd macro_goal_app/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```

## Run frontend

```bash
cd macro_goal_app/frontend
npm install
npm run dev
```

Open `http://localhost:5173`.

## Deploy (Vercel + Railway)

See **[DEPLOY.md](../DEPLOY.md)** in the repo root for environment variables and root-directory settings.

## Notes

- This is intentionally simple starter logic, not a clinical tool.
- The R script currently refits the model on each request for transparency over speed.
