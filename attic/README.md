# Attic

Superseded methodology references, kept for historical context only. Not
maintained, not sourced by any pipeline script, and not covered by tests.

- `pacta_demo.R` — original generic PACTA demo (r2dii sample data), superseded
  by `scripts/pacta_vietnam_scenario.R`.
- `pacta_synthesis.R` — "best of both" synthesis demo, superseded by
  `scripts/pacta_vietnam_scenario.R`.
- `generate_report.R` (retired 2026-08-27, Wave 3 PHASE-02) — the HTML
  report generator for the r2dii-package demonstration pipeline above. Reads
  `output_dir <- "output"` and renders the 14 numbered CSV/PNG artifacts now
  under `demo_output/`. Retired because
  `dashboard/data/reports/PACTA_Alignment_Report.html` and
  `PACTA_Comparison_Report.html` (the reports it and `pacta_demo.R` produce)
  were being republished into the public Vietnam-facing dashboard snapshot —
  a European demo portfolio (`output/01_loanbook_sample.csv` row 1: "Vitale
  Group / Scholz KGaA / 225625 EUR / NACE D35.11") sitting inside a Vietnam
  bank showcase. No pipeline step invokes this script; it is called by no
  config and referenced by no CI job.
- `demo_output/` (retired 2026-08-27, Wave 3 PHASE-02) — the 14 numbered
  CSV/PNG files `generate_report.R` and `pacta_demo.R` produced under
  `output/` (matches `output/0[1-9]_*` and `output/1[0-4]_*`; not
  `output/engagement/`, `output/engagement_letters/`, `output/disclosure/`,
  or `output/trisk_inputs/`, which remain live pipeline output directories).

Their rendered HTML reports remain under `reports/` for methodology
reference (see `reports/report_catalog.json`, category
`methodology_reference`) but are no longer eligible for the public
dashboard snapshot.

## `compare/` — methodology-convergence comparison (retired 2026-09-02, Wave 4 PHASE-06)

`attic/compare/` holds a side-by-side comparison of this repository's PACTA
implementation against a staff-written reference implementation
(`PACTA for Banks staff.Rmd`, by Trang Tran), which used exact matching only
(`min_score = 1`), the official `r2dii.plot` package, and R Markdown. The
comparison documented that the two approaches converge, and produced
`reports/PACTA_Comparison_Report.html`.

It was retired because nothing live reads it: no pipeline step, script,
dashboard module or doc referenced `compare/` — only superseded plans and
research briefs did. It is kept for the same reason as everything else here:
the methodology-convergence exercise is worth being able to re-read, but it is
not part of any pipeline and is never tested.
- `PACTA_Synthesis_Report.html` (retired 2026-09-07, Wave 5 PHASE-04) — superseded methodology reference; the Vietnam bank report (`reports/PACTA_Vietnam_Bank_Report.html`) supersedes it. Retired together with its generator `attic/pacta_synthesis.R`.
