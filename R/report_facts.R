# ==============================================================================
# R/report_facts.R
# Wave 5 PHASE-03: machine-readable facts sidecars for gated HTML deliverables.
#
# Each gated report declares its headline figures in a `.facts.json` sidecar
# beside the HTML file. INV-013 (tools/verify_refactor.R) recomputes each
# value from its source CSV and asserts the rendered string appears in the
# HTML -- so a wrong number fails a gate instead of being frozen by one.
#
# Sidecars contain only report path, generator path and the fact list: no
# timestamp, git SHA or other per-run-volatile value (ASM-005).
# ==============================================================================

#' Build one report fact.
#'
#' @param name character(1) — snake_case identifier, unique within the sidecar.
#' @param value numeric(1) — the value as computed by the generator.
#' @param source_csv character(1) — repo-relative path of the source CSV.
#' @param agg character(1) — one of "sum", "nrow", "n_distinct".
#' @param column character(1) — column name; ignored when agg is "nrow".
#' @param unit character(1) — free text ("VND", "tCO2e", "loans"); optional.
#' @param rendered character(1) — exact formatted substring in the HTML.
#' @return list — one fact matching the sidecar schema (S1).
#' @export
report_fact <- function(name, value, source_csv, agg,
                        column = NA_character_, unit = NA_character_,
                        rendered) {
  if (!identical(agg, "sum") && !identical(agg, "nrow") && !identical(agg, "n_distinct")) {
    stop(sprintf("report_fact: unknown agg '%s' (expected 'sum', 'nrow' or 'n_distinct')", agg),
         call. = FALSE)
  }
  fact <- list(
    name = name,
    value = value,
    source = list(csv = source_csv, column = column, agg = agg),
    rendered = rendered
  )
  if (!is.na(unit)) fact$unit <- unit
  # Keep canonical key order: name, value, unit, rendered, source.
  fact[c("name", "value", "unit", "rendered", "source")]
}

#' Write a facts sidecar beside a report.
#'
#' @param facts list — list of report_fact() outputs.
#' @param html_path character(1) — path of the HTML report.
#' @param generated_by character(1) — repo-relative generator script path.
#' @return character(1) — the sidecar path written.
#' @export
write_report_facts <- function(facts, html_path, generated_by) {
  facts_path <- sub("\\.html$", ".facts.json", html_path)
  payload <- list(
    report = html_path,
    generated_by = generated_by,
    facts = facts
  )
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  writeLines(json, facts_path, useBytes = TRUE)
  facts_path
}

#' Read a facts sidecar.
#'
#' @param facts_path character(1) — path of the `.facts.json` file.
#' @return list — parsed sidecar with report, generated_by and facts.
#' @export
read_report_facts <- function(facts_path) {
  if (!file.exists(facts_path)) {
    stop(sprintf("read_report_facts: file not found: %s", facts_path), call. = FALSE)
  }
  parsed <- jsonlite::fromJSON(facts_path, simplifyVector = FALSE)
  if (is.null(parsed$facts)) {
    stop(sprintf("read_report_facts: '%s' lacks a facts array", facts_path), call. = FALSE)
  }
  parsed
}
