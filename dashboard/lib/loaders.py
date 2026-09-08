from __future__ import annotations

import os

import json
from pathlib import Path

import pandas as pd
import streamlit as st


ROOT = Path(__file__).resolve().parents[1]


def snapshot_root() -> Path:
    """The snapshot directory the app reads (Wave 5 PHASE-06).

    From `PACTATRISK_SNAPSHOT_DIR` when set, otherwise the frozen public
    snapshot `dashboard/data`. A client engagement is a directory, not a
    repository fork.
    """
    return Path(os.environ.get("PACTATRISK_SNAPSHOT_DIR", str(ROOT / "data"))).resolve()


def pacta_dir() -> Path:
    return snapshot_root() / "pacta"


def trisk_dir() -> Path:
    return snapshot_root() / "trisk"


def reports_dir() -> Path:
    return snapshot_root() / "reports"


def analytics_dir() -> Path:
    return snapshot_root() / "analytics"


def trisk_manifest() -> Path:
    return trisk_dir() / "manifest.csv"


def pipeline_manifest_path() -> Path:
    return snapshot_root() / "pipeline_manifest.json"


def load_pipeline_manifest() -> dict | None:
    """Read the pipeline refresh manifest, or None if it hasn't been generated yet."""
    manifest_path = pipeline_manifest_path()
    if not manifest_path.exists():
        return None
    try:
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


# Every cached loader takes its path as an argument (never closes over a
# module-level snapshot directory), so switching PACTATRISK_SNAPSHOT_DIR
# mid-session serves the new snapshot instead of a stale memoized frame.


@st.cache_data(show_spinner=False)
def load_csv(path: str | Path) -> pd.DataFrame:
    return pd.read_csv(path)


@st.cache_data(show_spinner=False)
def load_markdown_text(path: str | Path) -> str:
    return Path(path).read_text(encoding="utf-8")


@st.cache_data(show_spinner=False)
def load_bytes(path: str | Path) -> bytes:
    return Path(path).read_bytes()


def pacta_path(name: str) -> Path:
    return pacta_dir() / name


def trisk_path(name: str) -> Path:
    return trisk_dir() / name


def trisk_sector_path(sector: str, name: str) -> Path:
    return trisk_dir() / sector / name


def reports_path(name: str) -> Path:
    return reports_dir() / name


def analytics_path(name: str) -> Path:
    return analytics_dir() / name


# Filenames copied into <snapshot>/analytics/ by scripts/refresh_dashboard_data.R,
# keyed by the name the app uses for each table.
ANALYTICS_TABLES = {
    "financed_emissions": "financed_emissions.csv",
    "data_quality_summary": "data_quality_summary.csv",
    "target_registry": "target_registry.csv",
    "sll_readiness": "sll_readiness.csv",
}


def load_analytics_tables() -> dict[str, pd.DataFrame]:
    """The Wave 3 analytics (PCAF inventory, target registry, SLL shortlist) as
    data rather than rendered HTML.

    A file that is absent is omitted from the result rather than raising: an
    engagement may not have run financed emissions, targets or the SLL screen,
    and an older snapshot predates the analytics/ directory entirely.
    """
    tables: dict[str, pd.DataFrame] = {}
    for key, filename in ANALYTICS_TABLES.items():
        path = analytics_path(filename)
        if not path.exists():
            continue
        try:
            tables[key] = load_csv(path)
        except (OSError, ValueError, pd.errors.ParserError):
            continue
    return tables


def load_pacta_alignment_tables() -> dict[str, pd.DataFrame]:
    return {
        "matches": load_csv(pacta_path("02_vn_matched_prioritized.csv")),
        "ms_company": load_csv(pacta_path("04_vn_ms_company.csv")),
        "ms_portfolio": load_csv(pacta_path("04_vn_ms_portfolio.csv")),
        "sda_portfolio": load_csv(pacta_path("05_vn_sda_portfolio.csv")),
        "ms_alignment": load_csv(pacta_path("06_vn_ms_alignment_2030.csv")),
        "sda_alignment": load_csv(pacta_path("06_vn_sda_alignment_2030.csv")),
    }


def load_trisk_tables() -> dict[str, pd.DataFrame]:
    manifest = load_csv(trisk_manifest())
    default_sector = manifest.iloc[0]["sector"]
    return {
        "manifest": manifest,
        "default_sector": pd.DataFrame({"sector": [default_sector]}),
        **load_trisk_sector_tables(default_sector),
    }


def load_trisk_sector_tables(sector: str) -> dict[str, pd.DataFrame]:
    return {
        "assets": load_csv(trisk_sector_path(sector, "assets.csv")),
        "company_summary": load_csv(trisk_sector_path(sector, "company_summary.csv")),
        "company_trajectories_latest": load_csv(trisk_sector_path(sector, "company_trajectories_latest.csv")),
        "npv_results": load_csv(trisk_sector_path(sector, "npv_results_latest.csv")),
        "pd_results": load_csv(trisk_sector_path(sector, "pd_results_latest.csv")),
        "pd_summary": load_csv(trisk_sector_path(sector, "pd_summary.csv")),
        "financial_features": load_csv(trisk_sector_path(sector, "financial_features.csv")),
        "carbon_price": load_csv(trisk_sector_path(sector, "ngfs_carbon_price.csv")),
        "run_catalog": load_csv(trisk_sector_path(sector, "run_catalog.csv")),
        "scenarios": load_csv(trisk_sector_path(sector, "scenarios.csv")),
        "sensitivity_results": load_csv(trisk_sector_path(sector, "sensitivity_results.csv")),
        "sensitivity_summary": load_csv(trisk_sector_path(sector, "sensitivity_summary.csv")),
        "combined": load_csv(trisk_sector_path(sector, "top_borrowers_alignment_trisk.csv")),
    }


@st.cache_data(show_spinner=False)
def load_parquet(path: str | Path) -> pd.DataFrame:
    return pd.read_parquet(path)


def load_trisk_grid(sector: str) -> dict[str, pd.DataFrame]:
    grid_dir = trisk_dir() / "grid" / sector
    return {
        "scenarios": load_csv(grid_dir / "scenarios.csv"),
        "borrower_results": load_parquet(grid_dir / "borrower_results.parquet"),
    }


def list_report_files() -> list[Path]:
    return sorted(reports_dir().glob("*.html"))


def _load_report_catalog_sidecar() -> dict[str, dict[str, str]]:
    """Read the report_catalog.json sidecar copied into the snapshot by
    scripts/refresh_dashboard_data.R (Wave 3 PHASE-02). Returns {} if the
    sidecar is absent (e.g. an old snapshot predating this phase) or
    unreadable -- report_catalog() below degrades every file to an
    uncatalogued entry rather than raising.
    """
    sidecar_path = reports_dir() / "report_catalog.json"
    if not sidecar_path.exists():
        return {}
    try:
        import json

        return json.loads(sidecar_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _artifact_date(path: Path, fallback: str = "") -> str:
    """Displayed date for a published artifact (Wave 5 PHASE-04): the file's
    own modification date formatted YYYY-MM-DD, falling back to the catalog
    string when stat() raises."""
    import datetime

    try:
        return datetime.datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d")
    except OSError:
        return fallback


def report_catalog() -> list[dict[str, str | Path]]:
    """Every HTML file actually present in the reports snapshot, with
    metadata from report_catalog.json when available. A published file with
    no catalog entry is never silently dropped (Wave 3 PHASE-02, N-008) --
    it gets a filename-derived title and an explicit "no summary" marker
    instead. The displayed date comes from the artifact file itself, not
    the catalog's hand-typed string (Wave 5 PHASE-04).
    """
    catalog = _load_report_catalog_sidecar()
    rows: list[dict[str, str | Path]] = []
    for path in list_report_files():
        meta = catalog.get(path.name)
        if meta:
            rows.append({
                "path": path,
                "title": meta.get("title", path.stem),
                "date": _artifact_date(path, meta.get("date", "")),
                "summary": meta.get("summary", "No summary available."),
                "category": meta.get("category", "uncatalogued"),
            })
        else:
            rows.append({
                "path": path,
                "title": path.stem,
                "date": _artifact_date(path),
                "summary": "No summary available.",
                "category": "uncatalogued",
            })
    return rows
