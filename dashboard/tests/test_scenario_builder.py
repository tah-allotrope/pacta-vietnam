from __future__ import annotations

import json

import pandas as pd
import pytest

from dashboard.lib.loaders import load_trisk_grid, trisk_dir

CARBON_LABELS = {
    "NGFS_NetZero2050": "Net Zero 2050 (strict)",
    "NGFS_Below2C": "Below 2\u00b0C (moderate)",
    "NGFS_Delayed": "Delayed transition (mild)",
}


def _build_scenario_id(
    shock_year: int, discount_rate: float, risk_free_rate: float,
    market_passthrough: float, carbon_price_family: str,
) -> str:
    return f"s{shock_year}_d{discount_rate}_rf{risk_free_rate}_mp{market_passthrough}_c{carbon_price_family}"


def _parse_scenario_id(scenario_id: str) -> dict:
    prefix, carbon_part = scenario_id.split("_c", 1)
    parts = prefix.split("_")
    return {
        "shock_year": int(parts[0][1:]),
        "discount_rate": float(parts[1][1:]),
        "risk_free_rate": float(parts[2][2:]),
        "market_passthrough": float(parts[3][2:]),
        "carbon_price_family": carbon_part,
    }


def _grid_label(scenario: pd.Series) -> str:
    return (
        f"Shock {scenario['shock_year']} | Disc {scenario['discount_rate']} | "
        f"RF {scenario['risk_free_rate']} | Pass {scenario['market_passthrough']} | "
        f"{CARBON_LABELS.get(scenario['carbon_price_family'], scenario['carbon_price_family'])}"
    )


def test_scenario_id_roundtrip() -> None:
    levers = {
        "shock_year": 2028,
        "discount_rate": 0.08,
        "risk_free_rate": 0.03,
        "market_passthrough": 0.25,
        "carbon_price_family": "NGFS_NetZero2050",
    }
    sid = _build_scenario_id(**levers)
    assert sid == "s2028_d0.08_rf0.03_mp0.25_cNGFS_NetZero2050"
    parsed = _parse_scenario_id(sid)
    assert parsed == levers


def test_scenario_id_parse_known_id() -> None:
    sid = "s2026_d0.06_rf0.02_mp0.15_cNGFS_Below2C"
    parsed = _parse_scenario_id(sid)
    assert parsed["shock_year"] == 2026
    assert parsed["discount_rate"] == 0.06
    assert parsed["risk_free_rate"] == 0.02
    assert parsed["market_passthrough"] == 0.15
    assert parsed["carbon_price_family"] == "NGFS_Below2C"


def test_grid_label_format() -> None:
    fake = pd.Series({
        "shock_year": 2030,
        "discount_rate": 0.10,
        "risk_free_rate": 0.04,
        "market_passthrough": 0.35,
        "carbon_price_family": "NGFS_Delayed",
    })
    label = _grid_label(fake)
    assert "2030" in label
    assert "Delayed" in label


@pytest.mark.parametrize("sector", ["power", "cement", "steel"])
def test_all_sectors_have_scenario_data(sector: str) -> None:
    grid = load_trisk_grid(sector)
    assert len(grid["scenarios"]) > 0
    assert len(grid["borrower_results"]) > 0


def test_every_scenario_id_exists_in_borrower_results() -> None:
    grid = load_trisk_grid("power")
    scenario_ids_in_scenarios = set(grid["scenarios"]["scenario_id"])
    scenario_ids_in_results = set(grid["borrower_results"]["scenario_id"])
    missing = scenario_ids_in_scenarios - scenario_ids_in_results
    assert not missing, f"Missing scenario_ids in borrower_results: {missing}"


def test_scenario_lookup_by_id() -> None:
    grid = load_trisk_grid("power")
    sample_sid = grid["scenarios"]["scenario_id"].iloc[0]
    result = grid["borrower_results"][grid["borrower_results"]["scenario_id"] == sample_sid]
    assert len(result) > 0
    assert all(result["scenario_id"] == sample_sid)


def test_baseline_vs_scenario_delta_computation() -> None:
    grid = load_trisk_grid("power")
    first_sid = grid["scenarios"]["scenario_id"].iloc[0]
    results = grid["borrower_results"].copy()
    scenario_slice = results[results["scenario_id"] == first_sid].copy()

    assert "delta_npv_change_vs_base" in scenario_slice.columns
    assert "delta_pd_change_vs_base" in scenario_slice.columns
    assert scenario_slice["delta_npv_change_vs_base"].notna().any()


def test_scenario_export_json_roundtrip() -> None:
    grid = load_trisk_grid("power")
    sample_row = grid["scenarios"].iloc[0]
    export = {
        "scenario_id": sample_row["scenario_id"],
        "sector": sample_row["sector"],
        "levers": {
            "shock_year": int(sample_row["shock_year"]),
            "discount_rate": float(sample_row["discount_rate"]),
            "risk_free_rate": float(sample_row["risk_free_rate"]),
            "market_passthrough": float(sample_row["market_passthrough"]),
            "carbon_price_family": sample_row["carbon_price_family"],
        },
    }
    serialized = json.dumps(export)
    restored = json.loads(serialized)
    assert restored["scenario_id"] == export["scenario_id"]
    assert restored["levers"]["carbon_price_family"] == export["levers"]["carbon_price_family"]
