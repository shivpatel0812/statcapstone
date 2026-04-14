# Macro Goal App (Starter)

Super simple starter app:
- **Frontend:** React (Vite)
- **Backend:** FastAPI
- **R bridge:** Calls your existing `Rcode` pipeline and applies macro adjustments.

## What it does

User enters current macro intake and a workout goal:
- fat_loss
- maintenance
- muscle_gain
- endurance

Backend runs `backend/recommend_macros.R`, which:
1. Sources your current R analysis modules (`00`, `01`, `02`),
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

## Notes

- This is intentionally simple starter logic, not a clinical tool.
- The R script currently refits the model on each request for transparency over speed.
