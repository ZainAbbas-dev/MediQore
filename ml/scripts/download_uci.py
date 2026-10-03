"""M4 FE-1: download the UCI Maternal Health Risk dataset (P0-10).

    python scripts/download_uci.py                       # download from UCI
    python scripts/download_uci.py --from-file PATH.csv  # use a copy you downloaded yourself

Saves the CSV to ml/data/raw/maternal_health_risk.csv (git-ignored), checks
its columns and labels, and compares its SHA-256 with the copy the team
analysed in notebooks/01_uci_exploration.ipynb.

Source: https://archive.ics.uci.edu/dataset/863/maternal+health+risk
(public, de-identified, CC BY 4.0). Cite it in the report.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mediqore_ml.uci import DEFAULT_CSV, class_balance, duplicate_report, load_uci  # noqa: E402

URL = "https://archive.ics.uci.edu/static/public/863/maternal+health+risk.zip"
# SHA-256 of the file analysed in notebooks/01_uci_exploration.ipynb (1,014 rows).
EXPECTED_SHA256 = "a1f7025719f84715096e0d1f95ae2e56b57809b9b15449e1836c96a7d976ae9b"


def extract_csv(archive: bytes) -> bytes:
    """Returns the single CSV file inside the UCI zip archive."""
    with zipfile.ZipFile(io.BytesIO(archive)) as zf:
        names = [n for n in zf.namelist() if n.lower().endswith(".csv") and not n.startswith("__MACOSX")]
        if len(names) != 1:
            raise ValueError(f"expected one CSV in the archive, found {names}")
        return zf.read(names[0])


def save(data: bytes, target: Path) -> str:
    """Writes the CSV, validates it and returns its SHA-256."""
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    try:
        load_uci(target)
    except ValueError:
        target.unlink()
        raise
    return hashlib.sha256(data).hexdigest()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--from-file", type=Path, help="CSV you already downloaded (from the UCI page)")
    parser.add_argument("--out", type=Path, default=DEFAULT_CSV, help=f"where to save it (default {DEFAULT_CSV})")
    args = parser.parse_args(argv)

    if args.from_file:
        data = args.from_file.read_bytes()
    else:
        print(f"Downloading {URL}")
        with urllib.request.urlopen(URL, timeout=60) as response:  # noqa: S310 (fixed https URL)
            data = extract_csv(response.read())

    digest = save(data, args.out)
    df = load_uci(args.out)
    report = duplicate_report(df)
    print(f"Saved {args.out} ({report['rows']} rows, {report['unique_rows']} unique)")
    print(class_balance(df).to_string())
    if digest == EXPECTED_SHA256:
        print("SHA-256 matches the copy analysed in notebooks/01_uci_exploration.ipynb.")
    else:
        print(f"Note: SHA-256 {digest} differs from the analysed copy ({EXPECTED_SHA256}).")
        print("The data may have changed; re-run the notebook and compare its numbers.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
