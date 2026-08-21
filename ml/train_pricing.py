"""Train the F3 pricing model from comparables.csv.

Usage:  python train_pricing.py
Outputs pricing_model.pkl (a sklearn Pipeline) consumed by the backend.

This is intentionally simple — a RandomForest over one-hot categorical
features. Grow comparables.csv (scrape Amazon Karigar / Meesho / Etsy handloom
listings) to improve accuracy. Keep it honest: it predicts a *base* price the
backend turns into a range with reasoning.
"""
import os

import joblib
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

HERE = os.path.dirname(__file__)
CSV = os.path.join(HERE, "comparables.csv")
OUT = os.path.join(HERE, "pricing_model.pkl")

FEATURES = ["category", "material", "size", "region"]


def main() -> None:
    df = pd.read_csv(CSV)
    X, y = df[FEATURES], df["price"]

    pre = ColumnTransformer(
        [("cat", OneHotEncoder(handle_unknown="ignore"), FEATURES)]
    )
    model = Pipeline([
        ("pre", pre),
        ("rf", RandomForestRegressor(n_estimators=200, random_state=42)),
    ])
    model.fit(X, y)
    joblib.dump(model, OUT)
    print(f"Saved {OUT}  (trained on {len(df)} comparables)")


if __name__ == "__main__":
    main()
