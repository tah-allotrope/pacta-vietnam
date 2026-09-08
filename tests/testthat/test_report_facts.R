library(testthat)

root <- project_root()
source(file.path(root, "R", "report_facts.R"))
source(file.path(root, "tools", "verify_refactor.R"))

test_that("report_fact builds a well-formed fact", {
  fact <- report_fact("portfolio_total_vnd", 25020000000000,
                      "data/vietnam_loanbook.csv", "sum",
                      column = "loan_size_outstanding", unit = "VND",
                      rendered = "25,020.0 bn VND")
  expect_equal(fact$value, 25020000000000)
  expect_equal(fact$source$agg, "sum")
  expect_equal(fact$unit, "VND")
})

test_that("report_fact rejects an unknown agg verb", {
  expect_error(report_fact("x", 1, "a.csv", "median", rendered = "1"), "agg")
})

test_that("facts sidecars round-trip large integers without scientific notation", {
  facts <- list(
    report_fact("portfolio_total_vnd", 25020000000000,
                "data/vietnam_loanbook.csv", "sum",
                column = "loan_size_outstanding", unit = "VND",
                rendered = "25,020.0 bn VND")
  )
  html_path <- file.path(tempdir(), "roundtrip.html")
  writeLines("<html></html>", html_path)
  facts_path <- write_report_facts(facts, html_path, "scripts/pacta_vietnam_scenario.R")
  raw <- paste(readLines(facts_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("25020000000000", raw, fixed = TRUE))
  parsed <- read_report_facts(facts_path)
  expect_equal(parsed$facts[[1]]$value, 25020000000000)
})

test_that("read_report_facts stops on a missing file or a missing facts array", {
  expect_error(read_report_facts(file.path(tempdir(), "no-such.facts.json")))
  bad_path <- file.path(tempdir(), "bad.facts.json")
  writeLines('{"report": "x.html"}', bad_path)
  expect_error(read_report_facts(bad_path), "facts")
})

.inv_fixture <- function(root_dir, html_body, value) {
  dir.create(file.path(root_dir, "reports"), showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(root_dir, "data"), showWarnings = FALSE, recursive = TRUE)
  writeLines(html_body, file.path(root_dir, "reports", "X.html"), useBytes = TRUE)
  utils::write.csv(data.frame(loan_size_outstanding = c(25020000000000)),
                   file.path(root_dir, "data", "loanbook.csv"), row.names = FALSE)
  sidecar <- list(
    report = "reports/X.html",
    generated_by = "scripts/fixture.R",
    facts = list(list(
      name = "portfolio_total_vnd", value = value, unit = "VND",
      rendered = "25,020.0 bn VND",
      source = list(csv = "data/loanbook.csv", column = "loan_size_outstanding", agg = "sum")
    ))
  )
  json <- jsonlite::toJSON(sidecar, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  writeLines(json, file.path(root_dir, "reports", "X.facts.json"), useBytes = TRUE)
}

test_that("INV-013 passes on a consistent fixture", {
  fixture <- file.path(tempdir(), "inv13-happy")
  unlink(fixture, recursive = TRUE)
  .inv_fixture(fixture, "<p>25,020.0 bn VND</p>", 25020000000000)
  gate <- inv_report_facts_agree(fixture, "reports/X.html")
  expect_true(gate$ok)
})

test_that("INV-013 fails on a wrong value", {
  fixture <- file.path(tempdir(), "inv13-value")
  unlink(fixture, recursive = TRUE)
  .inv_fixture(fixture, "<p>25,020.0 bn VND</p>", 999)
  gate <- inv_report_facts_agree(fixture, "reports/X.html")
  expect_false(gate$ok)
  expect_true(any(grepl("fact 'portfolio_total_vnd' is 999", gate$detail, fixed = TRUE)))
})

test_that("INV-013 fails when the rendered string is absent", {
  fixture <- file.path(tempdir(), "inv13-rendered")
  unlink(fixture, recursive = TRUE)
  .inv_fixture(fixture, "<p>2.502e+10</p>", 25020000000000)
  gate <- inv_report_facts_agree(fixture, "reports/X.html")
  expect_false(gate$ok)
  expect_true(any(grepl("does not appear in the report", gate$detail, fixed = TRUE)))
})

test_that("INV-013 skips a gated report with no sidecar", {
  fixture <- file.path(tempdir(), "inv13-noskip")
  unlink(fixture, recursive = TRUE)
  dir.create(file.path(fixture, "reports"), showWarnings = FALSE, recursive = TRUE)
  writeLines("<p>anything</p>", file.path(fixture, "reports", "X.html"), useBytes = TRUE)
  gate <- inv_report_facts_agree(fixture, "reports/X.html")
  expect_true(gate$ok)
})

test_that("INV-013 fails when the source CSV is missing", {
  fixture <- file.path(tempdir(), "inv13-missing")
  unlink(fixture, recursive = TRUE)
  dir.create(file.path(fixture, "reports"), showWarnings = FALSE, recursive = TRUE)
  writeLines("<p>25,020.0 bn VND</p>", file.path(fixture, "reports", "X.html"), useBytes = TRUE)
  sidecar <- list(
    report = "reports/X.html",
    generated_by = "scripts/fixture.R",
    facts = list(list(
      name = "portfolio_total_vnd", value = 1,
      rendered = "25,020.0 bn VND",
      source = list(csv = "data/gone.csv", column = "loan_size_outstanding", agg = "sum")
    ))
  )
  json <- jsonlite::toJSON(sidecar, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  writeLines(json, file.path(fixture, "reports", "X.facts.json"), useBytes = TRUE)
  gate <- inv_report_facts_agree(fixture, "reports/X.html")
  expect_false(gate$ok)
  expect_true(any(grepl("gone.csv", gate$detail, fixed = TRUE)))
})
