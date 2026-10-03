"""Tests for loading and checking the UCI dataset (P0-10).

tests/fixtures/uci_sample.csv holds made-up rows in the UCI format (LI-10):
12 rows, 4 exact duplicates and one feature row recorded as both mid and high risk.
"""

from pathlib import Path

import pandas as pd
import pytest

from mediqore_ml.uci import COLUMNS, LABELS, class_balance, conflicting_rows, csv_path, duplicate_report, load_uci

FIXTURE = Path(__file__).parent / "fixtures" / "uci_sample.csv"


def test_loads_the_csv_with_its_byte_order_mark():
    df = load_uci(FIXTURE)
    assert list(df.columns) == COLUMNS
    assert len(df) == 12


def test_counts_duplicates_and_conflicting_labels():
    report = duplicate_report(load_uci(FIXTURE))
    assert report == {
        "rows": 12,
        "exact_duplicates": 4,
        "unique_rows": 8,
        "conflicting_feature_rows": 1,
        "unique_rows_in_conflict": 2,
    }
    conflicts = conflicting_rows(load_uci(FIXTURE).drop_duplicates())
    assert conflicts[["Age", "mid risk", "high risk"]].values.tolist() == [[36, 1, 1]]


def test_class_balance_is_in_risk_order():
    balance = class_balance(load_uci(FIXTURE))
    assert balance.index.tolist() == LABELS
    assert balance["rows"].tolist() == [5, 3, 4]
    assert balance["share"].sum() == pytest.approx(1.0, abs=0.01)


@pytest.mark.parametrize(
    ("change", "message"),
    [
        (lambda df: df.drop(columns=["HeartRate"]), "expected columns"),
        (lambda df: df.assign(RiskLevel="severe"), "unknown RiskLevel"),
        (lambda df: df.assign(BS=None), "missing values"),
        (lambda df: df.assign(Age="adult"), "non-numeric"),
    ],
)
def test_rejects_files_that_are_not_the_uci_dataset(tmp_path, change, message):
    bad = tmp_path / "bad.csv"
    change(pd.read_csv(FIXTURE, encoding="utf-8-sig")).to_csv(bad, index=False)
    with pytest.raises(ValueError, match=message):
        load_uci(bad)


def test_missing_file_says_how_to_download(tmp_path):
    with pytest.raises(FileNotFoundError, match="download_uci.py"):
        load_uci(tmp_path / "absent.csv")


def test_path_can_be_overridden(monkeypatch):
    monkeypatch.setenv("MEDIQORE_UCI_CSV", str(FIXTURE))
    assert csv_path() == FIXTURE
