# PACTA + TRISK Vietnam — Bank Climate Alignment & Transition-Risk Platform
[![CI](https://github.com/tah-allotrope/pacta-trisk/actions/workflows/ci.yml/badge.svg)](https://github.com/tah-allotrope/pacta-trisk/actions/workflows/ci.yml)

An end-to-end demonstration platform that shows how a Vietnamese bank can
measure loanbook climate alignment (**PACTA** — Paris Agreement Capital
Transition Assessment) and stress-test transition risk at borrower level
(**TRISK**), then turn the results into engagement and disclosure
deliverables aligned with Decision 263/QĐ-TTg, TCFD, and ISSB.

> **All data is synthetic.** Every number comes from the fictional
> "Mekong Commercial Bank (MCB)" case — synthetic loanbook, synthetic
> asset-based company data, and adapted PDP8 / NDC / IEA NZE scenario
> pathways. Nothing here is a real assessment of any institution.

**Live demo:** https://pactavn.streamlit.app

## Architecture

`scripts/run_engagement.R` is the single orchestrator for every engagement,
including the public MCB demo. `scripts/pipeline_refresh.R` is a thin
compatibility wrapper that delegates to it with
`engagements/mcb-demo/engagement_config.json` (run weekly by
`.github/workflows/refresh.yml`); every flag it receives (`--full`,
`--dry-run`) passes straight through.

```
scripts/generate_vietnam_data.R       synthetic inputs (loanbook, ABCD, scenarios)  [--full only]
        │
        ▼
scripts/pacta_vietnam_scenario.R      PACTA alignment vs PDP8 / NDC / NZE
        │                             → synthesis_output/vietnam/
        ▼
scripts/trisk_prepare_inputs.R        TRISK input packages per sector
scripts/trisk_sector_demo.R           TRISK stress runs (power / cement / steel)
scripts/trisk_scenario_grid.R         243-scenario sensitivity grid per sector
        │                             → synthesis_output/trisk/
        ▼
scripts/sector_prioritization.R       sector ranking (alignment × stress × exposure)
scripts/refresh_dashboard_data.R      publish frozen snapshot → dashboard/data/
        │
        ▼
dashboard/                            Streamlit app (8 pages; 3 operator-gated)
        │
        ▼
scripts/engagement_scoring.R          borrower engagement priority
scripts/generate_engagement_letters.R per-borrower letters
scripts/generate_disclosure_pack.R    TCFD / ISSB / Decision 263 pack
        │
        ▼
scripts/generate_refresh_audit.R      refresh audit report                          [mcb-demo only]
```

The whole chain, in order, is orchestrated by
`R/step_runner.R`'s `run_steps()`, invoked from `scripts/run_engagement.R`'s
config-driven step list (see "Running a client engagement" below).

## Quick start

Prerequisites: R 4.5+ (Windows path assumed below) and Python 3.11+.

```powershell
# Python deps (dashboard)
python -m pip install -r dashboard/requirements.txt

# R deps (pipeline)
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/ci/install_deps.R

# Rebuild the TRISK chain + dashboard snapshot (writes pipeline_manifest.json)
$env:Path += ";C:\Program Files\R\R-4.5.2\bin"
Rscript scripts/pipeline_refresh.R

# Tests
python -m pytest dashboard/tests

# Run the app
python -m streamlit run dashboard/app.py
```

On Linux/macOS use plain `Rscript` on PATH. Always run from the repo root —
all R scripts resolve paths relative to the working directory.

## Refactor acceptance check

Any change touching `scripts/` or `R/` must leave every default-mode CSV output
byte-identical to its pre-change content (PNGs are exempt; a generated HTML
deliverable may differ only in timestamp text, which is now checked rather
than assumed). Verify this with one command instead of hand-diffing:

```powershell
$env:Path += ";C:\Program Files\R\R-4.5.2\bin"
Rscript tools/verify_refactor.R
```

This reruns `scripts/pipeline_refresh.R` and classifies every tracked file
`git diff` reports as changed into expected churn (timestamps/manifests),
known-volatile noise (a named list of TRISK CSVs with a regenerated run-id
column — currently empty, since PHASE-04 made every run-id deterministic),
or genuine drift. It prints `BYTE-IDENTITY PASS` and exits 0 only when no
genuine drift is found. Pass `--full` to check against a
`pipeline_refresh.R --full` run, or `--skip-refresh` to classify the current
working tree without rerunning the pipeline.

Byte-identity answers "does run N+1 match run N?" — it is structurally
blind to a cache that never regenerates, or two committed artifacts that
silently disagree with each other. A second, independent mode answers that
question instead:

```powershell
$env:Path += ";C:\Program Files\R\R-4.5.2\bin"
Rscript tools/verify_refactor.R --invariants
```

This checks thirteen cross-artifact consistency rules against the current tree
without running anything: the TRISK scenario grid's base-parameter cell
must equal the base (non-grid) TRISK run; no scenario vintage may exist at
two paths; every engagement's `data_source` column must equal its own
`bank_slug`; the supported-sector literal must agree across every file
that hardcodes it; every published TRISK manifest sector must be a known
registry sector; every declared-VND loanbook must be on a plausible scale;
no tracked engagement file may fall outside the fixture allowlist; the
dependency manifests must agree; every engagement must declare a scenario
vintage that exists; every generated HTML deliverable must carry its
synthetic-data disclaimer; a complete pipeline manifest must not report one
identical duration for every step; and the refresh audit's recorded scenario
checksums must match the inputs the engagement config actually declares. It
prints `INVARIANTS PASS` and exits 0 only
when every invariant holds. Gated reports carry a .facts.json sidecar whose values are recomputed from source CSVs by INV-013 (currently covering the PACTA bank report and the financed-emissions report); a headline figure that disagrees with its CSV fails the gate. Both `.github/workflows/ci.yml` and
`.github/workflows/refresh.yml` run this on every push and every weekly
refresh.

**Where each check runs.** `ci.yml` runs both modes on every push and pull
request: a `byte-identity` job runs the default (non-`--full`) byte-identity
check, and the `r-tests` job runs `--invariants`. `refresh.yml` runs
`--invariants` after every weekly refresh, then runs byte-identity in
`--skip-refresh` mode as a gate immediately before the auto-commit step —
any genuine drift stops the workflow before `dashboard/data` and
`synthesis_output` are pushed. To land an intentional, reviewed refreeze,
re-run `refresh.yml` manually via `workflow_dispatch` with `allow_drift: true`,
which skips only that gate step.

## Running a client engagement

`scripts/run_engagement.R` runs the full delivery flow — intake, validation
report, coverage & reconciliation report, PACTA, TRISK, prioritization,
snapshot, scoring, letters, disclosure — for any engagement config in one
command:

```powershell
$env:Path += ";C:\Program Files\R\R-4.5.2\bin"
Rscript scripts/run_engagement.R --config engagements/<slug>/engagement_config.json --raw-loanbook <path/to/loanbook.csv>
```

`system2("Rscript", ...)` needs `Rscript` on PATH even when the outer call
used a full path — set `$env:Path` first as shown above (same requirement as
`scripts/pipeline_refresh.R`). Add `--dry-run` to print the resolved step
list without executing or writing anything — useful for checking which
steps a config will run (e.g. whether the scenario grid is included) before
committing to a full run. Omit `--raw-loanbook` to run against the loanbook
already named in the engagement config, or add `--skip-intake` to skip
intake and re-run only the downstream stages. `mcb-demo` is the only
engagement allowed to publish into the public `dashboard/data` snapshot; any
other engagement's `snapshot_dir` must point elsewhere, or the run refuses
to start.

Every engagement that runs intake produces a **Coverage & Reconciliation
Report** (`engagements/<slug>/reports/Coverage_Reconciliation_Report.html`)
plus a machine-readable sidecar `engagements/<slug>/intake/coverage_metrics.json`
(Wave 2 PHASE-06). Together they answer, in both row counts and VND, what the
client submitted, what was normalized, what was dropped and why, what was
retained-with-warning and why, and what fraction of processed exposure has
asset-level (ABCD) coverage. USD rows are converted once at intake using the
engagement config's `inputs.fx_rate_usd_vnd`; without a configured rate they
are retained with exposure set to `NA` and the intake exits non-zero naming
the missing key — never silently dropped.

## Repository map

| Path | Contents |
|---|---|
| `scripts/` | R pipeline stages (incl. `generate_vietnam_data.R`), report generators, and `run_engagement.R` — the single orchestrator for every engagement (`pipeline_refresh.R` is a thin wrapper over it for the public MCB demo) |
| `R/` | Shared R modules sourced by `scripts/*.R` and loadable as the `pactatrisk` package: engagement config loader, sector registry, report toolkit, matching helpers, PACTA core functions |
| `engagements/` | Per-engagement config (`engagement_config.json`); `mcb-demo/` documents the built-in defaults |
| `data/` | Synthetic Vietnam input CSVs (generated by `scripts/generate_vietnam_data.R`) |
| `synthesis_output/` | Pipeline outputs (PACTA, TRISK, scenario grid) |
| `dashboard/` | Streamlit app: `app.py`, `pages/`, `lib/`, `tests/`, frozen snapshot `data/` |
| `intake/` | "Bring Your Own Loanbook" schema contract + templates |
| `pilot/` | Bank-agnostic pilot conversion pack (`{{BANK_NAME}}` tailoring slots) |
| `docs/` | Methodology guides, deployment notes, assumption registers |
| `reports/` | Rendered self-contained HTML reports |
| `tools/` | `verify_refactor.R` (byte-identity + invariants gates), `run_tests.R`, the scale benchmark, `render_pdf.R` |
| `templates/` | Engagement letter, disclosure narrative, and i18n label tables |
| `output/` | Engagement scoring, letters, disclosure pack, financed emissions, TRISK inputs |
| `history/` | Append-only per-run result snapshots, for year-over-year comparison |
| `workshop/` | Client facilitation kit (`README.md`, `actions_log_template.csv`) |
| `plans/`, `research/` | Implementation plans and research briefs |
| `attic/` | Superseded methodology-reference scripts and comparisons, kept for historical context only |

## Operator features (env-gated, off by default)

| Flag | Feature |
|---|---|
| `BYOL_INTAKE=1` | Intake Wizard (page 6): validate + map a client loanbook |
| `OUTPUTS_LAYER=1` | Outputs (page 7): engagement letters + disclosure pack |
| `TRISK_LIVE_RERUN=1` | Live TRISK rerun in the Scenario Builder (**never on Cloud** — no R runtime) |
| `PILOT_ANALYTICS_ENDPOINT` | Anonymous page-view counter (see `docs/streamlit-deploy.md`) |
| `R_RSCRIPT` | Path to `Rscript` for the R-calling features above |
| `PACTATRISK_SNAPSHOT_DIR` | Read a different snapshot directory (default `dashboard/data`) |
| `ENGAGEMENT_PICKER=1` | Sidebar engagement picker (operator machine only — never on a multi-user deployment) |

## Methodology & caveats

- PACTA: `r2dii.data` / `r2dii.match` / `r2dii.analysis` (RMI); TRISK:
  `trisk.model` (Theia Finance Labs), after Baer et al. (2022).
- TRISK NPV/PD figures are **illustrative stress indicators**, not
  production credit-model outputs.
- Cement and steel use sector-level SDA context (not borrower-specific
  alignment); steel match coverage in the synthetic book is low.
- See `docs/TRISK_Demo_Assumptions.md`, `docs/trisk_multisector_contract.md`,
  and `dashboard/data/README.md` for the full assumption registers.

## License

Proprietary — see `NOTICE.md`. Upstream R packages retain their own
open-source licenses.
