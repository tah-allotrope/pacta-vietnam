#!/usr/bin/env Rscript
# =============================================================================
# Engagement Scoring Backbone
# Engagement & Disclosure Output Layer — PHASE-01
# Plan: plans/2026-05-28-engagement-disclosure-output-layer-plan.md
# =============================================================================
# Produces ONE canonical, data-driven borrower priority table that both
# downstream generators (engagement letters, disclosure pack) consume, so
# borrower numbers are computed once and never hardcoded.
#
# Composite score (DEC-002, Q-004 = fixed 50/50), rewritten in Wave 2
# PHASE-03 to use absolute severity anchors instead of min-max normalization
# (docs/scoring_anchors.md is the source of truth for the anchor tables):
#   composite = (w_align * severity_alignment + w_trisk * severity_trisk)
#               / (sum of weights actually available for the row)
# Borrowers with PACTA alignment but no TRISK coverage (automotive) renormalise
# to the alignment component only (==> composite = severity_alignment) and are
# flagged composite_partial = TRUE rather than dropped (TASK-01-04).
#
# Confirmed input schema (TASK-01-01, verified 2026-05-31):
#   dashboard/data/trisk/<sector>/top_borrowers_alignment_trisk.csv
#     company_id, company_name, sector, assets, npv_baseline, npv_shock,
#     npv_difference, npv_change, pd_baseline, pd_shock, pd_change,
#     mean_abs_alignment_gap_pp, worst_alignment_gap_pp, alignment_context,
#     stress_priority_score   (power=13 borrowers, cement=2, steel=2)
#   synthesis_output/vietnam/04_vn_ms_company.csv  (long format)
#     sector, technology, year, region, scenario_source, name_abcd, metric,
#     production, technology_share, scope, percentage_of_initial_production_by_scope
#     sectors: automotive, power; metrics: projected, target_pdp8_ndc,
#     target_nze_global, target_steps, corporate_economy; years 2025-2030
#   synthesis_output/vietnam/02_vn_matched_prioritized.csv
#     name_abcd (col 21), loan_size_outstanding (col 6)  -> exposure_vnd
#
# Cross-sector caveat: power/automotive alignment gaps are market-share
# percentage-points; cement/steel gaps are SDA emission-intensity gap_pct.
# These are NOT comparable magnitudes on a shared scale, which is exactly
# why severity_alignment() (R/severity_scoring.R) uses two separate anchor
# tables (Table A1 for market-share sectors, Table A2 for SDA sectors) keyed
# by alignment_basis_for_sector(), rather than one shared scale.
#
# Provenance: the output's data_source column is cfg$bank_slug — every
# engagement's engagement_priority.csv is stamped with its own bank_slug,
# never a hardcoded literal (Wave 1 PHASE-02, C2).
#
# Usage:
#   Rscript scripts/engagement_scoring.R [--w_align 0.5] [--w_trisk 0.5]
# =============================================================================

suppressWarnings(suppressMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
}))

source("R/engagement_config.R")
source("R/severity_scoring.R")

# --- Section 1: Configuration ------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

parse_arg <- function(args, name, default) {
  idx <- which(args == paste0("--", name))
  if (length(idx) > 0 && idx < length(args)) {
    return(as.numeric(args[idx + 1]))
  }
  default
}

cfg <- load_engagement_config(get_config_arg(args))

w_align <- parse_arg(args, "w_align", 0.5)
w_trisk <- parse_arg(args, "w_trisk", 0.5)

target_year     <- 2030
# Wave 3 PHASE-03/07: derive the PDP8 scenario_source from the engagement's
# own vintage so the new pdp8_2025_adjusted vintage is not silently ignored
# (it would otherwise filter to zero rows and break the automotive gap).
auto_scenario   <- gsub("-", "_", cfg$inputs$scenario_vintage)
auto_target_met <- "target_pdp8_ndc" # PDP8 target metric in the company file

base_dir   <- getwd()
trisk_dir  <- file.path(base_dir, cfg$paths$snapshot_dir, "trisk")
pacta_file <- file.path(base_dir, cfg$paths$pacta_output_dir, "04_vn_ms_company.csv")
matched_file <- file.path(base_dir, cfg$paths$pacta_output_dir, "02_vn_matched_prioritized.csv")
output_dir <- file.path(base_dir, cfg$paths$engagement_output_dir)

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

trisk_sectors <- cfg$trisk_sectors
data_source   <- cfg$bank_slug

cat(sprintf("Engagement Scoring — weights: alignment=%.2f, trisk=%.2f (target year %d)\n",
            w_align, w_trisk, target_year))

# --- Section 2: TRISK borrower results (power, cement, steel) ----------------

cat("\n[1/5] Loading TRISK borrower results...\n")

trisk_rows <- list()
for (s in trisk_sectors) {
  f <- file.path(trisk_dir, s, "top_borrowers_alignment_trisk.csv")
  if (!file.exists(f)) {
    cat(sprintf("  %s: NOT FOUND (%s) — skipped\n", s, f))
    next
  }
  df <- readr::read_csv(f, show_col_types = FALSE)
  trisk_rows[[s]] <- tibble::tibble(
    name_abcd             = df$company_name,
    sector                = s,
    alignment_gap         = df$mean_abs_alignment_gap_pp,
    npv_change            = df$npv_change,
    pd_change             = df$pd_change,
    trisk_stress_rank_pct  = df$stress_priority_score,
    trisk_status          = sprintf("Covered \u2014 TRISK %s pilot", s),
    alignment_basis       = df$alignment_context
  )
  cat(sprintf("  %s: %d borrowers\n", s, nrow(df)))
}
trisk_borrowers <- dplyr::bind_rows(trisk_rows)

# --- Section 3: Automotive borrowers (PACTA-only, no TRISK) -------------------

cat("\n[2/5] Computing automotive borrower alignment gaps (PACTA market share)...\n")

pacta <- readr::read_csv(pacta_file, show_col_types = FALSE)

auto_gap <- pacta |>
  dplyr::filter(
    sector == "automotive",
    grepl("^pdp8", scenario_source),
    year == target_year,
    metric %in% c("projected", auto_target_met),
    !name_abcd %in% c("corporate_economy")
  ) |>
  dplyr::select(name_abcd, technology, metric, technology_share) |>
  tidyr::pivot_wider(names_from = metric, values_from = technology_share) |>
  dplyr::filter(!is.na(projected), !is.na(.data[[auto_target_met]])) |>
  dplyr::mutate(gap_pp = (projected - .data[[auto_target_met]]) * 100) |>
  dplyr::group_by(name_abcd) |>
  dplyr::summarise(alignment_gap = mean(abs(gap_pp)), .groups = "drop")

auto_borrowers <- auto_gap |>
  dplyr::transmute(
    name_abcd            = name_abcd,
    sector               = "automotive",
    alignment_gap        = alignment_gap,
    npv_change           = NA_real_,
    pd_change            = NA_real_,
    trisk_stress_rank_pct = NA_real_,
    trisk_status         = "N/A - sector not in TRISK pilot",
    alignment_basis      = sprintf("PACTA market-share gap (PDP8, %d)", target_year)
  )

cat(sprintf("  automotive: %d borrowers (PACTA alignment only, TRISK N/A)\n",
            nrow(auto_borrowers)))

# --- Section 4: Exposure (VND) from the matched, prioritised loanbook --------

cat("\n[3/5] Loading borrower exposure (VND)...\n")

matched <- readr::read_csv(matched_file, show_col_types = FALSE)
exposure <- matched |>
  dplyr::group_by(name_abcd) |>
  dplyr::summarise(exposure_vnd = sum(loan_size_outstanding, na.rm = TRUE),
                   .groups = "drop")
cat(sprintf("  %d distinct borrowers carry loanbook exposure\n", nrow(exposure)))

# --- Section 5: Join, normalise, composite -----------------------------------

cat("\n[4/5] Building composite priority table...\n")

borrowers <- dplyr::bind_rows(trisk_borrowers, auto_borrowers) |>
  dplyr::left_join(exposure, by = "name_abcd")

# RISK-01-01: surface (never silently drop) any scored borrower missing exposure
unmatched <- borrowers |> dplyr::filter(is.na(exposure_vnd))
if (nrow(unmatched) > 0) {
  warning(sprintf("%d scored borrower(s) have no loanbook exposure match — see unmatched_names.csv",
                  nrow(unmatched)))
  readr::write_csv(
    dplyr::select(unmatched, name_abcd, sector, alignment_basis),
    file.path(output_dir, "unmatched_names.csv")
  )
}

if (nrow(borrowers) == 0) {
  cat("\n[NOTE] No borrowers to score — writing empty engagement_priority.csv.\n")
  priority <- tibble::tibble(
    name_abcd = character(),
    sector = character(),
    exposure_vnd = numeric(),
    alignment_gap = numeric(),
    npv_change = numeric(),
    pd_change = numeric(),
    trisk_stress_rank_pct = numeric(),
    trisk_status = character(),
    composite_score = numeric(),
    composite_partial = logical(),
    severity_alignment = numeric(),
    severity_trisk = numeric(),
    composite_rank_pct = numeric(),
    alignment_basis = character(),
    data_source = character()
  )
  out_file <- file.path(output_dir, "engagement_priority.csv")
  readr::write_csv(priority, out_file)
  cat(sprintf("  Written: %s (0 borrowers)\n", out_file))
  cat("\n=== Engagement Priority — Top 10 ===\n  (empty)\n")
  cat(sprintf("\nOutputs in: %s\n", output_dir))
  quit(status = 0)
}

borrowers <- borrowers |>
  dplyr::rowwise() |>
  dplyr::mutate(
    # Named .sev_* to avoid a same-name column shadowing the
    # severity_alignment()/severity_trisk() functions being called in the
    # same mutate() chain; renamed to their public names below.
    .sev_align = severity_alignment(alignment_gap, alignment_basis_for_sector(sector)),
    .sev_trisk = severity_trisk(npv_change),
    composite_partial = is.na(.sev_trisk)
  ) |>
  dplyr::mutate(
    composite_score = {
      a_term <- w_align * .sev_align
      if (is.na(.sev_trisk)) {
        # renormalise to the available weight -> alignment component only
        a_term / w_align
      } else {
        (a_term + w_trisk * .sev_trisk) / (w_align + w_trisk)
      }
    }
  ) |>
  # Wave 3 PHASE-07 S1: round to 10 decimals before ranking and before writing,
  # so the published number and the published rank agree and a 1-ULP floating
  # residue no longer splits otherwise-identical borrowers.
  dplyr::mutate(composite_score = round(composite_score, 10)) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    # Percentile rank within this engagement: an explicit, separately-named
    # relative view that survives now that composite_score itself is
    # absolute (Wave 2 PHASE-03). rank()/n so the top borrower reads 1.0.
    # Ties now genuinely tie on the rounded score (S1).
    composite_rank_pct = rank(composite_score, ties.method = "average") / dplyr::n(),
    severity_alignment = .sev_align,
    severity_trisk = .sev_trisk
  ) |>
  dplyr::arrange(dplyr::desc(composite_score))

priority <- borrowers |>
  dplyr::select(
    name_abcd, sector, exposure_vnd, alignment_gap, npv_change, pd_change,
    trisk_stress_rank_pct, trisk_status, composite_score, composite_partial,
    severity_alignment, severity_trisk, composite_rank_pct, alignment_basis
  ) |>
  dplyr::mutate(data_source = data_source)

# --- Section 6: Write outputs ------------------------------------------------

cat("\n[5/5] Writing outputs...\n")
out_file <- file.path(output_dir, "engagement_priority.csv")
readr::write_csv(priority, out_file)
cat(sprintf("  Written: %s (%d borrowers)\n", out_file, nrow(priority)))

# --- Console summary ---------------------------------------------------------

cat("\n=== Engagement Priority — Top 10 ===\n")
top10 <- head(priority, 10)
for (i in seq_len(nrow(top10))) {
  r <- top10[i, ]
  cat(sprintf("  %2d. %-32s [%-10s] composite=%.3f  gap=%.2f  trisk=%s%s\n",
              i, r$name_abcd, r$sector, r$composite_score, r$alignment_gap,
              if (is.na(r$trisk_stress_rank_pct)) "N/A" else sprintf("%.1f", r$trisk_stress_rank_pct),
              if (isTRUE(r$composite_partial)) "  (partial)" else ""))
}

cat("\nBorrowers by sector:\n")
by_sec <- priority |> dplyr::count(sector, name = "n")
for (i in seq_len(nrow(by_sec))) {
  cat(sprintf("  %-12s %d\n", by_sec$sector[i], by_sec$n[i]))
}

n_partial <- sum(priority$composite_partial)
cat(sprintf("\nCoverage caveat: %d/%d borrowers are TRISK-covered; %d automotive borrower(s) are\n",
            sum(!priority$composite_partial), nrow(priority), n_partial))
cat("scored on PACTA alignment only (composite_partial = TRUE) and renormalised to the\n")
cat("alignment component. composite_score is an absolute severity in [0, 1] from the\n")
cat("documented anchor tables in docs/scoring_anchors.md (Wave 2 PHASE-03) -- not a\n")
cat("rank within this run. composite_rank_pct carries the relative (percentile) view\n")
cat("separately. Power/automotive alignment gaps are market-share pp; cement/steel gaps\n")
cat("are SDA gap_pct -- not the same scale, which is why severity_alignment() uses two\n")
cat("separate anchor tables keyed by sector.\n")
cat(sprintf("\nOutputs in: %s\n", output_dir))
