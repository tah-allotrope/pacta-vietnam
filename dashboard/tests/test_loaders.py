from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

from dashboard.lib.loaders import (
    load_pacta_alignment_tables,
    load_trisk_grid,
    load_trisk_sector_tables,
    load_trisk_tables,
    snapshot_root,
    trisk_dir,
)


def test_pacta_loaders_return_dataframes() -> None:
    tables = load_pacta_alignment_tables()
    assert tables["ms_portfolio"].empty is False
    assert tables["ms_alignment"].empty is False


def test_trisk_loaders_return_dataframes() -> None:
    tables = load_trisk_tables()
    assert tables["manifest"].empty is False
    assert tables["company_summary"].empty is False
    assert tables["company_trajectories_latest"].empty is False
    assert tables["sensitivity_results"].empty is False


def test_trisk_sector_loader_returns_dataframes() -> None:
    tables = load_trisk_sector_tables("cement")
    assert tables["company_summary"].empty is False
    assert tables["company_trajectories_latest"].empty is False
    assert tables["combined"].empty is False


def test_trisk_grid_sectors_have_required_files() -> None:
    manifest = load_trisk_tables()["manifest"]
    for sector in manifest[manifest["grid_available"] == True]["sector"]:
        grid_dir = trisk_dir() / "grid" / sector
        assert (grid_dir / "scenarios.csv").exists(), f"Missing scenarios.csv for {sector}"
        assert (grid_dir / "borrower_results.parquet").exists(), f"Missing borrower_results.parquet for {sector}"
        assert (grid_dir / "grid_meta.json").exists(), f"Missing grid_meta.json for {sector}"


def test_trisk_grid_loader_returns_correct_schema() -> None:
    grid = load_trisk_grid("power")
    assert "scenarios" in grid
    assert "borrower_results" in grid
    assert isinstance(grid["scenarios"], pd.DataFrame)
    assert isinstance(grid["borrower_results"], pd.DataFrame)

    expected_scenario_cols = {"scenario_id", "sector", "shock_year", "discount_rate", "risk_free_rate", "market_passthrough", "carbon_price_family"}
    assert expected_scenario_cols.issubset(set(grid["scenarios"].columns)), f"Missing columns: {expected_scenario_cols - set(grid['scenarios'].columns)}"

    expected_result_cols = {"scenario_id", "company_id", "company_name", "npv_change_pct", "pd_change_pct", "stress_priority_score"}
    assert expected_result_cols.issubset(set(grid["borrower_results"].columns)), f"Missing columns: {expected_result_cols - set(grid['borrower_results'].columns)}"

    assert grid["scenarios"]["scenario_id"].nunique() > 0
    assert grid["borrower_results"]["scenario_id"].nunique() > 0


def test_trisk_grid_scenario_count() -> None:
    grid = load_trisk_grid("power")
    n_scenarios = len(grid["scenarios"])

    grid_meta = json.loads((trisk_dir() / "grid" / "power" / "grid_meta.json").read_text())
    assert n_scenarios == grid_meta["scenario_count"], (
        f"Loaded grid has {n_scenarios} scenarios but grid_meta.json records "
        f"scenario_count={grid_meta['scenario_count']}"
    )

    # Wave 1 PHASE-04 (Specification S3): all five levers (shock_year,
    # discount_rate, risk_free_rate, market_passthrough, carbon_price_family)
    # were measured and confirmed to each independently affect at least one
    # output metric, so all five were kept at cardinality 3. grid_meta.json
    # does not itself store a per-lever cardinality breakdown, so this
    # asserts against the documented product (see
    # docs/trisk_scenario_grid_contract.md) rather than a bare magic number.
    assert grid_meta["scenario_count"] == 3 ** 5


# --- Wave 3 PHASE-02: report_catalog() reads the report_catalog.json sidecar --

def test_report_catalog_never_drops_a_published_html_file(monkeypatch, tmp_path) -> None:
    import dashboard.lib.loaders as loaders_mod

    reports_dir = tmp_path / "reports"
    reports_dir.mkdir()
    monkeypatch.setenv("PACTATRISK_SNAPSHOT_DIR", str(tmp_path))
    (reports_dir / "Known_Report.html").write_text("<html></html>", encoding="utf-8")
    (reports_dir / "Mystery_Report.html").write_text("<html></html>", encoding="utf-8")
    (reports_dir / "report_catalog.json").write_text(
        json.dumps({
            "Known_Report.html": {
                "title": "Known Report", "date": "2026-01-01",
                "summary": "A cataloged report.", "category": "client_facing",
            }
        }),
        encoding="utf-8",
    )

    rows = loaders_mod.report_catalog()
    names = {row["path"].name: row for row in rows}

    assert len(rows) == 2
    assert names["Known_Report.html"]["title"] == "Known Report"
    assert names["Known_Report.html"]["category"] == "client_facing"
    assert names["Mystery_Report.html"]["title"] == "Mystery_Report"
    assert names["Mystery_Report.html"]["summary"] == "No summary available."
    assert names["Mystery_Report.html"]["category"] == "uncatalogued"


def test_report_catalog_degrades_gracefully_with_no_sidecar(monkeypatch, tmp_path) -> None:
    import dashboard.lib.loaders as loaders_mod

    reports_dir = tmp_path / "reports"
    reports_dir.mkdir()
    monkeypatch.setenv("PACTATRISK_SNAPSHOT_DIR", str(tmp_path))
    (reports_dir / "Orphan.html").write_text("<html></html>", encoding="utf-8")

    rows = loaders_mod.report_catalog()
    assert len(rows) == 1
    assert rows[0]["title"] == "Orphan"
    assert rows[0]["category"] == "uncatalogued"


def test_live_snapshot_report_catalog_matches_published_reports() -> None:
    """The public MCB snapshot's report_catalog() must reflect exactly the
    files scripts/refresh_dashboard_data.R actually copied, with no
    internal_build entries eligible for it (Wave 3 PHASE-02, DEC-006)."""
    from dashboard.lib.loaders import report_catalog

    rows = report_catalog()
    for row in rows:
        assert row["category"] != "internal_build", (
            f"{row['path'].name} is category internal_build and must not be in the published snapshot"
        )


def test_report_catalog_date_comes_from_artifact_mtime(monkeypatch, tmp_path) -> None:
    """Displayed dates derive from the artifact file, not the catalog string
    (Wave 5 PHASE-04)."""
    import os
    import dashboard.lib.loaders as loaders_mod

    reports_dir = tmp_path / "reports"
    reports_dir.mkdir()
    monkeypatch.setenv("PACTATRISK_SNAPSHOT_DIR", str(tmp_path))
    html = reports_dir / "Dated.html"
    html.write_text("<html></html>", encoding="utf-8")
    (reports_dir / "report_catalog.json").write_text(
        json.dumps({
            "Dated.html": {
                "title": "Dated", "date": "1999-01-01",
                "summary": "s", "category": "client_facing",
            }
        }),
        encoding="utf-8",
    )

    import datetime
    expected = datetime.datetime.fromtimestamp(html.stat().st_mtime).strftime("%Y-%m-%d")
    rows = loaders_mod.report_catalog()
    assert rows[0]["date"] == expected
    assert rows[0]["date"] != "1999-01-01"


def test_report_catalog_date_falls_back_to_catalog(monkeypatch, tmp_path) -> None:
    """When the artifact is gone after listing (stat() failure), the catalog
    string is used."""
    import dashboard.lib.loaders as loaders_mod

    reports_dir = tmp_path / "reports"
    reports_dir.mkdir()
    monkeypatch.setenv("PACTATRISK_SNAPSHOT_DIR", str(tmp_path))
    (reports_dir / "Gone.html").write_text("<html></html>", encoding="utf-8")
    (reports_dir / "report_catalog.json").write_text(
        json.dumps({
            "Gone.html": {
                "title": "Gone", "date": "1999-01-01",
                "summary": "s", "category": "client_facing",
            }
        }),
        encoding="utf-8",
    )

    real_glob = list(loaders_mod.list_report_files())
    (reports_dir / "Gone.html").unlink()
    monkeypatch.setattr(loaders_mod, "list_report_files", lambda: real_glob)

    rows = loaders_mod.report_catalog()
    assert rows[0]["date"] == "1999-01-01"


def test_snapshot_root_defaults_to_dashboard_data(monkeypatch) -> None:
    import dashboard.lib.loaders as loaders_mod

    monkeypatch.delenv("PACTATRISK_SNAPSHOT_DIR", raising=False)
    assert str(loaders_mod.snapshot_root()).endswith("dashboard" + __import__("os").sep + "data")


def test_snapshot_root_reads_env_and_rebases_helpers(monkeypatch, tmp_path) -> None:
    import dashboard.lib.loaders as loaders_mod

    monkeypatch.setenv("PACTATRISK_SNAPSHOT_DIR", str(tmp_path))
    assert loaders_mod.snapshot_root() == tmp_path.resolve()
    assert (
        loaders_mod.pacta_path("04_vn_ms_portfolio.csv")
        == tmp_path.resolve() / "pacta" / "04_vn_ms_portfolio.csv"
    )
