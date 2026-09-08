from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

import pandas as pd

ENV_FLAG = "BYOL_INTAKE"
ENV_RSCRIPT = "R_RSCRIPT"
DEFAULT_RSCRIPT = "Rscript"
SUBPROCESS_TIMEOUT = 60  # seconds

INTAKE_SCRIPT = (
    Path(__file__).resolve().parents[2] / "scripts" / "intake_validate_and_map.R"
)
INTAKE_DEFAULT_OUTPUT_DIR = (
    Path(__file__).resolve().parents[2] / "intake" / "output"
)


def is_intake_enabled() -> bool:
    return os.environ.get(ENV_FLAG) == "1"


def get_rscript_path() -> str:
    return os.environ.get(ENV_RSCRIPT, DEFAULT_RSCRIPT)


def cleanup_temp_files(*paths) -> None:
    """Delete temp files, ignoring missing paths and OS errors.

    Used by the intake wizard's finally block so both the uploaded file and
    any converted CSV are removed even when validation calls st.stop().
    """
    for path in paths:
        try:
            Path(path).unlink(missing_ok=True)
        except OSError:
            pass


def convert_xlsx_to_csv(xlsx_path: Path) -> Path:
    """Read the Data sheet from an XLSX and write to a temp CSV."""
    import openpyxl

    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    ws = wb["Data"]

    rows: list[list[str | None]] = []
    for row in ws.iter_rows(values_only=True):
        rows.append([str(cell) if cell is not None else "" for cell in row])

    header = rows[0]
    data_rows = rows[1:]

    # Filter out completely empty rows
    data_rows = [r for r in data_rows if any(c.strip() for c in r)]

    fd, tmp_path = tempfile.mkstemp(suffix=".csv", prefix="intake_xlsx_")
    os.close(fd)

    df = pd.DataFrame(data_rows, columns=header)
    df.to_csv(tmp_path, index=False)
    return Path(tmp_path)


def parse_validation_summary(summary_path: Path) -> dict:
    """Parse the validation summary text file into structured fields."""
    result: dict = {
        "total_rows": 0,
        "passing_rows": 0,
        "error_rows": 0,
        "sector_distribution": {},
        "unresolved_codes": [],
        "match_count": 0,
        "review_count": 0,
        "raw_text": "",
    }

    if not summary_path.exists():
        return result

    text = summary_path.read_text(encoding="utf-8")
    result["raw_text"] = text

    for line in text.splitlines():
        line = line.strip()
        if line.startswith("Total rows processed:"):
            result["total_rows"] = int(line.split(":")[-1].strip())
        elif line.startswith("Rows passing validation:"):
            result["passing_rows"] = int(line.split(":")[-1].strip())
        elif line.startswith("Rows with errors:"):
            result["error_rows"] = int(line.split(":")[-1].strip())
        elif line.startswith("Total candidate matches:"):
            result["match_count"] = int(line.split(":")[-1].strip())
        elif line.startswith("Review needed (score < 1.0):"):
            result["review_count"] = int(line.split(":")[-1].strip())

    return result


def run_intake_validation(
    uploaded_path: Path,
    output_dir: Path | None = None,
) -> dict:
    """Call the R intake validation script via subprocess and return structured results."""
    if not is_intake_enabled():
        raise RuntimeError(
            f"Intake is not enabled. Set {ENV_FLAG}=1 to use this feature."
        )
    if not INTAKE_SCRIPT.exists():
        raise RuntimeError(
            f"Intake script not found at {INTAKE_SCRIPT}."
        )

    if output_dir is None:
        output_dir = INTAKE_DEFAULT_OUTPUT_DIR

    output_dir.mkdir(parents=True, exist_ok=True)

    rscript = get_rscript_path()
    cmd = [
        str(rscript),
        str(INTAKE_SCRIPT),
        f"--input={uploaded_path}",
        f"--output-dir={output_dir}",
    ]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(
            f"Intake R subprocess timed out after {SUBPROCESS_TIMEOUT}s. "
            "Check that the input file is valid and not too large."
        )
    except FileNotFoundError:
        raise RuntimeError(
            f"Rscript not found at '{rscript}'. "
            f"Set the {ENV_RSCRIPT} env var to the full path of Rscript."
        )

    if proc.returncode != 0:
        stderr_msg = proc.stderr.strip() if proc.stderr.strip() else "(no stderr)"
        raise RuntimeError(
            f"Intake R subprocess failed (exit code {proc.returncode}).\n"
            f"Stderr:\n{stderr_msg}"
        )

    results: dict = {
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }

    # Load output files
    for fname in [
        "normalized_loanbook.csv",
        "validation_errors.csv",
        "match_preview.csv",
        "validation_summary.txt",
    ]:
        fpath = output_dir / fname
        if fpath.exists():
            if fname.endswith(".csv"):
                results[fname.replace(".csv", "")] = pd.read_csv(fpath)
            else:
                results[fname.replace(".txt", "")] = parse_validation_summary(fpath)

    return results
