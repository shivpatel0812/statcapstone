# Deploy: Vercel (frontend) + Railway (API + R)

## What gets deployed where

| Service   | Folder                         | Needs |
|----------|---------------------------------|--------|
| **Vercel**  | `macro_goal_app/frontend`      | Node build; env `VITE_API_URL` |
| **Railway** | `macro_goal_app/backend`       | Docker (`Dockerfile`); includes `Rcode/` and `python_code/combined_data.csv` |

## Railway (backend)

1. New project → **Deploy from GitHub** → select this repo.
2. **Settings → Root Directory:** `macro_goal_app/backend`
3. Railway should detect `Dockerfile` (see `railway.toml`).
4. **Variables:** optional; `PORT` is set automatically.
5. After deploy, copy the public URL (e.g. `https://xxxx.up.railway.app`).
6. Confirm **`GET /health`** returns `{"status":"ok"}`.

**Note:** First boot builds R packages in the image; builds can take several minutes.

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
