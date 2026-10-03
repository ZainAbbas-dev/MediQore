# ml/: model training and analytics worker

Python pipeline for the Module 4 risk model (training, SHAP Urdu lookup, ONNX export) and the Module 6 analytics worker. Follow the root `CLAUDE.md` first; this file only adds what is specific to `ml/`.

## Stack (scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.11 | Training and analytics runtime |
| scikit-learn | 1.4 | Logistic Regression, Random Forest, Gradient Boosting |
| imbalanced-learn (SMOTE) | Latest | Class balancing |
| SHAP | Latest | Feature-threshold-to-risk-class mappings, exported as a JSON lookup for the app |
| sklearn2onnx | Latest | Export of the chosen model to ONNX for on-device inference |
| numpy + scipy | Latest | Analytics worker: linear-regression trends and Z-score anomalies (M6 FE-3) |

Data sources:

- UCI Maternal Health Risk Dataset, used for training.
- PDHS 2017–18, used for domain validation only (LI-2).

From the roadmap: tests use pytest, including saved metrics.

## Key rules

- Remove duplicate rows. Keep a stratified 20% hold-out set untouched until the end.
- Apply SMOTE inside each training fold only, never before the split.
- Select the model by high-risk recall of at least 90% first, then by F1-macro (BO-2).
- Export to ONNX with plain probability output (no ZipMap). Keep a parity test showing that Python and ONNX agree on every test row.
- Version every exported model; the app stores the model version on each risk assessment.

## Commands

<!-- Fill in when P0-10 starts the ML track. -->
