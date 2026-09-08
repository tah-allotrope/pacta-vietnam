library(testthat)
suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(r2dii.data)
  library(ggplot2)
  library(scales)
})

root <- project_root()
source(file.path(root, "R", "matching_helpers.R"))
source(file.path(root, "R", "report_toolkit.R"))
source(file.path(root, "R", "format_money.R"))
source(file.path(root, "R", "pacta_core.R"))

# --- pacta_prejoin_sectors ---------------------------------------------------

test_that("pacta_prejoin_sectors maps ISIC codes to PACTA sectors", {
  loanbook <- tibble(
    id_loan = c("L1", "L2"),
    id_direct_loantaker = c("D1", "D2"),
    name_direct_loantaker = c("Power Co", "Auto Co"),
    id_ultimate_parent = c("D1", "D2"),
    name_ultimate_parent = c("Power Co", "Auto Co"),
    loan_size_outstanding = c(1000, 2000),
    loan_size_outstanding_currency = c("VND", "VND"),
    loan_size_credit_limit = c(1000, 2000),
    loan_size_credit_limit_currency = c("VND", "VND"),
    sector_classification_system = c("ISIC", "ISIC"),
    sector_classification_direct_loantaker = c("3511", "2910"),
    lei_direct_loantaker = c(NA_character_, NA_character_),
    isin_direct_loantaker = c(NA_character_, NA_character_)
  )

  result <- pacta_prejoin_sectors(loanbook)

  expect_equal(
    result$sector_classified[result$sector_classification_direct_loantaker == "3511"],
    "power"
  )
  expect_equal(
    result$sector_classified[result$sector_classification_direct_loantaker == "2910"],
    "automotive"
  )
})

# --- pacta_coverage -----------------------------------------------------------

test_that("pacta_coverage computes matched exposure fraction from raw VND weights", {
  loanbook_classified <- tibble(
    sector_classified = rep("power", 3),
    loan_size_outstanding = c(100, 200, 300)
  )
  matched <- tibble(
    sector = rep("power", 2),
    loan_size_outstanding = c(100, 200)
  )

  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  coverage <- pacta_coverage(loanbook_classified, matched, tmp_dir, "Test Bank", "TB")

  power_row <- coverage[coverage$sector_classified == "power", ]
  expect_equal(power_row$match_pct, 50, tolerance = 1e-9)
  expect_true(file.exists(file.path(tmp_dir, "03_vn_coverage_pie.png")))
})

# --- pacta_market_share: pdp8_scenario_source parameterization (Wave 3 PHASE-03) ---

test_that("pacta_market_share accepts pdp8_scenario_source with a pdp8_2023 default", {
  # Regression guard for the bug found building the pdp8-2025-adjusted
  # vintage: five chart filters inside pacta_market_share() used to
  # hardcode scenario_source == "pdp8_2023" literally, so a second vintage's
  # rows were silently dropped from every chart even though the underlying
  # target_market_share() computation itself was already vintage-agnostic.
  # A full data fixture is expensive to build here; this pins the interface
  # contract instead -- see scripts/pacta_vietnam_scenario.R for the
  # end-to-end exercise (both vintages run cleanly via
  # scripts/compare_scenario_vintages.R).
  args <- formals(pacta_market_share)
  expect_true("pdp8_scenario_source" %in% names(args))
  expect_equal(eval(args$pdp8_scenario_source), "pdp8_2023")
})

test_that("no hardcoded scenario_source literal remains in pacta_market_share's body", {
  body_text <- deparse(body(pacta_market_share))
  expect_false(any(grepl('scenario_source == "pdp8_2023"', body_text, fixed = TRUE)))
})

# --- pacta_load_inputs: non-path cfg$inputs values must not be treated as files ---

test_that("pacta_load_inputs does not treat scenario_vintage or fx_rate_usd_vnd as file paths", {
  root <- project_root()
  cfg <- list(inputs = list(
    loanbook_csv = file.path(root, "data", "vietnam_loanbook.csv"),
    abcd_csv = file.path(root, "data", "vietnam_abcd.csv"),
    scenario_ms_csv = file.path(root, "data", "scenarios", "pdp8-2023", "vietnam_scenario_ms.csv"),
    scenario_co2_csv = file.path(root, "data", "scenarios", "pdp8-2023", "vietnam_scenario_co2.csv"),
    region_isos_csv = file.path(root, "data", "vietnam_region_isos.csv"),
    scenario_vintage = "pdp8-2023",
    fx_rate_usd_vnd = 26300
  ))

  result <- NULL
  invisible(capture.output(result <- pacta_load_inputs(cfg)))
  expect_true(is.list(result))
  expect_true(all(c("loanbook", "abcd", "scenario", "co2", "region") %in% names(result)))
})
