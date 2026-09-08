from __future__ import annotations

import json

from dashboard.lib import loaders


def _point_snapshot_at(monkeypatch, snapshot_dir) -> None:
    """Wave 5 PHASE-06: the snapshot seam is PACTATRISK_SNAPSHOT_DIR."""
    monkeypatch.setenv("PACTATRISK_SNAPSHOT_DIR", str(snapshot_dir))


def test_load_pipeline_manifest_missing(monkeypatch, tmp_path) -> None:
    _point_snapshot_at(monkeypatch, tmp_path)
    assert loaders.load_pipeline_manifest() is None


def test_load_pipeline_manifest_present(monkeypatch, tmp_path) -> None:
    (tmp_path / "pipeline_manifest.json").write_text(
        json.dumps({"generated_at": "2026-07-04T00:00:00", "git_sha": "abc123", "status": "ok"}),
        encoding="utf-8",
    )
    _point_snapshot_at(monkeypatch, tmp_path)
    manifest = loaders.load_pipeline_manifest()
    assert manifest is not None
    assert manifest["status"] == "ok"


def test_load_pipeline_manifest_corrupt(monkeypatch, tmp_path) -> None:
    (tmp_path / "pipeline_manifest.json").write_text("{not valid json", encoding="utf-8")
    _point_snapshot_at(monkeypatch, tmp_path)
    assert loaders.load_pipeline_manifest() is None


# --- Wave 3 PHASE-03: data_freshness_badge() surfaces scenario_vintage --------

def test_data_freshness_badge_shows_scenario_vintage(monkeypatch, tmp_path) -> None:
    from streamlit.testing.v1 import AppTest

    manifest_path = tmp_path / "pipeline_manifest.json"
    manifest_path.write_text(
        json.dumps({
            "generated_at": "2026-08-27T00:00:00", "git_sha": "abc123def",
            "status": "ok", "scenario_vintage": "pdp8-2025-adjusted",
        }),
        encoding="utf-8",
    )

    script_path = tmp_path / "badge_script.py"
    script_path.write_text(
        "import os\n"
        "from dashboard.lib import branding\n"
        f"_prev_snapshot = os.environ.get('PACTATRISK_SNAPSHOT_DIR')\n"
        f"os.environ['PACTATRISK_SNAPSHOT_DIR'] = r'{tmp_path}'\n"
        "try:\n"
        "    branding.data_freshness_badge()\n"
        "finally:\n"
        "    if _prev_snapshot is None:\n"
        "        del os.environ['PACTATRISK_SNAPSHOT_DIR']\n"
        "    else:\n"
        "        os.environ['PACTATRISK_SNAPSHOT_DIR'] = _prev_snapshot\n",
        encoding="utf-8",
    )

    at = AppTest.from_file(str(script_path))
    at.run()
    assert not at.exception
    caption_text = " ".join(c.value for c in at.caption)
    assert "pdp8-2025-adjusted" in caption_text


def test_data_freshness_badge_omits_vintage_when_absent(tmp_path) -> None:
    from streamlit.testing.v1 import AppTest

    manifest_path = tmp_path / "pipeline_manifest.json"
    manifest_path.write_text(
        json.dumps({"generated_at": "2026-08-27T00:00:00", "git_sha": "abc123def", "status": "ok"}),
        encoding="utf-8",
    )

    script_path = tmp_path / "badge_script2.py"
    script_path.write_text(
        "import os\n"
        "from dashboard.lib import branding\n"
        f"_prev_snapshot = os.environ.get('PACTATRISK_SNAPSHOT_DIR')\n"
        f"os.environ['PACTATRISK_SNAPSHOT_DIR'] = r'{tmp_path}'\n"
        "try:\n"
        "    branding.data_freshness_badge()\n"
        "finally:\n"
        "    if _prev_snapshot is None:\n"
        "        del os.environ['PACTATRISK_SNAPSHOT_DIR']\n"
        "    else:\n"
        "        os.environ['PACTATRISK_SNAPSHOT_DIR'] = _prev_snapshot\n",
        encoding="utf-8",
    )

    at = AppTest.from_file(str(script_path))
    at.run()
    assert not at.exception
    caption_text = " ".join(c.value for c in at.caption)
    assert "scenario vintage" not in caption_text
