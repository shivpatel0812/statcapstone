"""
Variable Details - Summary of each variable in the combined dataset
Run combined_results.py first to generate combined_data.csv
"""

import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
COMBINED_PATH = BASE_DIR / "python_code" / "combined_data.csv"

# Variable descriptions
VAR_DESCRIPTIONS = {
    "SEQN": "Respondent sequence number",
    "total_calories": "Total calories per day (kcal)",
    "total_protein": "Total protein per day (g)",
    "total_carbs": "Total carbohydrates per day (g)",
    "total_fat": "Total fat per day (g)",
    "total_sugar": "Total sugar per day (g)",
    "total_fiber": "Total dietary fiber per day (g)",
    "total_cholesterol": "Total cholesterol per day (mg)",
    "PAD790Q": "Work activity quantity",
    "PAD790U": "Work activity unit",
    "PAD800": "Work activity minutes per week",
    "PAD810Q": "Transportation activity quantity",
    "PAD810U": "Transportation activity unit",
    "PAD820": "Transportation activity minutes per week",
    "PAD680": "Total moderate-intensity activity minutes per week",
    "DBQ010": "How healthy is your diet",
    "DBD030": "Days since last ate fish",
    "DBD041": "Days since last ate beans",
    "DBD050": "Days since last ate peanuts",
    "DBD055": "Days since last ate other nuts",
    "DBD061": "Days since last ate seeds",
    "DBQ073A": "Frequency: meals from fast food/pizza place",
    "DBQ073B": "Frequency: meals from restaurant with waiter",
    "DBQ073C": "Frequency: meals from restaurant without waiter",
    "DBQ073D": "Frequency: meals from store (deli/supermarket)",
    "DBQ073E": "Frequency: meals from vending machine",
    "DBQ073U": "Frequency: meals from other source",
    "DBQ301": "How often: meals from fast food/pizza place",
    "DBQ330": "How often: meals from restaurant with waiter",
    "DBQ360": "How often: meals from restaurant without waiter",
    "DBQ370": "How often: meals from store (deli/supermarket)",
    "DBD381": "Days since last ate meals from store",
    "DBQ390": "How often: meals from vending machine",
    "DBQ400": "How often: meals from other source",
    "DBD411": "Days since last ate meals from other source",
    "DBQ421": "How often: meals prepared away from home",
    "DBQ424": "How often: meals prepared away from home (past 7 days)",
    "DBQ930": "How often: meals prepared away from home (past 30 days)",
    "DBQ935": "How often: meals prepared away from home (past 12 months)",
    "DBQ940": "How often: meals prepared away from home (lifetime)",
    "DBQ945": "How often: meals prepared away from home (other)",
}


def load_data():
    """Load combined data. Run combined_results.py first if CSV doesn't exist."""
    if not COMBINED_PATH.exists():
        from combined_results import load_and_combine
        return load_and_combine()
    return pd.read_csv(COMBINED_PATH)


def get_variable_summary(df):
    """Build summary table for all variables."""
    rows = []
    for col in df.columns:
        desc = VAR_DESCRIPTIONS.get(col, f"Variable: {col}")
        missing = df[col].isna().sum()
        total = len(df)
        missing_pct = round(missing / total * 100, 2)
        non_missing = total - missing

        row = {
            "variable": col,
            "description": desc,
            "dtype": str(df[col].dtype),
            "missing_count": missing,
            "missing_pct": missing_pct,
            "non_missing": non_missing,
        }

        # Numeric stats
        if pd.api.types.is_numeric_dtype(df[col]) and non_missing > 0:
            row["mean"] = round(df[col].mean(), 2)
            row["median"] = round(df[col].median(), 2)
            row["min"] = df[col].min()
            row["max"] = df[col].max()
            row["std"] = round(df[col].std(), 2)
        else:
            row["unique_values"] = df[col].nunique()
            if df[col].dtype == "object" and non_missing > 0:
                top = df[col].value_counts().head(3).to_dict()
                row["top_values"] = str(top)

        rows.append(row)
    return pd.DataFrame(rows)


def print_summary(df, summary_df):
    """Print formatted variable details."""
    print("=" * 60)
    print("COMBINED DATASET VARIABLE DETAILS")
    print("=" * 60)
    print(f"\nTotal people: {len(df)}")
    print(f"Total variables: {len(df.columns)}")
    print(f"Total data points: {len(df) * len(df.columns)}")

    # 1. Missing values summary (most important for data quality)
    print("\n" + "-" * 60)
    print("1. MISSING VALUES BY VARIABLE (sorted by most missing)")
    print("-" * 60)
    missing_view = summary_df[["variable", "description", "missing_count", "missing_pct", "non_missing"]].copy()
    missing_view = missing_view.sort_values("missing_count", ascending=False)
    print(missing_view.to_string(index=False))

    # 2. Variables with no missing data
    print("\n" + "-" * 60)
    print("2. VARIABLES WITH NO MISSING DATA")
    print("-" * 60)
    complete = summary_df[summary_df["missing_count"] == 0][["variable", "description"]]
    print(complete.to_string(index=False))
    print(f"\nCount: {len(complete)} variables")

    # 3. Key numeric variable stats
    print("\n" + "-" * 60)
    print("3. SUMMARY STATISTICS (Key Numeric Variables)")
    print("-" * 60)
    key_vars = ["total_calories", "total_protein", "total_fat", "PAD680", "DBQ010"]
    key_summary = summary_df[summary_df["variable"].isin(key_vars)]
    key_cols = ["variable", "description", "mean", "median", "min", "max", "missing_pct"]
    key_cols = [c for c in key_cols if c in key_summary.columns]
    print(key_summary[key_cols].to_string(index=False))

    # 4. Data overlap
    print("\n" + "-" * 60)
    print("4. DATA OVERLAP (People with data from each source)")
    print("-" * 60)
    has_dietary = df["total_calories"].notna().sum()
    has_activity = df["PAD680"].notna().sum()
    has_behavior = df["DBQ010"].notna().sum()
    has_diet_activity = (df["total_calories"].notna() & df["PAD680"].notna()).sum()
    has_all = (df["total_calories"].notna() & df["PAD680"].notna() & df["DBQ010"].notna()).sum()

    print(f"  Dietary data:     {has_dietary} people ({has_dietary/len(df)*100:.1f}%)")
    print(f"  Activity data:    {has_activity} people ({has_activity/len(df)*100:.1f}%)")
    print(f"  Behavior data:    {has_behavior} people ({has_behavior/len(df)*100:.1f}%)")
    print(f"  Dietary + Activity: {has_diet_activity} people ({has_diet_activity/len(df)*100:.1f}%)")
    print(f"  All three:        {has_all} people ({has_all/len(df)*100:.1f}%)")

    # 5. Full variable table (variable, description)
    print("\n" + "-" * 60)
    print("5. ALL VARIABLES WITH DESCRIPTIONS")
    print("-" * 60)
    var_table = summary_df[["variable", "description"]].sort_values("variable")
    print(var_table.to_string(index=False))


if __name__ == "__main__":
    df = load_data()
    summary_df = get_variable_summary(df)
    print_summary(df, summary_df)
