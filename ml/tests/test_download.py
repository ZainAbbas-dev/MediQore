"""Tests for scripts/download_uci.py without the network."""

import importlib.util
import io
import zipfile
from pathlib import Path

import pytest

FIXTURE = Path(__file__).parent / "fixtures" / "uci_sample.csv"
SCRIPT = Path(__file__).parent.parent / "scripts" / "download_uci.py"
spec = importlib.util.spec_from_file_location("download_uci", SCRIPT)
download_uci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(download_uci)


def zip_of(files):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as zf:
        for name, data in files.items():
            zf.writestr(name, data)
    return buffer.getvalue()


def test_extracts_the_csv_from_the_archive():
    data = FIXTURE.read_bytes()
    assert download_uci.extract_csv(zip_of({"Maternal Health Risk Data Set.csv": data, "readme.txt": b"x"})) == data


def test_refuses_an_archive_without_exactly_one_csv():
    with pytest.raises(ValueError, match="one CSV"):
        download_uci.extract_csv(zip_of({"readme.txt": b"x"}))


def test_from_file_saves_and_checks_the_copy(tmp_path, capsys):
    out = tmp_path / "raw" / "maternal_health_risk.csv"
    assert download_uci.main(["--from-file", str(FIXTURE), "--out", str(out)]) == 0
    assert out.read_bytes() == FIXTURE.read_bytes()
    printed = capsys.readouterr().out
    assert "12 rows, 8 unique" in printed
    assert "differs from the analysed copy" in printed  # the fixture is not the real file


def test_an_invalid_file_is_not_kept(tmp_path):
    bad = tmp_path / "bad.csv"
    bad.write_text("a,b\n1,2\n")
    out = tmp_path / "raw" / "maternal_health_risk.csv"
    with pytest.raises(ValueError):
        download_uci.main(["--from-file", str(bad), "--out", str(out)])
    assert not out.exists()
