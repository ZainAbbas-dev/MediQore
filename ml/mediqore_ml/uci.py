"""Loading and checking the UCI Maternal Health Risk dataset (M4 FE-1, P0-10).

The dataset is public and de-identified (UCI id 863, CC BY 4.0). It is
downloaded to ``ml/data/raw/`` by ``scripts/download_uci.py`` and never
committed.
"""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd

ML_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CSV = ML_ROOT / "data" / "raw" / "maternal_health_risk.csv"
CSV_ENV_VAR = "MEDIQORE_UCI_CSV"  # overrides DEFAULT_CSV, e.g. for tests

FEATURES = ["Age", "SystolicBP", "DiastolicBP", "BS", "BodyTemp", "HeartRate"]
TARGET = "RiskLevel"
COLUMNS = [*FEATURES, TARGET]
LABELS = ["low risk", "mid risk", "high risk"]  # ordered from lowest to highest risk

# Units as the dataset records them. MediQore stores temperature in °C, so the
# app converts to °F only at the model input (CLAUDE.md: units).
UNITS = {
    "Age": "years",
    "SystolicBP": "mmHg",
    "DiastolicBP": "mmHg",
    "BS": "mmol/L",
    "BodyTemp": "°F",
    "HeartRate": "beats/min",
}


def csv_path() -> Path:
    """Where the dataset is read from: $MEDIQORE_UCI_CSV, else ml/data/raw/."""
    return Path(os.environ.get(CSV_ENV_VAR, DEFAULT_CSV))


def load_uci(path: str | Path | None = None) -> pd.DataFrame:
    """Reads the CSV and checks its columns, types and labels.

    Raises ValueError if the file does not look like the UCI dataset.
    """
    path = Path(path) if path is not None else csv_path()
    if not path.exists():
        raise FileNotFoundError(f"{path} not found. Run: python scripts/download_uci.py")
    df = pd.read_csv(path, encoding="utf-8-sig")  # the UCI file starts with a byte-order mark
    validate(df)
    return df


def validate(df: pd.DataFrame) -> None:
    """Raises ValueError unless df has exactly the UCI columns, numeric features and known labels."""
    if list(df.columns) != COLUMNS:
        raise ValueError(f"expected columns {COLUMNS}, got {list(df.columns)}")
    if df.empty:
        raise ValueError("the dataset has no rows")
    if df.isna().any().any():
        missing = df.columns[df.isna().any()].tolist()
        raise ValueError(f"missing values in {missing}")
    not_numeric = [c for c in FEATURES if not pd.api.types.is_numeric_dtype(df[c])]
    if not_numeric:
        raise ValueError(f"non-numeric values in {not_numeric}")
    unknown = sorted(set(df[TARGET]) - set(LABELS))
    if unknown:
        raise ValueError(f"unknown {TARGET} values {unknown}; expected {LABELS}")


def duplicate_report(df: pd.DataFrame) -> dict[str, int]:
    """Counts exact duplicates and feature rows that appear with more than one label."""
    unique = df.drop_duplicates()
    labels_per_row = unique.groupby(FEATURES)[TARGET].nunique()
    conflicting = labels_per_row[labels_per_row > 1]
    rows_in_conflict = unique.merge(conflicting.reset_index()[FEATURES], on=FEATURES)
    return {
        "rows": len(df),
        "exact_duplicates": int(df.duplicated().sum()),
        "unique_rows": len(unique),
        "conflicting_feature_rows": len(conflicting),
        "unique_rows_in_conflict": len(rows_in_conflict),
    }


def conflicting_rows(df: pd.DataFrame) -> pd.DataFrame:
    """Feature rows recorded with different labels, with how often each label appears."""
    counts = df.groupby(FEATURES)[TARGET].value_counts().unstack(fill_value=0)
    counts = counts.reindex(columns=[label for label in LABELS if label in counts.columns])
    return counts[(counts > 0).sum(axis=1) > 1].reset_index()


def class_balance(df: pd.DataFrame) -> pd.DataFrame:
    """Rows per risk level, in LABELS order, with counts and shares."""
    counts = df[TARGET].value_counts().reindex(LABELS, fill_value=0)
    return pd.DataFrame({"rows": counts, "share": (counts / counts.sum()).round(3)})
