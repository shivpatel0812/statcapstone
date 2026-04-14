# Deploy: Vercel (frontend) + Railway (API + R)

## What gets deployed where

| Service   | Folder                         | Needs |
|----------|---------------------------------|--------|
| **Vercel**  | `macro_goal_app/frontend`      | Node build; env `VITE_API_URL` |
| **Railway** | `macro_goal_app/backend`       | Docker (`Dockerfile`); includes `Rcode/` and `python_code/combined_data.csv` |

## Railway (backend)

1. New project → **Deploy from GitHub** → select this repo.
2. **Settings → Service → Root Directory:** set to exactly **`macro_goal_app/backend`** (required for this monorepo). If this is wrong, Railway may try **Railpack** on the repo root and fail with “Error creating build plan with Railpack”.
3. **Settings → Build:** builder should be **Dockerfile** (config-as-code: `macro_goal_app/backend/railway.json` sets `"builder": "DOCKERFILE"`).
4. Confirm a **`Dockerfile`** exists at `macro_goal_app/backend/Dockerfile` (same folder as `railway.json`).
5. **Variables:** optional; `PORT` is set automatically.
6. After deploy, copy the public URL (e.g. `https://xxxx.up.railway.app`).
7. Confirm **`GET /health`** returns `{"status":"ok"}`.

**Note:** First Docker build installs R packages in the image; builds can take several minutes.

### If you see “Error creating build plan with Railpack”

- Set **Root Directory** to **`macro_goal_app/backend`** (not empty, not repo root).
- In **Build** settings, choose **Dockerfile** as the builder (override Railpack).
- Redeploy after changing root directory.

## Vercel (frontend)

1. New project → import the same repo.
2. **Root Directory:** `macro_goal_app/frontend`
3. **Environment variables:**
   - `VITE_API_URL` = your Railway URL **without** a trailing slash  
     Example: `https://xxxx.up.railway.app`
4. Deploy. The app calls `VITE_API_URL + "/recommend"`.

## Local check

```bash
# Backend
cd macro_goal_app/backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --reload --port 8000

# Frontend (default API: http://localhost:8000)
cd macro_goal_app/frontend
npm install && npm run dev
```

Copy `macro_goal_app/frontend/.env.example` to `.env` to override the API URL locally.
