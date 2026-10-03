"""Runs the exploratory notebook end to end on the made-up fixture file."""

from pathlib import Path

import nbformat
from nbclient import NotebookClient

NOTEBOOKS = Path(__file__).parent.parent / "notebooks"
FIXTURE = Path(__file__).parent / "fixtures" / "uci_sample.csv"


def test_exploration_notebook_runs(monkeypatch):
    monkeypatch.setenv("MEDIQORE_UCI_CSV", str(FIXTURE))  # the kernel inherits this
    monkeypatch.setenv("MPLBACKEND", "Agg")
    nb = nbformat.read(NOTEBOOKS / "01_uci_exploration.ipynb", as_version=4)
    NotebookClient(nb, timeout=120, kernel_name="python3", resources={"metadata": {"path": str(NOTEBOOKS)}}).execute()
    printed = "".join(o.get("text", "") for cell in nb.cells for o in cell.get("outputs", []))
    assert "uci_sample.csv: 12 rows" in printed
