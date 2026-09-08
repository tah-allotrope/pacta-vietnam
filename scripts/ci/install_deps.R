#!/usr/bin/env Rscript
# install_deps.R
# Supported dependency install path for CI and for local setup (not renv:
# .Rprofile's renv activation is intentionally left commented out, and
# renv.lock is kept only as a declarative manifest checked by INV-008).
# Installs the R packages the TRISK pipeline chain needs. Everything is on
# CRAN except trisk.model, which is no longer available there and installs
# from the Theia-Finance-Labs GitHub repo pinned to the commit matching the
# verified local version (2.6.1).

cran_packages <- c(
  "arrow", "base64enc", "dplyr", "fs", "ggplot2", "ggrepel", "glue",
  "jsonlite", "magrittr", "pacta.loanbook", "purrr", "r2dii.analysis",
  "r2dii.data", "r2dii.match", "r2dii.plot", "readr", "rlang",
  "scales", "stringi", "tibble", "tidyr", "uuid", "xfun", "zoo"
)

dev_packages <- c("testthat", "roxygen2", "devtools")

# trisk.model 2.6.1 — pinned commit tarball (avoids the GitHub API and its
# rate limits; the archive URL needs no authentication).
trisk_model_tarball <- "https://github.com/Theia-Finance-Labs/trisk.model/archive/cf720666a10d5517135ca17b7b158ad0ca64824b.tar.gz"

# Prefer the repos configured by the environment (e.g. r-lib/actions
# setup-r with use-public-rspm installs fast Linux binaries from Posit
# Package Manager); fall back to CRAN cloud when nothing is configured.
repos <- getOption("repos")
if (is.null(repos) || length(repos) == 0 || identical(unname(repos["CRAN"]), "@CRAN@")) {
  repos <- c(CRAN = "https://cloud.r-project.org")
}

args <- commandArgs(trailingOnly = TRUE)
want_dev <- "--dev" %in% args

wanted <- cran_packages
if (isTRUE(want_dev)) wanted <- c(wanted, dev_packages)

missing <- setdiff(wanted, rownames(installed.packages()))
if (length(missing) > 0) {
  install.packages(missing, repos = repos)
}

if (!"trisk.model" %in% rownames(installed.packages())) {
  tarball <- file.path(tempdir(), "trisk.model.tar.gz")
  download.file(trisk_model_tarball, tarball, mode = "wb", quiet = TRUE)
  install.packages(tarball, repos = NULL, type = "source")
}

still_missing <- setdiff(c(wanted, "trisk.model"), rownames(installed.packages()))
if (length(still_missing) > 0) {
  stop("Failed to install: ", paste(still_missing, collapse = ", "))
}

cat("All pipeline R dependencies installed.\n")
