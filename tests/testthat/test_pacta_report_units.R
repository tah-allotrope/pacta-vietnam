library(testthat)

root <- project_root()
source(file.path(root, "R", "format_money.R"))

test_that("format_vnd_bn renders the MCB portfolio total without scientific notation", {
  expect_equal(format_vnd_bn(25020000000000), "25,020.0 bn VND")
  expect_false(grepl("e\\+", format_vnd_bn(25020000000000)))
})

test_that("PACTA report carries the corrected portfolio figure", {
  html_path <- file.path(root, "reports", "PACTA_Vietnam_Bank_Report.html")
  skip_if_not(file.exists(html_path), "PACTA report not generated yet")
  html <- paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_true(grepl("25,020.0 bn VND", html, fixed = TRUE))
  expect_false(grepl("2\\.502e\\+10", html))
  expect_false(grepl("1000800", html, fixed = TRUE))
})

test_that("loanbook total anchors the display assertions", {
  loanbook <- utils::read.csv(file.path(root, "data", "vietnam_loanbook.csv"))
  expect_equal(sum(loanbook$loan_size_outstanding), 25020000000000)
})

test_that("format_vnd_bn keeps its NA behaviour", {
  expect_equal(format_vnd_bn(NA_real_), "Not available")
})
