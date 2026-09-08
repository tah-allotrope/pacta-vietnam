---
title: "Wave 5: Gate Enforcement, Deliverable Truth, and the Read-Side Seam"
date: "2026-09-07"
type: "brainstorm"
depth: "standard"
source_request: "Unattended analysis: what would take pacta-trisk to the next level, grounded in the repo at b1d53e1 (post-Wave-4 0.6.0, plus the unrecorded orchestrator-planning refactor)"
slug: "wave5-gate-enforcement-and-deliverable-truth"
predecessors:
  - "research/2026-09-01-wave4-deliverable-trust-and-scale-followthrough-brainstorm.md"
  - "research/2026-08-26-wave3-convergence-vintage-and-delivery-readiness-brainstorm.md"
  - "research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md"
---

# Brainstorm: Wave 5 — Gate Enforcement, Deliverable Truth, and the Read-Side Seam

## Problem & Why Now

Wave 4 closed cleanly. I verified that independently before writing anything
here, and re-verified the whole platform from a cold start in this session:

| Check | Command | Result today |
|---|---|---|
| R suite | `Rscript -e "testthat::test_dir('tests/testthat')"` | `FAIL 0 \| WARN 5 \| SKIP 1 \| PASS 756` |
| Python suite | `python -m pytest dashboard/tests` | `69 passed` |
| Invariants | `Rscript tools/verify_refactor.R --invariants` | `INVARIANTS PASS` (INV-001..012) |
| Version | `DESCRIPTION` | `0.6.0` |
| Working tree | `git status` | clean, `main` at `b1d53e1` |

Every local gate is green. The pipeline runs 16 steps in 68.8 seconds. There
are zero `TODO`/`FIXME` markers in `R/`, `scripts/`, `tools/`, `dashboard/`
or `tests/`. By every measure this repository takes internal to itself, it is
in the best shape it has ever been.

Then I asked the one question the repository never asks itself: **does any of
this run anywhere except on this laptop?**

```
$ gh run list --limit 60 --json conclusion,createdAt,name
2026-07-10 success Refresh pipeline data
2026-07-10 failure CI
2026-07-13 failure CI
...  (28 more)  ...
2026-09-06 failure CI
2026-09-07 failure Refresh pipeline data
```

**Every CI run and every scheduled refresh has failed since 2026-07-10** — the
entire span of Waves 1, 2, 3 and 4. The byte-identity gate, the twelve
invariants, the 756 tests, the second-engagement end-to-end job, and the weekly
gated auto-refresh of the public demo have not executed successfully once in
two months. `python-tests` is the only job that passes, because it is the only
job that does not touch R.

That single fact reframes the wave. Waves 0–4 were about *building* verification
machinery. Wave 5 has to be about the machinery being **load-bearing**: it must
actually run, and — the second half of the same problem — it must check that the
numbers are *right*, not merely that they are *unchanged*. Because while looking
for the answer to the first question I found the second one already broken:

> The flagship bilingual client report says the Mekong Commercial Bank portfolio
> is **`2.502e+10 tỷ VND (~$1000800 tỷ USD)`**. The true figure is
> **25,020.0 bn VND (~US$0.95 bn)**. It is off by six orders of magnitude,
> rendered in raw scientific notation, converted at a hardcoded FX rate that
> contradicts the engagement config, and it is on the public demo right now.

Wave 4's gate did not catch it, and *cannot* catch it, because the gate compares
each report to its own committed version. It pins whatever was true at freeze
time. This one was wrong at freeze time.

## Current vs Desired State

**Current state.** Version `0.6.0`, `main` at `b1d53e1`. Two engagements
(`mcb-demo`, `sdb-rehearsal`) run through one declarative orchestrator; a
six-commit refactor (`b75e676`..`b1d53e1`, unrecorded in `plans/` or `NEWS.md`)
has since moved planning policy into `R/engagement_plan.R`. Seven HTML
deliverables are gated by normalized-content comparison; twelve invariants hold;
`library(pactatrisk)` exports 59 functions. CI is red on every push. The weekly
public-demo refresh has been failing for two months. The PACTA report and two
published charts state the portfolio total six orders of magnitude too large.

**Desired state.** A push that breaks a gate turns CI red *for that reason*, and
a push that breaks nothing turns it green. The weekly refresh republishes the
public snapshot or stops with a named drift. Every client-facing deliverable
asserts its headline figures against the CSV they came from, so a wrong number
fails a gate instead of being frozen by one. No money figure in the repository
is rendered outside `R/format_money.R`. The dashboard reads whichever snapshot
it is pointed at, so a client engagement is a directory, not a repository fork.
And the step registry knows what each step *needs*, not only what it *runs*.

**Key repo surfaces.** `.Rprofile`; `.github/workflows/ci.yml`;
`.github/workflows/refresh.yml`; `scripts/ci/install_deps.R`; `R/pacta_core.R`;
`R/format_money.R`; `tools/verify_refactor.R`; `R/step_registry.R`;
`R/engagement_plan.R`; `dashboard/lib/loaders.py`;
`dashboard/pages/6_Intake_Wizard.py`; `reports/report_catalog.json`;
`engagements/mcb-demo/engagement_config.json`.

## Findings

New findings are `N-2xx` to avoid colliding with the Wave 4 `N-1xx` series.
Every finding below was verified against the working tree or the live GitHub
Actions history in this session; the command, file:line or rendered artifact
that establishes it is quoted inline.

---

### N-201 — CI has failed on every run for two months; the gate apparatus is unenforced

**Severity: highest. Everything else in this document is downstream of it.**

`gh run list` over the last 60 runs returns exactly one success — a
`Refresh pipeline data` run on 2026-07-10, which produced the repository's only
automated commit (`9255692 chore: automated pipeline refresh 2026-07-10`).
Every run since has failed, including yesterday's scheduled refresh
(`34092172783`, 2026-09-07) and the most recent CI push (`34019743113`,
2026-09-06).

Job breakdown of the latest CI run:

```
sdb-engagement: failure
python-tests:   success
byte-identity:  failure
r-tests:        failure
```

The failing step and its exact error, from `gh run view 34019743113 --log-failed`:

```
Run r-lib/actions/setup-renv@v2
Installing package into '/home/runner/work/_temp/Library'
Error in contrib.url(repos, type) :
  trying to use CRAN without setting a mirror
Calls: install.packages -> startsWith -> contrib.url
Execution halted
```

The same error ends the 2026-09-07 weekly refresh at the same step.

**Root cause**, `.Rprofile` — the entire file:

```r
# source("renv/activate.R")
```

renv's activation line is commented out, and `git log --follow -- .Rprofile`
shows exactly one commit (`ff6dec9`): it has *never* been active. So on a clean
runner `setup-renv@v2` bootstraps into a project where renv was never
initialized, tries `install.packages("renv")` with no repository configured, and
dies before a single test, invariant or byte comparison executes. Locally
nothing notices, because the developer machine has all 24 packages in its user
library and never consults `renv.lock` at all.

The consequences are exactly as large as they sound:

- `README.md` states "Both `.github/workflows/ci.yml` and
  `.github/workflows/refresh.yml` run this on every push and every weekly
  refresh." `CLAUDE.md` law 5 states "Byte-identity runs in `ci.yml`'s
  `byte-identity` job on every push, and gates `refresh.yml`'s weekly
  auto-commit." Both statements are currently false.
- The `sdb-engagement` job exists specifically because `lessons.md` §4 argued
  that a fixture-content test is not a regression test and the orchestrator must
  actually be re-run "every push, not whenever someone remembers". It has never
  run.
- The public demo at `pactavn.streamlit.app` has not been refreshed since
  2026-07-10. Its freshness badge reads whatever the last hand-pushed manifest
  says (`2026-09-02`), and nothing on the page can distinguish "refreshed on
  schedule" from "the schedule has been dead for two months".

The repository's own documented fallback already solves this:
`scripts/ci/install_deps.R:22-26` explicitly handles the case CI is failing on —

```r
repos <- getOption("repos")
if (is.null(repos) || length(repos) == 0 || identical(unname(repos["CRAN"]), "@CRAN@")) {
  repos <- c(CRAN = "https://cloud.r-project.org")
}
```

— and it also pins `trisk.model` to a commit tarball, which `renv.lock` cannot
restore from CRAN anyway. CI uses `setup-renv@v2` instead of the installer the
project documents.

---

### N-202 — The flagship client report states the portfolio as `2.502e+10 tỷ VND (~$1000800 tỷ USD)`

Rendered text, `reports/PACTA_Vietnam_Bank_Report.html`, executive summary —
the first sentence a bank reader sees:

> Phân tích PACTA này đánh giá danh mục cho vay **2.502e+10 tỷ VND
> (~$1000800 tỷ USD)** của Mekong Commercial Bank …

The first KPI card, same page:

```html
<div class="value">2.502e+10</div>
<div class="label">bn VND<br>Tổng danh mục PACTA</div>
```

The same value appears in the portfolio table's "Tổng cộng" total row, and a
"Cơ hội tích cực" callout carries `3.25e+09 tỷ VND`.

**The true figure**, computed from the loanbook the report analysed:

```
total raw VND: 25,020,000,000,000
current render: 2.502e+10 "tỷ VND"   (format(round(x/1000), big.mark = ","))
correct:        25,020.0 bn VND      (format_vnd_bn(x))
correct USD @ the config's 26,300:   0.95 bn USD
```

**Cause.** Wave 2 PHASE-02 ("true VND everywhere, one money formatter") migrated
the repository to whole VND and created `R/format_money.R` so that "a unit fix or
a display-format change happens in one place instead of three".
`R/pacta_core.R` — the oldest and largest module, 1,474 lines — was never
migrated and does not source `R/format_money.R` at all. It still divides whole
VND by **1000** and labels the result "bn VND" / "tỷ VND" in ten places:
lines 68, 70, 131, 280, 327, 772, 786, 909, 919-929, and the Vietnamese
narrative at 1119. Above 1e15, `format(round(x), big.mark = ",")` also falls back
to scientific notation, which is where `2.502e+10` comes from rather than a
merely-wrong `25,020,000,000`.

**The report contradicts itself, which is the tell.** Line 1251 carries a
hand-written narrative constant:

> Ngành điện chiếm **63% danh mục MCB** (15,750 tỷ VND).

15,750 tỷ VND *is* 63% of 25,020 tỷ VND. The hardcoded prose was written on the
correct post-migration scale; every computed figure around it was not.

**Blast radius** — everything below is regenerated by the pipeline and published:

| Artifact | Where the wrong figure appears | Published to |
|---|---|---|
| `reports/PACTA_Vietnam_Bank_Report.html` | exec summary, KPI card, portfolio total, callout | gated deliverable; rendered inline on the public dashboard's Reports page |
| `dashboard/data/pacta/03_vn_coverage_pie.png` | chart subtitle: `Total: 2.502e+10 bn VND` (visually confirmed) | public dashboard, PACTA Alignment page |
| `dashboard/data/pacta/13_vn_coal_stranded_risk.png` | per-borrower bar labels in "bn VND" | public dashboard |
| console | `pacta_load_inputs()` and `scripts/pacta_vietnam_scenario.R:91` summaries | pipeline logs |

**A hardcoded FX rate compounds it.** Lines 70 and 1119 divide by a literal
`25000` while `cfg$inputs$fx_rate_usd_vnd` is `26300` in both engagement configs
— the config value the intake layer already uses to convert USD rows.

**The good news, verified:** no committed CSV carries a `/1000`-scaled column. I
checked every header in `synthesis_output/vietnam/`, `dashboard/data/pacta/`,
`output/engagement/` and `synthesis_output/prioritization/` for a `bn` column and
found none — `total_bn_vnd` at `R/pacta_core.R:131` and `:280` is printed to the
console, never written. So **fixing this moves no golden number**. It changes one
gated HTML file and two PNGs, which is the cheapest possible correction of a
defect this visible.

---

### N-203 — The gate detects change, not correctness — and Wave 4 decided otherwise

This is the general form of N-202, and it was foreseen. Wave 4's own
**DEC-001** reads:

> Gate HTML by normalized content, not byte-identity … strip the known
> timestamp/`git_sha` spans, hash the remainder, **and pin a small set of content
> assertions per deliverable (the synthetic-data disclaimer is present; named
> headline figures match the CSV they came from).**

Only the first assertion was built. `inv_deliverables_carry_disclaimer()`
(INV-010) checks the disclaimer; nothing anywhere checks a *number*. The
mechanism that remains, `.html_is_timestamp_only()` at
`tools/verify_refactor.R:103`, compares the working tree to the **HEAD blob**.
That is a change detector. Applied to a value that was already wrong when it was
committed, it becomes a preservation mechanism: the gate added in Wave 4 to
protect the deliverables is what now guarantees `2.502e+10` survives every future
refresh unchanged.

Wave 4's own `OQ-001` asked precisely this and answered "both — hash for change
detection, assertions for the disclaimer and headline figures". Half of that
answer is still owed.

The generators already compute every figure they render, so the cost is low: each
report writes a `<report>.facts.json` sidecar of its headline values; an
invariant recomputes those values from the source CSV and compares; a second
check asserts the formatted string actually appears in the HTML. That would have
failed on the day `2.502e+10` was first written, and it makes the PNG charts
— currently exempt from the gate entirely, "compared visually only" — checkable
through their underlying facts rather than their pixels.

---

### N-204 — A gated, published deliverable is generated by a script that was retired to `attic/`

`reports/PACTA_Synthesis_Report.html` is:

- in `GATED_HTML_PATHS` (`tools/verify_refactor.R:75`),
- in `DISCLAIMER_HTML_PATHS`,
- in `engagements/mcb-demo/engagement_config.json`'s `published_reports`,
- copied into `dashboard/data/reports/` and rendered inline to every visitor of
  the public Reports page.

And the only file in the repository that can produce it is
`attic/pacta_synthesis.R` — the do-not-touch directory that `CLAUDE.md` defines
as "retired methodology-reference scripts … Not sourced by any pipeline, not
tested." `git log -- reports/PACTA_Synthesis_Report.html` returns a single
commit: `f6597e5 first commit`.

So one of the seven "gated" deliverables can never drift, because nothing
regenerates it — the gate passes trivially forever. Meanwhile the public demo
ships it as a current artifact alongside reports that *are* rebuilt every run. If
the pipeline's numbers move, this report silently stops agreeing with them, and
no invariant is structurally capable of noticing: INV-001..012 compare artifacts
to *each other*, and this one has no counterpart to be compared against.

**Related, same class:** `reports/report_catalog.json` carries a hand-typed
`date` per report, shown to users by `dashboard/pages/3_Reports.py:24`
(`st.caption(report["date"])`). It says `2026-03-20` for
`PACTA_Vietnam_Bank_Report.html`, a file the weekly refresh regenerates. This is
`CLAUDE.md` law 9's principle (never state a fact no gate verifies) applied to a
field nobody has revisited.

---

### N-205 — The step registry declares scripts but not dependencies, so `--only-step` can silently produce stale output

`R/step_registry.R` is a genuine improvement over the `if` ladder it replaced,
but it encodes only *what to run*, never *what a step needs*. The dependencies
exist — as comments:

```r
    # Wave 3 PHASE-05: reads output/engagement/engagement_priority.csv, so
    # it must run after engagement_scoring.
    financed_emissions = list(...)
```

Nothing enforces that. Two paths break it:

1. `resolve_step_list()` accepts `cfg$steps` in **any order** and validates only
   that each name exists in the registry.
2. `filter_step_list(steps, only = "financed_emissions")` will happily run that
   step alone, against whatever `engagement_priority.csv` is left on disk from a
   previous run, and the step will exit 0.

Wave 4 PHASE-02 hardened the *manifest* against this (a filtered run is marked
`partial` and refuses to clobber a complete public manifest). It did not harden
the *data*: a partial run still reads stale upstream artifacts and writes
confident downstream ones. The manifest will say `partial: true`; the CSV it
describes will look exactly like a good one.

Giving each registry entry `requires` / `produces` file lists would (a) let
`plan_engagement_run()` reject a `cfg$steps` order that violates a dependency,
(b) let the runner refuse or warn when a required input predates the run,
(c) hand the refresh audit a real provenance graph instead of a step list, and
(d) make incremental re-runs possible at real-client scale, where re-running 16
steps to redo one is not free.

---

### N-206 — The `pactatrisk` package is a façade the pipeline never loads

```
$ grep -rn 'source("R/' scripts/*.R tools/*.R | wc -l
70
$ grep -rn "library(pactatrisk)\|pactatrisk::" --include=*.R . | grep -v attic
./tests/testthat.R:7:library(pactatrisk)
```

Seventy `source()` calls; `R/engagement_config.R` alone is sourced by 21
different scripts. The single `library(pactatrisk)` is in `tests/testthat.R`,
which **never executes**: CI runs `testthat::test_dir()` (and would run
`devtools::load_all()`, which loads everything in `R/` regardless of
`NAMESPACE`), not `R CMD check`. The test files themselves `source()` the module
files directly via `helper-root.R`'s `project_root()`.

Wave 4 PHASE-04 correctly identified that 20 exported functions were missing from
`NAMESPACE`, restored the surface (33 → 55, now 59 exports, 79 `man/` pages) and
added a CI check that `roxygen2::roxygenise()` produces no diff. All of that
guards an interface that **no caller in this repository uses**. The package is
documented, exported, version-bumped and CI-checked; it is not consumed.

The choice is worth making explicitly rather than by drift: either make the
scripts consume the package (`library(pactatrisk)` with a `devtools::load_all()`
dev fallback), which makes the export surface load-bearing and gives the
byte-identity gate a second thing to prove; or demote the package to
"documentation and test entrypoint only" and stop paying for the upkeep. The
first is the better trade — it removes 70 hand-maintained load statements and
makes the tested loading path the same one production uses.

---

### N-207 — Multi-engagement viewing is blocked by one module-level constant, and the private-instance recipe is fork-per-client

`dashboard/lib/loaders.py:10-17`:

```python
ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
PACTA_DIR = DATA_DIR / "pacta"
...
```

Every path helper derives from that import-time constant, so the app can only
ever read `dashboard/data`. Three brainstorms have recorded multi-engagement
viewing as "blocked by design" (`CON-004`). What it is actually blocked by is one
line.

The cost of the workaround is in `docs/private-instance-deploy.md`, which tells
an operator to clone the whole repository per bank, delete `dashboard/data/*`,
copy the client snapshot in, and push to a private repo. Every client instance is
a **fork that never receives another fix**. With BIDV and Techcombank both live,
that is the maintenance shape being locked in.

The write side already solved the corresponding problem: an engagement may not
publish into `dashboard/data` unless `public_snapshot_allowed` is true
(`R/engagement_plan.R:74`). The read side needs the twin — resolve the snapshot
root from `PACTATRISK_SNAPSHOT_DIR` (default `dashboard/data`), plus an
operator-gated picker that lists `engagements/*/snapshot/`, following the exact
env-flag pattern `BYOL_INTAKE` / `OUTPUTS_LAYER` / `TRISK_LIVE_RERUN` already
establish. The public build keeps the default and changes in no way. A client
engagement becomes a directory, not a fork.

---

### N-208 — The MoU's "KPI/SPT input" has no artifact; the value chain stops at the SLL shortlist

Per the recorded GTB 2026 client scopes, the BIDV MoU commits to a
financed-emissions toolset, a framework recommendation report, an SLL
client-readiness screen with a shortlist of three, **and KPI/SPT input for two
clients**. The first three exist and are good. The fourth:

```
$ grep -rli "SPT|sustainability performance target" --include=*.R --include=*.md --include=*.csv .
./research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md
```

One hit, in a brainstorm that scoped KPI/SPT out as "advisory-only". That
framing is worth revisiting, because the MoU wording is *input*, not *design* —
and every input the pack would need already exists and is already computed:

- `sll_readiness.csv` — who is on the shortlist, with readiness band and
  materiality/exposure/data-availability components,
- `target_registry.csv` — per sector and horizon (2030 proposed / 2035 / 2050
  not_set) the baseline value, target value, method (`market_share` /
  SDA convergence) and scenario vintage,
- `financed_emissions.csv` — attribution factor, borrower emissions and a PCAF
  data-quality score per borrower,
- `06_vn_ms_alignment_2030.csv` / `06_vn_sda_alignment_2030.csv` — the
  benchmark-measured gap.

A `generate_sll_term_inputs.R` step joining those would produce, per shortlisted
borrower: observable KPI candidates ranked by data quality, the baseline the KPI
starts from, the SPT trajectory implied by the sector's convergence path, and an
ambition test against the scenario — as a CSV plus a bilingual HTML pack, with
the house-standard caveat that these are indicative inputs for advisor review,
not a term sheet. It is the natural terminal node of the chain the platform
already builds (alignment → stress → engagement priority → SLL readiness → **KPI/SPT
input**), and it is the only MoU commitment with no artifact at all.

---

### N-209 — A quarter of the engagement priority list is scored on half the evidence

```
rows 23 | sectors: power 13, automotive 6, steel 2, cement 2
composite_partial: FALSE 17, TRUE 6
```

All six `composite_partial = TRUE` rows are automotive: they have PACTA alignment
but no TRISK run, because `trisk_sectors` is `power, cement, steel`. Automotive
is the second-largest sector by borrower count in the book, and the demo's
headline EV/Vingroup narrative sits inside it. Open since the 2026-07-13 runway
brainstorm (T3.1).

It is cheaper now than when it was deferred: `trisk_prepare_sector_inputs()` is
sector-generic, `R/sector_registry.R` is the single source of truth, and
INV-004/INV-005 already enforce that a new sector is added everywhere or nowhere.
The real question is methodological, not structural — automotive stress needs a
production/market-share shock rather than the CO2-intensity path cement and steel
use — which is why this is a candidate rather than a certainty for this wave.

---

### N-210 — Real-loanbook intake is a first-class layer; real-ABCD intake is not

The loanbook side is genuinely production-shaped: `intake/SCHEMA.md` states the
contract, `scripts/intake_validate_and_map.R` (616 lines) validates and
normalizes it, `generate_validation_report.R` and `generate_coverage_report.R`
tell the client what happened to every row in both counts and VND, and a wizard
page drives it.

The ABCD side — the other half of what PACTA needs, and the half
`docs/abcd_sourcing_decision.md` says a real bank must license or build — has
`validate_abcd_schema()` in `R/trisk_core.R:53`, called from exactly one place:

```
R/trisk_core.R:513:  validate_abcd_schema(vietnam_abcd, source_label = cfg$inputs$abcd_csv)
```

That is inside `trisk_prepare_sector_inputs()`, which runs **after** PACTA.
`pacta_load_inputs()` (`R/pacta_core.R:28`) reads the ABCD with no validation
whatsoever — it checks only that the file exists. So a malformed, wrong-vintage
or thin ABCD reaches `match_name()` unchecked, and the first thing that notices
is a sparse match rate three steps later, or a TRISK failure four steps later.

Two things close the asymmetry, and both are small: validate the ABCD at load in
the PACTA path (the validator already exists), and add an ABCD coverage report —
what share of matched exposure has asset-level data, by sector, with
`data_source` and `as_of_year` provenance. That is the input-side twin of the
coverage & reconciliation report, and it is the engineering half of a decision
whose procurement half is already documented.

---

### N-211 — The intake wizard leaves a client's raw workbook in the OS temp directory

`dashboard/pages/6_Intake_Wizard.py:57-72`:

```python
with tempfile.NamedTemporaryFile(suffix=f"_{file_name}", delete=False) as tmp:
    tmp.write(file_bytes)
    tmp_path = Path(tmp.name)
...
if file_name.endswith(".xlsx"):
    tmp_path = convert_xlsx_to_csv(tmp_path)      # rebinds tmp_path
```

and the only cleanup, at line 175:

```python
    try:
        tmp_path.unlink()
```

On the XLSX path `tmp_path` has been rebound to the converted CSV, so the
original workbook — a real bank's loanbook with real counterparty names — is
never deleted. Cleanup is also not in a `finally`, so every `st.stop()` on a
validation error skips it entirely.

`docs/intake_privacy.md` lists "Delete temporary uploaded files after
processing" as an operator responsibility. The code makes that impossible to
honour without manually finding `intake_xlsx_*.csv` and `*_<filename>` files in
the system temp directory. `dashboard/lib/live_rerun.py:93` does the right thing
(`os.unlink(output_path)`), so the pattern is present in the codebase, just not
here — on the one page that handles real client data.

---

### N-212 — The largest client-facing generator in the repo has no test

| Script | Lines | Test referencing it | Produces |
|---|---|---|---|
| `scripts/generate_bidv_report.R` | 1,078 | none | `BIDV_Framework_Recommendation_Report.html` (gated, published, named after the MoU client) |
| `scripts/generate_validation_report.R` | 326 | none | `Intake_Validation_Report.html` (client deliverable) |
| `scripts/generate_refresh_audit.R` | 244 | none | `pipeline_refresh_audit.html` (gated) |
| `scripts/generate_financed_emissions.R` | 123 | none | `Financed_Emissions.html` (gated) |

Their only protection is the HTML snapshot gate — which, per N-201, has not run
in CI for two months, and which per N-203 cannot tell a wrong number from a right
one. `R/sector_registry.R` is also the one R module with no dedicated test file,
though INV-004 covers it indirectly.

---

### N-213 — Documentation that no gate can check has drifted

- `activeContext.md` names `plans/2026-08-26-wave3-convergence-vintage-delivery-plan.md`
  as the "current program". Wave 3 shipped, Wave 4 shipped and was triaged
  complete, and the actual current work is the unrecorded orchestrator refactor.
- `research/future_planning_ideas.md` (2026-04-28) proposes three "next phase"
  ideas — multi-sector TRISK, a pipeline refresh orchestrator with a
  reproducibility report, and an engagement action layer. All three shipped
  months ago. The file reads as a live roadmap and is a fossil.
- `plans/PROGRESS.md` is accurate and well-maintained; it is the model the other
  two should follow.

`CLAUDE.md` law 9 already codifies the underlying rule for changelogs ("nothing
verifies a hand-typed count, so it silently goes stale"). These are the same
failure in files the law does not name.

---

### N-214 — The orchestrator-planning refactor is unrecorded

Six commits, `b75e676`..`b1d53e1`, created `R/engagement_plan.R` (251 lines) and
moved CLI parsing, step resolution, the intake split, the manifest path/partial
policy, the guard rail and the banner out of `scripts/run_engagement.R`, with
`tests/testthat/test_engagement_plan.R` growing alongside (the R suite is up from
680 at Wave 4's close to 756 today). The work is coherent, tested and green.

It appears in no plan file, no `NEWS.md` entry and no report. Triage cannot see
it; a future session cannot tell whether it is finished or abandoned mid-stream.
The module's own header says "Execution (subprocesses, manifest JSON shape) stays
in `R/step_runner.R`", which reads like a deliberate stopping point — and step 6
was documentation only, which reads like a wrap-up. It should be recorded as
either, explicitly. It is also the natural foundation for N-205: the
`requires`/`produces` validation belongs in `plan_engagement_run()`, exactly
where planning policy now lives.

---

### N-215 — Smaller notes, verified but not wave-shaping

- **The demo's match rate is 100%.** 43 loans, 43 matched
  (`02_vn_matched_prioritized.csv`), which is why
  `03_vn_coverage_pie.png` is a single-slice pie chart carrying no information.
  A bank evaluator's first practical question is "what fraction of my book will
  actually match?", and the synthetic fixture is too clean to answer it or to
  showcase the coverage & reconciliation report built for exactly that question.
  A deliberately imperfect fixture (unmatchable names, out-of-scope sectors,
  missing LEIs) would demo better than a perfect one.
- **No linter, formatter or type checker** for either language, and no
  `pyproject.toml`. For a repository this disciplined about semantic gates, the
  syntactic ones are conspicuously absent — though they are also the least
  valuable thing to add, so they belong in a wave's tail, not its head.
- **`dashboard/requirements.txt` is unpinned ranges** while
  `requirements.lock` is fully pinned. CI installs the lock (correct); the
  README's quick start installs `requirements.txt` (drift-prone).
- **Performance is not a problem** and should not be optimized: the full MCB
  pipeline is 68.8 s across 16 steps, with the 243-cell × 3-sector scenario grid
  served in 3.0 s from a fingerprint-validated cache. The open scale question is
  the one Wave 4 deliberately left (TASK-05-08): the PACTA and TRISK stages have
  never been timed at real-book scale, and `tools/generate_scale_fixture.R`
  emitting asset-level inputs is the named prerequisite.
- **`present/` holds ~40 MB of tracked `.pptx`/`.pdf` deck archives** (four
  decks, two of them in `archive/`). Not urgent; worth knowing before anyone
  wonders why a clone is slow.

## Resolved Decisions

Adopted here without asking, per the unattended-analysis brief. Each is the
option I would have recommended.

- **DEC-201 — Fix CI by adopting the repository's own documented installer, not
  by reviving renv.** `.Rprofile` has never activated renv, `renv.lock` cannot
  restore `trisk.model` (it is a pinned GitHub tarball, not a CRAN package), and
  `scripts/ci/install_deps.R` already handles repository configuration and the
  tarball correctly. Replace `r-lib/actions/setup-renv@v2` with
  `setup-r` (`use-public-rspm: true`) plus `Rscript scripts/ci/install_deps.R` in
  all four R jobs, and keep `renv.lock` as the declarative manifest INV-008
  already checks `DESCRIPTION` against. Reviving renv properly is the larger,
  slower alternative and buys nothing this repo currently uses.
- **DEC-202 — Treat the VND display fix as a reviewed refreeze of one HTML file
  and two PNGs, not a golden refreeze.** Verified: no committed CSV carries a
  `/1000`-scaled column, so no golden number moves. `refresh.yml`'s manual
  `allow_drift: true` dispatch exists for exactly this, and
  `tests/testthat/test_golden_numbers.R` must stay green through it — that is the
  proof the change is display-only.
- **DEC-203 — Route every money render in `R/pacta_core.R` through
  `R/format_money.R`, and take the FX rate from `cfg$inputs$fx_rate_usd_vnd`.**
  No new formatter, no new config key. The hardcoded `25000` is deleted, not
  parameterized separately.
- **DEC-204 — Build the fact-assertion half of Wave 4's DEC-001 as sidecar JSON
  per report, checked by a new invariant.** Not by parsing HTML with regexes in
  the invariant, and not by embedding assertions in the generators' own tests —
  a sidecar is machine-readable, diffable, reusable by the dashboard, and lets
  the same check cover the PNG charts, which the gate cannot see at all.
- **DEC-205 — Retire `PACTA_Synthesis_Report.html` rather than resurrect its
  generator.** The catalog itself classifies it `methodology_reference`, the
  Vietnam report supersedes it, and its generator was deliberately retired. Drop
  it from `published_reports`, `GATED_HTML_PATHS` and `dashboard/data/reports/`,
  and move the file to `attic/` beside `attic/pacta_synthesis.R`.
- **DEC-206 — Derive `report_catalog.json`'s date from the artifact, not from a
  typed string.** Same principle as `CLAUDE.md` law 9.
- **DEC-207 — Put `requires`/`produces` validation in `plan_engagement_run()`,
  not in `run_steps()`.** Planning policy now has a home
  (`R/engagement_plan.R`); the runner should stay an executor. A missing-input
  check at execution time is a second, cheaper guard, not the primary one.
- **DEC-208 — Make the dashboard snapshot root an environment variable with the
  current path as its default.** `PATH`-shaped configuration, not a config file,
  matching the four env flags the app already uses. The public deployment sets
  nothing and behaves identically.

## Assumptions & Constraints

- **ASM-201:** The GitHub Actions failures are environmental (dependency
  bootstrap), not a genuine test or gate failure. Evidence: the same suites, the
  same invariants and the same byte-identity check all pass locally today at
  `b1d53e1`. Risk: fixing CI may reveal a *real* platform difference
  (Windows-authored artifacts vs Linux runner, `core.autocrlf`, locale-dependent
  Vietnamese collation). The first green CI run is therefore a discovery step,
  and the wave should budget for one round of genuine cross-platform fixes.
- **ASM-202:** Correcting N-202 changes `reports/PACTA_Vietnam_Bank_Report.html`,
  `03_vn_coverage_pie.png` and `13_vn_coal_stranded_risk.png`, and nothing else.
  Verified by inspecting every committed CSV header for a scaled column.
- **ASM-203:** The public Streamlit deployment tracks `main`, so a corrected
  report reaches the live demo on the next push — which makes N-202 both the most
  visible defect and the fastest-visible fix.
- **CON-201:** `CLAUDE.md` laws 2 (VND never rescaled) and 5 (byte-identical MCB
  CSVs) bind every task here. The VND fix is legal precisely because it is a
  display-layer change; law 2's carve-out ("except where existing code already
  does so for display") is what the current code leans on, and the fix replaces
  an ad-hoc display divisor with the sanctioned formatter.
- **CON-202:** No new pipeline dependency (law 8). Every finding above is
  addressable with the 24 packages in `renv.lock`.
- **CON-203:** `dashboard/data/` may be written only by
  `scripts/refresh_dashboard_data.R`; the snapshot-root change (N-207) is
  read-side only and must not touch that rule.

## Approaches Considered

- **APP-201 (recommended) — "Make the gates real, then make the numbers true."**
  Sequence: CI green (N-201) → VND correction + fact assertions (N-202, N-203) →
  cheap truth cleanups (N-204, N-211, N-213, N-214) → step dependencies and the
  package seam (N-205, N-206) → read-side snapshot seam (N-207). Rationale: no
  finding below N-201 can be *proven* fixed until N-201 lands, and N-202 is the
  only defect currently visible to a prospective client.
- **APP-202 — Client-value-first.** Start with N-208 (KPI/SPT pack), N-209
  (automotive TRISK) and N-207 (multi-engagement viewing). Rejected as the *lead*:
  building new client-facing artifacts on an unverified pipeline compounds the
  exact risk N-202 demonstrates. Better as the wave's second half or the next
  wave, once the gates run.
- **APP-203 — Report-shell refactor first** (the 12 generators' duplicated CSS
  and ~4,000 lines of `paste0` HTML, deferred by Wave 4 until PHASE-01 made it
  verifiable). Deferred again, one wave: it is *verifiable* only if the gate
  actually runs, which is N-201, and it is *safe* only if the deliverables assert
  their facts, which is N-203. After both, it becomes a low-risk mechanical
  refactor — and `pacta_build_report()` at ~570 lines, the largest function in
  the repository, is its natural first target.
- **APP-204 — Minimal patch: fix CI and stop.** Tempting and genuinely valuable,
  but it leaves `2.502e+10` on the public demo and leaves the gate structurally
  unable to catch the next one.

## Out of Scope

- Refactoring `R/pacta_core.R` or `R/trisk_core.R` for their own sake — the VND
  work touches `pacta_core.R`'s display layer only.
- The report-shell/CSS consolidation (see APP-203) — deferred one more wave, with
  its two named prerequisites.
- The ABCD procurement decision itself (`docs/abcd_sourcing_decision.md`);
  N-210 is the engineering half only.
- Migrating off Streamlit, or full Vietnamese narrative translation beyond the
  existing label/disclaimer layer.
- Optimizing `r2dii.match::match_name()` or the pipeline runtime — measured at
  68.8 s end to end; there is nothing here to optimize.
- Any change to the MCB public snapshot's published *numbers* other than the
  display-layer corrections in N-202.

## Open Questions

Recorded, not blocking; each has a stated default so a plan can proceed.

- **OQ-201:** Should CI gain a scheduled "is CI still green?" notification, given
  that two months of red went unnoticed? *Default: yes, minimally — add
  `if: failure()` notification to `refresh.yml` and a badge to `README.md`. A red
  badge in the README is the cheapest instrument that would have caught this.*
- **OQ-202:** Should the fact sidecars be committed, or generated and checked in
  memory? *Default: committed. They are small, they diff legibly, they let the
  dashboard show "this report's headline figure, and the CSV it came from", and a
  committed sidecar makes the invariant a three-way check (CSV → sidecar → HTML)
  rather than two-way.*
- **OQ-203:** Should `--only-step` **refuse** to run with stale inputs, or warn?
  *Default: warn by default, refuse under a new `--strict-deps` flag, and always
  record the staleness in the manifest. `--only-step` is a debugging affordance;
  making it refuse outright would hurt its main use.*
- **OQ-204:** Does the multi-engagement picker (N-207) belong behind a new env
  flag or the existing `OUTPUTS_LAYER`? *Default: a new `ENGAGEMENT_PICKER=1`.
  The existing flags each gate one page; this gates a global data-source change
  and deserves its own switch.*
- **OQ-205:** Should the synthetic fixture be made deliberately imperfect
  (N-215) so the demo can show a realistic match rate? *Default: not this wave —
  it would move every golden number, which is the most expensive kind of change
  this repository can make. Worth a dedicated, planned refreeze later.*

## Suggested Next Step

Run `/plan wave5-gate-enforcement-and-deliverable-truth` against this document,
sequenced as **APP-201**.

Land N-201 first and alone. It is a workflow-file change plus a one-line
`.Rprofile` decision, it can be verified the moment it is pushed, and until it is
green every other claim in this repository — including every claim in this
document — rests on one laptop. Land N-202 second: it is the only defect a bank
evaluator can currently see, the fix moves no golden number, and it reaches the
live demo on the next push.
