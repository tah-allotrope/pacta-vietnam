#!/usr/bin/env Rscript
# ==============================================================================
# generate_financed_emissions.R
# Wave 3 PHASE-05: the PCAF financed-emissions pipeline step. Reads the
# normalized loanbook (via output/engagement/engagement_priority.csv, which
# already carries matched exposure_vnd per borrower), ABCD, the borrower-
# capital sidecar, and the emission/capacity factor tables; writes
# financed_emissions.csv, data_quality_summary.csv and carbon_cost_exposure.csv
# plus an HTML report. Purely additive -- reads existing committed outputs,
# writes to its own directory, never mutates any frozen artifact.
#
# Usage: Rscript scripts/generate_financed_emissions.R --config <path>
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

source("R/engagement_config.R")
source("R/financed_emissions.R")
source("R/report_toolkit.R")
source("R/report_facts.R")
source("R/sector_registry.R")

cfg <- load_engagement_config(get_config_arg())

out_dir <- cfg$paths$financed_emissions_output_dir
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

abcd <- utils::read.csv(cfg$inputs$abcd_csv, stringsAsFactors = FALSE)
capital <- utils::read.csv("data/vietnam_borrower_capital.csv", stringsAsFactors = FALSE)
emission_factors <- utils::read.csv("data/vietnam_emission_factors.csv", stringsAsFactors = FALSE)
capacity_factors <- utils::read.csv("data/vietnam_capacity_factors.csv", stringsAsFactors = FALSE)

priority_path <- file.path(cfg$paths$engagement_output_dir, "engagement_priority.csv")
if (!file.exists(priority_path)) {
  stop(sprintf(
    "generate_financed_emissions.R: %s not found -- run engagement_scoring first (it must precede this step in the config's step order).",
    priority_path
  ), call. = FALSE)
}
priority <- utils::read.csv(priority_path, stringsAsFactors = FALSE)
loanbook_exposure <- data.frame(
  name_company = priority$name_abcd, outstanding_vnd = priority$exposure_vnd,
  stringsAsFactors = FALSE
)

# Wave 4 PHASE-03: stamp the engagement's OWN slug. This was hardcoded to
# "mcb-demo" inside R/financed_emissions.R, so sdb-rehearsal's committed
# inventory carried another bank's identifier on every row.
fe <- financed_emissions(abcd, capital, loanbook_exposure, emission_factors, capacity_factors,
                         data_source = cfg$bank_slug)
dq <- data_quality_summary(fe)

# Sum carbon-cost exposure across every TRISK sector's NGFS carbon-price
# pathway, using the "increasing_carbon_tax_50" central scenario (the same
# central case the TRISK sensitivity grid's base parameters use --
# see R/trisk_core.R's trisk_base_params()) and renaming its price column
# to the generic name carbon_cost_exposure() expects.
cc_rows <- list()
for (sector in sector_registry()$sector) {
  cp_path <- sprintf("data/vietnam_trisk_ngfs_carbon_price_%s.csv", sector)
  if (!file.exists(cp_path)) next
  cp <- utils::read.csv(cp_path, stringsAsFactors = FALSE)
  cp <- cp[cp$scenario == "increasing_carbon_tax_50", c("year", "carbon_tax")]
  names(cp) <- c("year", "carbon_price_usd_per_tco2")
  fe_sector <- fe[fe$sector == sector, , drop = FALSE]
  if (nrow(fe_sector) == 0 || nrow(cp) == 0) next
  cc_rows[[sector]] <- carbon_cost_exposure(fe_sector, cp, cfg$inputs$fx_rate_usd_vnd)
}
carbon_cost <- if (length(cc_rows) > 0) do.call(rbind, cc_rows) else data.frame()

utils::write.csv(fe, file.path(out_dir, "financed_emissions.csv"), row.names = FALSE, na = "")
utils::write.csv(dq, file.path(out_dir, "data_quality_summary.csv"), row.names = FALSE)
utils::write.csv(carbon_cost, file.path(out_dir, "carbon_cost_exposure.csv"), row.names = FALSE, na = "")

fx_configured <- length(cfg$inputs$fx_rate_usd_vnd) > 0

dq_table_html <- paste0(
  "<table><tr><th>PCAF quality score</th><th>Borrowers</th><th>tCO2e</th><th>Share</th></tr>",
  paste(vapply(seq_len(nrow(dq)), function(i) sprintf(
    "<tr><td>%d</td><td>%d</td><td>%.1f</td><td>%.1f%%</td></tr>",
    dq$data_quality_score[i], dq$n_borrowers[i], dq$financed_emissions_tco2e[i], dq$share_of_total[i] * 100
  ), character(1)), collapse = ""),
  "</table>"
)

total_fe <- sum(fe$financed_emissions_tco2e, na.rm = TRUE)
excluded <- fe[!is.na(fe$exclusion_reason), , drop = FALSE]

html <- paste0(
  "<!DOCTYPE html><html><head><meta charset='utf-8'><title>", report_label("financed_emissions_title", cfg$report_language %||% "en", tryCatch(load_report_labels(override_csv = if (length(cfg$paths$i18n_override_csv) > 0) cfg$paths$i18n_override_csv else NULL), error=function(e) NULL)), "</title>",
  report_css(),
  "</head><body><div class='container'>",
  sprintf("<h1>%s: %s</h1>", report_label("financed_emissions_title", cfg$report_language %||% "en", tryCatch(load_report_labels(override_csv = if (length(cfg$paths$i18n_override_csv) > 0) cfg$paths$i18n_override_csv else NULL), error=function(e) NULL)), cfg$bank_name),
  "<p style='color:#c53030;'><strong>", report_label("synthetic_disclaimer", cfg$report_language %||% "en", tryCatch(load_report_labels(override_csv = if (length(cfg$paths$i18n_override_csv) > 0) cfg$paths$i18n_override_csv else NULL), error=function(e) NULL)), "</strong></p>",
  sprintf("<h2>Total Scope 1+2 financed emissions: %.1f tCO2e across %d scored borrowers (%d-borrower inventory)</h2>", total_fe, sum(!is.na(fe$financed_emissions_tco2e)), nrow(fe)),
  "<p>No total is published without its data-quality composition:</p>",
  dq_table_html,
  "<h2>Scope 3 exclusion</h2>",
  sprintf(
    "<p>%d borrower(s) in sectors where Scope 3 emissions dominate the financed-emissions profile ",
    nrow(excluded)
  ),
  "(automotive, coal mining) are excluded from this Scope 1+2 inventory. Excluding them understates ",
  "exactly the sectors where financed emissions are largest in practice; a future Scope 3 extension ",
  "is scoped by design (the `scope` column already carries the literal \"1+2\" so Scope 3 rows are a ",
  "population, not a migration).</p>",
  if (!fx_configured) "<p><em>Carbon-cost exposure not computed: inputs.fx_rate_usd_vnd is not configured for this engagement.</em></p>" else "",
  "</div></body></html>"
)

# --- i18n bilingual note (PHASE-07) ---
if (identical(cfg$report_language %||% "en", "bilingual")) {
  html <- sub("<div class='container'>",
              paste0("<div class='container'><div class=\"callout callout-info\">Section headings, table column labels and the synthetic-data disclaimer are shown as English / Vietnamese; analyst-written narrative remains English.</div>"),
              html, fixed = TRUE)
}
write_html_report(html, file.path(cfg$paths$reports_dir, "Financed_Emissions.html"))

# Wave 5 PHASE-03: facts sidecar (see scripts/pacta_vietnam_scenario.R).
fe_csv_rel <- file.path(cfg$paths$financed_emissions_output_dir, "financed_emissions.csv")
fe_facts <- list(
  report_fact("total_financed_emissions_tco2e", total_fe, fe_csv_rel,
              "sum", column = "financed_emissions_tco2e", unit = "tCO2e",
              rendered = sprintf("%.1f tCO2e", total_fe)),
  report_fact("n_borrowers", nrow(fe), fe_csv_rel,
              "nrow", unit = "borrowers", rendered = sprintf("%d-borrower inventory", nrow(fe)))
)
write_report_facts(fe_facts,
                   file.path(cfg$paths$reports_dir, "Financed_Emissions.html"),
                   "scripts/generate_financed_emissions.R")
cat(sprintf("[OK] Financed emissions written: %s (total %.1f tCO2e across %d scored borrowers)\n",
            out_dir, total_fe, sum(!is.na(fe$financed_emissions_tco2e))))
if (!fx_configured) {
  cat("[WARN] inputs.fx_rate_usd_vnd is not configured; carbon_cost_vnd is NA throughout carbon_cost_exposure.csv\n")
}
