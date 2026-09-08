---
title: "Wave 5: Gate Enforcement, Deliverable Truth, and the Read-Side Seam"
date: "2026-09-07"
status: "draft"
request: "Turn research/2026-09-07-wave5-gate-enforcement-and-deliverable-truth-brainstorm.md into a multi-phase implementation plan, sequenced as APP-201: make CI actually execute, correct the VND display defect in the published PACTA report, add fact assertions to the deliverable gate, retire the orphan deliverable and fix documentation drift, give the step registry a dependency contract, and make the dashboard snapshot root a parameter."
plan_type: "multi-phase"
research_inputs:
  - "research/2026-09-07-wave5-gate-enforcement-and-deliverable-truth-brainstorm.md"
  - "research/2026-09-01-wave4-deliverable-trust-and-scale-followthrough-brainstorm.md"
---

# Plan: Wave 5 — Gate Enforcement, Deliverable Truth, and the Read-Side Seam

## Objective

Make this repository's verification machinery load-bearing. Today every gate
passes locally and **every GitHub Actions run has failed since 2026-07-10**, so
nothing is enforced anywhere but one developer laptop; and the gate that does run
compares each deliverable to its own committed copy, so it froze a headline
figure that was already wrong — the published PACTA report tells a bank its
portfolio is `2.502e+10 tỷ VND (~$1000800 tỷ USD)` when the true figure is
`25,020.0 bn VND (~US$0.95 bn)`. This plan makes CI execute, corrects the number,
adds assertions so a wrong number fails a gate instead of being preserved by one,
and closes four structural gaps behind it.

## Context Snapshot

- **Current state:** Version `0.6.0`, `main` at `b1d53e1`. Two engagements
  (`mcb-demo`, `sdb-rehearsal`) run through one orchestrator
  (`scripts/run_engagement.R` + `R/engagement_plan.R` + `R/step_registry.R` +
  `R/step_runner.R`), 16 steps for MCB in 68.8 seconds. Locally:
  `Rscript -e "testthat::test_dir('tests/testthat')"` reports
  `FAIL 0 | WARN 5 | SKIP 1 | PASS 756`; `python -m pytest dashboard/tests`
  reports `69 passed`; `Rscript tools/verify_refactor.R --invariants` prints
  `INVARIANTS PASS` for INV-001..012. In CI, all four R-dependent jobs fail at
  the dependency-install step and have done so on every run for two months.
- **Desired state:** Every GitHub Actions job passes on a clean push. No money
  figure in the repository is rendered outside `R/format_money.R`. Every gated
  HTML deliverable ships a machine-readable facts sidecar whose values are
  recomputed from their source CSV and whose rendered strings are asserted to
  appear in the HTML. No deliverable is published from a retired generator. The
  step registry declares what each step reads and writes, and a mis-ordered or
  filtered run is refused or flagged instead of silently reading stale inputs.
  The Streamlit app reads whichever snapshot directory it is pointed at.
- **Key repo surfaces:** `.Rprofile`; `.github/workflows/ci.yml`;
  `.github/workflows/refresh.yml`; `scripts/ci/install_deps.R`;
  `R/pacta_core.R`; `R/format_money.R`; `R/report_facts.R` (new);
  `tools/verify_refactor.R`; `R/step_registry.R`; `R/engagement_plan.R`;
  `scripts/generate_financed_emissions.R`; `dashboard/lib/loaders.py`;
  `dashboard/pages/6_Intake_Wizard.py`; `reports/report_catalog.json`;
  `engagements/mcb-demo/engagement_config.json`; `README.md`;
  `activeContext.md`; `NEWS.md`.
- **Out of scope:** The KPI/SPT input pack for the SLL shortlist; automotive
  TRISK coverage (6 of 23 priority borrowers carry `composite_partial = TRUE`);
  ABCD intake validation symmetry in the PACTA path; unit tests for
  `scripts/generate_bidv_report.R`; the report-shell/CSS consolidation across the
  12 HTML generators; the full-chain scale benchmark; migrating off Streamlit;
  making the synthetic fixture deliberately imperfect (it would move every golden
  number); refactoring `R/pacta_core.R` or `R/trisk_core.R` for their own sake
  beyond the display-layer changes named in PHASE-02.

## Environment & Conventions

- **Stack:** R 4.5 for the entire analytical pipeline (no Node, no npm).
  Python 3.12 for the Streamlit dashboard. R dependencies are listed in
  `DESCRIPTION` (`Imports` + `Suggests`), recorded in `renv.lock`, and actually
  installed by `scripts/ci/install_deps.R`. Python dependencies are pinned in
  `dashboard/requirements.lock`. The R code is also structured as a loadable
  package named `pactatrisk` (`DESCRIPTION`, `NAMESPACE`, `man/`), version
  `0.6.0`.
- **Setup:**
  - R: `Rscript scripts/ci/install_deps.R` (the supported path — see ASM-001;
    `renv` is present in the repo but has never been activated).
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
  - Public MCB demo refresh (68.8 s, 16 steps):
    `Rscript scripts/pipeline_refresh.R`
  - Any engagement:
    `Rscript scripts/run_engagement.R --config engagements/<slug>/engagement_config.json`
    Add `--dry-run` to print the resolved step list without executing or writing.
  - Dashboard: `python -m streamlit run dashboard/app.py`
- **Test:**
  - Full R suite: `Rscript -e "testthat::test_dir('tests/testthat')"` — expected
    at the start of this plan: `FAIL 0 | WARN 5 | SKIP 1 | PASS 756`. The 5
    warnings are `package 'X' was built under R version 4.5.3` environment
    warnings, not failures.
  - Single R test file:
    `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`
  - Wrapper that also lists environment-gated tests it skipped:
    `Rscript tools/run_tests.R`
  - The one skipped test regenerates the second engagement and is opt-in:
    `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`
  - Full Python suite: `python -m pytest dashboard/tests` — expected `69 passed`.
  - Single Python test: `python -m pytest dashboard/tests/test_loaders.py -v`
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
    to 5e12; the MCB book totals 25,020,000,000,000 VND across 43 loans. Never
    divide or multiply except through the display formatters in
    `R/format_money.R`. Correcting violations of this rule is PHASE-02's entire
    subject.
  - **Vietnamese counterparty names are matched after ASCII normalization.** Use
    `normalize_vn_name()` from `R/matching_helpers.R`, which wraps
    `stringi::stri_trans_general(x, "Latin-ASCII")`. CSVs are UTF-8 with no BOM.
    Report HTML is written with `writeLines(..., useBytes = TRUE)`.
  - **Byte-identity is verified with `git diff`, never with raw `md5sum` on
    working-tree files.** Git applies `core.autocrlf` normalization, so a file
    that is byte-identical after normalization can have a different raw digest
    across Windows and Linux. `tools/verify_refactor.R` is the canonical
    implementation — extend it rather than hand-rolling a comparison.
  - **The engagement-config convention.** Scripts source `R/engagement_config.R`
    and call `cfg <- load_engagement_config(get_config_arg())`. Passing no
    `--config` flag yields the built-in Mekong Commercial Bank defaults. Never
    hardcode a new path outside this mechanism.
  - **Config validation rejects unknown keys.** Any new config key added by this
    plan must be registered in `.default_engagement_config()`
    (`R/engagement_config.R`) or every config using it fails validation.
  - **`jsonlite` empty-value round-trip trap.** An optional config field written
    with `jsonlite::toJSON(..., auto_unbox = TRUE)` and read back with
    `jsonlite::read_json(..., simplifyVector = TRUE)` comes back as an empty
    `list()` whether it started as `NULL` or as `character(0)`. Always test "not
    configured" with `length(x) == 0`, never with `is.null(x)` or
    `is.character(x)`.
  - **No casual new pipeline dependencies.** Dev-only tooling (already in
    `DESCRIPTION`'s `Suggests`: `testthat`, `roxygen2`, `devtools`) is the only
    category added without a strong reason. `yaml` was deliberately rejected in
    favour of JSON via `jsonlite`. Every task in this plan is implementable with
    the currently declared packages.
  - **Windows PowerShell 5.1 has no `&&` chaining.** Use separate commands or
    `;` sequencing. Prefer the portable `Rscript -e "..."` one-liners used
    throughout this repository, which run identically on Windows and Linux.
  - **`attic/` is retired reference code** — never sourced by any pipeline,
    never tested, and modified only to receive newly retired scripts.
  - **`dashboard/data/` is the frozen public snapshot**; only
    `scripts/refresh_dashboard_data.R` may write it, and only an engagement with
    `public_snapshot_allowed: true` may publish there.
  - **Every generated artifact must carry a disclaimer stating the data is
    synthetic and illustrative.** Enforced by INV-010.
  - **Changelog entries must not quote test counts.** `NEWS.md` is prose, and a
    hand-typed pass count silently goes stale. Write "full R suite green
    (FAIL 0)" rather than a specific PASS number.
- **Repo map:**
  ```
  R/                    shared modules sourced by scripts/ (engagement_config,
                        engagement_plan, step_registry, step_runner, pacta_core,
                        trisk_core, prioritization_core, severity_scoring,
                        financed_emissions, target_setting, sll_readiness,
                        report_toolkit, report_fingerprint, run_history,
                        format_money, matching_helpers, sector_registry)
  scripts/              pipeline stages, 12 HTML report generators,
                        run_engagement.R orchestrator, pipeline_refresh.R wrapper,
                        ci/install_deps.R
  tools/                verify_refactor.R (byte-identity + invariants gates),
                        run_tests.R, benchmark_scale.R, generate_scale_fixture.R,
                        render_pdf.R
  data/                 synthetic input CSVs; data/scenarios/<vintage>/ holds
                        the scenario pathway files (pdp8-2023, pdp8-2025-adjusted)
  synthesis_output/     PACTA, TRISK and prioritization outputs
  output/               engagement scoring, letters, disclosure, financed
                        emissions, TRISK inputs
  reports/              rendered self-contained HTML reports + report_catalog.json
  engagements/<slug>/   per-engagement config and committed regression fixtures
  dashboard/            Streamlit app (app.py, pages/, lib/, tests/) and its
                        frozen snapshot dashboard/data/
  tests/testthat/       R test suite (25 files)
  .github/workflows/    ci.yml (4 jobs), refresh.yml (weekly, auto-commits)
  ```

## Research Inputs

- From `research/2026-09-07-wave5-gate-enforcement-and-deliverable-truth-brainstorm.md`:
  - **CI has failed on every run since 2026-07-10.** `gh run list --limit 60`
    returns one success (a `Refresh pipeline data` run on 2026-07-10, which
    produced commit `9255692`) and roughly thirty failures since, including the
    2026-09-07 scheduled refresh and the 2026-09-06 CI push. Job breakdown of the
    latest CI run: `python-tests: success`, and `r-tests`, `byte-identity`,
    `sdb-engagement` all `failure`.
  - **The exact failure** is in the `r-lib/actions/setup-renv@v2` step:
    `Error in contrib.url(repos, type) : trying to use CRAN without setting a mirror`,
    `Calls: install.packages -> startsWith -> contrib.url`, `Execution halted`.
    Root cause: `.Rprofile` contains only the single commented line
    `# source("renv/activate.R")`, and `git log --follow -- .Rprofile` shows one
    commit — renv has never been active in this project, so the action bootstraps
    into an uninitialized renv with no repository configured.
  - **`scripts/ci/install_deps.R` already solves this** (lines 22-26 fall back to
    `c(CRAN = "https://cloud.r-project.org")` when no repository is configured,
    and it installs `trisk.model` from a pinned commit tarball that `renv.lock`
    cannot restore from CRAN). CI does not use it.
  - **`R/pacta_core.R` never migrated to whole VND in Wave 2.** It does not
    source `R/format_money.R` at all, and divides whole VND by 1000 while
    labelling the result "bn VND" / "tỷ VND" at lines 68, 70, 131, 280, 327, 772,
    786, 909, 919, 925, 929 and 1118-1119. Above 1e15,
    `format(round(x), big.mark = ",")` also falls back to scientific notation,
    which is why the rendered value is `2.502e+10` rather than a merely-wrong
    `25,020,000,000`.
  - **The report contradicts itself, which confirms the diagnosis.** Line 1251
    carries a hand-written constant — "Ngành điện chiếm 63% danh mục MCB
    (15,750 tỷ VND)" — and 15,750 tỷ VND is exactly 63% of the true 25,020 tỷ
    VND. The hardcoded narrative is on the correct scale; every computed figure
    around it is not.
  - **The fix moves no golden number.** Every committed CSV header under
    `synthesis_output/vietnam/`, `dashboard/data/pacta/`, `output/engagement/`
    and `synthesis_output/prioritization/` was checked for a scaled column; none
    exists. `total_bn_vnd` at `R/pacta_core.R:131` and `:280` is printed to the
    console, never written to a file.
  - **Wave 4's DEC-001 was only half-delivered.** It committed to "hash the
    remainder, **and** pin a small set of content assertions per deliverable (the
    synthetic-data disclaimer is present; named headline figures match the CSV
    they came from)". Only the disclaimer half exists (INV-010). Nothing anywhere
    asserts a number, so `.html_is_timestamp_only()` — which compares the working
    tree to the HEAD blob — preserves a wrong committed value indefinitely.
  - **`reports/PACTA_Synthesis_Report.html` is generated only by
    `attic/pacta_synthesis.R`.** It is nonetheless in `GATED_HTML_PATHS`, in
    `DISCLAIMER_HTML_PATHS`, in mcb-demo's `published_reports`, copied into
    `dashboard/data/reports/`, and rendered inline to every public visitor.
    `git log` on the file returns a single commit: `f6597e5 first commit`.
  - **The step registry encodes what to run, never what a step needs.**
    Dependencies exist only as comments ("reads
    `output/engagement/engagement_priority.csv`, so it must run after
    `engagement_scoring`"). `resolve_step_list()` accepts any `cfg$steps` order,
    and `filter_step_list(steps, only = "financed_emissions")` will run that step
    alone against a stale CSV and exit 0.
  - **The dashboard can only ever read `dashboard/data`** because
    `dashboard/lib/loaders.py:10-17` computes `DATA_DIR` at import time. The
    documented consequence is `docs/private-instance-deploy.md`, which tells
    operators to clone the whole repository per bank — a fork per client that
    never receives another fix.
  - **The intake wizard leaks a client's raw workbook.**
    `dashboard/pages/6_Intake_Wizard.py:57-72` writes the upload to a
    `NamedTemporaryFile(delete=False)`, then on the XLSX path rebinds `tmp_path`
    to the converted CSV, so the original workbook is never unlinked; the single
    `tmp_path.unlink()` at line 175 is also outside any `finally`, so every
    `st.stop()` on a validation error skips cleanup entirely.
  - **A six-commit orchestrator refactor (`b75e676`..`b1d53e1`) is unrecorded**
    in `plans/` and `NEWS.md`. It created `R/engagement_plan.R` and moved CLI
    parsing, step resolution, the intake split, the manifest policy, the guard
    rail and the banner out of `scripts/run_engagement.R`.
- From `research/2026-09-01-wave4-deliverable-trust-and-scale-followthrough-brainstorm.md`:
  - `classify_path()` in `tools/verify_refactor.R` returns `"timestamp-class"`
    for every `.html` file that is not in `GATED_HTML_PATHS`, and PNG files
    always return `"png-noise"` — so published charts are outside every gate.
  - `R/report_fingerprint.R`'s `normalize_report_html()` must apply its
    embedded-image rule **before** its git-SHA rule: a base64 payload contains
    long runs of `[0-9a-f]`, so the SHA rule otherwise punches `<SHA>` tokens
    into the middle of image payloads.

## Assumptions and Constraints

- **ASM-001:** `renv` has never been active in this project and `renv.lock`
  cannot restore `trisk.model` (a pinned GitHub commit tarball, not a CRAN
  package). — **BINDING DEFAULT:** CI installs R dependencies with
  `Rscript scripts/ci/install_deps.R --dev` behind an `actions/cache` step, and
  `r-lib/actions/setup-renv@v2` is removed from every job. `.Rprofile` is left
  exactly as it is (the commented line is not uncommented). `renv.lock` is kept
  as a declarative manifest that INV-008 continues to check.
- **ASM-002:** The GitHub Actions failures are environmental, not a genuine gate
  failure — the same suites, invariants and byte-identity check all pass locally
  at `b1d53e1`. — **BINDING DEFAULT:** if the first green-dependency CI run
  surfaces a *real* Linux-vs-Windows difference (line endings, locale collation
  of Vietnamese names, `format()` locale), fix the normalization or the code so
  the check is correct on both platforms. Do **not** add the failing artifact to
  an exclusion list, and do **not** use `refresh.yml`'s `allow_drift: true` to
  bypass it. Record what was found in `NEWS.md`.
- **ASM-003:** The correct US-dollar reference rate for display is the
  engagement config's `inputs$fx_rate_usd_vnd` (26300 in both committed
  configs), not the `25000` literal currently hardcoded at `R/pacta_core.R:70`
  and `:1119`. — **BINDING DEFAULT:** read it from `cfg` where `cfg` is in
  scope; where it is not (inside `pacta_build_report()`), pass it in as a new
  parameter with default `26300`.
- **ASM-004:** The hardcoded per-technology rows in the PACTA report's portfolio
  table (`15,750`, `4,500`, `1,000`, `250` at `R/pacta_core.R:1236-1243`,
  `:1251`, `:1283`) are already on the correct whole-VND-billions scale and are
  correct for the current synthetic loanbook. — **BINDING DEFAULT:** leave them
  unchanged in this plan; correcting the computed figures makes the table
  internally consistent. Note their staleness risk in `NEWS.md` and leave
  replacing them with computed values to a later wave.
- **ASM-005:** Facts sidecars must contain no timestamp, git SHA, or any other
  per-run-volatile value, or they would themselves become churn the gate has to
  normalize. — **BINDING DEFAULT:** a sidecar contains only report path,
  generator path, and the fact list; nothing else.
- **ASM-006:** `reports/PACTA_Synthesis_Report.html` is a superseded
  methodology reference (its own catalog entry classifies it
  `"category": "methodology_reference"`), not a live deliverable. —
  **BINDING DEFAULT:** retire it rather than restore its generator.
- **ASM-007:** The environment variable naming convention for the dashboard is
  an uppercase flag read with `os.environ.get`, matching `BYOL_INTAKE`,
  `OUTPUTS_LAYER`, `TRISK_LIVE_RERUN` and `R_RSCRIPT`. — **BINDING DEFAULT:** the
  new snapshot-root variable is `PACTATRISK_SNAPSHOT_DIR` and the new picker gate
  is `ENGAGEMENT_PICKER`; both default to today's behaviour when unset.
- **CON-001:** Every change touching `scripts/` or `R/` must leave every
  `synthesis_output/vietnam/*.csv` byte-identical to its pre-change content,
  verified with `Rscript tools/verify_refactor.R`. PHASE-02 is the single,
  deliberate exception, and only for one HTML file and two PNG files — no CSV may
  change.
- **CON-002:** `tests/testthat/test_golden_numbers.R` pins exact values (e.g.
  `engagement_priority.csv` rank-1 `name_abcd == "Nghi Son Power LLC"`,
  `composite_score[1] == 0.9816483381`). It must stay green through every phase.
  A change that moves a golden number is out of scope for this plan.
- **CON-003:** `dashboard/data/` may be written only by
  `scripts/refresh_dashboard_data.R`. PHASE-06's snapshot-root change is
  read-side only.
- **DEC-001:** Fix CI by adopting the repository's own documented installer, not
  by reviving renv (see ASM-001).
- **DEC-002:** Treat the VND display fix as a reviewed refreeze of one HTML file
  and two PNGs, not a golden refreeze.
- **DEC-003:** Route every money render in `R/pacta_core.R` through
  `R/format_money.R`; delete the hardcoded `25000` rather than parameterize it
  separately.
- **DEC-004:** Build the fact-assertion half of Wave 4's DEC-001 as a sidecar
  JSON per report, checked by a new invariant — not by regex-parsing HTML inside
  the invariant, and not by embedding assertions in each generator's own tests.
- **DEC-005:** Retire `PACTA_Synthesis_Report.html` rather than resurrect its
  generator.
- **DEC-006:** Derive `report_catalog.json`'s displayed date from the artifact's
  filesystem modification time, not from a hand-typed string.
- **DEC-007:** Put `requires`/`produces` validation in `plan_engagement_run()`
  (`R/engagement_plan.R`), where planning policy now lives, not in `run_steps()`.
  A missing-input check at execution time is a second, cheaper guard.
- **DEC-008:** Make the dashboard snapshot root an environment variable whose
  default is today's path, so the public deployment sets nothing and behaves
  identically.

## Specification

### S1 — Facts sidecar schema (PHASE-03)

A sidecar lives beside its report, with the same basename and the extension
`.facts.json`. For `reports/PACTA_Vietnam_Bank_Report.html` the sidecar is
`reports/PACTA_Vietnam_Bank_Report.facts.json`.

```json
{
  "report": "reports/PACTA_Vietnam_Bank_Report.html",
  "generated_by": "scripts/pacta_vietnam_scenario.R",
  "facts": [
    {
      "name": "portfolio_total_vnd",
      "value": 25020000000000,
      "unit": "VND",
      "rendered": "25,020.0 bn VND",
      "source": {
        "csv": "data/vietnam_loanbook.csv",
        "column": "loan_size_outstanding",
        "agg": "sum"
      }
    }
  ]
}
```

Field meanings, all mandatory except `unit`:

- `report` — repo-relative path of the HTML file this sidecar describes.
- `generated_by` — repo-relative path of the script that wrote both files.
- `facts[].name` — snake_case identifier, unique within the sidecar.
- `facts[].value` — the numeric value as computed by the generator.
- `facts[].unit` — free text (`"VND"`, `"tCO2e"`, `"loans"`), or omitted.
- `facts[].rendered` — the exact formatted substring that must appear in the
  HTML. For money this is the output of `format_vnd_bn()` or
  `format_vnd_full()`.
- `facts[].source.csv` — repo-relative path of the CSV the value derives from.
- `facts[].source.column` — column name; ignored when `agg` is `"nrow"`.
- `facts[].source.agg` — one of exactly three verbs:
  - `"sum"` → `sum(as.numeric(df[[column]]), na.rm = TRUE)`
  - `"nrow"` → `nrow(df)`
  - `"n_distinct"` → `length(unique(df[[column]]))`

### S2 — INV-013 checking rule (PHASE-03)

For every path `p` in `GATED_HTML_PATHS`, let `s` be `p` with `.html` replaced
by `.facts.json`. If `s` does not exist, skip `p` (a report without a sidecar is
not yet covered; PHASE-03 adds two, and later waves add the rest). If `s` exists:

1. `p` must exist on disk. Otherwise: violation `"<p> has a facts sidecar but no report"`.
2. For each fact:
   a. `source.csv` must exist. Otherwise: violation naming the missing CSV.
   b. Recompute the value per S1's `agg` verb. Compare to `value` with
      `abs(recomputed - value) <= 1e-9 * max(1, abs(value))`. On mismatch:
      violation `"<p>: fact '<name>' is <value> but <csv> gives <recomputed>"`.
   c. `rendered` must occur as a literal substring of the file contents of `p`
      read with `readLines(p, warn = FALSE, encoding = "UTF-8")` collapsed by
      `"\n"`. On failure: violation
      `"<p>: fact '<name>' rendered as '<rendered>' does not appear in the report"`.

INV-013 passes when no violation is collected.

### S3 — Step dependency contract (PHASE-05)

Each `step_registry()` entry gains two optional fields, each a function of the
engagement config returning a character vector of repo-relative paths:

- `produces_fn = function(cfg) character()` — files the step writes.
- `requires_fn = function(cfg) character()` — files the step reads that another
  step in the registry produces. Static inputs under `data/` are **not** listed;
  only inter-step dependencies.

Validation rule applied by `validate_step_dependencies(steps, cfg)`:

For each step `i` in the resolved list, for each path `r` in its `requires_fn`:
if any step `j` in the **full registry** produces `r`, and `j` appears in the
resolved list at a position **after** `i`, that is a hard ordering violation —
`stop()` naming both step names and the file. If no step in the resolved list
produces `r`, the step depends on an artifact this run will not create; that is
a *warning* (not an error), because a filtered run legitimately relies on a
previous run's output — and the warning text must name the file and say it will
be read from a previous run.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Make CI actually execute | None | `ci.yml` and `refresh.yml` install deps via `install_deps.R`; `--dev` flag; CI badge; first green run in 2 months |
| PHASE-02 | Correct the VND display layer | PHASE-01 | `R/pacta_core.R` routed through `R/format_money.R`; corrected PACTA report + 2 PNGs; no golden number moved |
| PHASE-03 | Assert facts, not just sameness | PHASE-02 | `R/report_facts.R`; 2 facts sidecars; INV-013 |
| PHASE-04 | Deliverable inventory truth | PHASE-03 | Orphan report retired; catalog dates derived; `activeContext.md`, `NEWS.md`, `README.md` reconciled |
| PHASE-05 | Step dependency contract | PHASE-04 | `requires_fn`/`produces_fn` in the registry; `validate_step_dependencies()`; `--strict-deps` |
| PHASE-06 | Read-side snapshot seam | PHASE-05 | `PACTATRISK_SNAPSHOT_DIR`; engagement picker; intake temp-file leak fixed |

## Detailed Phases

### PHASE-01 - Make CI Actually Execute

**Goal**
Every GitHub Actions job passes on a clean push, for the first time since
2026-07-10, so that every gate this repository has built is enforced somewhere
other than one developer laptop.

**Tasks**
- [ ] TASK-01-01: In `scripts/ci/install_deps.R`, add a `dev_packages` vector
      immediately after the existing `cran_packages` vector, containing exactly
      `c("testthat", "roxygen2", "devtools")` — all three are already declared in
      `DESCRIPTION`'s `Suggests`, so INV-008 stays green once TASK-01-03 lands.
      Install them only when the script is invoked with a `--dev` argument:
      read `commandArgs(trailingOnly = TRUE)` and set
      `want_dev <- "--dev" %in% args`. Keep the existing repository fallback
      (lines 22-26) and the `trisk.model` tarball install exactly as they are.
      Extend the final `still_missing` check to include `dev_packages` when
      `want_dev` is TRUE.
- [ ] TASK-01-02: In `scripts/ci/install_deps.R`, update the header comment to
      state that this script — not `renv` — is the supported dependency install
      path for CI and for local setup, and that `.Rprofile`'s renv activation is
      intentionally left commented out.
- [ ] TASK-01-03: In `tools/verify_refactor.R`, extend
      `.parse_install_deps_packages()` (line 632) so it unions the
      `dev_packages` literal alongside `cran_packages`:
      `dev <- .extract_c_literal_from_file(path, "dev_packages")` and include it
      in the returned vector when non-NULL. Leave the `trisk.model` special case
      unchanged. Without this, INV-008 never sees the dev packages, which is a
      silent hole rather than a failure — the extension keeps the invariant
      honest.
- [ ] TASK-01-04: In `.github/workflows/ci.yml`, in **each** of the three R jobs
      (`r-tests`, `sdb-engagement`, `byte-identity`), delete the step
      `- name: Restore R dependencies via renv` / `uses: r-lib/actions/setup-renv@v2`
      and replace it with the three steps given verbatim in **File Changes**
      below (library directory, `actions/cache@v4`, `install_deps.R --dev`). Add
      the job-level `env: R_LIBS_USER: ${{ github.workspace }}/.rlib` block to
      each of those three jobs. Leave `python-tests` untouched — it is the only
      job that currently passes.
- [ ] TASK-01-05: In `.github/workflows/ci.yml`'s `r-tests` job, delete the
      inline `install.packages('devtools')` and `install.packages('roxygen2')`
      fallbacks from the `Verify pactatrisk package loads` and
      `NAMESPACE is up to date with roxygen` steps — TASK-01-01 now guarantees
      both are present, and an inline `install.packages()` with no configured
      repository is the same failure mode this phase is removing. The steps
      become `Rscript -e "devtools::load_all('.'); cat('pactatrisk loads OK\n')"`
      and `Rscript -e "roxygen2::roxygenise()"` respectively; keep the
      surrounding `cp`/`diff` logic of the NAMESPACE step exactly as it is.
- [ ] TASK-01-06: Apply the identical replacement in `.github/workflows/refresh.yml`'s
      single `refresh` job: same `env` block, same three steps replacing
      `setup-renv`. Leave every other step (`Run pipeline refresh`,
      `Regression-test refreshed outputs`, `Cross-artifact invariants`,
      `Byte-identity drift gate`, `Commit refreshed snapshot`) exactly as it is.
- [ ] TASK-01-07: Add a failure-visibility step to `.github/workflows/refresh.yml`
      as the last step of the `refresh` job:
      `- name: Report failure` with `if: failure()` and
      `run: echo "::error::Weekly refresh failed — the public snapshot was NOT updated. See the failing step above."`.
      Two months of silent red is the reason this step exists.
- [ ] TASK-01-08: Add a CI status badge as the second line of `README.md`,
      immediately under the `# PACTA + TRISK Vietnam …` heading:
      `[![CI](https://github.com/tah-allotrope/pacta-trisk/actions/workflows/ci.yml/badge.svg)](https://github.com/tah-allotrope/pacta-trisk/actions/workflows/ci.yml)`.
      A red badge at the top of the README is the cheapest instrument that would
      have caught this outage.
- [ ] TASK-01-09: Push the branch and confirm every job of the resulting CI run
      passes. If a job fails for a reason that is **not** dependency
      installation, apply ASM-002: fix the underlying cross-platform difference,
      do not suppress the check.

**File Changes**
- `scripts/ci/install_deps.R` (modify): add `dev_packages` and the `--dev`
  argument handling; extend the `still_missing` assertion; update the header
  comment. **Leave alone:** the `cran_packages` contents, the `repos` fallback
  block (lines 22-26), and the `trisk.model` tarball URL and install.
- `tools/verify_refactor.R` (modify): `.parse_install_deps_packages()` only.
  **Leave alone:** every `inv_*()` function, `classify_path()`,
  `GATED_HTML_PATHS`, `DISCLAIMER_HTML_PATHS`.
- `.github/workflows/ci.yml` (modify): in `r-tests`, `sdb-engagement` and
  `byte-identity`, add the job-level `env` block and replace the `setup-renv`
  step with:
  ```yaml
      - name: Create R library directory
        run: mkdir -p "$R_LIBS_USER"

      - name: Cache R library
        uses: actions/cache@v4
        with:
          path: ${{ github.workspace }}/.rlib
          key: ${{ runner.os }}-R4.5-${{ hashFiles('scripts/ci/install_deps.R') }}

      - name: Install R dependencies
        run: Rscript scripts/ci/install_deps.R --dev
  ```
  **Leave alone:** the `python-tests` job in its entirety, the `setup-r` steps
  (`r-version: "4.5"`, `use-public-rspm: true`), the `apt-get` system-dependency
  steps, and the `Assert no cross-contamination` step in `sdb-engagement`.
- `.github/workflows/refresh.yml` (modify): the same `env` block and step
  replacement in the `refresh` job, plus the new `Report failure` step.
  **Leave alone:** the `schedule` cron (`0 2 * * 1`), the `allow_drift` input,
  and the `Commit refreshed snapshot` script.
- `README.md` (modify): add the CI badge line only.
- `.Rprofile` (leave unchanged): per ASM-001, the commented renv activation stays
  commented. Do not edit this file.

**Function Signatures**
- `.parse_install_deps_packages(root: character(1)) -> character` — the union of
  the `cran_packages` and `dev_packages` literals in
  `scripts/ci/install_deps.R`, plus `"trisk.model"` when that string appears in
  the file; `character(0)` when the file is absent or unparseable.

**Test Specs**
- `Rscript scripts/ci/install_deps.R` on a machine that already has every CRAN
  package → prints `All pipeline R dependencies installed.` and exits 0 without
  attempting to install `devtools`.
- `Rscript scripts/ci/install_deps.R --dev` → same, and additionally verifies
  `testthat`, `roxygen2`, `devtools` are present, erroring with
  `Failed to install: <names>` if any is missing.
- Add to `tests/testthat/test_verify_invariants.R`: a fixture directory
  containing a `scripts/ci/install_deps.R` whose `dev_packages <- c("roxygen2")`
  and whose `DESCRIPTION` lists `roxygen2` under `Suggests` →
  `inv_dependency_manifests_agree(fixture_root)$ok` is `TRUE`.
- Same fixture with `dev_packages <- c("notapackage")` and a `DESCRIPTION` that
  does not list it → `$ok` is `FALSE` and `$detail` contains
  `"'notapackage' is used by (scripts/ci/install_deps.R) but missing from DESCRIPTION Imports"`.

**Dependencies**
- None. This phase must land before every other phase, because until it does, no
  later phase's exit criteria can be verified anywhere but locally.

**Exit Criteria**
- [ ] `grep -c "setup-renv" .github/workflows/ci.yml .github/workflows/refresh.yml`
      returns `0` for both files.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS`
      (INV-008 still holds with the new `dev_packages` vector).
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0` with a
      PASS count strictly greater than 756.
- [ ] A pushed commit produces a GitHub Actions CI run in which all four jobs —
      `python-tests`, `r-tests`, `sdb-engagement`, `byte-identity` — report
      `success`. Verify with
      `gh run list --limit 1 --json conclusion --jq '.[0].conclusion'` → `success`.
- [ ] A manual `workflow_dispatch` of `Refresh pipeline data` (without
      `allow_drift`) completes with conclusion `success`.

**Phase Risks**
- **RISK-01-01:** The first green-dependency run reveals genuine Linux-vs-Windows
  drift in `byte-identity` (line endings, locale collation of Vietnamese names,
  locale-dependent `format()` output). Mitigation: ASM-002 — this is a discovery,
  not a defect in the plan. Fix the normalization or the code so the check is
  correct on both platforms; never add the artifact to an exclusion list, and
  never bypass with `allow_drift: true`.
- **RISK-01-02:** Installing `devtools` from source on a cold Ubuntu runner is
  slow (several minutes). Mitigation: the `actions/cache@v4` step keyed on
  `hashFiles('scripts/ci/install_deps.R')` makes it a one-time cost; the
  `byte-identity` job already carries `timeout-minutes: 30`. If the r-tests job
  approaches its default 360-minute limit on the first run, that is expected for
  the uncached build only.
- **RISK-01-03:** `trisk.model` installs from a GitHub tarball; a network blip
  fails the whole job. Mitigation: the cache means it is fetched once per
  `install_deps.R` change; re-run the job on a transient failure.

### PHASE-02 - Correct the VND Display Layer

**Goal**
Make every money figure `R/pacta_core.R` renders — in the console, in two
published charts, and in the flagship bilingual client report — state the true
whole-VND value through `R/format_money.R`, and convert to USD at the
engagement's configured rate rather than a hardcoded literal.

**Tasks**
- [ ] TASK-02-01: Add `source("R/format_money.R")` to the top of
      `scripts/pacta_vietnam_scenario.R`, alongside its existing
      `source("R/...")` lines, so `format_vnd_bn()` and `vnd_to_billion()` are
      available to every function in `R/pacta_core.R` (which is sourced by that
      script and never runs standalone).
- [ ] TASK-02-02: In `R/pacta_core.R`'s `pacta_load_inputs()`, replace lines
      68-70. The total becomes `total_vnd <- sum(loanbook$loan_size_outstanding)`
      and the message becomes
      `cat(sprintf("  Total portfolio: %s (~$%.2fB USD)\n\n", format_vnd_bn(total_vnd), total_vnd / cfg$inputs$fx_rate_usd_vnd / 1e9))`.
      Expected new output for MCB: `Total portfolio: 25,020.0 bn VND (~$0.95B USD)`.
- [ ] TASK-02-03: In `R/pacta_core.R:131`, change the console-only
      `sector_breakdown` column from
      `total_bn_vnd = round(sum(loan_size_outstanding, na.rm = TRUE) / 1000)` to
      `total_bn_vnd = round(vnd_to_billion(sum(loan_size_outstanding, na.rm = TRUE)), 1)`.
      Keep the column name `total_bn_vnd` and the `arrange(desc(total_bn_vnd))`
      that follows.
- [ ] TASK-02-04: In `R/pacta_core.R:280`, change
      `total_bn_vnd = round(total_outstanding / 1000)` to
      `total_bn_vnd = round(vnd_to_billion(total_outstanding), 1)`.
- [ ] TASK-02-05: In `R/pacta_core.R:327`, change the coverage-pie subtitle to
      `subtitle = paste0("Total: ", format_vnd_bn(outstanding_total), " | ", bank_name, " 2025")`.
      Expected rendered subtitle: `Total: 25,020.0 bn VND | Mekong Commercial Bank 2025`.
- [ ] TASK-02-06: In `R/pacta_core.R:772` and `:786`, change
      `sum(loan_size_outstanding) / 1000` to
      `vnd_to_billion(sum(loan_size_outstanding))` in both the
      `coal_exposure_bn` summarise and the `coal_loans` `exposure_bn` summarise.
      These feed the stranded-risk chart, whose bar labels at line ~808 use
      `paste0(round(exposure_bn), " bn VND")` — leave that expression alone; it
      now labels correct billions.
- [ ] TASK-02-07: In `R/pacta_core.R:802`, change
      `format(round(coal_exposure_bn), big.mark = ",")` to
      `format_vnd_bn(coal_exposure_bn * 1e9)` **or**, preferably, keep
      `coal_exposure_bn` in whole VND throughout and call
      `format_vnd_bn(coal_exposure_vnd)`. Choose the second: rename the local to
      `coal_exposure_vnd`, drop the `vnd_to_billion()` from TASK-02-06's first
      summarise, and convert only at render time. Apply the same treatment to
      `coal_loans$exposure_bn`: keep it as `exposure_vnd` in whole VND, and set
      the ggplot aesthetic to `y = vnd_to_billion(exposure_vnd)` with the bar
      label `paste0(round(vnd_to_billion(exposure_vnd)), " bn VND")` and the axis
      title `y = "Exposure (bn VND)"` unchanged.
- [ ] TASK-02-08: Add an `fx_rate_usd_vnd = 26300` parameter to
      `pacta_build_report()` (`R/pacta_core.R:901`), inserted after
      `report_dir`, and pass `cfg$inputs$fx_rate_usd_vnd` at its call site in
      `scripts/pacta_vietnam_scenario.R`.
- [ ] TASK-02-09: In `pacta_build_report()`, replace line 909 with
      `total_portfolio_vnd <- sum(loanbook$loan_size_outstanding)` and lines 919,
      925, 929 with plain `sum(loan_size_outstanding)` (whole VND), renaming the
      locals `coal_power_bn` → `coal_power_vnd`, `renew_bn` → `renew_vnd`,
      `ev_bn` → `ev_vnd`. The three percentage computations at lines 931-933 are
      ratios and need no change beyond the renames.
- [ ] TASK-02-10: In `pacta_build_report()`'s HTML string, replace every money
      render with a formatter call:
      - line 1118: `format_vnd_bn(total_portfolio_vnd)` in place of
        `format(total_portfolio_bn, big.mark = ",")`, and drop the now-duplicated
        literal ` tỷ VND` that follows it (`format_vnd_bn()` already appends
        `" bn VND"` — see the label-decision entry in **Gotchas**).
      - line 1119: `round(total_portfolio_vnd / fx_rate_usd_vnd / 1e9, 2)` in
        place of `round(total_portfolio_bn / 25000, 1)`.
      - line 1125 (KPI card value) and line 1242 (portfolio table total cell):
        `formatC(vnd_to_billion(total_portfolio_vnd), format = "f", digits = 1, big.mark = ",")`
        — the surrounding markup already supplies the unit label, so these two
        sites take the number without a unit suffix.
      - lines 1152, 1265, 1421: `format_vnd_bn(coal_power_vnd)` in place of
        `format(round(coal_power_bn), big.mark = ",")`, dropping the adjacent
        literal ` tỷ VND`.
      - line 1273: `format_vnd_bn(renew_vnd)` likewise.
      - lines 1399, 1401, 1403: `format_vnd_bn(coal_power_vnd * 0.10)`,
        `* 0.20`, `* 0.35` respectively, dropping no adjacent label (the table
        header already says `(tỷ VND)` — replace that header with `(VND)` since
        the cells now carry their own unit).
      **Leave alone:** line 1283's hardcoded `4500` and the hardcoded
      per-technology rows at 1236-1243 and 1251, per ASM-004.
- [ ] TASK-02-11: In `scripts/pacta_vietnam_scenario.R:91`, replace
      `total_portfolio_bn <- round(sum(inputs$loanbook$loan_size_outstanding) / 1000)`
      with `total_portfolio_vnd <- sum(inputs$loanbook$loan_size_outstanding)`
      and update the `cat(sprintf(...))` at lines 96-97 to
      `format_vnd_bn(total_portfolio_vnd)`. Expected final-summary line:
      `  Loanbook analysed : 43 loans / 25,020.0 bn VND`.
- [ ] TASK-02-12: Run `Rscript scripts/pipeline_refresh.R` from the repo root to
      regenerate every artifact. Use the full refresh, not
      `--only-step pacta_vietnam_scenario`: a filtered run writes a partial
      manifest over the complete public one and the orchestrator will refuse
      without `--allow-partial-manifest`. The full run takes about 69 seconds.
- [ ] TASK-02-13: Run `git diff --name-only` and confirm the changed set is
      exactly: `reports/PACTA_Vietnam_Bank_Report.html`,
      `synthesis_output/vietnam/03_vn_coverage_pie.png`,
      `synthesis_output/vietnam/13_vn_coal_stranded_risk.png`, their
      `dashboard/data/pacta/` copies, plus timestamp-only churn in
      `dashboard/data/pipeline_manifest.json`,
      `reports/pipeline_refresh_audit.html` and
      `reports/refresh_audit_metrics.json`. **If any `.csv` appears in that
      list, stop and investigate — no CSV may change** (CON-001).
- [ ] TASK-02-14: Add a regression test file
      `tests/testthat/test_pacta_report_units.R` per **Test Specs** below.
- [ ] TASK-02-15: Commit the regenerated artifacts as a deliberate, reviewed
      refreeze, with a commit message that states the corrected figure and that
      no golden number moved.

**File Changes**
- `R/pacta_core.R` (modify): lines 68-70, 131, 280, 327, 772, 786, 796-808,
  901 (signature), 909, 919, 925, 929, 1118-1119, 1125, 1152, 1242, 1265, 1273,
  1397-1403, 1421. **Leave alone:** every analytical function
  (`pacta_match_and_prioritize`, `pacta_market_share`, `pacta_sda`,
  `pacta_alignment_gaps`), every CSV write, the hardcoded narrative constants at
  1236-1243 / 1251 / 1283, and `chart_html()`.
- `scripts/pacta_vietnam_scenario.R` (modify): add
  `source("R/format_money.R")`; line 91 and the summary `cat()` at 96-97; pass
  `fx_rate_usd_vnd` to `pacta_build_report()`. **Leave alone:** the step order
  and every other `cat()`.
- `tests/testthat/test_pacta_report_units.R` (create): the unit-regression test.
- `reports/PACTA_Vietnam_Bank_Report.html` (modify, regenerated): the corrected
  report.
- `synthesis_output/vietnam/03_vn_coverage_pie.png`,
  `synthesis_output/vietnam/13_vn_coal_stranded_risk.png` and their
  `dashboard/data/pacta/` copies (modify, regenerated).

**Function Signatures**
- `pacta_build_report(bank_name: character(1), bank_short: character(1), loanbook: data.frame, matched: data.frame, ms_alignment_2030: data.frame, sda_alignment_2030: data.frame, imgs: list, report_dir: character(1), fx_rate_usd_vnd: numeric(1) = 26300) -> character(1)` —
  writes `<report_dir>/PACTA_Vietnam_Bank_Report.html` and returns its path.

**Test Specs**
In `tests/testthat/test_pacta_report_units.R`, sourcing `R/format_money.R` via
`helper-root.R`'s `project_root()`:
- `format_vnd_bn(25020000000000)` → `"25,020.0 bn VND"` (exact string).
- `format_vnd_bn(25020000000000)` does **not** match the regex `"e\\+"` — the
  guard against the scientific-notation regression that produced `2.502e+10`.
- Read `reports/PACTA_Vietnam_Bank_Report.html`; assert it contains the literal
  substring `"25,020.0 bn VND"`.
- Read the same file; assert `grepl("2\\.502e\\+10", html)` is `FALSE` and
  `grepl("1000800", html, fixed = TRUE)` is `FALSE`.
- Read `data/vietnam_loanbook.csv`; assert
  `sum(loanbook$loan_size_outstanding) == 25020000000000` — the anchor the other
  assertions are measured against, so a future loanbook change fails loudly here
  rather than silently invalidating the string assertions.
- Edge case: `format_vnd_bn(NA_real_)` → `"Not available"` (existing behaviour,
  pinned so the refactor cannot lose it).

**Dependencies**
- PHASE-01 — the corrected artifacts must be verified by a CI run that actually
  executes, or the refreeze is unverified.

**Exit Criteria**
- [ ] `grep -c "/ 1000" R/pacta_core.R` returns `0`.
- [ ] `grep -c "25000" R/pacta_core.R` returns `0`.
- [ ] `grep -c "e+10" reports/PACTA_Vietnam_Bank_Report.html` returns `0`.
- [ ] `grep -c "25,020.0 bn VND" reports/PACTA_Vietnam_Bank_Report.html` returns
      at least `1`.
- [ ] `git diff --name-only -- '*.csv'` is empty after the refresh.
- [ ] `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`
      reports `FAIL 0` — no golden number moved.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS`.
- [ ] After committing the regenerated artifacts,
      `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS`.

**Phase Risks**
- **RISK-02-01:** The HTML gate classifies the corrected report as `drift` on the
  refresh **before** the refreeze is committed, which is correct behaviour and
  will fail `tools/verify_refactor.R`. Mitigation: this is the one intended
  drift; commit the regenerated report and PNGs, then re-run the gate, which must
  then pass. Do not use `refresh.yml`'s `allow_drift: true` for the routine
  scheduled run — it exists for the manual dispatch that lands a reviewed
  refreeze.
- **RISK-02-02:** `format_vnd_bn()` appends the English `" bn VND"` while the
  Vietnamese narrative around it says `tỷ VND`. Mitigation: see the Gotchas
  entry on the label decision — the English suffix is used consistently and the
  adjacent Vietnamese literal is removed, so no site ever prints both.
- **RISK-02-03:** A local variable rename (`coal_power_bn` → `coal_power_vnd`)
  is missed at one of its six use sites, producing an R "object not found" error
  at report-build time. Mitigation:
  `grep -n "coal_power_bn\|renew_bn\|ev_bn\|total_portfolio_bn\|coal_exposure_bn\|exposure_bn" R/pacta_core.R`
  must return no matches after the phase.

### PHASE-03 - Assert Facts, Not Just Sameness

**Goal**
Deliver the half of Wave 4's DEC-001 that was never built: each gated deliverable
declares its headline figures, an invariant recomputes them from their source
CSV, and the formatted strings must actually appear in the HTML — so a wrong
number fails a gate instead of being frozen by one.

**Tasks**
- [ ] TASK-03-01: Create `R/report_facts.R` implementing `report_fact()`,
      `write_report_facts()` and `read_report_facts()` per **Function
      Signatures**, following the schema in **S1**. Use `jsonlite::toJSON(...,
      auto_unbox = TRUE, pretty = TRUE, digits = NA)` — `digits = NA` is required
      or `jsonlite` rounds `25020000000000` in a way that breaks the exact
      comparison in S2.
- [ ] TASK-03-02: In `scripts/pacta_vietnam_scenario.R`, after the report is
      written, emit `reports/PACTA_Vietnam_Bank_Report.facts.json` with exactly
      three facts:
      `portfolio_total_vnd` (`sum` of `loan_size_outstanding` from
      `cfg$inputs$loanbook_csv`, unit `VND`, rendered
      `format_vnd_bn(total_portfolio_vnd)`);
      `n_loans` (`nrow` of the same CSV, unit `loans`, rendered as the plain
      integer string);
      `n_matched` (`nrow` of
      `file.path(cfg$paths$pacta_output_dir, "02_vn_matched_prioritized.csv")`,
      unit `loans`, rendered as the plain integer string).
- [ ] TASK-03-03: In `scripts/generate_financed_emissions.R`, after
      `write_html_report(...)` at line 118, emit
      `reports/Financed_Emissions.facts.json` (path derived from
      `cfg$paths$reports_dir`) with two facts:
      `total_financed_emissions_tco2e` (`sum` of `financed_emissions_tco2e` from
      the `financed_emissions.csv` the script just wrote under
      `cfg$paths$financed_emissions_output_dir`, unit `tCO2e`, rendered exactly
      as the report renders it) and `n_borrowers` (`nrow` of the same CSV).
- [ ] TASK-03-04: Add `inv_report_facts_agree()` to `tools/verify_refactor.R`
      implementing **S2**, as INV-013.
- [ ] TASK-03-05: Register `inv_report_facts_agree(root)` in `run_invariants()`
      after `inv_audit_attests_configured_vintage(root)`.
- [ ] TASK-03-06: Create `tests/testthat/test_report_facts.R` covering the
      round-trip and the invariant's failure modes per **Test Specs**.
- [ ] TASK-03-07: In `tools/verify_refactor.R`, confirm that a `.facts.json`
      file changing classifies as `"drift"` under `classify_path()` — it should,
      because `.json` is not in `TIMESTAMP_BASENAMES` and the file carries no
      timestamp (ASM-005). Add a one-line comment above `GATED_HTML_PATHS`
      recording that a facts-sidecar change is intentionally genuine drift: the
      numbers moved.
- [ ] TASK-03-08: Run `Rscript scripts/pipeline_refresh.R`, then commit the two
      new sidecar files so subsequent runs produce no diff.
- [ ] TASK-03-09: Document the sidecar mechanism in `README.md`'s "Refactor
      acceptance check" section — two sentences stating that gated reports carry
      a `.facts.json` whose values are recomputed from source CSVs by INV-013,
      and update the invariant count from "twelve" to "thirteen" in the same
      section.

**File Changes**
- `R/report_facts.R` (create): the three functions in **Function Signatures**,
  with roxygen `#' @export` tags on all three so `NAMESPACE` picks them up.
- `scripts/pacta_vietnam_scenario.R` (modify): `source("R/report_facts.R")` and
  the sidecar emission after the report write.
- `scripts/generate_financed_emissions.R` (modify): `source("R/report_facts.R")`
  and the sidecar emission after line 118. **Leave alone:** the PCAF
  computation, the exclusion logic, and the HTML body.
- `tools/verify_refactor.R` (modify): add `inv_report_facts_agree()`, register it
  in `run_invariants()`, add the `classify_path()` comment. **Leave alone:**
  INV-001..012 and `.html_is_timestamp_only()`.
- `tests/testthat/test_report_facts.R` (create).
- `NAMESPACE` and `man/` (modify, generated): regenerate with
  `Rscript -e "roxygen2::roxygenise()"` and commit — CI's NAMESPACE freshness
  check will otherwise fail.
- `reports/PACTA_Vietnam_Bank_Report.facts.json`,
  `reports/Financed_Emissions.facts.json` (create, generated).
- `README.md` (modify): the sidecar sentences and the invariant count.

**Function Signatures**
- `report_fact(name: character(1), value: numeric(1), source_csv: character(1), agg: character(1), column: character(1) = NA_character_, unit: character(1) = NA_character_, rendered: character(1)) -> list` —
  one fact as a plain named list matching **S1**; `stop()`s when `agg` is not one
  of `"sum"`, `"nrow"`, `"n_distinct"`.
- `write_report_facts(facts: list, html_path: character(1), generated_by: character(1)) -> character(1)` —
  writes `sub("\\.html$", ".facts.json", html_path)` and returns that path.
- `read_report_facts(facts_path: character(1)) -> list` — parses a sidecar with
  `jsonlite::fromJSON(..., simplifyVector = FALSE)`; `stop()`s when the file is
  missing or lacks a `facts` array.
- `inv_report_facts_agree(root: character(1)) -> list` — `list(id = "INV-013", ok = logical(1), detail = character())`,
  following the shape every other `inv_*()` returns.

**Test Specs**
- `report_fact("portfolio_total_vnd", 25020000000000, "data/vietnam_loanbook.csv", "sum", column = "loan_size_outstanding", unit = "VND", rendered = "25,020.0 bn VND")`
  → a list whose `$value` is `25020000000000` and `$source$agg` is `"sum"`.
- `report_fact("x", 1, "a.csv", "median")` → error matching `"agg"`.
- Round-trip: `write_report_facts()` to a `tempfile(fileext = ".html")` path,
  then `read_report_facts()` on the returned path → `$facts[[1]]$value` is
  `25020000000000` exactly (guards the `digits = NA` requirement; without it
  `jsonlite` writes `2.502e+13` and the comparison in S2 still passes but the
  file is unreadable to a human — assert the raw file text contains
  `"25020000000000"`).
- Invariant, happy path: a fixture root containing `reports/X.html` with body
  `"<p>25,020.0 bn VND</p>"`, `reports/X.facts.json` declaring one `sum` fact
  over a fixture CSV whose column sums to `25020000000000`, and a
  `GATED_HTML_PATHS` override naming `reports/X.html`
  → `inv_report_facts_agree(fixture)$ok` is `TRUE`.
- Invariant, wrong value: same fixture with `"value": 999` → `$ok` is `FALSE`
  and `$detail` contains `"fact 'portfolio_total_vnd' is 999"`.
- Invariant, missing rendered string: same fixture with the HTML body changed to
  `"<p>2.502e+10</p>"` → `$ok` is `FALSE` and `$detail` contains
  `"does not appear in the report"`.
- Invariant, no sidecar: a gated report with no `.facts.json` → `$ok` is `TRUE`
  (skipped, not failed) — this is what lets the remaining five gated reports stay
  uncovered until a later wave.
- Invariant, missing source CSV: sidecar names `data/gone.csv` → `$ok` is `FALSE`
  naming the missing file.

**Dependencies**
- PHASE-02 — the sidecars must record the corrected values, not the wrong ones.

**Exit Criteria**
- [ ] `ls reports/*.facts.json` lists exactly two files.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS` and
      its output includes `[PASS] INV-013`.
- [ ] Deliberately corrupt the sidecar
      (`python -c "import json,io;p='reports/PACTA_Vietnam_Bank_Report.facts.json';d=json.load(io.open(p,encoding='utf-8'));d['facts'][0]['value']=1;io.open(p,'w',encoding='utf-8').write(json.dumps(d))"`)
      → `Rscript tools/verify_refactor.R --invariants` exits non-zero naming
      INV-013. Restore the file with `git checkout -- reports/PACTA_Vietnam_Bank_Report.facts.json`
      afterwards. This proves the invariant is calibrated rather than merely
      quiet.
- [ ] `Rscript -e "roxygen2::roxygenise()"` followed by
      `git diff --exit-code NAMESPACE` exits `0`.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [ ] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS` after the
      sidecars are committed.

**Phase Risks**
- **RISK-03-01:** `jsonlite` writes large integers in scientific notation,
  making the sidecar unreadable and fragile. Mitigation: `digits = NA` in
  `toJSON()`, pinned by the round-trip test that asserts the raw file text
  contains `"25020000000000"`.
- **RISK-03-02:** The `rendered` substring check is defeated by HTML entity
  encoding or line wrapping between the number and its unit. Mitigation: keep
  `rendered` to a single formatter output with no surrounding markup, and read
  the HTML collapsed by `"\n"` before searching, exactly as S2 specifies.

### PHASE-04 - Deliverable Inventory Truth

**Goal**
Stop publishing a deliverable no pipeline can regenerate, stop displaying
hand-typed dates for artifacts that are rebuilt every run, and bring the three
drifted documentation files back into agreement with the code.

**Tasks**
- [ ] TASK-04-01: Remove `"PACTA_Synthesis_Report.html"` from
      `engagements/mcb-demo/engagement_config.json`'s `published_reports` array.
- [ ] TASK-04-02: Remove `"reports/PACTA_Synthesis_Report.html"` from
      `GATED_HTML_PATHS` in `tools/verify_refactor.R` (it remains in
      `DISCLAIMER_HTML_PATHS` only through the `GATED_HTML_PATHS` union, so
      removing it from the former removes it from both — add it explicitly to
      `DISCLAIMER_HTML_PATHS` only if the file remains generated, which it does
      not, so do not re-add it).
- [ ] TASK-04-03: `git mv reports/PACTA_Synthesis_Report.html attic/PACTA_Synthesis_Report.html`
      so it sits beside its generator `attic/pacta_synthesis.R`, and add one line
      to `attic/README.md` recording that the report and its generator were
      retired together on 2026-09-07 because the Vietnam report supersedes it.
- [ ] TASK-04-04: Remove the `"PACTA_Synthesis_Report.html"` entry from
      `reports/report_catalog.json`.
- [ ] TASK-04-05: Delete `dashboard/data/reports/PACTA_Synthesis_Report.html`
      and confirm `scripts/refresh_dashboard_data.R` no longer copies it (it is
      driven by `cfg$published_reports`, so TASK-04-01 is sufficient; verify the
      cross-check at lines 87-91 does not error on the now-absent catalog entry).
- [ ] TASK-04-06: In `dashboard/lib/loaders.py`'s `report_catalog()`, replace the
      catalog's hand-typed `date` with the artifact's filesystem modification
      date, formatted `YYYY-MM-DD`: read `path.stat().st_mtime` and format with
      `datetime.fromtimestamp(...).strftime("%Y-%m-%d")`. Keep the catalog's
      `title`, `summary` and `category` fields as the source of truth for those.
      Fall back to the catalog's `date` string when `stat()` raises.
- [ ] TASK-04-07: Remove the now-unused `date` fields from
      `reports/report_catalog.json`, or — simpler and less churn — leave them as
      the documented fallback and add a comment-free `"date_is_fallback": true`
      marker at the top level of the JSON. Choose the fallback approach: keep the
      `date` fields, and record in `dashboard/data/README.md` that displayed
      dates come from the artifact, not the catalog.
- [ ] TASK-04-08: Rewrite `activeContext.md` so its "Current program" pointer
      names this plan file rather than
      `plans/2026-08-26-wave3-convergence-vintage-delivery-plan.md`. Keep the
      file's existing framing (it is a pointer, not a context dump).
- [ ] TASK-04-09: Delete `research/future_planning_ideas.md`. All three of its
      proposals — multi-sector TRISK, the pipeline refresh orchestrator with a
      reproducibility report, and the engagement action layer — shipped in
      2026-04 through 2026-07, and the file reads as a live roadmap. Record the
      deletion in `NEWS.md`.
- [ ] TASK-04-10: Add a `NEWS.md` entry for the previously unrecorded
      orchestrator-planning refactor (commits `b75e676`..`b1d53e1`): it created
      `R/engagement_plan.R` with `parse_engagement_cli()`,
      `plan_engagement_run()`, `enforce_manifest_policy()` and
      `materialize_resolved_config()`, moving CLI parsing, step resolution, the
      by-name intake split, the manifest path and partial policy, the
      snapshot guard rail and the banner out of `scripts/run_engagement.R`. State
      that execution (subprocesses, manifest JSON shape) remains in
      `R/step_runner.R`, and that the work is complete. Follow the repo's rule:
      no hand-typed test counts.
- [ ] TASK-04-11: Update `README.md`'s "Refactor acceptance check" section: the
      invariant count is now thirteen (PHASE-03), and the gated-report list no
      longer includes the synthesis report.

**File Changes**
- `engagements/mcb-demo/engagement_config.json` (modify): `published_reports`
  only. **Leave alone:** `row_count_files`, every path, and
  `public_snapshot_allowed`.
- `tools/verify_refactor.R` (modify): `GATED_HTML_PATHS` only.
- `reports/PACTA_Synthesis_Report.html` → `attic/PACTA_Synthesis_Report.html`
  (move).
- `attic/README.md` (modify): one retirement line.
- `reports/report_catalog.json` (modify): remove the synthesis-report entry.
- `dashboard/data/reports/PACTA_Synthesis_Report.html` (delete).
- `dashboard/lib/loaders.py` (modify): `report_catalog()` date derivation only.
- `dashboard/data/README.md` (modify): one sentence on date provenance.
- `activeContext.md` (modify): the "Current program" pointer.
- `research/future_planning_ideas.md` (delete).
- `NEWS.md` (modify): entries for the orchestrator refactor and this wave.
- `README.md` (modify): invariant count and gated-report list.

**Function Signatures**
- `report_catalog() -> list[dict]` (Python, `dashboard/lib/loaders.py`) — one
  dict per published report with keys `title`, `date`, `summary`, `category`,
  `path`; `date` is now the artifact's modification date formatted `YYYY-MM-DD`,
  falling back to the catalog string when `stat()` raises `OSError`.

**Test Specs**
- Add to `dashboard/tests/test_loaders.py`: monkeypatch a temporary reports
  directory containing one HTML file with a known mtime and a catalog entry whose
  `date` is `"1999-01-01"` → `report_catalog()[0]["date"]` equals the file's
  mtime date, not `"1999-01-01"`.
- Same fixture with the HTML file removed after the catalog is read (simulating
  `stat()` failure) → `report_catalog()[0]["date"]` equals `"1999-01-01"`.
- `python -m pytest dashboard/tests` → all tests pass with a count strictly
  greater than 69.
- R side: `Rscript tools/verify_refactor.R --invariants` → `INVARIANTS PASS`;
  in particular INV-010 must still pass with the synthesis report removed from
  `DISCLAIMER_HTML_PATHS`.

**Dependencies**
- PHASE-03 — `README.md`'s invariant count is only correct after INV-013 exists.

**Exit Criteria**
- [ ] `test -f reports/PACTA_Synthesis_Report.html` returns non-zero and
      `test -f attic/PACTA_Synthesis_Report.html` returns zero.
- [ ] `grep -c "PACTA_Synthesis_Report" engagements/mcb-demo/engagement_config.json tools/verify_refactor.R reports/report_catalog.json`
      returns `0` for all three.
- [ ] `test -f research/future_planning_ideas.md` returns non-zero.
- [ ] `grep -c "2026-08-26-wave3" activeContext.md` returns `0`.
- [ ] `grep -c "engagement_plan" NEWS.md` returns at least `1`.
- [ ] `python -m pytest dashboard/tests` passes with more than 69 tests.
- [ ] `Rscript scripts/pipeline_refresh.R` followed by
      `Rscript tools/verify_refactor.R --skip-refresh` prints
      `BYTE-IDENTITY PASS`.

**Phase Risks**
- **RISK-04-01:** `scripts/refresh_dashboard_data.R` cross-checks
  `published_reports` against `reports/report_catalog.json` (lines 87-91) and
  errors when a named report has no catalog entry. Removing both together is
  required; removing only one breaks the refresh. Mitigation: TASK-04-01 and
  TASK-04-04 land in the same commit, and the exit criterion runs a full refresh.
- **RISK-04-02:** Deleting `dashboard/data/reports/PACTA_Synthesis_Report.html`
  touches the frozen public snapshot, which only
  `scripts/refresh_dashboard_data.R` may write. Mitigation: the deletion is a
  removal of a file the refresh no longer produces, performed once by hand in the
  same commit; the subsequent full refresh proves the snapshot is
  self-consistent.

### PHASE-05 - Step Dependency Contract

**Goal**
Make the step registry declare what each step reads and writes, so a mis-ordered
`cfg$steps` is refused at plan time and a filtered run that will read a previous
run's artifact says so out loud instead of producing a confident, stale result.

**Tasks**
- [ ] TASK-05-01: In `R/step_registry.R`, add `produces_fn` and `requires_fn` to
      the registry entries that have real inter-step dependencies, per **S3**.
      At minimum: `intake` produces `<intake_dir>/normalized_loanbook.csv`;
      `validation_report` and `coverage_report` require it;
      `pacta_vietnam_scenario` produces
      `<pacta_output_dir>/02_vn_matched_prioritized.csv` and
      `<pacta_output_dir>/06_vn_ms_alignment_2030.csv`;
      `trisk_prepare_inputs` requires the first of those and produces
      `<trisk_input_root>/`; `trisk_sector_demo` requires `<trisk_input_root>/`
      and produces `<trisk_output_root>/<sector>/`;
      `sector_prioritization` requires the PACTA alignment CSV and the TRISK
      sector outputs and produces
      `<prioritization_output_dir>/sector_priority_ranking.csv`;
      `engagement_scoring` requires that and produces
      `<engagement_output_dir>/engagement_priority.csv`;
      `financed_emissions`, `sll_readiness` and `generate_targets` each require
      `<engagement_output_dir>/engagement_priority.csv`;
      `generate_engagement_letters` and `generate_disclosure_pack` require it
      too. Entries with no inter-step dependency omit both fields.
- [ ] TASK-05-02: Add `validate_step_dependencies()` to `R/engagement_plan.R`
      implementing **S3**, and call it from `plan_engagement_run()` immediately
      after `filter_step_list()`.
- [ ] TASK-05-03: Add a `--strict-deps` flag to `parse_engagement_cli()`
      (`R/engagement_plan.R`) defaulting to `FALSE`. When `TRUE`, the "no step in
      this run produces `<file>`" case escalates from a warning to a `stop()`.
      Document the flag in `scripts/run_engagement.R`'s header comment block
      alongside the existing flags.
- [ ] TASK-05-04: Record every dependency warning in the manifest: extend
      `write_pipeline_manifest()`'s `extra` argument at the call site in
      `scripts/run_engagement.R` with
      `dependency_warnings = <character vector from the plan>`, so a partial run's
      provenance record states which artifacts it read from a previous run.
      Register nothing new in `R/engagement_config.R` — this is a manifest field,
      not a config key.
- [ ] TASK-05-05: Add `tests/testthat/test_step_dependencies.R` per **Test
      Specs**.
- [ ] TASK-05-06: Document the contract in `R/step_registry.R`'s header comment:
      a new step declares `requires_fn`/`produces_fn` and the ordering is then
      checked rather than assumed, replacing the current practice of recording
      dependencies in prose comments.

**File Changes**
- `R/step_registry.R` (modify): add the two optional fields to the entries listed
  in TASK-05-01; update the header comment. **Leave alone:**
  `.resolve_step_list_from_flags()`'s ordering and boolean gating,
  `.order_sectors_power_first()`, `resolve_step_list()`'s `cfg$steps` expansion,
  and `filter_step_list()` — this phase adds validation, it does not change which
  steps run.
- `R/engagement_plan.R` (modify): add `validate_step_dependencies()`, call it
  from `plan_engagement_run()`, add `strict_deps` to `parse_engagement_cli()`'s
  returned list, and add `dependency_warnings` to the returned plan.
- `scripts/run_engagement.R` (modify): pass `dependency_warnings` into
  `write_pipeline_manifest()`'s `extra`; document `--strict-deps` in the header.
- `tests/testthat/test_step_dependencies.R` (create).
- `NAMESPACE`, `man/` (modify, generated): regenerate after adding the exported
  `validate_step_dependencies()`.

**Function Signatures**
- `validate_step_dependencies(steps: list, cfg: list, registry: list = step_registry(), strict: logical(1) = FALSE) -> character` —
  returns a character vector of warning messages (empty when none); `stop()`s on
  a hard ordering violation, and also on the "not produced by this run" case when
  `strict` is `TRUE`.

**Test Specs**
- Ordering violation: a `cfg$steps` of
  `c("financed_emissions", "engagement_scoring")` with the MCB config →
  `plan_engagement_run()` errors with a message containing both
  `"financed_emissions"`, `"engagement_scoring"` and
  `"engagement_priority.csv"`.
- Correct order: `c("engagement_scoring", "financed_emissions")` → no error, and
  `validate_step_dependencies()` returns `character(0)`.
- Filtered run: `filter_step_list(steps, only = "financed_emissions")` then
  `validate_step_dependencies(...)` with `strict = FALSE` → returns exactly one
  warning whose text contains `"engagement_priority.csv"` and
  `"previous run"`.
- Same, with `strict = TRUE` → errors with the same file named.
- A step with neither field (e.g. `generate_vietnam_data`) → contributes no
  requirement and no violation.
- Regression: `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --dry-run`
  prints the same 16-step list, in the same order, as it does before this phase
  — capture the output before and after and `diff` them.

**Dependencies**
- PHASE-04 — no technical dependency, but sequencing keeps each phase's
  byte-identity check attributable to one change set.

**Exit Criteria**
- [ ] `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --dry-run`
      prints 16 steps in the pre-existing order (byte-identical to the output
      captured before this phase).
- [ ] `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --only-step financed_emissions --allow-partial-manifest`
      prints a warning naming `engagement_priority.csv` and completes.
- [ ] Adding `--strict-deps` to the same command makes it exit non-zero.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [ ] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS`.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS`.

**Phase Risks**
- **RISK-05-01:** A `produces_fn` path is written slightly differently from the
  `requires_fn` path that consumes it (e.g. trailing slash, `file.path()` vs
  `paste0`), so a real dependency is silently never matched and the validation is
  decorative. Mitigation: the test that asserts the filtered run produces exactly
  one warning naming `engagement_priority.csv` proves at least one edge is
  actually wired; add a `test_that` that every `requires_fn` path in the full MCB
  resolved list is produced by some step in that same list.
- **RISK-05-02:** The new validation rejects a legitimate `cfg$steps` order used
  by an engagement config not in the repository. Mitigation: neither committed
  config sets `cfg$steps` (both fall through to the flag-driven path), and the
  "not produced by this run" case is a warning, not an error, unless
  `--strict-deps` is passed.

### PHASE-06 - Read-Side Snapshot Seam

**Goal**
Let the Streamlit app read whichever snapshot directory it is pointed at, so a
client engagement becomes a directory rather than a repository fork, and fix the
temp-file leak on the one page that handles a real bank's loanbook.

**Tasks**
- [ ] TASK-06-01: In `dashboard/lib/loaders.py`, replace the module-level
      `DATA_DIR = ROOT / "data"` with a function
      `snapshot_root() -> Path` that returns
      `Path(os.environ.get("PACTATRISK_SNAPSHOT_DIR", str(ROOT / "data"))).resolve()`,
      and convert `PACTA_DIR`, `TRISK_DIR`, `REPORTS_DIR`, `ANALYTICS_DIR`,
      `TRISK_MANIFEST` and `PIPELINE_MANIFEST` from module-level constants into
      functions or into calls made inside the existing path helpers
      (`pacta_path()`, `trisk_path()`, `trisk_sector_path()`, `reports_path()`,
      `analytics_path()`). Keep every helper's public signature unchanged so no
      page needs editing.
- [ ] TASK-06-02: Because `@st.cache_data` memoizes on arguments, confirm no
      cached function closes over the old module-level constants — `load_csv`,
      `load_markdown_text` and `load_bytes` all take an explicit `path`, so they
      are safe. Add a comment recording that any future cached loader must take
      its path as an argument for the snapshot root to remain switchable.
- [ ] TASK-06-03: Add an `ENGAGEMENT_PICKER` operator gate to
      `dashboard/lib/branding.py`'s `apply_page_frame()`: when
      `os.environ.get("ENGAGEMENT_PICKER") == "1"`, render a sidebar
      `st.selectbox` listing `dashboard/data` plus every directory matching
      `engagements/*/snapshot/` that contains a `pipeline_manifest.json`, and set
      `os.environ["PACTATRISK_SNAPSHOT_DIR"]` to the selection before any loader
      runs. When the variable is unset the picker does not render and behaviour is
      byte-identical to today.
- [ ] TASK-06-04: Rewrite `docs/private-instance-deploy.md`'s "Replace the
      Dashboard Snapshot" section: a private instance now sets
      `PACTATRISK_SNAPSHOT_DIR` (or copies the client snapshot into
      `dashboard/data` on a deployment that has no env-var control), instead of
      cloning the repository per bank. Keep the existing access-control and
      secrets guidance.
- [ ] TASK-06-05: Fix the temp-file leak in `dashboard/pages/6_Intake_Wizard.py`:
      keep a separate variable for the originally uploaded file
      (`upload_path`) and for the file handed to validation (`input_path`), and
      wrap everything from the upload through the results rendering in
      `try: ... finally:` that unlinks both paths with
      `Path.unlink(missing_ok=True)` inside a `try/except OSError`. The existing
      `st.stop()` calls must no longer skip cleanup — restructure so the
      `finally` block always runs.
- [ ] TASK-06-06: Add `dashboard/tests/test_intake_cleanup.py` per **Test
      Specs**.
- [ ] TASK-06-07: Update `docs/intake_privacy.md` rule 1 and the "Operator
      Responsibilities" list to state that the wizard now deletes both the
      uploaded file and any converted CSV automatically, and that the operator's
      remaining responsibility is the file they received out-of-band.
- [ ] TASK-06-08: Update `README.md`'s "Operator features (env-gated, off by
      default)" table with two new rows: `PACTATRISK_SNAPSHOT_DIR` (read a
      different snapshot) and `ENGAGEMENT_PICKER=1` (sidebar engagement picker).

**File Changes**
- `dashboard/lib/loaders.py` (modify): `snapshot_root()` and the path helpers.
  **Leave alone:** `ANALYTICS_TABLES`, `load_analytics_tables()`,
  `load_pacta_alignment_tables()`, `load_trisk_tables()`,
  `load_trisk_sector_tables()`, `load_parquet()`, `load_trisk_grid()` — their
  bodies call the helpers and need no change.
- `dashboard/lib/branding.py` (modify): the picker in `apply_page_frame()`.
  **Leave alone:** `public_demo_banner()`, `data_freshness_badge()`,
  `footer_note()`, and the `require_password()` call.
- `dashboard/pages/6_Intake_Wizard.py` (modify): the upload/convert/cleanup
  lifecycle. **Leave alone:** the `BYOL_INTAKE` gate, the ZIP bundle, and every
  results-rendering block's content.
- `dashboard/tests/test_intake_cleanup.py` (create).
- `docs/private-instance-deploy.md`, `docs/intake_privacy.md`, `README.md`
  (modify): documentation only.

**Function Signatures**
- `snapshot_root() -> Path` (Python) — the resolved snapshot directory, from
  `PACTATRISK_SNAPSHOT_DIR` when set, otherwise `dashboard/data`.
- `convert_xlsx_to_csv(xlsx_path: Path) -> Path` (unchanged signature) — still
  returns the converted CSV path; the caller is now responsible for unlinking
  both it and the original.

**Test Specs**
- `dashboard/tests/test_loaders.py`: with `PACTATRISK_SNAPSHOT_DIR` unset,
  `snapshot_root()` ends with `dashboard/data` (or the OS-appropriate
  equivalent).
- Same, with `monkeypatch.setenv("PACTATRISK_SNAPSHOT_DIR", str(tmp_path))` →
  `snapshot_root() == tmp_path.resolve()` and
  `pacta_path("04_vn_ms_portfolio.csv") == tmp_path.resolve() / "pacta" / "04_vn_ms_portfolio.csv"`.
- `dashboard/tests/test_intake_cleanup.py`: call the extracted cleanup helper
  with two existing temp files → both are gone afterwards.
- Same, where the second path does not exist → no exception raised
  (`missing_ok=True` behaviour).
- Same, where one path is a directory (simulating an OS error) → no exception
  propagates and the other file is still deleted.
- `python -m pytest dashboard/tests` → all tests pass with a count strictly
  greater than the PHASE-04 count.

**Dependencies**
- PHASE-05 — no technical dependency; sequencing only.

**Exit Criteria**
- [ ] `grep -c "^DATA_DIR" dashboard/lib/loaders.py` returns `0`.
- [ ] `python -m pytest dashboard/tests` passes with a count greater than the
      PHASE-04 count.
- [ ] With no environment variables set,
      `python -m streamlit run dashboard/app.py` renders the PACTA Alignment page
      with the same figures as before this phase.
- [ ] `PACTATRISK_SNAPSHOT_DIR=engagements/sdb-rehearsal/snapshot python -m streamlit run dashboard/app.py`
      renders Saigon Delta Bank's snapshot without any code change.
- [ ] `grep -c "clone" docs/private-instance-deploy.md` returns `0` in the
      "Replace the Dashboard Snapshot" section (the repository-clone recipe is
      gone).
- [ ] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS` (this phase
      touches no R code, so the check must be unaffected).

**Phase Risks**
- **RISK-06-01:** `@st.cache_data` caches a DataFrame keyed on a path argument;
  switching snapshots mid-session serves the correct data because the path
  differs, but a cached function that took no path would serve the previous
  engagement's data to the next one. Mitigation: TASK-06-02's audit and comment;
  every current cached loader already takes an explicit path.
- **RISK-06-02:** Setting `os.environ` from inside a Streamlit callback affects
  the whole process, so with multiple concurrent viewers one viewer's selection
  would change another's data. Mitigation: the picker is gated behind
  `ENGAGEMENT_PICKER=1`, which is an operator-machine feature only; state that
  constraint explicitly in the README row and in a comment beside the picker. Do
  not enable it on any multi-user deployment.
- **RISK-06-03:** The intake restructure changes control flow around several
  `st.stop()` calls and could swallow an error the operator needs to see.
  Mitigation: the `finally` block performs cleanup only; it must not catch or
  suppress the exceptions Streamlit uses for `st.stop()`.

## Gotchas

- **The console banner and the report disagree today, and both are wrong.**
  `pacta_load_inputs()` prints `Total portfolio: 25,020,000,000 bn VND
  (~$1000800.0B USD)` while the report prints `2.502e+10 tỷ VND`. They are the
  same defect rendered by two different `format()` calls. Fix both, or the next
  reader will assume one of them is the correct reference.
- **`format(round(x), big.mark = ",")` silently switches to scientific notation**
  above roughly 1e15. That is why the rendered value is `2.502e+10` and not
  `25,020,000,000`. `formatC(x, format = "f", digits = 0, big.mark = ",")` — what
  `R/format_money.R` already uses — does not. Never use `format()` for money.
- **`format = "d"` overflows.** `formatC(x, format = "d")` coerces via
  `as.integer()` and silently overflows for VND figures above 2^31-1 (about
  2.1e9). `R/format_money.R:26` documents this; do not "simplify" it back.
- **The label decision (`bn VND` vs `tỷ VND`).** `format_vnd_bn()` appends the
  English `" bn VND"`. The Vietnamese narrative sections currently append a
  separate literal `tỷ VND`. When you substitute a formatter call, **delete the
  adjacent literal**, or the report will read `25,020.0 bn VND tỷ VND`. The
  bilingual label layer (`templates/i18n/labels.csv`,
  `report_label(token, lang)`) is the right long-term home for a localized unit
  suffix; this plan does not extend it, so the English suffix is used
  consistently and the duplicated Vietnamese literal is removed.
- **VND is never rescaled in data — only at render time.** Keep every local
  variable in whole VND and convert inside the formatter call. The bug being
  fixed is precisely what happens when a scaled intermediate
  (`total_portfolio_bn`) travels through 300 lines of code and picks up a unit
  label from whatever text happens to be next to it.
- **Regenerate with the full refresh, not `--only-step`.** A filtered run writes
  a manifest describing only its own steps and the orchestrator refuses to
  overwrite the complete public manifest without `--allow-partial-manifest`. The
  full MCB refresh takes about 69 seconds. (PHASE-05 exists because the same
  filtering can silently read stale *inputs*, which nothing currently refuses.)
- **The image-normalization rule must run before the SHA rule** in
  `R/report_fingerprint.R`'s `normalize_report_html()`: a base64 payload contains
  long runs of `[0-9a-f]`, so applying the git-SHA rule first punches `<SHA>`
  tokens into image payloads and breaks the image pattern's contiguous match. Do
  not reorder those rules while working in that file.
- **PNG charts are outside every gate.** `classify_path()` returns
  `"png-noise"` for every `.png`, because compression is nondeterministic. Two of
  the three artifacts PHASE-02 corrects are PNGs, so their correctness is
  provable only through the underlying values — which is one more reason the
  facts sidecars in PHASE-03 matter.
- **`jsonlite::toJSON()` needs `digits = NA` for large integers.** Without it,
  `25020000000000` is written as `2.502e+13` and the sidecar becomes unreadable
  to a human reviewer even though the numeric comparison still passes.
- **An optional config field round-trips as an empty `list()`.** Whether it
  started as `NULL` or `character(0)`, a field written with
  `toJSON(auto_unbox = TRUE)` and read with `read_json(simplifyVector = TRUE)`
  comes back as `list()`. Always test "not configured" with `length(x) == 0`.
- **`git mv` a report out of `reports/` and the byte-identity gate sees a
  deletion.** `classify_path()` classifies by extension, and `.html` outside
  `GATED_HTML_PATHS` returns `"timestamp-class"`, so the move is expected churn
  — but only once TASK-04-02 has removed it from the gated list. Do the removal
  and the move in the same commit.
- **`scripts/refresh_dashboard_data.R` cross-checks `published_reports` against
  `reports/report_catalog.json`** and errors when a published report has no
  catalog entry. Both edits must land together.
- **Do not uncomment `.Rprofile`'s renv line** while doing anything else in this
  plan. If it is ever uncommented, every `Rscript` invocation in the repository
  starts consulting an uninitialized renv project, which is the exact failure CI
  has been suffering.

## Verification Strategy

- **TEST-001:** `Rscript -e "testthat::test_dir('tests/testthat')"` →
  `FAIL 0`, with a PASS count strictly greater than 756 at every phase boundary
  from PHASE-01 onward.
- **TEST-002:** `python -m pytest dashboard/tests` → all pass, count strictly
  greater than 69 from PHASE-04 onward.
- **TEST-003:** `Rscript tools/verify_refactor.R --invariants` →
  `INVARIANTS PASS`, listing `[PASS] INV-001` through `[PASS] INV-013` from
  PHASE-03 onward.
- **TEST-004:** `Rscript tools/verify_refactor.R` → `BYTE-IDENTITY PASS` at
  every phase boundary except the single intentional refreeze commit inside
  PHASE-02 (see MANUAL-002).
- **TEST-005:** `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`
  → `FAIL 0` at every phase boundary. This is the proof that PHASE-02 was a
  display-layer change.
- **TEST-006:** `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`
  → `FAIL 0` after PHASE-05, proving the dependency contract did not change what
  the second engagement produces.
- **TEST-007:** `gh run list --limit 1 --json conclusion --jq '.[0].conclusion'`
  → `success`, run after each phase is pushed. Before PHASE-01 this returns
  `failure`; from PHASE-01 onward a `failure` here blocks the next phase.
- **TEST-008:** `grep -c "/ 1000" R/pacta_core.R` → `0` after PHASE-02.
- **TEST-009:** `grep -o "2\.502e+10" reports/PACTA_Vietnam_Bank_Report.html | wc -l`
  → `0` after PHASE-02; `grep -c "25,020.0 bn VND" reports/PACTA_Vietnam_Bank_Report.html`
  → at least `1`.
- **TEST-010:** Negative control for INV-013 — corrupt a sidecar value, confirm
  `Rscript tools/verify_refactor.R --invariants` exits non-zero naming INV-013,
  then `git checkout --` the file. A gate that has never failed on purpose has
  not been shown to work.
- **MANUAL-001:** Open `dashboard/data/pacta/03_vn_coverage_pie.png` after
  PHASE-02 and read its subtitle: it must say
  `Total: 25,020.0 bn VND | Mekong Commercial Bank 2025`. PNGs are outside the
  automated gate, so this is a required visual check.
- **MANUAL-002:** PHASE-02's refresh will make `tools/verify_refactor.R` report
  drift on the report and the two PNGs **before** they are committed. That is the
  intended, reviewed refreeze. Confirm the drift list contains no `.csv` file,
  commit the regenerated artifacts, then re-run the gate and confirm
  `BYTE-IDENTITY PASS`.
- **MANUAL-003:** After PHASE-06, run
  `PACTATRISK_SNAPSHOT_DIR=engagements/sdb-rehearsal/snapshot python -m streamlit run dashboard/app.py`
  and confirm the landing page's freshness badge names `sdb-rehearsal`, then run
  with no environment variable set and confirm it names `mcb-demo`.
- **OBS-001:** After PHASE-01, confirm the weekly refresh is alive by triggering
  it manually (`gh workflow run refresh.yml`) and checking that it either
  auto-commits a refreshed snapshot or fails with the new
  `::error::Weekly refresh failed` annotation. Silence is the failure mode this
  wave exists to remove.
- **OBS-002:** After PHASE-01, confirm the README badge renders green on the
  repository's front page.

## Risks and Alternatives

- **RISK-001:** The first CI run with working dependencies exposes genuine
  Linux-vs-Windows differences that were masked for two months — most plausibly
  `core.autocrlf` line-ending handling in the byte-identity gate, or
  locale-dependent collation of Vietnamese counterparty names in a sort.
  Mitigation: ASM-002 makes this an expected discovery with a fixed response —
  fix the underlying difference, never suppress the check. Budget one round of
  cross-platform fixes inside PHASE-01 rather than treating them as scope creep.
- **RISK-002:** PHASE-02 changes a client-facing published artifact, and the
  corrected figure is roughly a millionth of the old one. Anyone who quoted the
  old number externally will notice. Mitigation: state the correction explicitly
  in `NEWS.md` and in the commit message, with the before and after values and
  the reason (a display-layer unit defect, no analytical change, no golden number
  moved).
- **RISK-003:** Six phases is a long wave, and the later phases (05, 06) are
  structural rather than corrective. Mitigation: the phases are independently
  landable and each has its own byte-identity and invariant exit criteria.
  PHASE-01 through PHASE-04 are the credibility-critical half; PHASE-05 and
  PHASE-06 may be split into a following wave without leaving anything in a
  half-finished state.
- **RISK-004:** Adding INV-013 without adding sidecars for the remaining five
  gated reports could read as false comfort — "facts are asserted" when only two
  reports assert any. Mitigation: S2 makes a missing sidecar an explicit skip,
  and the README wording added in TASK-03-09 must say which reports are covered.
- **ALT-001:** *Revive renv properly* — uncomment `.Rprofile`, run
  `renv::init()`, commit a working library state. Rejected: `renv.lock` cannot
  restore `trisk.model` (a pinned GitHub commit tarball), the project has never
  used renv in anger, and the repository already ships a working installer. The
  larger migration buys nothing this repo currently needs.
- **ALT-002:** *Fix CI and stop.* Genuinely valuable and much smaller. Rejected
  as the whole wave because it leaves `2.502e+10` on the public demo and leaves
  the gate structurally unable to catch the next wrong number.
- **ALT-003:** *Assert facts by parsing the HTML inside the invariant* rather
  than writing sidecars. Rejected: it would couple the invariant to each report's
  markup, and it could not check a value that the report renders only inside a
  PNG chart. The sidecar decouples the assertion from the presentation and is
  reusable by the dashboard.
- **ALT-004:** *Make the dashboard read a config file rather than an environment
  variable.* Rejected: the app already uses four environment flags
  (`BYOL_INTAKE`, `OUTPUTS_LAYER`, `TRISK_LIVE_RERUN`, `R_RSCRIPT`), Streamlit
  Community Cloud exposes environment configuration but not arbitrary local
  files, and a variable with a safe default keeps the public deployment
  byte-identical in behaviour.

## Suggested Next Step

Execute PHASE-01 and push it on its own branch. Its exit criteria are the only
ones in this plan that can be verified without it: run
`gh run list --limit 1 --json conclusion --jq '.[0].conclusion'` and require
`success` before starting PHASE-02. Until that command returns `success`, every
other phase's exit criteria are claims about one laptop rather than facts about
the repository.
