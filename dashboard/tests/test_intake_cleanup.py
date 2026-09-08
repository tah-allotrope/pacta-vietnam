from __future__ import annotations

from pathlib import Path

from dashboard.lib.intake import cleanup_temp_files


def test_cleanup_removes_both_temp_files(tmp_path: Path) -> None:
    upload = tmp_path / "upload_x.xlsx"
    converted = tmp_path / "converted.csv"
    upload.write_bytes(b"raw-workbook-bytes")
    converted.write_text("a,b\n1,2\n", encoding="utf-8")

    cleanup_temp_files(upload, converted)

    assert not upload.exists()
    assert not converted.exists()


def test_cleanup_ignores_a_missing_second_path(tmp_path: Path) -> None:
    upload = tmp_path / "upload.csv"
    upload.write_bytes(b"loanbook-bytes")

    cleanup_temp_files(upload, tmp_path / "does_not_exist.csv")

    assert not upload.exists()


def test_cleanup_never_raises_and_still_deletes_the_other_file(tmp_path: Path) -> None:
    blocked = tmp_path / "a_directory"
    blocked.mkdir()
    other = tmp_path / "other.csv"
    other.write_bytes(b"data")

    cleanup_temp_files(blocked, other)

    assert not other.exists()
