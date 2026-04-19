from pathlib import Path
import subprocess

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


class MacroInput(BaseModel):
    protein: float = Field(..., ge=0, description="Current protein intake (g/day)")
    carbs: float = Field(..., ge=0, description="Current carb intake (g/day)")
    fat: float = Field(..., ge=0, description="Current fat intake (g/day)")
    sugar: float = Field(..., ge=0, description="Current sugar intake (g/day)")
    fiber: float = Field(..., ge=0, description="Current fiber intake (g/day)")
    total_calories: float = Field(..., ge=0, description="User-tracked total daily calories (kcal)")
    sex: str
    weight_kg: float = Field(..., gt=0)
    height_cm: float = Field(..., gt=0)
    sleep_hours: float = Field(..., ge=0, le=24)
    activity_min: float = Field(default=0, ge=0, description="Weekly leisure-time physical activity (WHO-weighted)")
    sedentary_min: float = Field(default=0, ge=0, description="Daily sedentary time (minutes)")
    goal: str = Field(..., description="Health goal: lose_weight, gain_weight, build_muscle, improve_cholesterol, improve_glucose, reduce_bmi, reduce_waist, general_health")
    time_range: str = Field(default="general", description="Time range: general, 3_months, 6_months, 12_months")


app = FastAPI(title="Macro Goal Adjuster API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

R_SCRIPT = Path(__file__).with_name("recommend_macros.R")


def parse_kv_lines(stdout: str) -> dict:
    out = {}
    for line in stdout.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        out[key.strip()] = value.strip()
    return out


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/recommend")
def recommend(payload: MacroInput) -> dict:
    goal = payload.goal.strip().lower()
    allowed_goals = {
        "lose_weight", "gain_weight", "build_muscle",
        "improve_cholesterol", "improve_glucose",
        "reduce_bmi", "reduce_waist", "general_health"
    }
    if goal not in allowed_goals:
        raise HTTPException(status_code=400, detail=f"goal must be one of {sorted(allowed_goals)}")

    sex = payload.sex.strip().lower()
    allowed_sex = {"male", "female", "other"}
    if sex not in allowed_sex:
        raise HTTPException(status_code=400, detail=f"sex must be one of {sorted(allowed_sex)}")

    time_range = payload.time_range.strip().lower()
    allowed_time = {"general", "3_months", "6_months", "12_months"}
    if time_range not in allowed_time:
        raise HTTPException(status_code=400, detail=f"time_range must be one of {sorted(allowed_time)}")

    cmd = [
        "Rscript",
        str(R_SCRIPT),
        str(payload.protein),
        str(payload.carbs),
        str(payload.fat),
        str(payload.sugar),
        str(payload.fiber),
        sex,
        str(payload.weight_kg),
        str(payload.height_cm),
        str(payload.sleep_hours),
        str(payload.activity_min),
        str(payload.sedentary_min),
        goal,
        time_range,
        str(payload.total_calories),
    ]

    result = subprocess.run(
        cmd,
        cwd=str(R_SCRIPT.parent),
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "R recommendation script failed",
                "stderr": result.stderr[-1000:],
            },
        )

    data = parse_kv_lines(result.stdout)
    required_keys = {
        "protein",
        "carbs",
        "fat",
        "sugar",
        "fiber",
        "bmi",
        "current_calories",
        "target_calories",
    }
    if not required_keys.issubset(data.keys()):
        raise HTTPException(status_code=500, detail={"message": "Unexpected response from R script"})

    response = {
        "recommended": {
            "protein": float(data["protein"]),
            "carbs": float(data["carbs"]),
            "fat": float(data["fat"]),
            "sugar": float(data["sugar"]),
            "fiber": float(data["fiber"]),
        },
        "profile": {
            "bmi": float(data["bmi"]),
            "current_calories": float(data["current_calories"]),
            "target_calories": float(data["target_calories"]),
        },
        "note": data.get("note", ""),
    }

    # Add optional fields if present
    if "calorie_change" in data:
        response["profile"]["calorie_change"] = float(data["calorie_change"])
    if "health_benefits" in data:
        response["health_benefits"] = data["health_benefits"]
    if "activity_level" in data:
        response["profile"]["activity_level"] = data["activity_level"]
    if "implied_calories" in data:
        response["profile"]["implied_calories"] = float(data["implied_calories"])
    if "logged_calories" in data:
        try:
            response["profile"]["logged_calories"] = float(data["logged_calories"])
        except ValueError:
            pass
    if "goal_name" in data:
        response["goal_name"] = data["goal_name"]
    if "time_range" in data:
        response["time_range"] = data["time_range"]

    return response
