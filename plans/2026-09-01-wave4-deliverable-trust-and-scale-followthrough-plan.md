---
title: "Wave 4: Deliverable Trust, Provenance Truth, and Scale Follow-Through"
date: "2026-09-01"
status: "complete — all six phases implemented and committed (6e9b2ef..35a13c5, e9e1940; 0.5.0 -> 0.6.0), with only TASK-05-08 (--full-chain benchmark) deliberately deferred to a later wave because the fixture generator cannot produce asset-level inputs"
request: "Turn research/2026-09-01-wave4-deliverable-trust-and-scale-followthrough-brainstorm.md into a multi-phase implementation plan: extend the acceptance gate to generated HTML deliverables, fix three verified provenance defects, close two invariant blind spots, restore the package export surface, and finish the deferred scale work."
plan_type: "multi-phase"
research_inputs:
  - "research/2026-09-01-wave4-deliverable-trust-and-scale-followthrough-brainstorm.md"
  - "research/2026-08-26-wave3-convergence-vintage-and-delivery-readiness-brainstorm.md"
---

# Plan: Wave 4 — Deliverable Trust, Provenance Truth, and Scale Follow-Through

## Objective

Extend this repository's acceptance gates from the numbers to the deliverables.
Today three verification layers — byte-identical CSVs, nine cross-artifact
invariants, and 552 R tests — all point at CSV outputs, while all 71 tracked
`.html` artifacts (every client-facing report, letter and disclosure pack) are
classified as ignorable by construction. Three provenance defects are currently
committed in that blind spot: an audit report attesting to a scenario vintage
the pipeline did not use, a manifest that contradicts the audit rendered from
it, and a second bank's financed-emissions inventory stamped with the first
bank's identifier. This plan closes the blind spot, fixes the three defects,
makes two invariants self-maintaining, restores the `pactatrisk` export surface,
and completes the loanbook-scale measurement that Wave 3 started but did not
finish.

## Context Snapshot

- **Current state:** Version `0.5.0`. Two engagements (`mcb-demo`,
  `sdb-rehearsal`) run through one declarative orchestrator
  (`scripts/run_engagement.R` + `R/step_registry.R`), 16 steps for MCB and 15
  for SDB. `Rscript -e "testthat::test_dir('tests/testthat')"` reports
  `FAIL 0 | WARN 5 | SKIP 1 | PASS 552`; `python -m pytest dashboard/tests`
  reports `63 passed`; `Rscript tools/verify_refactor.R --invariants` prints
  `INVARIANTS PASS` for INV-001 through INV-009. `git status` is clean at commit
  `503743f`.
- **Desired state:** A changed `.html` deliverable is classified as genuine
  drift unless its only difference is a generated timestamp; the synthetic-data
  disclaimer is enforced by an invariant rather than by discipline; the refresh
  audit and pipeline manifest derive every path and checksum from the
  engagement config; no analytic hardcodes a bank slug or a sector list;
  `library(pactatrisk)` exposes the 20 Wave 3 functions it currently hides; and
  `docs/scale_benchmark.md` reports fuzzy-match and full-chain timings rather
  than intake only.
- **Key repo surfaces:** `tools/verify_refactor.R`;
  `scripts/generate_refresh_audit.R`; `scripts/run_engagement.R`;
  `R/step_runner.R`; `R/step_registry.R`; `R/financed_emissions.R`;
  `R/target_setting.R`; `R/report_toolkit.R`; `R/engagement_config.R`;
  `scripts/intake_validate_and_map.R`; `scripts/generate_financed_emissions.R`;
  `scripts/refresh_dashboard_data.R`; `dashboard/lib/loaders.py`; `NAMESPACE`;
  `man/`; `engagements/sdb-rehearsal/engagement_config.json`;
  `tools/benchmark_scale.R`; `docs/scale_benchmark.md`; `.github/workflows/ci.yml`.
- **Out of scope:** The ABCD sourcing decision (`docs/abcd_sourcing_decision.md`)
  stays open — it is a procurement decision. Multi-engagement viewing inside the
  Streamlit dashboard (the app reads only `dashboard/data`). Full narrative
  translation into Vietnamese (labels and disclaimers only). Refactoring
  `R/pacta_core.R` or `R/trisk_core.R` for their own sake. Consolidating the 12
  report generators' duplicated CSS into a shared shell — deliberately deferred
  until PHASE-01 makes such a refactor verifiable. Optimizing
  `r2dii.match::match_name()` — this plan measures it (PHASE-05) but does not
  change it.

## Environment & Conventions

- **Stack:** R 4.5 for the entire analytical pipeline (no Node, no npm). Python
  3.12 for the Streamlit dashboard. R dependencies pinned in `renv.lock`; Python
  dependencies pinned in `dashboard/requirements.lock`. The R code is also
  structured as a loadable package named `pactatrisk` (`DESCRIPTION`,
  `NAMESPACE`, `man/`), currently version `0.5.0`.
- **Setup:**
  - R: `Rscript -e "renv::restore()"`, or the no-renv fallback
    `Rscript scripts/ci/install_deps.R`.
  - Python: `python -m pip install -r dashboard/requirements.lock`.
  - On Windows, `Rscript.exe` lives at
    `C:\Program Files\R\R-4.5.2\bin\Rscript.exe`. Add it to `PATH` for the
    session before running anything that shells out to `Rscript` — the
    orchestrator uses `system2("Rscript", ...)` and needs it on `PATH` even when
    the outer call used a full path:
    `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"` in PowerShell, or
    `export PATH="$PATH:/c/Program Files/R/R-4.5.2/bin"` in Git Bash. On Linux
    and macOS use plain `Rscript`.
- **Build / Run:**
  - Public MCB demo refresh: `Rscript scripts/pipeline_refresh.R` (a thin
    wrapper delegating to `run_engagement.R` with
    `engagements/mcb-demo/engagement_config.json`).
  - Any engagement:
    `Rscript scripts/run_engagement.R --config engagements/<slug>/engagement_config.json`
    Add `--dry-run` to print the resolved step list without executing or writing.
  - Dashboard: `python -m streamlit run dashboard/app.py`.
- **Test:**
  - Full R suite: `Rscript -e "testthat::test_dir('tests/testthat')"` — expected
    at the start of this plan: `FAIL 0 | WARN 5 | SKIP 1 | PASS 552`. The 5
    warnings are `package 'X' was built under R version 4.5.3` environment
    warnings, not test failures.
  - Wrapper that also lists environment-gated tests it skipped:
    `Rscript tools/run_tests.R`.
  - Single R test file:
    `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`.
  - The one skipped test regenerates the second engagement and is opt-in:
    `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`.
  - Full Python suite: `python -m pytest dashboard/tests` — expected `63 passed`.
  - Single Python test: `python -m pytest dashboard/tests/test_loaders.py -v`.
  - Byte-identity acceptance: `Rscript tools/verify_refactor.R` — re-runs the
    MCB pipeline, then classifies every changed tracked file; prints
    `BYTE-IDENTITY PASS` and exits 0 only when nothing classifies as drift. Add
    `--skip-refresh` to classify the current working tree without re-running.
  - Cross-artifact invariants: `Rscript tools/verify_refactor.R --invariants` —
    read-only; prints `INVARIANTS PASS` and exits 0 only when every INV holds.
- **Conventions & traps:**
  - **Always run R commands from the repository root.** Every script resolves
    paths via `getwd()`; `tests/testthat/helper-root.R`'s `project_root()` walks
    upward looking for a `dashboard/` directory.
  - **Money is whole Vietnamese Dong (VND) and is never rescaled.** Loan
    exposures (`loan_size_outstanding`, `exposure_vnd`) span raw magnitudes 1e5
    to 5e12. Never divide or multiply except where existing code already does so
    for display. Display formatting goes through `R/format_money.R`.
  - **Vietnamese counterparty names are matched after ASCII normalization.** Use
    `normalize_vn_name()` from `R/matching_helpers.R`, which wraps
    `stringi::stri_trans_general(x, "Latin-ASCII")`. CSVs are UTF-8 with no BOM.
  - **Byte-identity is verified with `git diff`, never with raw `md5sum` on
    working-tree files.** Git applies `core.autocrlf` normalization, so a file
    that is byte-identical after normalization can have a different raw digest
    across Windows and Linux. `tools/verify_refactor.R` is the canonical
    implementation — extend it rather than hand-rolling a comparison.
  - **The engagement-config convention.** Scripts source `R/engagement_config.R`
    and call `cfg <- load_engagement_config(get_config_arg())`. Passing no
    `--config` flag yields the built-in Mekong Commercial Bank defaults. Never
    hardcode a new path outside this mechanism.
  - **Config validation rejects unknown keys.** `.merge_config_lists()` copies
    any key from a JSON override into the merged config, so
    `R/engagement_config.R` performs strict unknown-key rejection. **Any new
    config key added by this plan must be registered in
    `.default_engagement_config()` or every config using it fails validation.**
  - **`jsonlite` empty-value round-trip trap.** An optional config field written
    with `jsonlite::toJSON(..., auto_unbox = TRUE)` and read back with
    `jsonlite::read_json(..., simplifyVector = TRUE)` comes back as an empty
    `list()` whether it started as `NULL` or as `character(0)`. Always test "not
    configured" with `length(x) == 0`, never with `is.null(x)` or
    `is.character(x)`.
  - **No casual new dependencies.** The analysis stack is pinned in `renv.lock`;
    `yaml` was deliberately rejected in favour of JSON via `jsonlite`. Every task
    in this plan is implementable with the currently pinned packages.
  - **Windows PowerShell 5.1 has no `&&` chaining.** Use separate commands or
    `;` sequencing. Prefer the portable `Rscript -e "..."` one-liners used
    throughout this repository.
  - **`attic/` is retired reference code** — never sourced by any pipeline,
    never tested, and modified only to receive newly retired scripts.
  - **`dashboard/data/` is the frozen public snapshot**; only
    `scripts/refresh_dashboard_data.R` may write it, and only an engagement with
    `public_snapshot_allowed: true` may publish there.
  - **Every generated artifact must carry a disclaimer stating the data is
    synthetic and illustrative.** This is non-negotiable. PHASE-01 converts it
    from a convention into an enforced invariant.
  - **Changelog entries must not quote test counts.** `NEWS.md` is prose, and a
    hand-typed pass count silently goes stale. Write "full R suite green
    (FAIL 0)" rather than a specific PASS number.
- **Repo map:**
  ```
  R/                    shared modules sourced by scripts/ (engagement_config,
                        step_registry, step_runner, pacta_core, trisk_core,
                        severity_scoring, prioritization_core, report_toolkit,
                        financed_emissions, target_setting, sll_readiness,
                        run_history, format_money, matching_helpers,
                        sector_registry)
  scripts/              pipeline stages, report generators, run_engagement.R
                        orchestrator, pipeline_refresh.R wrapper
  tools/                verify_refactor.R (byte-identity + invariants gates),
                        run_tests.R, benchmark_scale.R, generate_scale_fixture.R,
                        render_pdf.R
  data/                 synthetic input CSVs; data/scenarios/<vintage>/ holds
                        the scenario pathway files (pdp8-2023,
                        pdp8-2025-adjusted)
  synthesis_output/     PACTA, TRISK and prioritization outputs
  output/               engagement scoring, letters, disclosure, financed
                        emissions, TRISK inputs
  history/              append-only per-run result snapshots (run_history)
  engagements/<slug>/   per-engagement config and committed regression fixtures
  dashboard/            Streamlit app (app.py, pages/, lib/, tests/) and its
                        frozen snapshot dashboard/data/
  intake/               "Bring Your Own Loanbook" schema contract and templates
  templates/            engagement letter, disclosure, and i18n label tables
  workshop/             facilitation kit (README.md, actions_log_template.csv)
  tests/testthat/       R test suite
  docs/                 methodology guides, deployment notes, assumption registers
  ```

## Research Inputs

- From `research/2026-09-01-wave4-deliverable-trust-and-scale-followthrough-brainstorm.md`:
  - `classify_path()` at `tools/verify_refactor.R:48-56` returns
    `"timestamp-class"` for **every** file whose extension is `.html`, so the
    byte-identity gate never inspects a report's contents. `git ls-files
    "*.html" | wc -l` returns 71. No test in either suite asserts the content of
    any generated report.
  - `scripts/generate_refresh_audit.R:31-35` hardcodes
    `data/scenarios/pdp8-2023/vietnam_scenario_ms.csv` and
    `...vietnam_scenario_co2.csv` in its `input_files` vector, while
    `engagements/mcb-demo/engagement_config.json` has pointed at
    `data/scenarios/pdp8-2025-adjusted/` since Wave 3. The recorded checksums
    `1827b2776aa0df5f50b72ff866d54665` and `ce806a7c4cdfa4d835ff925759ab695e`
    match the **pdp8-2023** files exactly, confirming the audit attests to
    inputs the run never read. The script also takes no `--config` at all — it
    is the only step whose `args_fn` in `R/step_registry.R` returns
    `character()` — and additionally hardcodes `dashboard/data/` and
    `data/vietnam_loanbook.csv`.
  - `reports/pipeline_refresh_audit.html` renders
    `engagement_scoring  failed  2.7s`, while the
    `dashboard/data/pipeline_manifest.json` committed in the same commit reports
    `"status": "ok"` for all 16 steps and `"seconds": 1` for every one of them.
    Comparable steps take 4.7–28.8 s in
    `engagements/sdb-rehearsal/pipeline_manifest.json` and took 12.7/16.1/11.5 s
    in the MCB manifest at the previous commit. Neither file is gate-visible:
    `.html` is ignored, and `pipeline_manifest.json` is listed in
    `TIMESTAMP_BASENAMES` at `tools/verify_refactor.R:37-41`.
  - `scripts/run_engagement.R:193` calls `write_pipeline_manifest(step_results, ...)`
    unconditionally after a possibly-filtered run, so `--only-step` or
    `--resume-from` overwrites the full-run manifest with only the executed
    steps and marks it in no way. This is the most likely mechanism behind the
    contradiction above.
  - `R/financed_emissions.R:115` hardcodes `data_source = "mcb-demo"`. The
    committed
    `engagements/sdb-rehearsal/output/financed_emissions/financed_emissions.csv`
    carries `"mcb-demo"` on every row. INV-003
    (`tools/verify_refactor.R:248-272`) exists to catch exactly this but only
    ever opens `engagement_priority.csv`.
  - `R/target_setting.R:73` and `scripts/generate_financed_emissions.R:55` both
    hardcode `c("power", "cement", "steel")` outside the four sites INV-004
    watches, so adding a fourth sector would silently yield a three-sector
    target registry and emissions inventory.
  - Twenty functions carry a roxygen `#' @export` and appear in no `NAMESPACE`
    entry — every Wave 3 module without exception — and `man/` holds no Wave 3
    topic. `pacta_market_share` is exported in `NAMESPACE` with no matching
    `@export`. `ci.yml` checks the package with `devtools::load_all('.')`, which
    loads every function in `R/` regardless of `NAMESPACE` and therefore cannot
    fail this way.
  - `R/target_setting.R` and the i18n engine in `R/report_toolkit.R`
    (`report_label()`, `load_report_labels()`, called from eight generators)
    have no test file. Their sibling specs do: financed emissions has
    `test_financed_emissions.R`, SLL readiness has `test_sll_readiness.R`.
  - `docs/scale_benchmark.csv` has `match_seconds` = `NA` for all 8 cells; the
    full PACTA + TRISK chain and memory usage were never measured. Intake was
    measured at 3.8 s (1,000 loans), 18.0–19.6 s (10,000) and 101.6–230.3 s
    (50,000), with the cause named as three row-wise passes at
    `scripts/intake_validate_and_map.R:196, 253, 285`.
  - Two suspected latent bugs were tested under R 4.5.2 and **do not
    reproduce**: `attribution_factor()` with an `NA` `capital_vnd` returns `NA`
    cleanly, and `sda_convergence_target()` with a zero-length
    `baseline_value` returns `NA` cleanly. Do not "fix" either.
- From `research/2026-08-26-wave3-convergence-vintage-and-delivery-readiness-brainstorm.md`:
  - Wave 3's `ALT-005` rejected optimizing the intake validator as "speculative
    — PHASE-04 measures first." PHASE-04 has now measured and names that exact
    code, so the stated precondition for this optimization has been satisfied.
  - Wave 3's `ALT-002` established that formatting work should follow, not
    precede, the content changes it formats. The same logic orders this plan:
    the deliverable gate lands before the provenance fixes it must verify.

## Assumptions and Constraints

- **ASM-001:** Wave 3 is complete and its plan file is marked `status: complete`.
  This plan is new work, not a continuation. Verified by green suites, passing
  invariants, and a clean tree at commit `503743f`.
- **ASM-002:** The exact invocation that produced the uniform 1-second MCB
  manifest is undetermined. — **BINDING DEFAULT:** do not investigate the
  historical incident. Fix the mechanism (PHASE-02: partial-run marking and
  manifest plausibility invariants) and let the first full pipeline refresh
  overwrite the anomalous manifest naturally.
- **ASM-003:** Which HTML files should the deliverable gate cover? —
  **BINDING DEFAULT:** exactly the files regenerated by a pipeline run, listed
  explicitly in a new `GATED_HTML_PATHS` constant (PHASE-01, TASK-01-02). The
  40-plus historical build reports under `reports/` dated 2026-04 to 2026-08 are
  static, never regenerated, and are **excluded** — they would otherwise fail
  the timestamp-normalization comparison for no benefit.
- **ASM-004:** How should HTML be compared, given embedded base64 PNGs? —
  **BINDING DEFAULT:** normalize (strip generated timestamps, git SHAs, and
  CRLF), then MD5 the result, and compare the working-tree file against its
  committed `HEAD` blob via `git show`. Do not attempt full-byte HTML identity;
  do not attempt to diff base64 image payloads.
- **ASM-005:** Fixing `data_source` (PHASE-03) changes the committed
  `engagements/sdb-rehearsal/output/financed_emissions/financed_emissions.csv`.
  — **BINDING DEFAULT:** treat this as a scoped fixture refreeze, not a golden
  refreeze. `data_source` feeds no score, no ranking and no composite. Do **not**
  re-pin `tests/testthat/test_golden_numbers.R` and do **not** bump the golden
  numbers; regenerate only the SDB engagement.
- **ASM-006:** Does any task in this plan change a golden number? —
  **BINDING DEFAULT:** no. If any change causes
  `tests/testthat/test_golden_numbers.R` to fail, stop and treat it as a defect
  in the change, not as a signal to re-pin the goldens.
- **ASM-007:** What target should the intake vectorization (PHASE-05) hit? —
  **BINDING DEFAULT:** at least a 3× reduction in wall-clock intake time at the
  50,000-loan × 1,000-counterparty cell (from the measured 230.3 s), with
  byte-identical `normalized_loanbook.csv`, `validation_errors.csv` and
  `validation_warnings.csv` for the SDB fixture. If byte-identity cannot be
  preserved, revert the optimization rather than re-pinning the fixture.
- **ASM-008:** Which R version runs CI? — **BINDING DEFAULT:** `4.5`, as pinned
  in `.github/workflows/ci.yml`'s `r-lib/actions/setup-r@v2` step. Local
  development on 4.5.2 or 4.5.3 is expected; the 5 build-version warnings in the
  suite are environmental and must not be "fixed".
- **CON-001:** No new R or Python package may be added. Every task is
  implementable with `renv.lock`'s pinned set (`jsonlite`, `dplyr`, `readr`,
  `stringi`, `tibble`, `tools`, `digest` via `tools::md5sum`) and the dashboard's
  existing `pandas`/`streamlit`.
- **CON-002:** `dashboard/data/` may only be written by
  `scripts/refresh_dashboard_data.R`. PHASE-06's new snapshot CSVs must be
  copied there by that script, not by any other.
- **CON-003:** Every generated artifact must continue to carry its
  synthetic-data disclaimer. PHASE-01 makes this a gate; no later phase may
  weaken it.
- **DEC-001:** Gate HTML by normalized content, not byte-identity. Reports embed
  base64 PNGs and a generated timestamp, so full-file hashing would be brittle.
  Strip the known timestamp spans, hash the remainder, and additionally pin a
  small set of content assertions per deliverable.
- **DEC-002:** Fix `data_source` as a scoped fixture refreeze (see ASM-005), not
  a golden refreeze. Batching a client-facing mislabelling behind a full golden
  refreeze delays it for no benefit.
- **DEC-003:** Make INV-004 self-maintaining with a source-scan rather than
  registering two more sites by hand. Registering fixes today's instance and
  leaves tomorrow's to memory.
- **DEC-004:** Vectorize the intake validator; do not touch
  `r2dii.match::match_name()` in this plan. Intake is measured, named and
  covered by a regenerating CI fixture. Fuzzy matching is unmeasured — measure
  it here, decide later.
- **DEC-005:** Bring `sdb-rehearsal` to feature parity rather than adding a
  third engagement. A third engagement multiplies fixtures; parity costs four
  config keys and makes the existing CI job mean what it appears to mean.
- **DEC-006:** Regenerate `NAMESPACE` with roxygen2 and add a freshness check to
  CI, rather than hand-editing `NAMESPACE`. The file's first line says
  "Generated by roxygen2: do not edit by hand."

## Specification

### S1 — HTML report normalization (PHASE-01)

`normalize_report_html(html)` applies the following substitutions, in this
order, to a single character string holding a complete HTML document. Each
pattern corresponds to a timestamp format actually emitted by a generator in
this repository; the literal format string and its source are given so the
executor can confirm coverage.

| # | Emitted by | R format string | Regex to replace | Replacement |
|---|---|---|---|---|
| 1 | `scripts/generate_engagement_letters.R:73` | `%Y-%m-%d %H:%M:%S` | `[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}` | `<TIMESTAMP>` |
| 2 | `scripts/generate_validation_report.R:71`, `scripts/generate_coverage_report.R:268`, `scripts/generate_wave3_summary.R:23` | `%Y-%m-%d %H:%M %Z` | `[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}( [A-Za-z+0-9:]+)?` | `<TIMESTAMP>` |
| 3 | manifest `generated_at`, rendered by `scripts/generate_refresh_audit.R` | `%Y-%m-%dT%H:%M:%S%z` | `[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4}` | `<TIMESTAMP>` |
| 4 | `scripts/generate_disclosure_pack.R:63`, `scripts/generate_engagement_letters.R:74` | `%d %B %Y` | `[0-9]{1,2} (January\|February\|March\|April\|May\|June\|July\|August\|September\|October\|November\|December) [0-9]{4}` | `<DATE>` |
| 5 | `R/pacta_core.R:905`, `scripts/generate_bidv_report.R:50` | `%B %d, %Y` | `(January\|February\|March\|April\|May\|June\|July\|August\|September\|October\|November\|December) [0-9]{1,2}, [0-9]{4}` | `<DATE>` |
| 6 | manifest `git_sha`, rendered by the refresh audit | — | `\b[0-9a-f]{7,40}\b` | `<SHA>` |
| 7 | line endings | — | `\r\n` | `\n` |

Apply pattern 3 **before** patterns 1 and 2, because an ISO-8601 timestamp with
an offset also matches the looser patterns. Apply pattern 7 last is acceptable;
applying it first is also acceptable — but it must be applied, because Windows
working-tree files may carry CRLF while `git show` returns LF.

Note that `scripts/generate_financed_emissions.R`, `scripts/sll_readiness.R`,
`scripts/generate_targets.R` and `scripts/generate_history_diff.R` emit **no**
timestamp at all, so their reports are already fully deterministic and will
compare equal without any normalization applying.

### S2 — HTML drift classification (PHASE-01)

Replacing the current unconditional `.html` → `"timestamp-class"` rule at
`tools/verify_refactor.R:54`:

1. If the file's extension is not `html`, fall through to the existing logic
   unchanged.
2. If the repo-relative path is **not** in `GATED_HTML_PATHS`, return
   `"timestamp-class"` (preserves today's behaviour for the ~60 static
   historical reports).
3. Otherwise, read the working-tree file. If it cannot be read, return
   `"drift"`.
4. Retrieve the committed version with
   `system2("git", c("show", paste0("HEAD:", path)), stdout = TRUE)`. If the
   path does not exist at `HEAD` (a newly created report), return
   `"timestamp-class"` — a new file is an addition, not drift.
5. Apply `normalize_report_html()` (S1) to both strings, collapse each to a
   single string, and compare `tools::md5sum`-equivalent digests of the two.
6. Equal → `"timestamp-class"`. Unequal → `"drift"`.

### S3 — Manifest plausibility (PHASE-02, INV-011)

A `pipeline_manifest.json` is implausible, and INV-011 fails, when **all** of
the following hold:

1. `partial` is absent or `false` (a partial run is exempt),
2. the manifest lists 3 or more steps, and
3. every step's `seconds` value is identical.

Rationale: a genuine multi-step run of this pipeline cannot produce identical
wall-clock durations for every step. Two or fewer steps is not enough evidence.
This check is deliberately weak — it catches the fabricated/degenerate case
without asserting any specific timing, which would be machine-dependent.

### S4 — Vintage attestation (PHASE-02, INV-010)

For every `engagements/*/engagement_config.json` with a readable
`inputs.scenario_vintage`:

1. Determine the engagement's metrics file. For an engagement with
   `public_snapshot_allowed: true`, this is
   `<paths.reports_dir>/refresh_audit_metrics.json`; otherwise the invariant
   skips the engagement (only the public engagement runs the refresh audit).
2. If that file does not exist, skip (the audit is optional).
3. Read its `scenario_ms_checksum` and `scenario_co2_checksum`.
4. Compute `tools::md5sum()` of the config's own
   `inputs.scenario_ms_csv` and `inputs.scenario_co2_csv`.
5. Both must match. A mismatch reports the expected path, the recorded digest,
   and the computed digest.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Make generated HTML deliverables a gated artifact class and enforce the synthetic-data disclaimer | None | `R/report_fingerprint.R`, reworked `classify_path()`, INV-010 disclaimer invariant, `tests/testthat/test_report_fingerprint.R` |
| PHASE-02 | Make the provenance chain derive from the engagement config and refuse to lie | PHASE-01 | `--config`-aware `scripts/generate_refresh_audit.R`, `partial` manifest marking, INV-011 + INV-012, corrected audit checksums |
| PHASE-03 | Remove hardcoded provenance and sector lists, and widen the invariants that should have caught them | PHASE-02 | `data_source` threaded through `financed_emissions()`, INV-003 widened, INV-004 made self-maintaining, regenerated SDB fixture |
| PHASE-04 | Restore the package export surface and test the two untested Wave 3 modules | PHASE-03 | Regenerated `NAMESPACE` + `man/`, CI freshness check, `test_target_setting.R`, `test_report_toolkit.R` |
| PHASE-05 | Finish the scale measurement Wave 3 started, and act on what it already found | PHASE-04 | Vectorized intake validator, `match_name()` and full-chain timings, updated `docs/scale_benchmark.md` |
| PHASE-06 | Bring the second engagement to parity, surface Wave 3 analytics as data, reconcile the docs | PHASE-05 | SDB config parity, dashboard loaders + page, corrected `CLAUDE.md`/`PROGRESS.md`/`README.md`, `NEWS.md` 0.6.0 |

## Detailed Phases

### PHASE-01 - Gate the Deliverables

**Goal**
Convert generated HTML from an ignored file class into a checked one, and turn
the synthetic-data disclaimer from a written convention into an automated
invariant. Nothing else in the repository changes behaviour in this phase; it is
purely additive verification, and it must be able to pass on the tree exactly as
it stands today.

**Tasks**
- [x] TASK-01-01: Create `R/report_fingerprint.R` implementing `normalize_report_html()`
      and `report_fingerprint()` exactly as specified in S1. Use only base R plus
      `tools` (`gsub`, `readLines`, `paste`, `tools::md5sum` on a tempfile, or
      `digest` only if already loaded — prefer writing the normalized string to
      a `tempfile()` and calling `tools::md5sum()` on it, since `digest` is not
      in `renv.lock`). Add roxygen `#' @export` blocks to both functions.
- [x] TASK-01-02: In `tools/verify_refactor.R`, add a `GATED_HTML_PATHS`
      character constant immediately after `TIMESTAMP_BASENAMES` (currently
      line 37), listing exactly the repo-relative HTML paths regenerated by a
      pipeline run. Populate it with, and only with:
      `reports/PACTA_Vietnam_Bank_Report.html`,
      `reports/PACTA_Synthesis_Report.html`,
      `reports/Financed_Emissions.html`,
      `reports/SLL_Readiness_Shortlist.html`,
      `reports/Sector_Target_Registry.html`,
      `reports/BIDV_Framework_Recommendation_Report.html`,
      `reports/pipeline_refresh_audit.html`,
      `output/disclosure/disclosure_pack.html`,
      `output/engagement_letters/index.html`.
      Add a comment stating that the historical build reports under `reports/`
      dated 2026-04 to 2026-08 are deliberately excluded because they are static
      and never regenerated.
- [x] TASK-01-03: Rework `classify_path()` in `tools/verify_refactor.R` (line 48)
      to implement S2. Keep the `png` branch, the `TIMESTAMP_BASENAMES` branch,
      the `volatile_basenames` branch and the `history/` branch exactly as they
      are. Change only the `.html` handling. `classify_path()` gains two new
      arguments with defaults so every existing caller and test keeps working:
      `gated_html_paths = GATED_HTML_PATHS` and `root = "."`.
- [x] TASK-01-04: Add `inv_deliverables_carry_disclaimer()` to
      `tools/verify_refactor.R` as **INV-010**. For every path in
      `GATED_HTML_PATHS` that exists on disk, read it and assert it contains the
      case-insensitive substring `synthetic`. Report every failing path. A path
      that does not exist is skipped, not failed (an engagement may not have run
      every step).
- [x] TASK-01-05: Register `inv_deliverables_carry_disclaimer(root)` in the
      `results` list inside `run_invariants()` (currently at
      `tools/verify_refactor.R:569`), appended after
      `inv_scenario_vintage_declared(root)`. Update the two header comments that
      say `INV-001..009` (lines 22 and 73) to read `INV-001..010`.
- [x] TASK-01-06: Create `tests/testthat/test_report_fingerprint.R` covering
      `normalize_report_html()`, `report_fingerprint()` and the new
      `classify_path()` HTML branch, per **Test Specs** below. Follow the
      existing style in `tests/testthat/test_verify_invariants.R`: `library(testthat)`,
      `root <- project_root()`, `source(file.path(root, "tools", "verify_refactor.R"))`,
      and build fixtures under `tempdir()` rather than against the live tree.
- [x] TASK-01-07: Add a `Cross-artifact invariants` assertion to the
      documentation in `README.md` where it currently describes the invariant
      count, and to `CLAUDE.md` law 5, noting that gated HTML deliverables are
      now compared after timestamp normalization rather than ignored. Do not
      change any other text in either file in this phase.

**File Changes**
- `R/report_fingerprint.R` (create): the two functions in S1 plus roxygen. No
  other module sources it yet; `tools/verify_refactor.R` will `source()` it.
- `tools/verify_refactor.R` (modify): add `GATED_HTML_PATHS` after
  `TIMESTAMP_BASENAMES`; `source()` `R/report_fingerprint.R` near the top
  (guarded with `file.exists()` so the script still runs from an incomplete
  checkout); rework the `.html` branch of `classify_path()`; add
  `inv_deliverables_carry_disclaimer()`; register it in `run_invariants()`;
  update the two `INV-001..009` header comments. **Leave alone:** the `png`,
  `TIMESTAMP_BASENAMES`, `volatile` and `history/` branches; every existing
  `inv_*()` function; `run_refresh()`; `changed_paths()`; `main()`.
- `tests/testthat/test_report_fingerprint.R` (create): tests per Test Specs.
- `README.md` (modify): update the invariant description only.
- `CLAUDE.md` (modify): law 5's sentence about HTML reports only.

**Function Signatures**
- `normalize_report_html(html: character) -> character` — the input string with
  every timestamp, date and git-SHA span replaced by a fixed placeholder and
  CRLF normalized to LF, per S1. Accepts a length-1 or length-n character
  vector; returns the same length.
- `report_fingerprint(path: character) -> character` — the lowercase MD5 hex
  digest of the file's normalized content, or `NA_character_` when the file does
  not exist.
- `classify_path(path: character, volatile_basenames: character = VOLATILE_BASENAMES, gated_html_paths: character = GATED_HTML_PATHS, root: character = ".") -> character` —
  one of `"png-noise"`, `"timestamp-class"`, `"volatile"`, `"drift"`.
- `inv_deliverables_carry_disclaimer(root: character, gated_html_paths: character = GATED_HTML_PATHS) -> list` —
  `list(id = "INV-010", ok = logical(1), detail = character())`, where `detail`
  names every gated HTML file that exists but lacks the word "synthetic".

**Test Specs**
- `normalize_report_html("Generated: 2026-08-27 16:29 +07")` →
  `"Generated: <TIMESTAMP>"`.
- `normalize_report_html("Generated 2026-08-27T16:19:03+0700")` →
  `"Generated <TIMESTAMP>"` (pattern 3 must win over patterns 1 and 2).
- `normalize_report_html("<p>27 August 2026</p>")` → `"<p><DATE></p>"`.
- `normalize_report_html("<p>August 27, 2026</p>")` → `"<p><DATE></p>"`.
- `normalize_report_html("Commit: f69ceca9c347804e0b511f7ddbf9d3cfee64c831")` →
  `"Commit: <SHA>"`.
- `normalize_report_html("a\r\nb")` → `"a\nb"`.
- Two strings differing **only** in their timestamp produce equal
  `normalize_report_html()` output; two strings differing in a numeric table
  cell (e.g. `"<td>0.9816</td>"` vs `"<td>0.8100</td>"`) produce different
  output.
- `report_fingerprint("<a path that does not exist>")` → `NA_character_`.
- `classify_path("reports/2026-04-16-trisk-power-pilot.html")` →
  `"timestamp-class"` (not in `GATED_HTML_PATHS`, so ungated as before).
- `classify_path("dashboard/data/pacta/04_vn_ms_portfolio.csv")` → `"drift"`
  (unchanged behaviour for CSVs).
- `classify_path("dashboard/data/trisk/power/chart.png")` → `"png-noise"`
  (unchanged).
- `classify_path("history/mcb-demo/x/manifest.json")` → `"timestamp-class"`
  (unchanged).
- In a `tempdir()` git fixture: commit a gated HTML file, then edit only its
  timestamp → `classify_path()` returns `"timestamp-class"`; edit a numeric
  value in a table cell → returns `"drift"`.
- A gated HTML path that exists at `HEAD` nowhere (newly created) →
  `"timestamp-class"`.
- `inv_deliverables_carry_disclaimer()` against a fixture root where one gated
  file contains "Synthetic data — illustrative only" and another contains no
  such word → `ok = FALSE`, `detail` naming exactly the second file.
- `inv_deliverables_carry_disclaimer()` against the **live repo root** →
  `ok = TRUE` (all eight published reports plus the letters index and disclosure
  pack currently contain the word).

**Dependencies**
- None. This phase is additive and must pass against the tree as it stands.

**Exit Criteria**
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0` with a
      PASS count strictly greater than 552.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS`
      and lists `[PASS] INV-010` among its output lines.
- [ ] `Rscript tools/verify_refactor.R --skip-refresh` exits 0 on the unmodified
      working tree (the new HTML branch must not report drift where none exists).
- [ ] `python -m pytest dashboard/tests` still reports `63 passed`.

**Execution notes (Wave 4, recorded during implementation)**
- ASM-003's nine gated paths became **seven**. `output/disclosure/disclosure_pack.html`
  and `output/engagement_letters/index.html` are gitignored (`.gitignore:21` and
  `:23`), so they never appear in `git diff --name-only` and can never be
  compared against a HEAD blob. They moved to a new `DISCLAIMER_HTML_PATHS`
  superset, which INV-010 uses; `GATED_HTML_PATHS` now holds only tracked files.
- INV-010 failed on its first run against the live tree, correctly:
  `reports/pipeline_refresh_audit.html` carried **no** synthetic-data
  disclaimer, and `scripts/generate_refresh_audit.R` emitted none. A bilingual
  disclaimer footer was added to that generator and the report regenerated.
  This was a pre-existing violation of the CLAUDE.md disclaimer law that no
  gate could see before this phase.
- `.html_is_timestamp_only()` must capture `git show` to a **file**, not through
  `system2(stdout = TRUE)`. An R pipe splits the reports' embedded base64 image
  payloads at a buffer boundary (600 lines on disk vs 609 from the pipe), which
  made untouched reports read as drift. Covered by a regression test.

**Phase Risks**
- **RISK-01-01:** The normalization may miss a timestamp format and cause a
  false `drift` on an untouched report. Mitigation: TASK-01-01's format table is
  derived from an exhaustive grep of `format(Sys.time()` and `format(Sys.Date()`
  across `R/` and `scripts/`; re-run
  `grep -rn 'format(Sys.time()\|format(Sys.Date()' R/ scripts/` before
  implementing and extend S1 if the grep finds a format not in the table.
- **RISK-01-02:** `git show HEAD:<path>` fails inside a worktree with no commits
  or a detached state, producing spurious drift. Mitigation: wrap the call in
  `tryCatch()` and return `"timestamp-class"` when git cannot resolve the blob,
  matching the "new file is not drift" rule in S2 step 4.

---

### PHASE-02 - Provenance Truth

**Goal**
Make the refresh audit derive every input path from the engagement config
instead of hardcoding a scenario vintage, and make the pipeline manifest
incapable of silently presenting a filtered run as a complete one. PHASE-01's
gate will detect the resulting change to `reports/pipeline_refresh_audit.html`,
which is the intended proof that the gate works.

**Tasks**
- [x] TASK-02-01: Rewrite the top of `scripts/generate_refresh_audit.R` to follow
      the engagement-config convention. Add
      `source("R/engagement_config.R")` and
      `cfg <- load_engagement_config(get_config_arg())`. Replace the hardcoded
      `manifest_path`, `out_html` and `metrics_path` (lines 17-19) with
      `file.path(cfg$paths$snapshot_dir, "pipeline_manifest.json")`,
      `file.path(cfg$paths$reports_dir, "pipeline_refresh_audit.html")` and
      `file.path(cfg$paths$reports_dir, "refresh_audit_metrics.json")`.
- [x] TASK-02-02: Replace the hardcoded `input_files` vector at
      `scripts/generate_refresh_audit.R:31-35` with a config-derived vector:
      `c(cfg$inputs$loanbook_csv, cfg$inputs$abcd_csv, cfg$inputs$scenario_ms_csv,
      cfg$inputs$scenario_co2_csv)`. Replace the two hardcoded lookups at lines
      84-85 (`input_checksums[["data/scenarios/pdp8-2023/vietnam_scenario_ms.csv"]]`
      and the `_co2` sibling) with `input_checksums[[cfg$inputs$scenario_ms_csv]]`
      and `input_checksums[[cfg$inputs$scenario_co2_csv]]`.
- [x] TASK-02-03: Add `scenario_vintage = cfg$inputs$scenario_vintage` as a new
      field in the metrics list written to `refresh_audit_metrics.json`, and add
      it to the `fields` vector at line 138 so the run-over-run diff includes it.
- [x] TASK-02-04: Replace the hardcoded `pacta_matched_path` at
      `scripts/generate_refresh_audit.R:44` with
      `file.path(cfg$paths$snapshot_dir, "pacta", "02_vn_matched_prioritized.csv")`.
      Audit the remainder of the file for any other literal path beginning
      `dashboard/data/`, `data/` or `reports/` and route each through `cfg`.
- [x] TASK-02-05: In `R/step_registry.R`, change the `refresh_audit` entry's
      `args_fn` from `function(cfg, ctx) character()` to
      `function(cfg, ctx) c("--config", ctx$effective_config_path)`.
- [x] TASK-02-06: Add a `partial` parameter to `write_pipeline_manifest()` in
      `R/step_runner.R`. Signature becomes
      `write_pipeline_manifest(step_results, manifest_path, row_count_files = character(0), extra = list(), partial = FALSE, filters = list())`.
      Write `partial` (a scalar logical) and, when `partial` is `TRUE`, a
      `filters` object recording `only_step` and `resume_from`, into the
      manifest JSON. When `partial` is `FALSE`, still write `"partial": false`
      so the field is always present.
- [x] TASK-02-07: In `scripts/run_engagement.R`, compute
      `run_is_partial <- length(only_steps) > 0 || (!is.na(resume_from) && nzchar(resume_from))`
      and pass `partial = run_is_partial` and
      `filters = list(only_step = only_steps, resume_from = resume_from)` to the
      `write_pipeline_manifest()` call at line 193.
- [x] TASK-02-08: In `scripts/run_engagement.R`, immediately before that call,
      refuse to overwrite a complete public manifest with a partial one: when
      `run_is_partial` is `TRUE` **and** `isTRUE(cfg$public_snapshot_allowed)`
      **and** the target manifest already exists with `partial` absent or
      `false`, `stop()` with a message naming the manifest path and instructing
      the operator to re-run without `--only-step`/`--resume-from`, or to pass
      the new `--allow-partial-manifest` flag. Add that flag to the argument
      parsing and to the usage string in the file header.
- [x] TASK-02-09: Add `inv_manifest_plausible()` to `tools/verify_refactor.R` as
      **INV-011**, implementing S3. Check every
      `pipeline_manifest.json` reachable from an engagement config
      (`<paths.snapshot_dir>/pipeline_manifest.json` when
      `public_snapshot_allowed` is `true`, otherwise
      `engagements/<slug>/pipeline_manifest.json`).
- [x] TASK-02-10: Add `inv_audit_attests_configured_vintage()` to
      `tools/verify_refactor.R` as **INV-012**, implementing S4.
- [x] TASK-02-11: Register both new invariants in `run_invariants()` after
      INV-010, and update the `INV-001..010` header comments to `INV-001..012`.
- [x] TASK-02-12: Extend `tests/testthat/test_verify_invariants.R` with fixture
      tests for INV-011 and INV-012, per Test Specs.
- [x] TASK-02-13: Fix the two documentation-versus-behaviour defects in
      `R/step_runner.R`. At lines 28-33, correct the comment that claims live
      console output "via `stdout = \"\"`" — the implementation buffers to a
      tempfile and echoes after the step returns, so state that plainly. At line
      86-89, move the `"Stopping pipeline."` message inside the
      `if (stop_on_failure)` branch so `run_steps()` no longer announces a stop
      it will not make.
- [x] TASK-02-14: Regenerate the MCB pipeline once
      (`Rscript scripts/pipeline_refresh.R`) so
      `reports/pipeline_refresh_audit.html`, `reports/refresh_audit_metrics.json`
      and `dashboard/data/pipeline_manifest.json` are rewritten with correct,
      config-derived provenance. Confirm the new metrics file records the
      `pdp8-2025-adjusted` checksums
      (`7454bb5c...` for `_ms` and `f3ff478f...` for `_co2`), not the
      `pdp8-2023` ones.

**File Changes**
- `scripts/generate_refresh_audit.R` (modify): add the config source and loader;
  replace all hardcoded paths and the two hardcoded scenario-checksum lookups;
  add `scenario_vintage` to the metrics. **Leave alone:** the HTML rendering
  layout, the run-over-run diff logic, and the disclaimer text.
- `R/step_registry.R` (modify): only the `refresh_audit` entry's `args_fn`.
- `R/step_runner.R` (modify): `write_pipeline_manifest()` signature and body;
  the two comment/message defects. **Leave alone:** `count_rows()`,
  `run_step()`'s capture logic, `.merge_manifest_extra()`.
- `scripts/run_engagement.R` (modify): `--allow-partial-manifest` parsing, the
  partial computation, the guard, and the `write_pipeline_manifest()` call.
  **Leave alone:** the intake-resolution block at lines 155-181 and the
  `public_snapshot_allowed` guard rail.
- `tools/verify_refactor.R` (modify): add INV-011 and INV-012; register both;
  update header comments.
- `tests/testthat/test_verify_invariants.R` (modify): append fixture tests.
- `reports/pipeline_refresh_audit.html`, `reports/refresh_audit_metrics.json`,
  `dashboard/data/pipeline_manifest.json` (modify, regenerated): corrected
  provenance.

**Function Signatures**
- `write_pipeline_manifest(step_results: list, manifest_path: character, row_count_files: character = character(0), extra: list = list(), partial: logical = FALSE, filters: list = list()) -> character` —
  invisibly returns the manifest path written.
- `inv_manifest_plausible(root: character) -> list` —
  `list(id = "INV-011", ok, detail)`; `detail` names each manifest whose steps
  all share one `seconds` value while `partial` is not `TRUE`.
- `inv_audit_attests_configured_vintage(root: character) -> list` —
  `list(id = "INV-012", ok, detail)`; `detail` names each mismatch with expected
  path, recorded digest and computed digest.

**Test Specs**
- INV-011 fixture with a manifest of 4 steps whose `seconds` are
  `[1, 1, 1, 1]` and no `partial` field → `ok = FALSE`, detail naming the file.
- Same manifest with `"partial": true` → `ok = TRUE` (partial runs are exempt).
- Manifest with `seconds` `[1, 1]` (2 steps) → `ok = TRUE` (below the 3-step
  threshold).
- Manifest with `seconds` `[12.7, 3.4, 16.1]` → `ok = TRUE`.
- INV-012 fixture: config declaring
  `inputs.scenario_ms_csv = "data/scenarios/v2/ms.csv"` plus a metrics file
  recording the digest of a **different** file → `ok = FALSE`, detail naming the
  expected path and both digests.
- INV-012 fixture where the recorded digests match the configured files →
  `ok = TRUE`.
- INV-012 where no `refresh_audit_metrics.json` exists → `ok = TRUE` (skipped).
- `write_pipeline_manifest(list(list(name="a",status="ok",seconds=1)), tmp, partial = TRUE, filters = list(only_step = "a", resume_from = NA_character_))`
  → the written JSON contains `"partial": true` and a `filters` object naming
  `a`.
- `write_pipeline_manifest(...)` with defaults → the written JSON contains
  `"partial": false`.
- Running
  `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --only-step refresh_audit`
  against an existing complete public manifest → exits non-zero with a message
  naming `dashboard/data/pipeline_manifest.json`; adding
  `--allow-partial-manifest` → succeeds and writes `"partial": true`.

**Dependencies**
- PHASE-01 (its HTML gate is what verifies TASK-02-14's regenerated audit report
  changed only where intended).

**Exit Criteria**
- [ ] `grep -c "pdp8-2023" scripts/generate_refresh_audit.R` returns `0`.
- [ ] `python -c "import json;m=json.load(open('reports/refresh_audit_metrics.json'));print(m['scenario_ms_checksum'],m['scenario_co2_checksum'],m['scenario_vintage'])"`
      prints `7454bb5c27224d77df3da3fb97210e1d f3ff478f028dd53cbd6f2b18cd356890 pdp8-2025-adjusted`.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS`
      including `[PASS] INV-011` and `[PASS] INV-012`.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [ ] `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --dry-run`
      lists `refresh_audit` with `--config` in its argument list.

**Execution notes (Wave 4, recorded during implementation)**
- Both new invariants fired on the exact defects they were written for, before
  any fix: INV-011 on `dashboard/data/pipeline_manifest.json` ("all 16 steps
  report the same duration (1 s)"), INV-012 on the audit's `pdp8-2023`
  checksums. After the fix and a full refresh, the manifest reports 12 distinct
  durations across 16 steps and the audit records
  `7454bb5c27224d77df3da3fb97210e1d` / `f3ff478f028dd53cbd6f2b18cd356890`.
- **RISK-02-01 materialized, and the cause was pre-existing.** The refresh
  changed `synthesis_output/prioritization/sector_priority_{ranking,detail}.csv`:
  power's `stress_score_raw` moved from `4.355628082916891` to
  `4.343708488002581`. This was proven NOT to be caused by Wave 4. In a pristine
  `git worktree` at the pre-Wave-4 commit `503743f`, with entirely unmodified
  code and data, `Rscript scripts/sector_prioritization.R` produces
  `4.343708488002581` — so the committed artifact never matched the inputs it
  claims to derive from. Zero TRISK outputs changed in the refresh, confirming
  the staleness is in the prioritization artifact, not upstream.
  `composite_score` (0.9224749999999999) and `priority_band` ("Critical") are
  unchanged, because power's `stress_score` is capped at 1; the moved value is a
  raw diagnostic column only, and `test_golden_numbers.R` stays green
  (FAIL 0). The regenerated values are accepted as the correct ones.
- `record_run_history` refuses a second run on the same calendar day at the same
  commit (its run ID is `date-shortsha-vintage` and it is append-only by
  contract), so re-running the pipeline twice in one session fails at the last
  step until the stale run directory is removed. Pre-existing Wave 3 behaviour,
  not changed here.

**Phase Risks**
- **RISK-02-01:** Regenerating the MCB pipeline (TASK-02-14) may surface
  unrelated drift accumulated since the last refresh. Mitigation: run
  `Rscript tools/verify_refactor.R --skip-refresh` **before** TASK-02-14 to
  record a clean baseline, then compare. Any drift outside the three provenance
  files is a separate problem and must be investigated, not committed.
- **RISK-02-02:** `scripts/generate_refresh_audit.R` previously took no
  arguments, so any external caller (a local script, a runbook) invoking it bare
  will now silently use MCB defaults. That is the correct fallback behaviour of
  `load_engagement_config(NULL)`, so no breakage results — but note it in the
  script header so the behaviour is documented rather than incidental.

---

### PHASE-03 - Remove Hardcoded Provenance and Sector Lists

**Goal**
Stop one bank's identifier appearing on another bank's deliverable, stop two
Wave 3 modules from carrying private copies of the supported-sector list, and
widen the two invariants that were supposed to prevent both.

**Tasks**
- [x] TASK-03-01: Add a `data_source` parameter to `financed_emissions()` in
      `R/financed_emissions.R`. New signature:
      `financed_emissions(abcd, capital, loanbook_exposure, emission_factors, capacity_factors, report_year = 2025L, data_source = NA_character_)`.
      Replace the hardcoded `data_source = "mcb-demo"` at line 115 with
      `data_source = data_source`. Update the roxygen `@param` block.
- [x] TASK-03-02: In `scripts/generate_financed_emissions.R`, pass
      `data_source = cfg$bank_slug` to the `financed_emissions()` call.
- [x] TASK-03-03: In `R/target_setting.R`, replace the hardcoded
      `sectors <- c("power", "cement", "steel")` at line 73 with a call to the
      sector registry: `source`/reference `sector_registry()` and use
      `sectors <- sector_registry()$sector`. `R/target_setting.R` is sourced by
      `scripts/generate_targets.R`; add the `sector_registry.R` source there
      rather than inside the module if the module is currently sourced without
      it, matching how `tests/testthat/test_engagement_config.R:5` sources it.
- [x] TASK-03-04: In `scripts/generate_financed_emissions.R`, replace the
      hardcoded `for (sector in c("power", "cement", "steel"))` at line 55 with
      `for (sector in sector_registry()$sector)`, sourcing
      `R/sector_registry.R` at the top of the script.
- [x] TASK-03-05: Widen INV-003 (`inv_engagement_data_source()`,
      `tools/verify_refactor.R:248`) from one filename to a set. For each
      engagement config, check every one of these paths that exists:
      `<paths.engagement_output_dir>/engagement_priority.csv`,
      `<paths.engagement_output_dir>/sll_readiness.csv`,
      `<paths.engagement_output_dir>/target_registry.csv`, and
      `<paths.financed_emissions_output_dir>/financed_emissions.csv`. For each,
      if it has a `data_source` column, every value must equal the config's
      `bank_slug`. Preserve the existing behaviour for files without the column
      (skip) and for missing files (skip).
- [x] TASK-03-06: Make INV-004 self-maintaining. Add
      `.scan_hardcoded_sector_triples(root)`, which greps every `.R` file under
      `R/`, `scripts/` and `tools/` for the regex
      `c\(\s*"power"\s*,\s*"cement"\s*,\s*"steel"\s*\)` and returns the matching
      `file:line` locations, excluding an allowlist of legitimate definition
      sites: `R/sector_registry.R`, `R/engagement_config.R`, `R/trisk_core.R`,
      `scripts/new_engagement.R`. Fold the result into
      `inv_sector_lists_agree()`: any hit outside the allowlist fails INV-004
      with a detail line naming the file and line. Keep the existing
      four-source agreement check unchanged and run both.
- [x] TASK-03-07: Regenerate the SDB engagement so its financed-emissions
      fixture carries the correct provenance:
      `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json`.
- [x] TASK-03-08: Add a test to `tests/testthat/test_financed_emissions.R`
      asserting that `financed_emissions()` propagates its `data_source`
      argument, and a test to `tests/testthat/test_verify_invariants.R` for the
      widened INV-003 and the new INV-004 scan.

**File Changes**
- `R/financed_emissions.R` (modify): the `financed_emissions()` signature, the
  `common` list at line 115, and the roxygen block. **Leave alone:**
  `attribution_factor()`, `borrower_emissions_power()`,
  `borrower_emissions_intensity()`, `pcaf_data_quality_score()`,
  `data_quality_summary()`, `carbon_cost_exposure()`, and
  `SCOPE_3_DOMINANT_SECTORS`. In particular do **not** "fix"
  `attribution_factor()`'s `NA` handling — it was tested and behaves correctly.
- `scripts/generate_financed_emissions.R` (modify): source
  `R/sector_registry.R`; pass `data_source = cfg$bank_slug`; replace the
  hardcoded sector loop.
- `R/target_setting.R` (modify): line 73 only. **Leave alone:**
  `sda_convergence_target()`, which was tested and behaves correctly on
  zero-length and `NA` inputs.
- `scripts/generate_targets.R` (modify): source `R/sector_registry.R` if not
  already sourced.
- `tools/verify_refactor.R` (modify): widen `inv_engagement_data_source()`; add
  `.scan_hardcoded_sector_triples()` and fold it into
  `inv_sector_lists_agree()`.
- `engagements/sdb-rehearsal/output/financed_emissions/financed_emissions.csv`
  (modify, regenerated): `data_source` becomes `sdb-rehearsal` on every row.
- `tests/testthat/test_financed_emissions.R` (modify): add the propagation test.
- `tests/testthat/test_verify_invariants.R` (modify): add INV-003/INV-004 tests.

**Function Signatures**
- `financed_emissions(abcd: data.frame, capital: data.frame, loanbook_exposure: data.frame, emission_factors: data.frame, capacity_factors: data.frame, report_year: integer = 2025L, data_source: character = NA_character_) -> data.frame` —
  one row per borrower with the 11 existing columns, `data_source` now taking
  the caller's value.
- `.scan_hardcoded_sector_triples(root: character, allowlist: character) -> character` —
  zero or more `"path:line"` strings naming hardcoded sector triples outside the
  allowlist.
- `inv_engagement_data_source(root: character) -> list` — unchanged shape
  (`list(id = "INV-003", ok, detail)`), widened coverage.

**Test Specs**
- `financed_emissions(..., data_source = "sdb-rehearsal")` → every row's
  `data_source` equals `"sdb-rehearsal"`.
- `financed_emissions(...)` with `data_source` omitted → every row's
  `data_source` is `NA_character_` (never a bank slug).
- After TASK-03-07:
  `awk -F',' 'NR>1{print $6}' engagements/sdb-rehearsal/output/financed_emissions/financed_emissions.csv | sort -u`
  → only `"sdb-rehearsal"` and empty values, never `"mcb-demo"`.
- INV-003 fixture: an engagement whose `sll_readiness.csv` has a `data_source`
  column containing `"other-bank"` → `ok = FALSE` naming that file.
- INV-003 fixture: a `target_registry.csv` with no `data_source` column →
  skipped, `ok = TRUE`.
- `.scan_hardcoded_sector_triples()` against a fixture containing
  `sectors <- c("power", "cement", "steel")` in `scripts/foo.R` → returns
  `"scripts/foo.R:<line>"`.
- `.scan_hardcoded_sector_triples()` against the **live repo root** after
  TASK-03-03 and TASK-03-04 → returns `character(0)`.
- `build_target_registry()` still returns exactly 9 rows and 12 columns in S6
  order after the registry substitution (the registry's three sectors are the
  same three that were hardcoded, so no output changes).

**Dependencies**
- PHASE-02 (INV registration ordering; INV-013 is not used, the new checks
  extend INV-003 and INV-004 in place).

**Exit Criteria**
- [ ] `grep -rn '"mcb-demo"' R/*.R` returns only
      `R/engagement_config.R:36` (the legitimate default `bank_slug`) and
      `R/trisk_core.R:517` (a mode comparison), with no match in
      `R/financed_emissions.R`.
- [ ] `grep -rn 'c("power", "cement", "steel")' R/ scripts/ tools/` returns only
      the four allowlisted definition sites.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS`.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [ ] `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`
      reports `FAIL 0` — no golden number moved.
- [ ] `git diff --stat engagements/sdb-rehearsal/` shows a change confined to
      `financed_emissions.csv` (and any file whose only diff is a timestamp).

**Execution notes (Wave 4, recorded during implementation)**
- **ASM-005 and DEC-002 were based on a false premise, now corrected.** Both
  said the `data_source` fix would change a *committed* SDB fixture and called
  for a "scoped fixture refreeze". It does not, and none was needed:
  `engagements/sdb-rehearsal/output/financed_emissions/financed_emissions.csv`
  is gitignored by `.gitignore:73` (`engagements/*/output/*`) and has never been
  committed (`git cat-file -e 503743f:<path>` fails). The file inspected during
  planning was a local build artifact. Regenerating the SDB engagement changed
  exactly one tracked file — its `pipeline_manifest.json`.
  The hardcoded literal at `R/financed_emissions.R:115` was real and is fixed;
  the accurate severity is "would stamp any real engagement's inventory with the
  demo bank's slug on generation", not "a wrong value is committed".
- INV-004 is now self-maintaining via `.scan_hardcoded_sector_triples()`, which
  scans `R/`, `scripts/` and `tools/` for the literal and ignores comment lines.
  Proven to detect a stray literal in a fixture, to ignore a comment-only
  mention, and to honour the four-file allowlist — not merely to return empty.

**Phase Risks**
- **RISK-03-01:** Regenerating the SDB engagement (TASK-03-07) may change more
  than the intended provenance column. Mitigation: run
  `git diff --numstat engagements/sdb-rehearsal/` immediately afterwards; if any
  file other than `financed_emissions.csv` shows a numeric-content change, stop
  and investigate before committing — per ASM-006 this plan changes no golden
  number.
- **RISK-03-02:** `sector_registry()` returns a tibble, so
  `sector_registry()$sector` is a character vector — but sourcing
  `R/sector_registry.R` pulls in `library(tibble)`. Mitigation: confirm `tibble`
  is already in `DESCRIPTION`'s `Imports` (it is) so no dependency is added, and
  confirm the scripts still run standalone via `Rscript`.

---

### PHASE-04 - Restore the Package Surface and Test the Untested Modules

**Goal**
Make `library(pactatrisk)` expose the API the package actually has, make CI able
to notice when it drifts again, and give the two untested Wave 3 modules the
same coverage their sibling specifications already have.

**Tasks**
- [x] TASK-04-01: Regenerate `NAMESPACE` and `man/` from the roxygen comments:
      `Rscript -e "roxygen2::roxygenise()"`. This adds the 20 missing exports
      (`attribution_factor`, `borrower_emissions_intensity`,
      `borrower_emissions_power`, `build_target_registry`,
      `carbon_cost_exposure`, `data_quality_summary`, `filter_step_list`,
      `financed_emissions`, `history_diff`, `history_runs`,
      `load_report_labels`, `make_run_id`, `pcaf_data_quality_score`,
      `record_run_history`, `report_label`, `resolve_step_list`,
      `sda_convergence_target`, `sll_readiness`, `sll_readiness_band`,
      `sll_readiness_score`) plus the two functions added by PHASE-01
      (`normalize_report_html`, `report_fingerprint`).
- [x] TASK-04-02: Resolve the reverse discrepancy: `pacta_market_share` is
      exported in `NAMESPACE` with no matching `#' @export` in `R/pacta_core.R`.
      Add the missing `#' @export` tag to its roxygen block (it has a `man/`
      page and is a legitimate public function), then re-run roxygenise so the
      export is generated rather than orphaned.
- [x] TASK-04-03: Add `R/report_fingerprint.R` to the package by confirming it
      is picked up by roxygenise (it lives in `R/`, so it is). Verify
      `DESCRIPTION`'s `Imports` needs no addition — the module uses only base R
      and `tools`.
- [x] TASK-04-04: Add a `NAMESPACE` freshness check to
      `.github/workflows/ci.yml`'s `r-tests` job, immediately after the
      `Verify pactatrisk package loads` step. The step runs roxygenise into a
      scratch copy and fails if `NAMESPACE` would change:
      ```yaml
      - name: NAMESPACE is up to date with roxygen
        run: |
          cp NAMESPACE /tmp/NAMESPACE.before
          Rscript -e "if (!requireNamespace('roxygen2', quietly = TRUE)) install.packages('roxygen2'); roxygen2::roxygenise()"
          diff -u /tmp/NAMESPACE.before NAMESPACE
      ```
      `diff` exits non-zero when the files differ, failing the job.
- [x] TASK-04-05: Create `tests/testthat/test_target_setting.R` covering
      `sda_convergence_target()` and `build_target_registry()` per Test Specs.
- [x] TASK-04-06: Create `tests/testthat/test_report_toolkit.R` covering
      `load_report_labels()` and `report_label()` per Test Specs.

**File Changes**
- `NAMESPACE` (modify, regenerated): 22 added exports.
- `man/` (modify, regenerated): approximately 22 new `.Rd` files.
- `R/pacta_core.R` (modify): add the missing `#' @export` tag to
  `pacta_market_share`'s roxygen block only. Change no logic.
- `.github/workflows/ci.yml` (modify): add the NAMESPACE freshness step to the
  `r-tests` job only. **Leave alone:** the `python-tests`, `sdb-engagement` and
  `byte-identity` jobs.
- `tests/testthat/test_target_setting.R` (create).
- `tests/testthat/test_report_toolkit.R` (create).

**Function Signatures**
- None — no code interfaces change in this phase. `pacta_market_share` gains an
  export tag; its signature is unchanged.

**Test Specs**

`test_target_setting.R`:
- `sda_convergence_target(baseline_value = 0.80, baseline_year = 2025L, scenario = data.frame(year = c(2025L, 2030L), emission_factor_value = c(1.00, 0.50)), target_year = 2030L)`
  → `0.40` (the portfolio baseline scaled by the scenario's own 0.50 ratio).
- Same call with `baseline_value = NA_real_` → `NA_real_`.
- Same call with `baseline_value = numeric(0)` → `NA_real_` (must not error —
  this behaviour was verified and must be locked in).
- Scenario missing the `target_year` row → `NA_real_`.
- Scenario whose `baseline_year` value is `0` → `NA_real_` (division guard).
- A `scenario` data frame lacking the `emission_factor_value` column → errors
  with a message containing `"year and emission_factor_value"`.
- `build_target_registry()` with minimal fixtures for all four inputs and
  `scenario_vintage = "pdp8-2025-adjusted"` → a data frame of exactly 9 rows
  (3 sectors × 3 horizons) and exactly 12 columns in this order:
  `sector, metric, unit, baseline_year, baseline_value, target_year,
  target_value, scope, method, scenario_vintage, status, source_artifact`.
- In that output: every `target_year == 2030L` row has `status == "proposed"`;
  every `2035L` and `2050L` row has `status == "not_set"` and
  `is.na(target_value)`.
- Cement and steel rows have `method == "sda_convergence"` and
  `unit` values `"tco2_per_tonne_cement"` and `"tco2_per_tonne_crude_steel"`
  respectively; power rows have `method == "market_share"` and
  `scope == "n/a"`.
- `baseline_year` and `target_year` are `integer`, `baseline_value` and
  `target_value` are `numeric`.
- Power with an empty `ms_portfolio` falls back to `scenario_ms`'s own
  `smsp` at 2025 for `baseline_value`.

`test_report_toolkit.R`:
- `load_report_labels(base_csv = <fixture with columns token,en,vi>)` → a data
  frame with those three columns and one row per fixture row.
- `load_report_labels(base_csv = <fixture missing the "vi" column>)` → errors
  with a message containing `"missing required columns"`.
- `load_report_labels(base_csv = <path that does not exist>)` → errors with a
  message containing `"base label file not found"`.
- `load_report_labels(base, override_csv = <override redefining one existing
  token and adding one new token>)` → the redefined token's `en`/`vi` come from
  the override, and the new token is appended.
- `load_report_labels(base, override_csv = <path that does not exist>)` → warns
  and returns the base table unchanged.
- `report_label("synthetic_disclaimer", lang = "en", labels = <fixture>)` →
  the fixture's `en` value.
- `report_label("synthetic_disclaimer", lang = "vi", labels = <fixture>)` →
  the fixture's `vi` value.
- `report_label("synthetic_disclaimer", lang = "bilingual", labels = <fixture>)`
  → `paste0(en, " / ", vi)`.
- `report_label("no_such_token", labels = <fixture>)` → returns
  `"no_such_token"` and emits exactly one warning; a second call with the same
  token in the same session emits no further warning.
- `report_label("x", labels = data.frame(a = 1))` (malformed table) → returns
  `"x"` without erroring.
- Every token referenced by a generator exists in `templates/i18n/labels.csv`:
  read the live `templates/i18n/labels.csv`, and assert it has at least the
  30 tokens the Wave 3 implementation shipped and that no `token` value is
  duplicated.

**Dependencies**
- PHASE-03. `roxygen2` is already in `DESCRIPTION`'s `Suggests`.

**Exit Criteria**
- [ ] `Rscript -e "roxygen2::roxygenise()"` followed by
      `git diff --exit-code NAMESPACE` exits `0` — regenerating produces no
      change.
- [ ] `Rscript -e "cat(sum(grepl('^export', readLines('NAMESPACE'))), '\n')"`
      prints a count of at least `55` (it prints `33` before this phase).
- [ ] `ls man/ | wc -l` returns at least `66`.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0` with
      a PASS count strictly greater than the PHASE-03 count.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS` —
      in particular INV-008 (dependency manifests agree) still holds after the
      `DESCRIPTION`/`NAMESPACE` touch.

**Execution notes (Wave 4, recorded during implementation)**
- **TASK-04-02 was unnecessary — the finding behind it was a scanner artifact.**
  `pacta_market_share` DOES carry `#' @export` (`R/pacta_core.R:362`); the
  planning-time scan missed it because several `@param` lines sit between the
  tag and the function definition, outside the scanner's 5-line lookahead.
  `roxygen2::roxygenise()` added 22 exports and removed none, confirming there
  was no reverse discrepancy to fix.
- Exports went 33 -> 55; `man/` went 45 -> 73 pages, with **no** page deleted.
- Roxygen emitted "Could not resolve link to topic 0, 1" warnings because
  `DESCRIPTION` sets `Roxygen: list(markdown = TRUE)` and 15 roxygen lines wrote
  a range as `[0, 1]`, which markdown reads as a link. Escaped to `\[0, 1\]`
  across `R/financed_emissions.R`, `R/prioritization_core.R`,
  `R/severity_scoring.R` and `R/sll_readiness.R`; roxygen now runs with 0
  warnings and is idempotent (a second run leaves `NAMESPACE` and every `man/`
  page byte-identical).

**Phase Risks**
- **RISK-04-01:** `roxygen2::roxygenise()` may rewrite existing `man/` pages
  with formatting differences unrelated to Wave 3, producing a large diff.
  Mitigation: that is acceptable and expected for a generated directory; review
  that no `.Rd` file **disappears** for a function that still exists, which
  would indicate a dropped `@export`.
- **RISK-04-02:** Adding `#' @export` to `pacta_market_share` changes the
  package's public surface. Mitigation: it is already listed in `NAMESPACE` and
  already has a `man/` page, so this makes the source agree with the shipped
  surface rather than expanding it.

---

### PHASE-05 - Scale Follow-Through

**Goal**
Act on the measurement Wave 3 produced — vectorize the three row-wise intake
passes it identified as the bottleneck — and complete the two measurements it
explicitly left undone: `r2dii.match::match_name()` timing and a full
PACTA + TRISK chain run at scale.

**Tasks**
- [x] TASK-05-01: Record a baseline before changing anything. Run
      `Rscript tools/benchmark_scale.R --timeout-seconds 300` and note the
      appended rows in `docs/scale_benchmark.csv`. The benchmark appends rather
      than overwrites, so prior rows are preserved.
- [x] TASK-05-02: Vectorize the first validation pass in
      `scripts/intake_validate_and_map.R` (the loop beginning at line 196).
      Replace the per-row `row <- input_data[i, ]` slice with column-wise
      vectors computed once outside any loop:
      `nm <- trimws(as.character(input_data$counterparty_name))`,
      `exp_val <- suppressWarnings(as.numeric(input_data$exposure_vnd))`,
      `cl_val <- suppressWarnings(as.numeric(input_data$credit_limit_vnd))`,
      `scs <- trimws(as.character(input_data$sector_code_system))`,
      `sc <- trimws(as.character(input_data$sector_code))`. Derive each error
      condition as a logical vector (`is.na(nm) | nm == ""`, `is.na(exp_val)`,
      `!is.na(exp_val) & exp_val < 0`, and so on) and emit errors by iterating
      only over `which(<condition>)`.
      **The emitted error order must be preserved exactly**: today the loop
      emits, for each row in ascending row order, the checks in the order
      counterparty_name → exposure_vnd → credit_limit_vnd → sector_code_system
      → sector_code. Reproduce that ordering by iterating rows in ascending
      order and, within each row, testing the five precomputed condition
      vectors in the same sequence.
- [x] TASK-05-03: Vectorize the sector-scope warning pass (the loop beginning at
      line 253). `normalize_sector_code()` and `map_sector_code()` are already
      called element-wise elsewhere via `mapply` at line 330 — compute
      `norm_codes <- mapply(normalize_sector_code, sc, scs, USE.NAMES = FALSE)`
      and `mapped <- vapply(norm_codes, map_sector_code, character(1))` once,
      then emit warnings only for `which(!is.na(sc) & sc != "" & !is.na(norm_codes) & mapped == "not in scope")`,
      in ascending row order.
- [x] TASK-05-04: Vectorize the currency-conversion pass (the loop beginning at
      line 285). The VND branch is already a no-op `next`; compute the USD row
      indices once as `usd_idx <- which(currency_effective == "USD")` and
      operate on those indices only, preserving the existing warning text and
      classification strings exactly.
- [x] TASK-05-05: Verify byte-identity of the intake outputs. Run
      `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json`
      and confirm `git diff --name-only engagements/sdb-rehearsal/intake/`
      reports no changes to `normalized_loanbook.csv`,
      `validation_errors.csv` or `validation_warnings.csv`. If any of the three
      changes, revert the optimization per ASM-007 rather than re-pinning.
- [x] TASK-05-06: Re-run `Rscript tools/benchmark_scale.R --timeout-seconds 300`
      and confirm the 50,000 × 1,000 cell is at least 3× faster than the
      baseline 230.3 s (ASM-007).
- [x] TASK-05-07: Fix the `match_seconds` measurement gap in
      `tools/benchmark_scale.R`. The harness currently records `NA` for every
      cell. Make the fixture exercise `r2dii.match::match_name()` the way the
      real intake pipeline does — i.e. call it with the same loanbook and ABCD
      shapes `scripts/intake_validate_and_map.R` uses — and record the wall-clock
      seconds. If matching cannot be made to run at a given cell within the
      timeout, record the timeout value and set a `note` explaining it rather
      than silently writing `NA`.
- [ ] TASK-05-08: Add a full-chain benchmark mode to `tools/benchmark_scale.R`,
      invoked as `--full-chain`, which runs the whole engagement
      (`scripts/run_engagement.R`) against a generated fixture at the 1,000 and
      10,000 loan cells and records the total wall-clock seconds plus per-step
      seconds from the resulting manifest. Write its fixtures under the
      gitignored `bench/` directory, exactly as
      `tools/generate_scale_fixture.R` already does, and never into
      `engagements/` or `dashboard/data/`.
- [x] TASK-05-09: Rewrite `docs/scale_benchmark.md`'s "What was NOT measured"
      section to reflect what is now measured, add the post-optimization intake
      table alongside the pre-optimization one (so the improvement is visible
      and attributable), and add the `match_name()` and full-chain results.
      Keep the honest framing and the "Machine" caveat.
- [x] TASK-05-10: Update `intake/SCHEMA.md`'s "Submission size" section
      (currently line 16) to state the new measured intake ceiling and, if
      TASK-05-08 supports it, the first end-to-end pipeline size statement.
      Keep the existing precision about what the number does and does not cover.

**File Changes**
- `scripts/intake_validate_and_map.R` (modify): the three loops at lines 196,
  253 and 285. **Leave alone:** `add_error()` and `add_warning()` and their
  accumulators (lines 165-179), the duplicate-row check at line 239, the
  required-column check, the currency policy semantics, and every emitted
  message string — the text of each error and warning must be byte-identical.
- `tools/benchmark_scale.R` (modify): fix `match_seconds`; add `--full-chain`.
- `docs/scale_benchmark.md` (modify): rewrite the measurement sections.
- `docs/scale_benchmark.csv` (modify, appended): new benchmark rows.
- `intake/SCHEMA.md` (modify): the "Submission size" section only.

**Function Signatures**
- None — no exported code interfaces change in this phase. The intake script's
  internal validation block is rewritten in place; its CLI contract
  (`--input`, `--output-dir`, `--fx-rate-usd-vnd`, `--anonymize`) and its output
  files are unchanged.

**Test Specs**
- `tests/testthat/test_intake_fixture.R` continues to pass unchanged — it is the
  primary guard that vectorization preserved behaviour. Run it alone first:
  `Rscript -e "testthat::test_file('tests/testthat/test_intake_fixture.R')"`
  → `FAIL 0`.
- A loanbook fixture with a row that is simultaneously missing
  `counterparty_name` **and** has a negative `exposure_vnd` → produces exactly
  two error rows for that row index, in the order `counterparty_name` then
  `exposure_vnd` (ordering preservation).
- A loanbook fixture with errors on rows 3 and 1 → `validation_errors.csv` lists
  row 1's errors before row 3's (ascending row order preserved).
- A row with `sector_code_system = "VSIC"` and `sector_code = "ABC"` → one
  `sector_code` error whose message contains `"is not a valid VSIC code"`.
- A well-formed but out-of-PACTA-scope sector code → a **warning** with
  classification `sector_out_of_scope`, and the row is **retained** in
  `normalized_loanbook.csv`.
- A `USD` row with a configured FX rate → converted, warning classification
  `fx_converted`, row retained.
- A `USD` row with no configured FX rate → row retained with `NA` exposure, and
  the script exits non-zero naming `fx_rate_usd_vnd`.
- Byte-identity: after regenerating the SDB engagement,
  `git diff --name-only engagements/sdb-rehearsal/intake/` → empty.

**Dependencies**
- PHASE-04. Requires `r2dii.match` (already pinned in `renv.lock`) for
  TASK-05-07.

**Exit Criteria**
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [ ] `git diff --name-only engagements/sdb-rehearsal/intake/` is empty after
      regenerating the SDB engagement.
- [ ] `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`
      reports `FAIL 0`.
- [ ] `docs/scale_benchmark.csv` contains at least one row with a non-`NA`
      `match_seconds` value.
- [ ] The 50,000 × 1,000 intake cell measures at most 77 seconds (one third of
      the 230.3 s baseline).
- [ ] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS`.

**Execution notes (Wave 4, recorded during implementation)**
- **TASK-05-08 (`--full-chain` benchmark) was NOT done.** It cannot be done
  honestly with the current fixture: `tools/generate_scale_fixture.R` emits a
  loanbook and an ABCD table only, while the chain past PACTA matching needs
  asset-level inputs (assets, financial features, carbon prices, scenarios) for
  the synthetic counterparties. Fabricating those would time a fiction. Recorded
  as still-unmeasured in `docs/scale_benchmark.md` rather than faked; extending
  the fixture generator is the prerequisite and belongs to a later wave.
- **The `match_seconds` gap was not a performance problem, it was a broken
  harness.** Every cell read `NA` because the harness built a five-column
  loanbook subset and an ABCD with no `sector` column, so `match_name()` raised
  "Must have missing names: `sector_classification_direct_loantaker`" and a
  `tryCatch` swallowed it. Fixed by passing the normalized loanbook whole (it is
  already the 13-column r2dii shape) and mirroring `R/pacta_core.R`'s exact call
  including the VSIC-to-ISIC classification extension. All 8 cells now report a
  real timing and a non-zero match count.
- **F-005's hypothesis is confirmed.** At 50,000 loans, matching goes 6.8 s ->
  9.3 s -> 26.9 s as distinct counterparties go 200 -> 1,000 -> 5,000, while
  intake is flat across the same axis. Intake scales with loan count; matching
  scales with counterparty count.
- **ASM-007's 3x bar: met at the margin, reported honestly.** A single sample at
  the 50,000 x 1,000 cell gave 2.58x. Re-timing that cell three times in
  isolation gave 28.7 / 29.3 / 33.5 s (median 29.3), i.e. 2.9x against the
  86.0 s baseline; the other two 50,000-row cells gave 3.01x and 3.21x. The
  documented claim is "about 2.6x-3.2x depending on cell and run, roughly 85-90 s
  down to roughly 28-33 s", not a clean 3x.
- Ordering preservation was verified against the pre-change implementation in a
  `git worktree` at `cec86ae`, using an adversarial fixture (a row with four
  simultaneous errors, unparseable numbers, a blank sector code, an out-of-scope
  code, USD conversion, and an unsupported currency). `validation_errors.csv`,
  `validation_warnings.csv` and `normalized_loanbook.csv` were byte-identical.

**Phase Risks**
- **RISK-05-01:** Vectorization changes the order of emitted validation errors,
  breaking the committed SDB fixture. Mitigation: TASK-05-02's explicit ordering
  requirement, and TASK-05-05's byte-identity check run **before** any other
  work in this phase proceeds. If ordering cannot be preserved cheaply, keep the
  outer row loop and vectorize only the per-column coercions
  (`as.numeric`, `trimws`) hoisted out of it — that alone removes the expensive
  `input_data[i, ]` slice, which is the dominant cost.
- **RISK-05-02:** The full-chain benchmark (TASK-05-08) may write into
  `engagements/` or the public snapshot. Mitigation: it must construct a
  throwaway engagement config under `bench/` whose every `paths.*` value points
  inside `bench/`, and it must **not** set `public_snapshot_allowed`; the
  orchestrator's existing guard rail then refuses any attempt to publish.
- **RISK-05-03:** `match_name()` may be genuinely quadratic and blow the
  300-second timeout at 5,000 counterparties. Mitigation: that is a finding, not
  a failure — record it as a timeout row with a `note` (TASK-05-07) and report
  it in `docs/scale_benchmark.md`. Do not optimize it in this plan (DEC-004).

---

### PHASE-06 - Parity, Surfacing, and Reconciliation

**Goal**
Make the second engagement exercise the full Wave 3 feature set so the CI
end-to-end job means what it appears to mean, surface the three Wave 3 analytics
in the dashboard as data rather than static pictures, and bring the
documentation back into agreement with the code.

**Tasks**
- [x] TASK-06-01: Bring `engagements/sdb-rehearsal/engagement_config.json` to
      feature parity. Add `"run_targets": true`, `"run_history": true`, and
      `"report_language": "bilingual"`. Do **not** add `published_reports` or
      `public_snapshot_allowed` — SDB must never publish to the public snapshot.
      Leave `inputs.scenario_vintage` at `"pdp8-2023"`: SDB is deliberately the
      engagement that still runs the prior vintage, which is what makes
      `compare_scenario_vintages` meaningful and what INV-012 now verifies.
- [x] TASK-06-02: Regenerate the SDB engagement and commit the resulting new
      fixtures (`target_registry.csv`, a `history/sdb-rehearsal/` run directory,
      and the bilingual-labelled reports). Update `.gitignore` if the target
      registry or history output falls outside the current
      `engagements/sdb-rehearsal/` allowlist — INV-007 polices that allowlist,
      so run the invariants immediately afterwards.
- [x] TASK-06-03: Extend `scripts/refresh_dashboard_data.R` to copy the three
      Wave 3 analytic CSVs into the snapshot, creating
      `<snapshot_dir>/analytics/`: `financed_emissions.csv` and
      `data_quality_summary.csv` from `cfg$paths$financed_emissions_output_dir`,
      and `target_registry.csv` and `sll_readiness.csv` from
      `cfg$paths$engagement_output_dir`. Copy a file only when it exists, so an
      engagement that did not run those steps still refreshes cleanly. This is
      the only script permitted to write `dashboard/data/` (CON-002).
- [x] TASK-06-04: Add loaders to `dashboard/lib/loaders.py`:
      `ANALYTICS_DIR = DATA_DIR / "analytics"`, `analytics_path(name)`, and
      `load_analytics_tables() -> dict[str, pd.DataFrame]` returning whichever
      of the four CSVs exist, keyed `financed_emissions`,
      `data_quality_summary`, `target_registry`, `sll_readiness`. A missing file
      must be omitted from the dict, never raise.
- [x] TASK-06-05: Create `dashboard/pages/8_Financed_Emissions.py` presenting
      the PCAF inventory: total financed emissions, the data-quality composition
      table (never a total without it), the Scope 3 exclusion note, the sector
      target registry, and the SLL readiness shortlist. Apply the existing page
      frame and banners via `dashboard.lib.branding.apply_page_frame` and
      `footer_note`, matching the structure of
      `dashboard/pages/2_TRISK_Risk.py`. Include the synthetic-data disclaimer.
- [x] TASK-06-06: Add `dashboard/tests/test_analytics_page.py` covering
      `load_analytics_tables()` per Test Specs.
- [x] TASK-06-07: Correct `CLAUDE.md` law 4. It currently pins
      ``composite_score[1]` == 1.0`; the 0.5.0 refreeze moved it to
      `0.9816483381`. Replace the stale value and keep the rest of the law
      unchanged.
- [x] TASK-06-08: Rewrite `plans/PROGRESS.md`. It currently states "Waves 0, 1
      and 2 are complete. The platform is at version 0.4.1 (...) six
      cross-artifact invariants." Update to Wave 4, the current version, and the
      current invariant count. Keep it a pointer, not a duplicate of `NEWS.md`.
- [x] TASK-06-09: Update `README.md`'s repository map table to add rows for
      `tools/`, `templates/`, `output/`, `history/` and `workshop/`, and correct
      the `scripts/` row, which currently calls `pipeline_refresh.R` the
      orchestrator — `run_engagement.R` is the orchestrator and
      `pipeline_refresh.R` is a thin wrapper over it.
- [x] TASK-06-10: Fix `dashboard/app.py:19`, which says "Work through the five
      steps below" above six `st.page_link` calls. Make the count agree with the
      links, accounting for the page added in TASK-06-05.
- [x] TASK-06-11: Retire `compare/` to `attic/`. It is referenced only from
      superseded plans and brainstorms — nothing in `scripts/`, `R/`,
      `dashboard/` or `docs/` reads it. Move the directory to
      `attic/compare/` and add a paragraph to `attic/README.md` recording what
      it was (a methodology-convergence comparison against the r2dii bundled
      demo) and why it was retired. Verify nothing live breaks with a
      tracked-files-only search (a plain recursive `grep` over the whole tree
      takes minutes here, because it scans the base64 payloads embedded in the
      HTML reports):
      `git grep -n "compare/" -- ':!attic/*' ':!plans/*' ':!research/*'`
      Before this task that command returns exactly three matches: two
      self-references inside `compare/compare_report.R` (which move with the
      directory) and one prose reference inside the static, never-regenerated
      `reports/PACTA_Comparison_Report.html`. Update that one report's
      `<code>compare/...</code>` path text to `attic/compare/...` so the
      rendered report still names a path that exists; note that this file is
      **not** in `GATED_HTML_PATHS`, so editing it does not trip the PHASE-01
      gate. After the move, the same command must return only matches inside
      `attic/`. A fourth copy of that report may exist locally at
      `engagements/sdb-rehearsal/snapshot/reports/PACTA_Comparison_Report.html`;
      it is gitignored by `.gitignore:52` (`engagements/*/snapshot/`), so it is
      a local build artifact that needs no edit and will be regenerated.
- [x] TASK-06-12: Bump `DESCRIPTION`'s `Version` to `0.6.0` and write the
      `NEWS.md` entry. Follow the existing structure: one bullet per phase
      naming the concrete artifacts. Per the repo convention, do **not** quote a
      test PASS count — write "full R suite green (FAIL 0)" instead.

**File Changes**
- `engagements/sdb-rehearsal/engagement_config.json` (modify): three added keys.
- `engagements/sdb-rehearsal/**` (modify, regenerated): new target registry,
  history run, and bilingual reports.
- `.gitignore` (modify, only if required by TASK-06-02): extend the
  `sdb-rehearsal` allowlist. **Leave alone:** every wildcard negation removed in
  Wave 3 — do not reintroduce `engagements/*/` negations, which INV-007 exists
  to prevent.
- `scripts/refresh_dashboard_data.R` (modify): copy the four analytic CSVs.
- `dashboard/lib/loaders.py` (modify): add the analytics loaders. **Leave
  alone:** the existing PACTA, TRISK, grid and report-catalog loaders.
- `dashboard/pages/8_Financed_Emissions.py` (create).
- `dashboard/tests/test_analytics_page.py` (create).
- `dashboard/app.py` (modify): the step-count sentence and, if the tour lists
  pages, a link to the new page.
- `CLAUDE.md` (modify): law 4's golden value.
- `plans/PROGRESS.md` (modify): full rewrite as a current pointer.
- `README.md` (modify): the repository map table.
- `attic/compare/` (create, moved from `compare/`); `attic/README.md` (modify).
- `DESCRIPTION` (modify): `Version: 0.6.0`.
- `NEWS.md` (modify): new top section.

**Function Signatures**
- `analytics_path(name: str) -> Path` — the path to a named CSV inside
  `dashboard/data/analytics/`.
- `load_analytics_tables() -> dict[str, pd.DataFrame]` — whichever of the four
  analytic CSVs exist, keyed by `financed_emissions`, `data_quality_summary`,
  `target_registry`, `sll_readiness`; missing files are omitted.

**Test Specs**
- `load_analytics_tables()` with all four CSVs present → a dict with exactly
  those four keys, each a non-empty `pd.DataFrame`.
- `load_analytics_tables()` with only `financed_emissions.csv` present → a dict
  with exactly one key, `financed_emissions`; no exception raised.
- `load_analytics_tables()` with the `analytics/` directory absent → an empty
  dict; no exception raised.
- The `financed_emissions` frame's `data_source` column contains only
  `mcb-demo` for the public snapshot (this is the dashboard-side echo of the
  PHASE-03 fix).
- `dashboard/tests/test_smoke.py` continues to pass with the new page present.
- A page render test asserting the rendered Financed Emissions page source
  contains the word `synthetic`.

**Dependencies**
- PHASE-05.

**Exit Criteria**
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [ ] `python -m pytest dashboard/tests` reports all tests passing with a count
      strictly greater than `63`.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS`
      for INV-001 through INV-012.
- [ ] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS`.
- [ ] `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`
      reports `FAIL 0`.
- [ ] `test -d compare` returns non-zero (the directory has moved) and
      `test -d attic/compare` returns zero.
- [ ] `git grep -n "compare/" -- ':!attic/*' ':!plans/*' ':!research/*'` returns
      no matches.
- [ ] `grep -c '0\.4\.1' plans/PROGRESS.md` returns `0` (it returns `1` before
      this phase).
- [ ] `grep -c '== 1.0' CLAUDE.md` returns `0` (it returns `1` before this
      phase).
- [ ] `Rscript -e "cat(read.dcf('DESCRIPTION')[, 'Version'], '\n')"` prints
      `0.6.0` (it prints `0.5.0` before this phase).

**Execution notes (Wave 4, recorded during implementation)**
- **RISK-06-01 was resolved the strict way**, as the plan preferred. A new
  `paths.history_dir` config key (registered in `.default_engagement_config()`,
  defaulting to `"history"`) lets `sdb-rehearsal` write its run history to
  `engagements/sdb-rehearsal/history/`, so `ci.yml`'s cross-contamination
  assertion stays strict rather than being loosened.
- **Parity exposed a real defect, now fixed.** With `run_history` enabled,
  re-running SDB the same day at the same commit made `record_run_history()`
  hit its append-only refusal, which failed the step, exited the orchestrator
  non-zero, and stamped an otherwise-clean manifest `"failed"` — untrue
  provenance, exactly what this wave exists to remove. The step wrapper
  `scripts/record_run_history.R` now treats an already-recorded
  date/commit/vintage as a `[SKIP]`; `R/run_history.R` keeps its strict
  contract for direct callers.
- `tests/testthat/test_step_registry.R`'s pinned SDB step list grew from 15 to
  17 (`generate_targets`, `record_history`) — the intended consequence of
  parity, updated rather than worked around.
- README's invariant count was stale in two places at once: it said "five
  cross-artifact consistency rules" when there were nine. Corrected to twelve
  and each rule named.

**Phase Risks**
- **RISK-06-01:** Enabling `run_history` for SDB writes a new
  `history/sdb-rehearsal/` tree that `classify_path()` treats as expected churn,
  but `ci.yml`'s `sdb-engagement` job asserts no uncommitted changes outside
  `engagements/sdb-rehearsal/` — and `history/` is outside it. Mitigation: add
  `history` to that job's `git status --porcelain` exclusion list, or point
  SDB's history output inside its own engagement tree. Prefer the latter: it
  keeps the "no cross-contamination" assertion strict.
- **RISK-06-02:** Adding a dashboard page changes the page numbering Streamlit
  derives from filenames, which several tests and `st.page_link` calls
  reference. Mitigation: name the new page `8_Financed_Emissions.py` so it sorts
  last and no existing page's number changes; grep for `pages/` string literals
  before and after.
- **RISK-06-03:** Moving `compare/` could break a path referenced from a
  document not covered by the TASK-06-11 search. Mitigation: `git grep` already
  covers every tracked file type, not just source, so widen the pattern rather
  than the file set:
  `git grep -n "compare" -- ':!attic/*' ':!plans/*' ':!research/*' | grep -v "compare_scenario_vintages\|scenario_vintage"`.
  Do not use a plain recursive `grep -rn` over the working tree — it scans the
  base64 image payloads inside the HTML reports and takes minutes.

## Gotchas

- **Run every R command from the repository root.** Every script resolves paths
  via `getwd()`. Running from `tests/` or `scripts/` produces
  "file not found" errors far from the real cause.
- **Register every new config key.** `R/engagement_config.R` performs strict
  unknown-key rejection. A key added to an `engagement_config.json` without a
  matching entry in `.default_engagement_config()` fails validation loudly. This
  bites in PHASE-06's SDB parity work.
- **Test "not configured" with `length(x) == 0`.** `jsonlite::toJSON(...,
  auto_unbox = TRUE)` followed by `read_json(..., simplifyVector = TRUE)`
  returns an empty `list()` for both `NULL` and `character(0)`, defeating
  `is.null()` and `is.character()` checks. This only manifests on the *second*
  generation of a config — the resolved config the orchestrator writes after
  intake — so it passes every direct test of the default config.
- **Never compare working-tree files with raw `md5sum` for byte-identity.**
  Git's `core.autocrlf` means a file that is identical after normalization can
  have a different raw digest across Windows and Linux. Use `git diff`. The one
  exception is PHASE-01's HTML fingerprint, which explicitly normalizes CRLF
  itself before hashing, and PHASE-02's INV-012, which compares a digest of a
  *data* file against a digest recorded by the same `tools::md5sum()` call — a
  like-for-like comparison on the same machine.
- **VND is never rescaled.** Values span 1e5 to 5e12. Note that
  `financed_emissions.csv` currently writes some values in scientific notation
  (`4.2e+11`); this is R's default 15-significant-digit formatting and is
  lossless at these magnitudes. Do not "fix" it by rounding, and do not
  introduce any division.
- **PCAF data-quality scores run 1 (best) to 5 (worst) — the opposite direction
  from this repo's severity scores, where 1 is worst.** Do not "correct" one to
  match the other. Both are documented in
  `docs/financed_emissions_methodology.md`.
- **Two functions look buggy and are not.** `attribution_factor()` with an `NA`
  `capital_vnd`, and `sda_convergence_target()` with a zero-length
  `baseline_value`, both return `NA` cleanly under R 4.5.2. This was verified
  empirically. PHASE-04's tests lock the behaviour in; do not change the
  implementations.
- **The five R suite warnings are environmental.** They read
  `package 'X' was built under R version 4.5.3` and come from `fs`, `arrow` and
  `jsonlite`. They are not test failures and must not be suppressed.
- **`--only-step` and `--resume-from` corrupt provenance until PHASE-02 lands.**
  While executing PHASE-01, avoid using them against `mcb-demo`, or the
  manifest will be overwritten with a partial one.
- **PHASE-01 must pass on the tree as-is before anything else changes.** If the
  new HTML branch reports drift on an untouched report, the normalization is
  incomplete — fix S1, do not add the file to an exclusion list.
- **`R CMD check` is not run by CI and is not added by this plan.** PHASE-04 adds
  a narrower `NAMESPACE`-freshness diff instead, because a full check would
  surface a large backlog of unrelated documentation warnings and would make the
  phase unlandable.

## Verification Strategy

- **TEST-001:** `Rscript -e "testthat::test_dir('tests/testthat')"` → reports
  `FAIL 0`, with `PASS` strictly greater than 552 after PHASE-01 and greater
  still after PHASE-04.
- **TEST-002:** `python -m pytest dashboard/tests` → all tests pass; count is
  `63` through PHASE-05 and strictly greater after PHASE-06.
- **TEST-003:** `Rscript tools/verify_refactor.R --invariants` → prints
  `INVARIANTS PASS` and one `[PASS] INV-0NN` line per invariant: 010 after
  PHASE-01, 011 and 012 after PHASE-02.
- **TEST-004:** `Rscript tools/verify_refactor.R` → prints
  `BYTE-IDENTITY PASS`. Run this at the end of every phase; it is the check that
  proves no phase moved a number it should not have.
- **TEST-005:** `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`
  → `FAIL 0` at the end of every phase. Per ASM-006, a failure here is a defect
  in the change, never a signal to re-pin.
- **TEST-006:** `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`
  → `FAIL 0` after PHASE-03, PHASE-05 and PHASE-06.
- **TEST-007:** `grep -c 'pdp8-2023' scripts/generate_refresh_audit.R` → `0`
  after PHASE-02 (it returns `4` before it).
- **TEST-008:** `awk -F',' 'NR>1{print $6}' engagements/sdb-rehearsal/output/financed_emissions/financed_emissions.csv | sort -u`
  → contains `"sdb-rehearsal"` and never `"mcb-demo"` after PHASE-03.
- **TEST-009:** `Rscript -e "roxygen2::roxygenise()"; git diff --exit-code NAMESPACE`
  → exits `0` after PHASE-04.
- **MANUAL-001:** After PHASE-01, deliberately edit a single numeric table cell
  in `reports/Financed_Emissions.html`, run
  `Rscript tools/verify_refactor.R --skip-refresh`, and confirm it reports that
  file as **drift** and exits non-zero. Restore the file with
  `git checkout -- reports/Financed_Emissions.html`. This is the proof that the
  new gate actually works rather than merely running.
- **MANUAL-002:** After PHASE-01, deliberately remove the word "synthetic" from
  `output/disclosure/disclosure_pack.html`, run
  `Rscript tools/verify_refactor.R --invariants`, and confirm INV-010 fails
  naming that file. Restore with `git checkout --`.
- **MANUAL-003:** After PHASE-02, open `reports/pipeline_refresh_audit.html` in
  a browser and confirm the "Input Checksums (MD5)" table names
  `data/scenarios/pdp8-2025-adjusted/` files, and that the step-timing table's
  statuses agree with `dashboard/data/pipeline_manifest.json`.
- **MANUAL-004:** After PHASE-06, run `python -m streamlit run dashboard/app.py`
  and confirm the new Financed Emissions page renders the data-quality
  composition beside every emissions total, shows the Scope 3 exclusion note,
  and carries the synthetic-data banner.
- **OBS-001:** After PHASE-02, confirm the weekly refresh workflow still gates
  correctly by reading `.github/workflows/refresh.yml`: the
  `Rscript tools/verify_refactor.R --skip-refresh` step now also evaluates the
  gated HTML deliverables, so a weekly run that corrupts a report will block the
  auto-commit rather than committing it. No workflow edit is required for this;
  verify by inspection that the step still runs before the `git add`.

## Risks and Alternatives

- **RISK-001:** PHASE-01's HTML gate may prove noisy in practice — a
  nondeterministic element in a report (an unstable sort, a locale-dependent
  number format) would surface as recurring false drift. Mitigation: the phase's
  exit criteria require a clean `--skip-refresh` run on the unmodified tree, and
  a second clean run after a full `Rscript scripts/pipeline_refresh.R`. If a
  specific report proves nondeterministic, fix the nondeterminism — that is a
  real defect worth finding — rather than removing the file from
  `GATED_HTML_PATHS`.
- **RISK-002:** The phases are ordered so each is verified by the one before it,
  which means stopping early leaves later findings unaddressed. If time runs
  short, drop phases from the end, not the middle. The minimum defensible subset
  is PHASE-01 through PHASE-03: the gate exists, the provenance chain tells the
  truth, and no client deliverable carries another bank's identifier.
- **RISK-003:** PHASE-05's vectorization is the only change in this plan that
  touches a hot path feeding committed fixtures. Mitigation: TASK-05-05 runs the
  byte-identity check immediately after the change and before any other work in
  the phase, and ASM-007 mandates reverting rather than re-pinning if identity
  cannot be preserved.
- **RISK-004:** Regenerating `man/` in PHASE-04 produces a large diff that could
  hide a meaningful change. Mitigation: review `git diff --stat man/` for
  *deletions* specifically; added files are expected, removed ones are not.
- **ALT-001:** Lead with the dashboard surfacing (PHASE-06's TASK-06-03 through
  TASK-06-06) as the most commercially visible improvement. Rejected as the
  lead: publishing the PCAF inventory more prominently while its provenance
  chain contradicts itself increases exposure rather than reducing it. It stays
  in the plan, at the end.
- **ALT-002:** Consolidate the 12 report generators' seven duplicated `<style>`
  blocks into a shared shell in `R/report_toolkit.R`. Rejected for this plan on
  its own merits: with HTML currently ungated it is the largest unverifiable
  change available in the repository. It becomes routine once PHASE-01 lands and
  is the natural first candidate for the next wave.
- **ALT-003:** Fix `data_source` (PHASE-03) inside a full golden refreeze
  alongside any future number-moving change, following the repo's batched-refreeze
  discipline. Rejected: `data_source` feeds no score, so the batching rationale
  (one expensive re-verification instead of several) does not apply, and it
  would leave a client-facing mislabelling in place for no benefit.
- **ALT-004:** Add a third engagement to prove multi-tenancy rather than
  bringing `sdb-rehearsal` to parity. Rejected: a third engagement multiplies
  committed fixtures and CI time, while parity on the existing one costs three
  config keys and makes the CI job's existing claim honest.
- **ALT-005:** Optimize `r2dii.match::match_name()` in the same phase that
  measures it. Rejected: it is currently unmeasured, and Wave 3's own `ALT-005`
  established the discipline — measure first, optimize on evidence. PHASE-05
  produces the evidence; the decision belongs to the next wave.

## Suggested Next Step

Execute PHASE-01. It has no dependencies, every task is additive, and it must
pass against the repository exactly as it stands today — which makes it a clean,
self-checking start. Confirm all four of its exit criteria, and run MANUAL-001
and MANUAL-002 to prove the new gate actually catches what it is meant to catch,
before beginning PHASE-02. Do not start a phase whose dependency phase has an
unmet exit criterion.
