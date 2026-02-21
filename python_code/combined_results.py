"""
Combined Results - Merge NHANES datasets (DR1IFF, PAQ, DBQ) by unique ID (SEQN)
"""

import pandas as pd
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
DR1IFF_PATH = BASE_DIR / "DR1IFF_L (1).xpt"
PAQ_PATH = BASE_DIR / "PAQ_L (2).xpt"
DBQ_PATH = BASE_DIR / "DBQ_L (1).xpt"

def load_and_combine():
    """Load all three datasets and combine by SEQN."""
    

    dr1iff = pd.read_sas(DR1IFF_PATH, format="xport")
    paq = pd.read_sas(PAQ_PATH, format="xport")
    dbq = pd.read_sas(DBQ_PATH, format="xport")
    

    diet_cols = ["SEQN", "DR1IKCAL", "DR1IPROT", "DR1ICARB", "DR1ITFAT", 
                 "DR1ISUGR", "DR1IFIBE", "DR1ICHOL"]
    dr1iff_subset = dr1iff[diet_cols].copy()
    
    dr1iff_person = dr1iff_subset.groupby("SEQN").agg(
        total_calories=("DR1IKCAL", "sum"),
        total_protein=("DR1IPROT", "sum"),
        total_carbs=("DR1ICARB", "sum"),
        total_fat=("DR1ITFAT", "sum"),
        total_sugar=("DR1ISUGR", "sum"),
        total_fiber=("DR1IFIBE", "sum"),
        total_cholesterol=("DR1ICHOL", "sum"),
    ).reset_index()
    
    
    merged = dr1iff_person.merge(paq, on="SEQN", how="left")
    merged = merged.merge(dbq, on="SEQN", how="left")
    
    return merged


if __name__ == "__main__":
    merged_data = load_and_combine()
    
    print(f"Combined dataset: {len(merged_data)} people, {len(merged_data.columns)} variables")
    print(f"\nColumns: {list(merged_data.columns)}")
    print(f"\nFirst 5 rows (key columns):")
    key_cols = [c for c in ["SEQN", "total_calories", "total_protein", "PAD680", "DBQ010"] 
                if c in merged_data.columns]
    print(merged_data[key_cols].head())
    

    output_path = BASE_DIR / "python_code" / "combined_data.csv"
    merged_data.to_csv(output_path, index=False)
    print(f"\nSaved to {output_path}")
