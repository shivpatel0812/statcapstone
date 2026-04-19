# Deploy (Railway API + Vercel frontend)

## Prerequisites

- GitHub repo connected to **Railway** (backend) and **Vercel** (frontend).
- **Do not commit** `macro_goal_app/frontend/.env` (it is gitignored). Set secrets in each host’s dashboard.

## Railway (FastAPI + R)

1. Create a service from this repo.
2. Set **Root Directory** to: `macro_goal_app/backend`  
   (so `Dockerfile` and `railway.json` at that path are used.)
3. Railway sets `PORT`; the Dockerfile already uses `${PORT:-8000}`.
4. Health check: `GET /health` (configured in `railway.json`).
5. After deploy, copy the public URL (e.g. `https://xxx.up.railway.app`).

## Vercel (Vite React)

1. Import the same GitHub repo.
2. Set **Root Directory** to: `macro_goal_app/frontend`  
   (so `vercel.json` and `package.json` are used.)
3. **Environment variables** (Production):
   - `VITE_API_URL` = your Railway URL **without** a trailing slash.
   - All `VITE_FIREBASE_*` keys from Firebase Console (same as local `.env`).
4. Optional: set `VITE_ENABLE_LOG_SEED=false` in production (or omit it).

## Firebase

- Deploy **Firestore rules** from Firebase Console or CLI when you change `firestore.rules` (not automatic with Vercel).

## Ship code

```bash
git add macro_goal_app/ .gitignore
git commit -m "Macro goal app: planner, logs, trends, deploy configs"
git push origin main
```

Adjust branch name if yours is not `main`.
