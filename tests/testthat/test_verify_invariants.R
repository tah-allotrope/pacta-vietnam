library(testthat)

root <- project_root()
source(file.path(root, "tools", "verify_refactor.R"))

# --- Fixture helpers ----------------------------------------------------------
# Every inv_*() function is exercised against tempdir()-built fixtures, never
# against the live repo tree (except inv_sector_lists_agree(), which is
# expected to pass on the live repo today and exists to guard future drift).

.new_fixture_root <- function() {
  path <- file.path(tempdir(), paste0(
    "verify_invariants_", as.integer(Sys.time()), "_", sample.int(1e6, 1)
  ))
  dir.create(path, recursive = TRUE)
  path
}

.write_manifest <- function(root, snapshot_dir, sector, grid_available) {
  dir.create(file.path(root, snapshot_dir, "trisk"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(sector = sector, grid_available = grid_available, stringsAsFactors = FALSE),
    file.path(root, snapshot_dir, "trisk", "manifest.csv"),
    row.names = FALSE
  )
}

.write_grid <- function(root, snapshot_dir, sector, company_id, npv_change_pct, pd_change_pct,
                         scenario_id = "s2028_d0.08_rf0.03_mp0.25_cNGFS_NetZero2050") {
  dir.create(file.path(root, snapshot_dir, "trisk", "grid", sector), recursive = TRUE, showWarnings = FALSE)
  arrow::write_parquet(
    data.frame(
      scenario_id = scenario_id,
      company_id = company_id,
      npv_change_pct = npv_change_pct,
      pd_change_pct = pd_change_pct,
      stringsAsFactors = FALSE
    ),
    file.path(root, snapshot_dir, "trisk", "grid", sector, "borrower_results.parquet")
  )
}

.write_company_summary <- function(root, snapshot_dir, sector, company_id, npv_change, pd_change) {
  dir.create(file.path(root, snapshot_dir, "trisk", sector), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(company_id = company_id, npv_change = npv_change, pd_change = pd_change, stringsAsFactors = FALSE),
    file.path(root, snapshot_dir, "trisk", sector, "company_summary.csv"),
    row.names = FALSE
  )
}

.write_engagement_fixture <- function(root, slug, engagement_output_dir, data_source_values) {
  dir.create(file.path(root, "engagements", slug), recursive = TRUE, showWarnings = FALSE)
  cfg <- list(
    bank_name = "Test Bank",
    bank_slug = slug,
    paths = list(engagement_output_dir = engagement_output_dir)
  )
  writeLines(
    jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
    file.path(root, "engagements", slug, "engagement_config.json")
  )
  if (!is.null(data_source_values)) {
    dir.create(file.path(root, engagement_output_dir), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(
      data.frame(
        name_abcd = seq_along(data_source_values),
        data_source = data_source_values,
        stringsAsFactors = FALSE
      ),
      file.path(root, engagement_output_dir, "engagement_priority.csv"),
      row.names = FALSE
    )
  }
}

# --- INV-001: grid base cell vs base run --------------------------------------

test_that("inv_grid_matches_base_run passes when grid base cell equals base run", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", TRUE)
  .write_grid(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)
  .write_company_summary(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

test_that("inv_grid_matches_base_run fails when npv_change diverges beyond tolerance", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", TRUE)
  .write_grid(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)
  .write_company_summary(fixture_root, "dashboard/data", "power", "X", -0.45, 0.1)

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_false(result$ok)
  expect_equal(length(result$detail), 1)
  expect_true(grepl("power/X", result$detail[1]))
})

test_that("inv_grid_matches_base_run tolerates sub-tolerance deltas", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", TRUE)
  .write_grid(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)
  .write_company_summary(fixture_root, "dashboard/data", "power", "X", -0.5000005, 0.1)

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_true(result$ok)
})

test_that("inv_grid_matches_base_run fails when company_id sets differ", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", TRUE)
  .write_grid(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)
  .write_company_summary(
    fixture_root, "dashboard/data", "power",
    c("X", "Y"), c(-0.5, -0.3), c(0.1, 0.05)
  )

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_false(result$ok)
  expect_true(any(grepl("Y", result$detail)))
})

test_that("inv_grid_matches_base_run skips sectors marked grid_available = FALSE", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", FALSE)

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

# --- INV-002: scenario vintage single source ----------------------------------

test_that("inv_scenario_vintage_single_source flags byte-identical duplicates", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "data", "scenarios", "v1"), recursive = TRUE)
  writeLines("a,b\n1,2", file.path(fixture_root, "data", "foo.csv"))
  writeLines("a,b\n1,2", file.path(fixture_root, "data", "scenarios", "v1", "foo.csv"))

  result <- inv_scenario_vintage_single_source(fixture_root)
  expect_false(result$ok)
  expect_equal(length(result$detail), 1)
})

test_that("inv_scenario_vintage_single_source passes when content differs", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "data", "scenarios", "v1"), recursive = TRUE)
  writeLines("a,b\n1,2", file.path(fixture_root, "data", "foo.csv"))
  writeLines("a,b\n3,4", file.path(fixture_root, "data", "scenarios", "v1", "foo.csv"))

  result <- inv_scenario_vintage_single_source(fixture_root)
  expect_true(result$ok)
})

test_that("inv_scenario_vintage_single_source passes when data/scenarios does not exist", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "data"), recursive = TRUE)

  result <- inv_scenario_vintage_single_source(fixture_root)
  expect_true(result$ok)
})

# --- INV-003: engagement data_source provenance -------------------------------

test_that("inv_engagement_data_source passes when data_source matches bank_slug", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_engagement_fixture(fixture_root, "acme", "output/engagement", c("acme", "acme"))

  result <- inv_engagement_data_source(fixture_root)
  expect_true(result$ok)
})

test_that("inv_engagement_data_source fails when data_source leaks another engagement's provenance", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_engagement_fixture(fixture_root, "acme", "output/engagement", c("acme", "MCB_synthetic"))

  result <- inv_engagement_data_source(fixture_root)
  expect_false(result$ok)
  expect_true(any(grepl("MCB_synthetic", result$detail)))
})

test_that("inv_engagement_data_source skips engagements with no engagement_priority.csv yet", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_engagement_fixture(fixture_root, "acme", "output/engagement", NULL)

  result <- inv_engagement_data_source(fixture_root)
  expect_true(result$ok)
})

# --- INV-004: sector list agreement (live repo) -------------------------------

test_that("inv_sector_lists_agree passes on the live repo", {
  result <- inv_sector_lists_agree(root)
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

# --- .md5_of() helper ----------------------------------------------------------

test_that(".md5_of returns NA for a nonexistent file", {
  expect_true(is.na(.md5_of(file.path(tempdir(), "definitely_does_not_exist_12345.csv"))))
})

# --- INV-006: loanbook currency/scale plausibility ----------------------------

.write_loanbook_currency_fixture <- function(root, slug, loanbook_rel_path, outstanding, currency) {
  dir.create(file.path(root, "engagements", slug), recursive = TRUE, showWarnings = FALSE)
  cfg <- list(
    bank_name = "Test Bank",
    bank_slug = slug,
    inputs = list(loanbook_csv = loanbook_rel_path)
  )
  writeLines(
    jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
    file.path(root, "engagements", slug, "engagement_config.json")
  )
  loanbook_path <- file.path(root, loanbook_rel_path)
  dir.create(dirname(loanbook_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(
      loan_size_outstanding = outstanding,
      loan_size_outstanding_currency = currency,
      stringsAsFactors = FALSE
    ),
    loanbook_path,
    row.names = FALSE
  )
}

test_that("inv_loanbook_currency_scale fails when a VND loanbook's median is implausibly small", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_loanbook_currency_fixture(
    fixture_root, "acme", "data/loanbook.csv",
    outstanding = c(800000, 650000), currency = c("VND", "VND")
  )

  result <- inv_loanbook_currency_scale(fixture_root)
  expect_false(result$ok)
  expect_equal(length(result$detail), 1)
  expect_true(grepl("median", result$detail[1]))
  expect_true(grepl("1e\\+08|100,000,000|100000000", result$detail[1]))
})

test_that("inv_loanbook_currency_scale passes when a VND loanbook's median is plausible", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_loanbook_currency_fixture(
    fixture_root, "acme", "data/loanbook.csv",
    outstanding = c(8e11, 6.5e11), currency = c("VND", "VND")
  )

  result <- inv_loanbook_currency_scale(fixture_root)
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

test_that("inv_loanbook_currency_scale skips an engagement whose loanbook path does not exist", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "engagements", "acme"), recursive = TRUE)
  cfg <- list(
    bank_name = "Test Bank",
    bank_slug = "acme",
    inputs = list(loanbook_csv = "data/does_not_exist.csv")
  )
  writeLines(
    jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
    file.path(fixture_root, "engagements", "acme", "engagement_config.json")
  )

  result <- inv_loanbook_currency_scale(fixture_root)
  expect_true(result$ok)
})

test_that("inv_loanbook_currency_scale ignores non-VND currency rows", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_loanbook_currency_fixture(
    fixture_root, "acme", "data/loanbook.csv",
    outstanding = c(800000, 8e11), currency = c("USD", "VND")
  )

  result <- inv_loanbook_currency_scale(fixture_root)
  expect_true(result$ok)
})

# --- INV-007: engagement fixture allowlist -------------------------------------

.git_init_with_tracked_file <- function(root, rel_path, content = "x") {
  full_path <- file.path(root, rel_path)
  dir.create(dirname(full_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(content, full_path)
  old_wd <- getwd()
  setwd(root)
  on.exit(setwd(old_wd), add = TRUE)
  system2("git", c("init", "-q"))
  system2("git", c("add", rel_path))
}

test_that("inv_engagement_fixture_allowlist passes on the live repo", {
  result <- inv_engagement_fixture_allowlist(root)
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

test_that("inv_engagement_fixture_allowlist fails when a non-allowlisted slug has a tracked fixture file", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .git_init_with_tracked_file(
    fixture_root, "engagements/bidv/intake/normalized_loanbook.csv"
  )

  result <- inv_engagement_fixture_allowlist(fixture_root)
  expect_false(result$ok)
  expect_equal(length(result$detail), 1)
  expect_true(grepl("bidv", result$detail[1], fixed = TRUE))
})

test_that("inv_engagement_fixture_allowlist exempts a non-allowlisted slug's own engagement_config.json", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .git_init_with_tracked_file(
    fixture_root, "engagements/bidv/engagement_config.json"
  )

  result <- inv_engagement_fixture_allowlist(fixture_root)
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

test_that("inv_engagement_fixture_allowlist passes when the allowlisted slug has tracked fixture files", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .git_init_with_tracked_file(
    fixture_root, "engagements/sdb-rehearsal/intake/normalized_loanbook.csv"
  )

  result <- inv_engagement_fixture_allowlist(fixture_root)
  expect_true(result$ok)
})

# --- INV-008: dependency manifest agreement ------------------------------------

.write_dep_fixture <- function(root, description_imports, description_suggests, install_deps_cran, renv_pkgs,
                             install_deps_dev = NULL) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "scripts", "ci"), recursive = TRUE, showWarnings = FALSE)

  desc_lines <- c(
    "Package: fixture",
    "Imports:",
    paste0("    ", paste(description_imports, collapse = ",\n    "))
  )
  if (length(description_suggests) > 0) {
    desc_lines <- c(desc_lines, "Suggests:", paste0("    ", paste(description_suggests, collapse = ",\n    ")))
  }
  writeLines(desc_lines, file.path(root, "DESCRIPTION"))

  install_deps_lines <- sprintf('cran_packages <- c(%s)', paste0('"', install_deps_cran, '"', collapse = ", "))
  if (!is.null(install_deps_dev)) {
    install_deps_lines <- c(install_deps_lines,
      sprintf('dev_packages <- c(%s)', paste0('"', install_deps_dev, '"', collapse = ", ")))
  }
  writeLines(install_deps_lines, file.path(root, "scripts", "ci", "install_deps.R"))

  lock <- list(Packages = setNames(
    lapply(renv_pkgs, function(p) list(Package = p, Version = "1.0.0")),
    renv_pkgs
  ))
  writeLines(jsonlite::toJSON(lock, auto_unbox = TRUE, pretty = TRUE), file.path(root, "renv.lock"))
}

test_that("inv_dependency_manifests_agree passes on the live repo", {
  result <- inv_dependency_manifests_agree(root)
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

test_that("inv_dependency_manifests_agree fails when install_deps.R installs a package absent from Imports", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_dep_fixture(
    fixture_root,
    description_imports = c("dplyr"), description_suggests = character(0),
    install_deps_cran = c("dplyr", "zoo"), renv_pkgs = c("dplyr")
  )

  result <- inv_dependency_manifests_agree(fixture_root)
  expect_false(result$ok)
  expect_true(any(grepl("zoo", result$detail, fixed = TRUE)))
})

test_that("inv_dependency_manifests_agree fails when renv.lock records a package absent from Imports", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_dep_fixture(
    fixture_root,
    description_imports = c("dplyr"), description_suggests = character(0),
    install_deps_cran = c("dplyr"), renv_pkgs = c("dplyr", "trisk.model")
  )

  result <- inv_dependency_manifests_agree(fixture_root)
  expect_false(result$ok)
  expect_true(any(grepl("trisk.model", result$detail, fixed = TRUE)))
})

test_that("inv_dependency_manifests_agree exempts a Suggests-listed package", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_dep_fixture(
    fixture_root,
    description_imports = c("dplyr"), description_suggests = c("testthat"),
    install_deps_cran = c("dplyr"), renv_pkgs = c("dplyr", "testthat")
  )

  result <- inv_dependency_manifests_agree(fixture_root)
  expect_true(result$ok)
})

test_that("inv_dependency_manifests_agree sees dev_packages listed in Suggests", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_dep_fixture(
    fixture_root,
    description_imports = c("dplyr"), description_suggests = c("roxygen2"),
    install_deps_cran = c("dplyr"), renv_pkgs = c("dplyr"),
    install_deps_dev = c("roxygen2")
  )
  result <- inv_dependency_manifests_agree(fixture_root)
  expect_true(result$ok)
})

test_that("inv_dependency_manifests_agree fails on a dev package missing from DESCRIPTION", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_dep_fixture(
    fixture_root,
    description_imports = c("dplyr"), description_suggests = character(0),
    install_deps_cran = c("dplyr"), renv_pkgs = c("dplyr"),
    install_deps_dev = c("notapackage")
  )
  result <- inv_dependency_manifests_agree(fixture_root)
  expect_false(result$ok)
  expect_true(any(grepl("'notapackage' is used by (scripts/ci/install_deps.R) but missing from DESCRIPTION Imports", result$detail, fixed = TRUE)))
})

test_that("inv_dependency_manifests_agree passes when every used package is declared", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_dep_fixture(
    fixture_root,
    description_imports = c("dplyr", "zoo", "trisk.model"), description_suggests = character(0),
    install_deps_cran = c("dplyr", "zoo"), renv_pkgs = c("dplyr", "zoo", "trisk.model")
  )

  result <- inv_dependency_manifests_agree(fixture_root)
  expect_true(result$ok)
})

# --- INV-009: scenario vintage declared and consistent -------------------------

.write_vintage_fixture <- function(root, slug, vintage, ms_dir_name, co2_dir_name, create_vintage_dir = TRUE) {
  dir.create(file.path(root, "engagements", slug), recursive = TRUE, showWarnings = FALSE)
  cfg <- list(
    bank_name = "Test Bank", bank_slug = slug,
    inputs = list(
      scenario_vintage = vintage,
      scenario_ms_csv = file.path("data", "scenarios", ms_dir_name, "vietnam_scenario_ms.csv"),
      scenario_co2_csv = file.path("data", "scenarios", co2_dir_name, "vietnam_scenario_co2.csv")
    )
  )
  writeLines(
    jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
    file.path(root, "engagements", slug, "engagement_config.json")
  )
  if (create_vintage_dir) {
    dir.create(file.path(root, "data", "scenarios", vintage), recursive = TRUE, showWarnings = FALSE)
  }
}

test_that("inv_scenario_vintage_declared passes on the live repo", {
  result <- inv_scenario_vintage_declared(root)
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

test_that("inv_scenario_vintage_declared fails when scenario_vintage does not match the scenario paths", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_vintage_fixture(fixture_root, "acme", "pdp8-2025-adjusted", "pdp8-2023", "pdp8-2023")

  result <- inv_scenario_vintage_declared(fixture_root)
  expect_false(result$ok)
  expect_equal(length(result$detail), 1)
  expect_true(grepl("acme", result$detail[1], fixed = TRUE))
})

test_that("inv_scenario_vintage_declared fails when the declared vintage directory does not exist", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_vintage_fixture(fixture_root, "acme", "pdp8-nonexistent", "pdp8-nonexistent", "pdp8-nonexistent", create_vintage_dir = FALSE)

  result <- inv_scenario_vintage_declared(fixture_root)
  expect_false(result$ok)
  expect_true(any(grepl("no directory", result$detail, fixed = TRUE)))
})

test_that("inv_scenario_vintage_declared passes when vintage and paths agree", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_vintage_fixture(fixture_root, "acme", "pdp8-2023", "pdp8-2023", "pdp8-2023")

  result <- inv_scenario_vintage_declared(fixture_root)
  expect_true(result$ok)
})

# --- INV-011: manifest plausibility (Wave 4 PHASE-02) -------------------------

#' Write an engagement config plus a pipeline manifest into a fixture root.
#' @param root character — fixture root.
#' @param slug character — bank slug.
#' @param seconds numeric — one duration per step.
#' @param partial logical — the manifest's `partial` flag; NULL omits the field.
.write_manifest_fixture <- function(root, slug, seconds, partial = FALSE) {
  dir.create(file.path(root, "engagements", slug), recursive = TRUE, showWarnings = FALSE)
  cfg <- list(
    bank_slug = slug,
    public_snapshot_allowed = FALSE,
    inputs = list(scenario_vintage = "pdp8-2023"),
    paths = list(reports_dir = "reports")
  )
  write(jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
        file.path(root, "engagements", slug, "engagement_config.json"))

  manifest <- list(
    generated_at = "2026-09-02T08:00:00+0700",
    steps = data.frame(
      name = paste0("step_", seq_along(seconds)),
      status = rep("ok", length(seconds)),
      seconds = seconds,
      stringsAsFactors = FALSE
    ),
    status = "ok"
  )
  if (!is.null(partial)) manifest$partial <- partial
  write(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
        file.path(root, "engagements", slug, "pipeline_manifest.json"))
}

test_that("inv_manifest_plausible fails when every step reports the same duration", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest_fixture(fixture_root, "acme", seconds = c(1, 1, 1, 1))

  result <- inv_manifest_plausible(fixture_root)
  expect_equal(result$id, "INV-011")
  expect_false(result$ok)
  expect_true(any(grepl("same duration", result$detail, fixed = TRUE)))
})

test_that("inv_manifest_plausible exempts a run marked partial", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest_fixture(fixture_root, "acme", seconds = c(1, 1, 1, 1), partial = TRUE)

  expect_true(inv_manifest_plausible(fixture_root)$ok)
})

test_that("inv_manifest_plausible ignores a run with fewer than three steps", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest_fixture(fixture_root, "acme", seconds = c(1, 1))

  expect_true(inv_manifest_plausible(fixture_root)$ok)
})

test_that("inv_manifest_plausible passes on realistic varied timings", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest_fixture(fixture_root, "acme", seconds = c(12.7, 3.4, 16.1))

  expect_true(inv_manifest_plausible(fixture_root)$ok)
})

# --- INV-012: the audit must attest to the configured vintage ----------------

#' Write a public engagement whose refresh-audit metrics record `recorded_*`
#' digests, alongside a scenario file whose real content is `ms_content`.
.write_audit_fixture <- function(root, ms_content, recorded_ms, recorded_co2 = NULL) {
  slug <- "pub"
  vintage_dir <- file.path("data", "scenarios", "v1")
  dir.create(file.path(root, vintage_dir), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "engagements", slug), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "reports"), recursive = TRUE, showWarnings = FALSE)

  ms_rel <- file.path(vintage_dir, "vietnam_scenario_ms.csv")
  co2_rel <- file.path(vintage_dir, "vietnam_scenario_co2.csv")
  writeLines(ms_content, file.path(root, ms_rel))
  writeLines("co2,content", file.path(root, co2_rel))

  cfg <- list(
    bank_slug = slug,
    public_snapshot_allowed = TRUE,
    inputs = list(
      scenario_vintage = "v1",
      scenario_ms_csv = gsub("\\\\", "/", ms_rel),
      scenario_co2_csv = gsub("\\\\", "/", co2_rel)
    ),
    paths = list(reports_dir = "reports", snapshot_dir = "snap")
  )
  write(jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
        file.path(root, "engagements", slug, "engagement_config.json"))

  metrics <- list(scenario_ms_checksum = recorded_ms)
  if (!is.null(recorded_co2)) metrics$scenario_co2_checksum <- recorded_co2
  write(jsonlite::toJSON(metrics, auto_unbox = TRUE, pretty = TRUE),
        file.path(root, "reports", "refresh_audit_metrics.json"))
  file.path(root, ms_rel)
}

test_that("inv_audit_attests_configured_vintage fails on a stale recorded checksum", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_audit_fixture(fixture_root, "real,content", recorded_ms = "00000000000000000000000000000000")

  result <- inv_audit_attests_configured_vintage(fixture_root)
  expect_equal(result$id, "INV-012")
  expect_false(result$ok)
  expect_true(any(grepl("hashes to", result$detail, fixed = TRUE)))
})

test_that("inv_audit_attests_configured_vintage passes when the digest matches the configured input", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  ms_path <- .write_audit_fixture(fixture_root, "real,content", recorded_ms = "placeholder")
  real_digest <- unname(tools::md5sum(ms_path))
  .write_audit_fixture(fixture_root, "real,content", recorded_ms = real_digest)

  expect_true(inv_audit_attests_configured_vintage(fixture_root)$ok)
})

test_that("inv_audit_attests_configured_vintage skips an engagement with no metrics file", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "engagements", "nope"), recursive = TRUE)
  cfg <- list(bank_slug = "nope", public_snapshot_allowed = TRUE,
              inputs = list(scenario_vintage = "v1"), paths = list(reports_dir = "reports"))
  write(jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
        file.path(fixture_root, "engagements", "nope", "engagement_config.json"))

  expect_true(inv_audit_attests_configured_vintage(fixture_root)$ok)
})

# --- INV-003 widened + INV-004 self-maintaining (Wave 4 PHASE-03) -------------

test_that("inv_engagement_data_source now checks the Wave 3 outputs too", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  slug <- "acme"
  dir.create(file.path(fixture_root, "engagements", slug), recursive = TRUE)
  dir.create(file.path(fixture_root, "out", "eng"), recursive = TRUE)
  dir.create(file.path(fixture_root, "out", "fe"), recursive = TRUE)

  cfg <- list(
    bank_slug = slug,
    paths = list(engagement_output_dir = "out/eng", financed_emissions_output_dir = "out/fe")
  )
  write(jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
        file.path(fixture_root, "engagements", slug, "engagement_config.json"))

  # Correct provenance in the file INV-003 always checked ...
  utils::write.csv(data.frame(name_abcd = "X", data_source = slug, stringsAsFactors = FALSE),
                   file.path(fixture_root, "out", "eng", "engagement_priority.csv"), row.names = FALSE)
  # ... and another bank's slug in one Wave 3 added.
  utils::write.csv(data.frame(name_abcd = "X", data_source = "other-bank", stringsAsFactors = FALSE),
                   file.path(fixture_root, "out", "fe", "financed_emissions.csv"), row.names = FALSE)

  result <- inv_engagement_data_source(fixture_root)
  expect_false(result$ok)
  expect_true(any(grepl("financed_emissions.csv", result$detail, fixed = TRUE)))
  expect_true(any(grepl("other-bank", result$detail, fixed = TRUE)))
})

test_that("inv_engagement_data_source skips a CSV with no data_source column", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  slug <- "acme"
  dir.create(file.path(fixture_root, "engagements", slug), recursive = TRUE)
  dir.create(file.path(fixture_root, "out", "eng"), recursive = TRUE)
  cfg <- list(bank_slug = slug, paths = list(engagement_output_dir = "out/eng"))
  write(jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
        file.path(fixture_root, "engagements", slug, "engagement_config.json"))
  utils::write.csv(data.frame(sector = "power", target_value = 1),
                   file.path(fixture_root, "out", "eng", "target_registry.csv"), row.names = FALSE)

  expect_true(inv_engagement_data_source(fixture_root)$ok)
})

test_that(".scan_hardcoded_sector_triples finds a stray literal and honours the allowlist", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "scripts"), recursive = TRUE)
  dir.create(file.path(fixture_root, "R"), recursive = TRUE)

  writeLines('for (s in c("power", "cement", "steel")) { }',
             file.path(fixture_root, "scripts", "bad.R"))
  writeLines('# prose naming c("power", "cement", "steel") is not a declaration',
             file.path(fixture_root, "scripts", "comment_only.R"))
  writeLines('sector <- c("power", "cement", "steel")',
             file.path(fixture_root, "R", "sector_registry.R"))

  hits <- .scan_hardcoded_sector_triples(fixture_root)
  expect_true(any(grepl("scripts/bad.R", hits, fixed = TRUE)))
  expect_false(any(grepl("comment_only", hits, fixed = TRUE)))
  expect_false(any(grepl("sector_registry", hits, fixed = TRUE)))
})

test_that("the live repo declares the sector list only in the entitled files", {
  expect_equal(.scan_hardcoded_sector_triples(root), character(0))
})
