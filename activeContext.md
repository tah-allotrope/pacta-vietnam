# Active Context: PACTA Vietnam Project

> Last updated: 2026-03-20 (Session 6 — Vietnam-specific pipeline written, partially executed)

## Project Goal

Learn and run the **PACTA (Paris Agreement Capital Transition Assessment)** tool end-to-end as a complete beginner. Specifically:

1. Understand the PACTA ecosystem (`r2dii.data`, `r2dii.match`, `r2dii.analysis`)
2. Have a comprehensive beginner guide saved as markdown
3. Run a complete demo of the PACTA pipeline with results, visualizations, and interpretation
4. Generate a professional, shareable HTML report with embedded visualizations
5. Compare AI implementation against Staff's independent implementation and produce a comparison report
6. Synthesize a "best of both" production pipeline merging AI + Staff approaches into a single script and HTML report
7. Build a Vietnam-specific PACTA pipeline using synthetic Vietnamese bank data (MCB) and adapted scenarios (PDP8, NDC, NZE)

**Status: 1–6 COMPLETE. Step 7 IN PROGRESS (pipeline partially executed — see Session 6)**

---

## Project Structure

```
pacta-vietnam/
├── activeContext.md              # This file — project memory & state tracker
├── scripts/
│   ├── pacta_demo.R              # Original AI demo pipeline (532 lines, 6 phases)
│   ├── generate_report.R        # Original AI HTML report generator
│   └── pacta_synthesis.R        # ★ Synthesis pipeline: best-of-both (~690 lines, 8 sections + HTML)
├── compare/
│   ├── PACTA for Banks staff.Rmd  # Staff's independent Rmd implementation (Trang Tran)
│   ├── PACTA for Banks staff.html # Staff's rendered HTML output
│   ├── MathJax staff.js           # MathJax library bundled for staff HTML
│   ├── compare_report.R           # Comparison report generator (AI vs Staff)
│   └── output/                    # 13 side-by-side comparison charts (PNG)
│       ├── 01_match_comparison.png
│       ├── 02a_power_techmix_ai.png
│       ├── 02b_power_techmix_staff.png
│       ├── 03a_auto_techmix_ai.png
│       ├── 03b_auto_techmix_staff.png
│       ├── 04a_renew_traj_ai.png
│       ├── 04b_renew_traj_staff.png
│       ├── 05a_cement_ai.png
│       ├── 05b_cement_staff.png
│       ├── 06a_steel_ai.png
│       ├── 06b_steel_staff.png
│       ├── 07_coverage_pie_staff.png
│       └── 08_alignment_overview_ai.png
├── output/
│   ├── 01_loanbook_sample.csv   # Sample of loanbook input data (20 rows)
│   ├── 01_abcd_sample.csv       # Sample of ABCD asset data (20 rows)
│   ├── 02_matched_raw.csv       # 326 rows of raw fuzzy matches
│   ├── 02_matched_prioritized.csv  # 177 rows after prioritization
│   ├── 03_match_coverage_by_sector.png
│   ├── 04_market_share_targets_portfolio.csv  # 1,210 rows
│   ├── 04_market_share_targets_company.csv    # 37,349 rows
│   ├── 05_power_techmix.png
│   ├── 06_power_renewables_trajectory.png
│   ├── 07_power_coal_trajectory.png
│   ├── 08_automotive_techmix.png
│   ├── 09_automotive_ev_trajectory.png
│   ├── 10_sda_targets_portfolio.csv  # 220 rows
│   ├── 11_cement_emission_intensity.png
│   ├── 12_steel_emission_intensity.png
│   ├── 13_alignment_summary_market_share.csv
│   ├── 13_alignment_summary_sda.csv
│   └── 14_alignment_overview.png
├── docs/
│   └── PACTA_Beginner_Guide.md  # Comprehensive beginner guide (439 lines)
├── reports/
│   ├── PACTA_Alignment_Report.html     # AI demo report (312 KB)
│   ├── PACTA_Comparison_Report.html    # AI vs Staff comparison (321 KB)
│   └── PACTA_Synthesis_Report.html     # ★ Best-of-both synthesis report (345 KB)
├── synthesis_output/              # ★ Output from synthesis pipeline
│   ├── 01_matched_raw.csv         # 312 raw fuzzy matches (min_score=0.9)
│   ├── 01_review_needed.csv       # 23 matches with score < 1.0 for manual review
│   ├── 02_matched_prioritized.csv # 177 prioritized matches
│   ├── 03_coverage_pie.png        # Coverage pie chart (with "Not in Scope")
│   ├── 04_coverage_bar.png        # Coverage bar chart by sector
│   ├── 05_market_share_portfolio.csv  # 1,210 portfolio-level market share rows
│   ├── 05_market_share_company.csv    # 37,349 company-level rows
│   ├── 06_power_techmix.png       # r2dii.plot power technology mix
│   ├── 06_sda_portfolio.csv       # 220 SDA target rows
│   ├── 07_alignment_market_share.csv  # Market share alignment gaps
│   ├── 07_alignment_sda.csv       # SDA alignment gaps
│   ├── 07_auto_techmix.png        # r2dii.plot automotive technology mix
│   ├── 08_power_renewables_traj.png   # Renewables trajectory
│   ├── 09_power_coal_traj.png     # Coal trajectory
│   ├── 10_auto_ev_traj.png        # EV trajectory
│   ├── 11_auto_ice_traj.png       # ICE trajectory (new — from Staff)
│   ├── 12_cement_emission.png     # r2dii.plot cement emission intensity
│   ├── 13_steel_emission.png      # r2dii.plot steel emission intensity
│   └── 14_alignment_overview.png  # Multi-sector alignment overview (custom ggplot2)
├── data/                          # ★ Vietnam-specific synthetic input data (Session 6)
│   ├── generate_vietnam_data.R    # Generator script for all 5 Vietnam CSVs
│   ├── vietnam_loanbook.csv       # Synthetic MCB loanbook (VND, ISIC codes, Vietnamese names)
│   ├── vietnam_abcd.csv           # Vietnam ABCD: EVN, Vinacomin, VinFast, THACO, VICEM, Hoa Phat, etc.
│   ├── vietnam_scenario_ms.csv    # PDP8/NDC/NZE market share scenario pathways
│   ├── vietnam_scenario_co2.csv   # CO2 intensity scenarios for cement & steel
│   └── vietnam_region_isos.csv    # Vietnam region ISO mapping
├── plans/                         # ★ Implementation plans (Session 6)
│   └── vietnam_bank_pacta_scenario_plan.md  # Full blueprint (~700 lines): Vietnam context, data design, roadmap
├── scripts/
│   ├── debug_ms.R                 # ★ Diagnostic for market share region/metric debugging
│   └── pacta_vietnam_scenario.R   # ★ Vietnam pipeline for Mekong Commercial Bank (1352 lines)
├── synthesis_output/vietnam/      # ★ Partial outputs from Vietnam pipeline (Sections 1–9 only)
│   ├── 01_vn_matched_raw.csv
│   ├── 02_vn_matched_prioritized.csv
│   ├── 03_vn_coverage_pie.png
│   ├── 04_vn_ms_portfolio.csv
│   ├── 04_vn_ms_company.csv
│   ├── 05_vn_power_techmix.png
│   ├── 06_vn_coal_trajectory.png
│   ├── 07_vn_renewables_trajectory.png
│   ├── 08_vn_auto_techmix.png
│   └── 09_vn_ev_trajectory.png
│   (MISSING: SDA outputs, alignment gaps, alignment overview, HTML report)
└── .opencode/                    # OpenCode tool internals (do not edit)
```

## What Was Done (Chronological)

### Session 1–2: Research through Report Generation

| Phase | Description | Outcome |
|---|---|---|
| A. Research | Studied DeepWiki pages for r2dii.data/match/analysis + official PACTA cookbook | Synthesized into beginner guide |
| B. Guide | Created `PACTA_Beginner_Guide.md` | 368-line comprehensive reference |
| C. Environment | Installed R 4.5.2, all packages to user library | Working R environment |
| D. Demo | Wrote & ran `pacta_demo.R` (6 phases) | 12 plots + 10 CSVs (Phases 1–4 clean) |
| E. Bug Fix | Fixed SDA metric naming bug (demo vs real scenario names) | All 18 outputs clean |
| F. Discussion | Interpreted all results across 4 sectors | Full alignment verdict |
| G. Report | Built `generate_report.R` with base64 image embedding | Self-contained 312 KB HTML |

### Session 3: Cleanup & Reorganization

- Updated `activeContext.md` with all findings and final state
- Added "Gotchas & Lessons Learned" section to `PACTA_Beginner_Guide.md`
- Deleted redundant files (`nul` artifact, `pacta_fix_rerun.R`)
- Reorganized into `scripts/`, `output/`, `docs/`, `reports/` structure

### Session 4: AI vs Staff Comparison Report

- **Goal:** Compare the AI-generated PACTA demo (`scripts/pacta_demo.R`) against the staff's independent R Markdown implementation (`compare/PACTA for Banks staff.Rmd` by Trang Tran)
- **Approach:** Built `compare/compare_report.R` — a single R script that re-runs both matching and analysis pipelines side-by-side, generates 13 comparison charts, and produces a self-contained HTML report
- **Key activities:**
  - Reviewed staff's 542-line `.Rmd` covering methodology, data dictionaries, matching, tech mix, trajectories, and emission intensity
  - Identified 14 dimensions of methodological difference (matching strategy, visualization library, coverage analysis, etc.)
  - Installed and used `r2dii.plot` + `ggrepel` to reproduce staff's official PACTA chart style
  - Ran both pipelines: AI fuzzy matching (326 raw → 177 prioritized) vs Staff exact matching (289 raw → 177 prioritized)
  - Generated side-by-side charts for power, automotive, cement, and steel sectors
  - Computed quantitative alignment gaps from both pipelines
  - Produced 10-section comparison HTML report (321 KB) with embedded charts
- **Output:** `reports/PACTA_Comparison_Report.html` + 13 PNGs in `compare/output/`

### Session 5: Best-of-Both Synthesis Pipeline

- **Goal:** Create a unified `scripts/pacta_synthesis.R` that merges the best elements from the AI demo and Staff implementations into a single production-quality pipeline and self-contained HTML report
- **Approach:** Single R script (~690 lines) with 8 pipeline sections + HTML generation, incorporating all 6 "Best of Both" recommendations from Session 4
- **Key activities:**
  - Read all four source files (`pacta_demo.R`, `generate_report.R`, `PACTA for Banks staff.Rmd`, `compare_report.R`) for synthesis
  - Wrote `scripts/pacta_synthesis.R` implementing:
    1. **Sector pre-join** before matching (Staff pattern) — enables mismatch validation
    2. **Fuzzy matching** with `min_score=0.9` + manual review flag for scores <1.0 + sector mismatch check
    3. **Coverage analysis** with pie chart + bar chart including "Not in Scope" category (Staff pattern)
    4. **Market share analysis** at portfolio and company levels with `r2dii.plot` techmix and trajectory charts (including ICE)
    5. **SDA analysis** for cement and steel with `r2dii.plot` emission intensity charts
    6. **Alignment gap calculation** — direction-aware, with both market share and SDA gaps
    7. **Multi-sector alignment overview chart** (custom ggplot2 faceted bar chart)
    8. **10-section HTML report** with methodology docs, data dictionary, KPI cards, and embedded charts
  - Executed the script successfully — no errors, only expected warnings (2 NA bars in power techmix, ggrepel label hints)
  - Verified output: 345 KB HTML with 11 base64-embedded charts, 10 h2 sections, 11 PNG charts + 8 CSVs in `synthesis_output/`
- **Results confirmed:**
  - 312 raw matches (vs 326 at default threshold, 289 exact) — 23 flagged for manual review
  - 177 prioritized matches (convergence confirmed)
  - Sector mismatch check: PASS
  - All alignment gaps match previous sessions (auto EV -0.5pp, hybrid -13.2pp, ICE +13.8pp, cement +76%, steel +37%)
  - Power sector still shows NA at 2025 for most technologies (demo data limitation)
- **Output:** `reports/PACTA_Synthesis_Report.html` + 19 files in `synthesis_output/` (11 PNGs + 8 CSVs)

### Session 6: Vietnam-Specific PACTA Pipeline (2026-03-20)

- **Goal:** Replace demo data with a Vietnam-realistic synthetic scenario — synthetic loanbook for "Mekong Commercial Bank (MCB)", Vietnam ABCD (EVN, Vinacomin, VinFast, THACO, VICEM, Hoa Phat, etc.), and adapted climate scenarios (PDP8, NDC, IEA NZE)
- **Key activities:**
  - Created `plans/vietnam_bank_pacta_scenario_plan.md` — comprehensive blueprint covering Vietnam energy context (PDP8, NDC, JETP), bank loanbook design, ABCD design, scenario adaptation, and 11-section implementation roadmap
  - Created `data/generate_vietnam_data.R` + 5 CSV files:
    - `vietnam_loanbook.csv` — synthetic MCB loanbook in VND with ISIC codes and Vietnamese company names (EVN subsidiaries, THACO, VinFast, VICEM, Hoa Phat, Vinacomin, etc.)
    - `vietnam_abcd.csv` — ABCD with Vietnamese company production data for power/auto/cement/steel/coal sectors
    - `vietnam_scenario_ms.csv` — market share pathways for PDP8, Vietnam NDC, and IEA NZE 2050
    - `vietnam_scenario_co2.csv` — CO2 intensity scenarios for cement and steel
    - `vietnam_region_isos.csv` — Vietnam region ISO mapping
  - Wrote `scripts/pacta_vietnam_scenario.R` (1352 lines): full pipeline with VSIC→ISIC→PACTA custom mapping, ASCII normalization for Vietnamese diacritics, `min_score=0.8` fuzzy matching, PDP8/NDC scenario alignment, bilingual Vietnamese/English HTML report targeting Vietnamese bank audience
  - Wrote `scripts/debug_ms.R` — diagnostic script to investigate market share `region`/`metric` output structure
- **Execution status: PARTIAL**
  - Pipeline ran through Section 9 (EV trajectory charts) — 10 files produced in `synthesis_output/vietnam/`
  - Pipeline stopped before completing: SDA analysis (cement/steel), alignment gap calculation, alignment overview chart, and HTML report (`reports/PACTA_Vietnam_Bank_Report.html`) were NOT produced
  - Root cause: likely a market share region/metric mismatch (debug_ms.R was written mid-session to diagnose)
- **Outstanding issue:** Need to run `debug_ms.R` output and fix the pipeline so it completes through HTML report generation

---

## Key Findings (Demo Portfolio)

| Sector | Method | Aligned? | Gap | Notes |
|---|---|---|---|---|
| Automotive — Electric | Market Share | NO | -0.5pp share | Minor gap, nearly aligned |
| Automotive — Hybrid | Market Share | NO | -13.2pp share | Major underproduction |
| Automotive — ICE | Market Share | NO | +13.8pp share | Overproduction vs target |
| Power | Market Share | Incomplete | N/A | Most tech has NA at 2025 |
| Cement | SDA | NO | +76% above target | Worst misalignment |
| Steel | SDA | NO | +37% above target | Only 4% match coverage |

**Verdict:** Demo portfolio is not Paris-aligned in any sector.

---

## Comparison Findings: AI vs Staff (Session 4)

### Quantitative Convergence

Both implementations reach the **same alignment verdict** despite different matching strategies. Key numbers:

| Metric | AI Approach | Staff Approach | Delta |
|---|---|---|---|
| Raw matches | 326 | 289 | +37 (fuzzy extras) |
| Prioritized matches | 177 | 177 | 0 |
| MS target rows | 1,210 | 1,210 | 0 |
| SDA target rows | 220 | 220 | 0 |
| Sectors misaligned | 4/4 | 4/4 | Same |

The fuzzy approach captures 37 additional raw matches (score < 1.0), but after prioritization both converge to 177. This confirms the demo dataset was designed for clean exact matching.

### Methodological Differences (14 dimensions)

| Dimension | AI | Staff | Better For |
|---|---|---|---|
| Report format | .R script + HTML generator | .Rmd (literate programming) | Staff: reproducibility |
| Matching | Default fuzzy (~0.8+) | Exact only (min_score=1) | AI: real-world data; Staff: demo |
| Sector pre-join | During coverage | Before matching | Staff: enables mismatch check |
| Mismatch validation | Not present | Validates sector_matched vs sector | Staff |
| Visualization | Custom ggplot2 | r2dii.plot + ggrepel labels | Staff: standardized & labeled |
| Coverage analysis | Bar chart only | Pie + bar with "Not in Scope" | Staff: more complete |
| Data labels | None on charts | ggrepel percentage/value labels | Staff |
| ICE trajectory | Not charted | Included | Staff |
| Company-level analysis | Yes (37K rows) | Not included | AI: borrower engagement |
| Alignment gap calc | Explicit + overview chart | Visual only | AI: quantitative rigor |
| CPS scenario | Included | Not included | AI: additional benchmark |
| Methodology docs | In report (post-hoc) | Inline with code | Staff: learning tool |
| PACTA references | None | 5 official links | Staff |
| Vietnam context | Not addressed | VSIC/NAICS notes, ABCD challenges | Staff |

### Recommended "Best of Both" Architecture

For the production version targeting Vietnamese bank data:

1. **Matching:** Fuzzy (min_score=0.9) with mandatory manual review of <1.0 matches (AI flexibility + Staff rigor)
2. **Visualization:** `r2dii.plot` for standardized charts + custom ggplot2 for alignment overview (Staff charts + AI summary)
3. **Report format:** R Markdown for the analytical notebook + standalone HTML for stakeholder distribution (both)
4. **Content:** Staff's methodology docs & data dictionary + AI's alignment gap calculations & KPI cards
5. **Coverage:** Staff's pie + bar with "Not in Scope" category
6. **Sector classification:** Pre-join before matching (Staff pattern) to enable mismatch validation

---

## Technical Gotchas Discovered

These are important for anyone running PACTA with the R packages:

### 1. User Library Required on Windows
R system library at `C:\Program Files\R\R-4.5.2\library` is not writable without admin. Must use:
```r
install.packages("pkg", lib = Sys.getenv("R_LIBS_USER"))
library(pkg, lib.loc = Sys.getenv("R_LIBS_USER"))
```

### 2. Demo Scenario Metric Naming Asymmetry (Critical)
The `pacta.loanbook` demo datasets use scenario source `demo_2020`. This produces **different** metric naming conventions for the two analysis methods:

- **Market Share** metrics: `projected`, `target_sds`, `target_cps`, `target_sps`, `corporate_economy`
  - Pattern: `target_<scenario_name>` (standard)
- **SDA** metrics: `projected`, `target_demo`, `adjusted_scenario_demo`, `corporate_economy`
  - Pattern: `target_<scenario_source_suffix>` (non-standard)

This asymmetry means scripts that hardcode `target_sds` for SDA will crash when using demo data. The fix: always inspect `unique(sda_targets$emission_factor_metric)` before filtering.

### 3. Power Sector NA Values at 2025
Several power technologies (gascap, hydrocap, nuclearcap, renewablescap) have `NA` production values at 2025 in the `projected` metric. This causes `pivot_wider` to produce NA columns and alignment calculations to fail silently. Real ABCD data typically has 5–10 year projections.

### 4. Steel Match Coverage ~4%
Most demo steel borrowers could not be linked to physical asset data. This makes steel alignment results unreliable. In production: manually review unmatched borrowers and add intermediate parent names.

### 5. ggplot2 Silent Scale Warnings
When filtering data to a subset of metrics but providing `scale_*_manual()` mappings for non-present levels, ggplot2 silently ignores unused mappings. This is safe but can hide the fact that expected data is missing from the plot.

---

## Environment Details

| Component | Detail |
|---|---|
| R version | 4.5.2 |
| Rscript path | `C:\Program Files\R\R-4.5.2\bin\Rscript.exe` |
| User library | `C:\Users\tukum\AppData\Local/R/win-library/4.5` |
| Key packages | pacta.loanbook, r2dii.plot, ggrepel, dplyr, readr, ggplot2, tidyr, scales, base64enc |
| Platform | Windows (win32) |

---

## Possible Next Steps

- [x] ~~Explore `r2dii.plot` package for standardized PACTA visualizations~~ (done in Session 4)
- [x] ~~Merge implementations: Create a unified pipeline combining best elements from AI + Staff~~ (done in Session 5: `scripts/pacta_synthesis.R`)
- [x] ~~Add ICE trajectory chart~~ (included in synthesis pipeline)
- [x] ~~Implement sector mismatch validation~~ (included in synthesis pipeline)
- [x] ~~Replace demo data with a real or simulated Vietnam bank loanbook~~ (done in Session 6: synthetic MCB dataset)
- [x] ~~Source IEA WEO or NGFS scenarios for production-grade pathways~~ (done in Session 6: PDP8/NDC/NZE scenarios)
- [x] ~~Prepare VSIC-to-PACTA sector mapping~~ (done in Session 6: VSIC→ISIC→PACTA mapping in `pacta_vietnam_scenario.R`)
- [ ] **⚠️ URGENT: Fix Vietnam pipeline completion** — run `debug_ms.R`, diagnose market share region/metric issue, and complete pipeline through HTML report (`reports/PACTA_Vietnam_Bank_Report.html`)
- [ ] Build R Markdown version: Convert `pacta_synthesis.R` into an `.Rmd` literate programming notebook for internal use
- [ ] Investigate ABCD data sources for Vietnamese companies (Asset Impact or self-prepared)
- [ ] Build a Shiny dashboard for interactive exploration
- [ ] Extend analysis to oil & gas and aviation sectors
- [ ] Set up quarterly re-run monitoring framework
