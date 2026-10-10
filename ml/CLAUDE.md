# ml/: model training

Python pipeline for the Module 4 risk models (training, SHAP explanation lookup, ONNX export). Module 6 trends run on the phone in Dart (M6 FE-3), so there is no server analytics worker. Follow the root `CLAUDE.md` first; this file only adds what is specific to `ml/`.

## Stack (scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.11 | Training runtime |
| scikit-learn | 1.4 | Logistic Regression, Random Forest, Gradient Boosting |
| imbalanced-learn (SMOTE) | Latest | Class balancing |
| SHAP | Latest | Feature-threshold-to-risk-class mappings, exported as a JSON lookup for the app |
| skl2onnx | Latest | Export of the chosen models to ONNX for on-device inference |

Supporting tools, not in the scope Tools table (exact versions pinned in `requirements*.txt`):

| Tool | Version | Purpose |
|---|---|---|
| pandas + matplotlib | 2.2 / 3.9 | The exploratory notebook the roadmap asks for (P0-10). SHAP depends on pandas anyway. |
| Jupyter kernel (ipykernel) | 6.29 | Runs the notebooks, in VS Code's Jupyter extension or `jupyter` |
| pytest | 8.3 | Tests (roadmap) |
| nbclient + nbformat | 0.10 / 5.10 | The test that runs each notebook end to end |
| ruff | 0.6 | Lint and format (CI) |

Phase 2 adds scikit-learn, imbalanced-learn, SHAP and skl2onnx to `requirements.txt` when training starts.

Data sources:

- UCI Maternal Health Risk Dataset, used for training.
  - Public and de-identified; CC BY 4.0, so cite it in the report.
  - `scripts/download_uci.py` saves it to `ml/data/raw/`, which is git-ignored. Never commit the CSV.
  - Findings so far are in `notebooks/01_uci_exploration.ipynb`.
- PDHS 2017–18, used for domain validation only (LI-2).

From the roadmap: tests use pytest, including saved metrics.

## Key rules

- Remove duplicate rows. Keep a stratified 20% hold-out set untouched until the end.
- Apply SMOTE inside each training fold only, never before the split.
- Train two input sets and validate and report them separately (M4 FE-1, BO-2): the default five-feature model (SystolicBP, DiastolicBP, BodyTemp, HeartRate, Age) and the six-feature model that adds BloodSugar, used only with a same-visit blood sugar reading.
- Select each model by high-risk recall of at least 90% first, then by F1-macro (BO-2); if neither reaches the target, report the shortfall.
- Export to ONNX with plain probability output (no ZipMap). Keep a parity test showing that Python and ONNX agree on every test row.
- Version every exported model; the app stores the model version and input set on each risk assessment, with the Clinical Rules Table version.
- Read the dataset only through `mediqore_ml.uci.load_uci()`: it checks the columns, types and labels. UCI body temperature is in °F and blood sugar in mmol/L (`UNITS`).
- Test notebooks and scripts on `tests/fixtures/uci_sample.csv` (made-up rows), never on the real file, so CI needs no download.
- Commit notebooks with their outputs, so supervisors can read them on GitHub. Outputs may show summaries of the public UCI data, never MediQore patient data.

## Layout

- `mediqore_ml/`: the Python package.
  - `uci.py`: dataset path, loading and validation, duplicate report, conflicting labels, class balance.
- `scripts/download_uci.py`:
  - downloads the dataset from UCI, or takes a copy you downloaded with `--from-file`;
  - validates the file and compares its SHA-256 with the analysed copy.
- `notebooks/01_uci_exploration.ipynb`: the P0-10 exploratory analysis (duplicates, class balance, data quality).
- `tests/`: pytest.
  - `test_uci.py`, `test_download.py`;
  - `test_notebook.py` runs the notebook on the fixture. Add a test like it for each new notebook.
- `pyproject.toml`: package, pytest and ruff settings. `requirements-dev.txt` installs the package in editable mode (`-e .`), so notebooks and tests can `import mediqore_ml`.

## Commands

Run from `ml/` with Python 3.11 (Windows PowerShell):

```powershell
py -3.11 -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt    # runtime + dev tools + the mediqore_ml package
python scripts/download_uci.py         # or: python scripts/download_uci.py --from-file <downloaded.csv>
ruff check .                           # lint (CI)
ruff format .                          # format
pytest                                 # tests (CI); uses the fixture, no download needed
```

Open the notebooks in VS Code (Python and Jupyter extensions) and choose the `.venv` kernel.
