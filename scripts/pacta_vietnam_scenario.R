# ==============================================================================
# pacta_vietnam_scenario.R
# Vietnam-specific PACTA pipeline for Mekong Commercial Bank (MCB)
#
# Demonstrates climate alignment of a synthetic Vietnamese commercial bank
# loanbook against Vietnam's Power Development Plan 8 (PDP8), NDC targets,
# and global IEA NZE benchmarks.
#
# Prerequisites: run data/generate_vietnam_data.R first to produce input CSVs.
#
# Run from project root:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/pacta_vietnam_scenario.R
# ==============================================================================

library(pacta.loanbook)
library(r2dii.data)
library(r2dii.match)
library(r2dii.analysis)
library(r2dii.plot)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(ggrepel)
library(base64enc)
library(readr)
library(stringi)

cat("========================================\n")
cat("PACTA VIETNAM: Mekong Commercial Bank\n")
cat("========================================\n\n")

# --- Output directories ---
vn_output  <- file.path(getwd(), "synthesis_output", "vietnam")
report_dir <- file.path(getwd(), "reports")
dir.create(vn_output,  showWarnings = FALSE, recursive = TRUE)
dir.create(report_dir, showWarnings = FALSE, recursive = TRUE)

# --- Helper: base64 encode a PNG ---
img_to_base64 <- function(path) {
  raw <- readBin(path, "raw", file.info(path)$size)
  b64 <- base64enc::base64encode(raw)
  paste0("data:image/png;base64,", b64)
}

# ==============================================================================
# SECTION 1: LOAD VIETNAM DATA
# ==============================================================================

cat("--- Section 1: Loading Vietnam data ---\n\n")

# Check that generated CSVs exist
required_files <- c(
  "data/vietnam_loanbook.csv",
  "data/vietnam_abcd.csv",
  "data/vietnam_scenario_ms.csv",
  "data/vietnam_scenario_co2.csv",
  "data/vietnam_region_isos.csv"
)

missing <- required_files[!file.exists(required_files)]
if (length(missing) > 0) {
  stop(paste(
    "Missing data files. Run data/generate_vietnam_data.R first.\nMissing:",
    paste(missing, collapse = "\n  ")
  ))
}

loanbook <- read_csv("data/vietnam_loanbook.csv", show_col_types = FALSE)
abcd     <- read_csv("data/vietnam_abcd.csv",     show_col_types = FALSE)
scenario <- read_csv("data/vietnam_scenario_ms.csv",  show_col_types = FALSE)
co2      <- read_csv("data/vietnam_scenario_co2.csv", show_col_types = FALSE)
region   <- read_csv("data/vietnam_region_isos.csv",  show_col_types = FALSE)

cat(sprintf("  Loanbook: %d rows, %d cols\n", nrow(loanbook), ncol(loanbook)))
cat(sprintf("  ABCD: %d rows | Sectors: %s\n",
            nrow(abcd), paste(unique(abcd$sector), collapse = ", ")))
cat(sprintf("  Market share scenario: %d rows | Scenarios: %s\n",
            nrow(scenario), paste(unique(scenario$scenario), collapse = ", ")))
cat(sprintf("  CO2 intensity scenario: %d rows | Scenarios: %s\n",
            nrow(co2), paste(unique(co2$scenario), collapse = ", ")))
cat(sprintf("  Region ISOs: %d rows\n\n", nrow(region)))

# Portfolio summary
total_vnd_bn <- sum(loanbook$loan_size_outstanding) / 1000
cat(sprintf("  Total portfolio: %s bn VND (~$%.1fB USD)\n\n",
            format(round(total_vnd_bn), big.mark = ","), total_vnd_bn / 25000))

# ==============================================================================
# SECTION 2: SECTOR PRE-JOIN
# VSIC codes are structurally identical to ISIC Rev.4 codes.
# loanbook uses sector_classification_system = "ISIC" for compatibility.
# ==============================================================================

cat("--- Section 2: Sector pre-join (ISIC classification) ---\n\n")

# r2dii.data::sector_classifications uses NACE/GICS codes by default.
# VSIC 2018 is structurally identical to ISIC Rev.4 but uses raw 4-digit codes
# that are not in the standard table. We extend it with a custom mapping.
vsic_to_pacta <- tibble::tribble(
  ~code_system, ~code,  ~sector,      ~borderline,
  "ISIC",       "3511", "power",       FALSE,
  "ISIC",       "2910", "automotive",  FALSE,
  "ISIC",       "2394", "cement",      FALSE,
  "ISIC",       "2410", "steel",       FALSE,
  "ISIC",       "0510", "coal",        FALSE,
  "ISIC",       "0610", "oil and gas", FALSE
)

sector_classifications <- bind_rows(sector_classifications, vsic_to_pacta)

loanbook_classified <- loanbook %>%
  mutate(sector_classification_direct_loantaker =
           as.character(sector_classification_direct_loantaker)) %>%
  left_join(sector_classifications, by = c(
    "sector_classification_system" = "code_system",
    "sector_classification_direct_loantaker" = "code"
  )) %>%
  rename(
    sector_classified    = sector,
    borderline_classified = borderline
  )

# Validate all ISIC codes resolved to a PACTA sector
unresolved <- loanbook_classified %>%
  filter(is.na(sector_classified)) %>%
  distinct(sector_classification_direct_loantaker)

if (nrow(unresolved) > 0) {
  cat("  WARNING: Unresolved ISIC codes (no PACTA sector mapping):\n")
  print(as.data.frame(unresolved))
  cat("  These loans will be classified as 'not in scope'.\n\n")
} else {
  cat("  All ISIC codes resolved to PACTA sectors. PASS.\n")
}

sector_breakdown <- loanbook_classified %>%
  group_by(sector_classified) %>%
  summarise(
    n_loans           = n(),
    total_bn_vnd      = round(sum(loan_size_outstanding, na.rm = TRUE) / 1000),
    pct_of_portfolio  = round(sum(loan_size_outstanding, na.rm = TRUE) /
                                sum(loanbook$loan_size_outstanding) * 100, 1),
    .groups = "drop"
  ) %>%
  arrange(desc(total_bn_vnd))

cat("\n  Loanbook sector breakdown:\n")
print(as.data.frame(sector_breakdown))
cat("\n")

# ==============================================================================
# SECTION 3: FUZZY MATCHING (Vietnamese company names)
# ASCII-normalize names in both loanbook and ABCD before matching.
# This handles cases where bank systems strip Vietnamese diacritics (e.g.,
# "Vinh Tan" vs "Vinh Tan" - both already ASCII here, but normalization
# is applied for robustness and to document the pattern for real data).
# min_score = 0.8 (lower than default to handle partial Vietnamese name matches).
# ==============================================================================

cat("--- Section 3: Fuzzy matching ---\n\n")

# ASCII-normalize company names in-place (removes diacritics if present).
# Do NOT add _orig suffix columns — match_name() internally creates id_*_orig
# columns and will abort if any _orig columns already exist in the input.
loanbook_norm <- loanbook_classified %>%
  mutate(
    name_direct_loantaker = stri_trans_general(name_direct_loantaker, "Latin-ASCII"),
    name_ultimate_parent  = stri_trans_general(name_ultimate_parent,  "Latin-ASCII")
  )

abcd_norm <- abcd %>%
  mutate(
    name_company = stri_trans_general(name_company, "Latin-ASCII")
  )

# Match loanbook against ABCD by sector
# by_sector = TRUE ensures loan sector (from ISIC) matches ABCD sector
matched_raw <- match_name(
  loanbook_norm, abcd_norm,
  by_sector  = TRUE,
  min_score  = 0.8,
  method     = "jw",
  p          = 0.1
)

cat(sprintf("  Raw matches: %d rows\n", nrow(matched_raw)))
if (nrow(matched_raw) > 0) {
  cat(sprintf("  Score range: %.3f to %.3f\n",
              min(matched_raw$score), max(matched_raw$score)))
}

# Flag matches needing review (score < 1.0)
review_needed <- matched_raw %>%
  filter(score < 1.0) %>%
  select(id_loan, name_direct_loantaker, name_abcd, score, sector_abcd, level) %>%
  arrange(score)

n_review <- nrow(review_needed)
cat(sprintf("  Matches needing manual review (score < 1.0): %d\n", n_review))
if (n_review > 0 && n_review <= 20) {
  cat("  Review candidates:\n")
  print(as.data.frame(review_needed))
}

# Export raw matches for manual review
write_csv(matched_raw, file.path(vn_output, "01_vn_matched_raw.csv"))

# Prioritize: select best match per loan
matched <- prioritize(matched_raw)
cat(sprintf("\n  Prioritized matches: %d rows\n", nrow(matched)))
cat("  Match levels:\n")
print(as.data.frame(matched %>% count(level)))

# Sector mismatch check
mismatch <- matched %>%
  filter(sector_classified != sector) %>%
  select(id_loan, name_direct_loantaker, sector_classified, sector)

if (nrow(mismatch) > 0) {
  cat(sprintf("\n  WARNING: %d sector mismatches:\n", nrow(mismatch)))
  print(as.data.frame(mismatch))
} else {
  cat("\n  Sector mismatch check: PASS\n")
}

write_csv(matched, file.path(vn_output, "02_vn_matched_prioritized.csv"))
cat("\n")

# ==============================================================================
# SECTION 4: COVERAGE ANALYSIS
# ==============================================================================

cat("--- Section 4: Coverage analysis ---\n\n")

loanbook_sector_summary <- loanbook_classified %>%
  group_by(sector_classified) %>%
  summarise(total_outstanding = sum(loan_size_outstanding, na.rm = TRUE),
            .groups = "drop")

matches_sector_summary <- matched %>%
  group_by(sector) %>%
  summarise(matches_outstanding = sum(loan_size_outstanding, na.rm = TRUE),
            .groups = "drop")

sector_coverage <- loanbook_sector_summary %>%
  left_join(matches_sector_summary, by = c("sector_classified" = "sector")) %>%
  mutate(
    matches_outstanding = ifelse(is.na(matches_outstanding), 0, matches_outstanding),
    match_pct           = round(matches_outstanding / total_outstanding * 100, 1),
    total_bn_vnd        = round(total_outstanding / 1000)
  )

cat("  Coverage by sector:\n")
print(as.data.frame(sector_coverage %>%
  select(sector_classified, total_bn_vnd, match_pct) %>%
  arrange(desc(total_bn_vnd))))
cat("\n")

outstanding_total    <- sum(sector_coverage$total_outstanding)
outstanding_matched  <- sum(sector_coverage$matches_outstanding)
outstanding_not_scope <- sector_coverage %>%
  filter(sector_classified %in% c("not in scope", NA)) %>%
  pull(total_outstanding) %>% sum()

matched_pct <- round(outstanding_matched /
                     (outstanding_total - outstanding_not_scope) * 100, 1)
cat(sprintf("  In-scope portfolio matched: %.1f%%\n\n", matched_pct))

# --- Coverage Pie Chart ---
df_pie <- data.frame(
  status = c("(In Scope) Matched", "(In Scope) Not Matched", "Not in Scope"),
  amount = c(
    outstanding_matched,
    max(0, outstanding_total - outstanding_not_scope - outstanding_matched),
    outstanding_not_scope
  )
) %>%
  mutate(
    pct   = amount / sum(amount),
    label = paste0(status, "\n", percent(pct, accuracy = 0.1))
  ) %>%
  filter(amount > 0)

p_pie <- ggplot(df_pie, aes(x = "", y = amount, fill = status)) +
  geom_bar(stat = "identity", width = 1, color = "white") +
  coord_polar("y", start = 0) +
  geom_text(aes(label = label),
            position = position_stack(vjust = 0.5),
            color = "white", fontface = "bold", size = 3.2) +
  scale_fill_manual(values = c(
    "(In Scope) Matched"     = "#14645c",
    "(In Scope) Not Matched" = "#e8594b",
    "Not in Scope"           = "#9E9E9E"
  )) +
  labs(
    title    = "MCB Portfolio: PACTA Coverage",
    subtitle = paste0("Total: ", format(round(outstanding_total / 1000), big.mark = ","),
                      " bn VND | Mekong Commercial Bank 2025"),
    fill     = NULL
  ) +
  theme_void() +
  theme(
    legend.position    = "bottom",
    plot.title         = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle      = element_text(hjust = 0.5, size = 10, color = "#555555")
  )

ggsave(file.path(vn_output, "03_vn_coverage_pie.png"), p_pie,
       width = 7, height = 6, dpi = 150)
cat("  Saved: 03_vn_coverage_pie.png\n\n")

# ==============================================================================
# SECTION 5: MARKET SHARE ANALYSIS (Power + Automotive)
# Primary scenario: pdp8_ndc
# Region: "vietnam" (mapped from VN isos in region_isos)
# The sector_classified and borderline_classified columns must be removed
# before passing to target_market_share().
# ==============================================================================

cat("--- Section 5: Market share analysis ---\n\n")

matched_for_ms <- matched %>%
  select(-any_of(c("sector_classified", "borderline_classified")))

ms_portfolio <- target_market_share(
  data        = matched_for_ms,
  abcd        = abcd_norm,
  scenario    = scenario,
  region_isos = region
)

cat(sprintf("  Portfolio-level MS: %d rows | Sectors: %s\n",
            nrow(ms_portfolio), paste(unique(ms_portfolio$sector), collapse = ", ")))
cat(sprintf("  Metrics: %s\n",
            paste(unique(ms_portfolio$metric), collapse = ", ")))

ms_company <- target_market_share(
  data             = matched_for_ms,
  abcd             = abcd_norm,
  scenario         = scenario,
  region_isos      = region,
  by_company       = TRUE,
  weight_production = FALSE
)

cat(sprintf("  Company-level MS: %d rows\n", nrow(ms_company)))

write_csv(ms_portfolio, file.path(vn_output, "04_vn_ms_portfolio.csv"))
write_csv(ms_company,   file.path(vn_output, "04_vn_ms_company.csv"))

# Identify available scenario metrics for filtering
ms_metrics   <- unique(ms_portfolio$metric)
target_pdp8  <- grep("target_pdp8", ms_metrics, value = TRUE)[1]
target_steps <- grep("target_steps", ms_metrics, value = TRUE)[1]
target_nze   <- grep("target_nze",  ms_metrics, value = TRUE)[1]

cat(sprintf("\n  Available metrics: %s\n", paste(ms_metrics, collapse = ", ")))
cat(sprintf("  PDP8 target metric: %s\n\n", target_pdp8))

# --- Chart: Power Technology Mix (PDP8 scenario) ---
power_techmix_data <- ms_portfolio %>%
  filter(sector == "power", region == "vietnam",
         metric %in% c("projected", "corporate_economy", target_pdp8), scenario_source == "pdp8_2023")

if (nrow(power_techmix_data) > 0) {
  p_power_techmix <- qplot_techmix(power_techmix_data) +
    labs(
      title    = "Power Sector: Technology Mix",
      subtitle = "MCB Portfolio vs Market vs PDP8/NDC Target (Vietnam, 2025-2030)"
    ) +
    theme(text = element_text(family = "sans"))

  ggsave(file.path(vn_output, "05_vn_power_techmix.png"), p_power_techmix,
         width = 10, height = 6, dpi = 150)
  cat("  Saved: 05_vn_power_techmix.png\n")
}

# --- Chart: Coal Capacity Trajectory ---
coal_traj_data <- ms_portfolio %>%
  filter(sector == "power", technology == "coalcap", region == "vietnam", scenario_source == "pdp8_2023")

if (nrow(coal_traj_data) > 0) {
  coal_labels <- coal_traj_data %>%
    filter(year == max(year)) %>%
    rename(value = percentage_of_initial_production_by_scope)

  p_coal_traj <- qplot_trajectory(coal_traj_data) +
    ggrepel::geom_text_repel(
      aes(label = paste0(round(value * 100, 0), "%")),
      data = coal_labels, size = 3, show.legend = FALSE
    ) +
    labs(
      title    = "Power: Coal Capacity Trajectory",
      subtitle = paste0("MCB portfolio coal exposure vs PDP8 ceiling & NZE phase-down",
                        "\n(BOT plants locked to contracts; legal constraint noted)"),
      caption  = "PDP8: no new coal post-2030; JETP: peak emissions by 2030"
    ) +
    theme(text = element_text(family = "sans"))

  ggsave(file.path(vn_output, "06_vn_coal_trajectory.png"), p_coal_traj,
         width = 10, height = 6, dpi = 150)
  cat("  Saved: 06_vn_coal_trajectory.png\n")
}

# --- Chart: Renewables Buildout Trajectory ---
renew_traj_data <- ms_portfolio %>%
  filter(sector == "power", technology == "renewablescap", region == "vietnam", scenario_source == "pdp8_2023")

if (nrow(renew_traj_data) > 0) {
  renew_labels <- renew_traj_data %>%
    filter(year == max(year)) %>%
    rename(value = percentage_of_initial_production_by_scope)

  p_renew_traj <- qplot_trajectory(renew_traj_data) +
    ggrepel::geom_text_repel(
      aes(label = paste0(round(value * 100, 0), "%")),
      data = renew_labels, size = 3, show.legend = FALSE
    ) +
    labs(
      title    = "Power: Renewables Capacity Buildout",
      subtitle = "MCB solar+wind loans vs PDP8 target (74.8 GW by 2030) & NZE global"
    ) +
    theme(text = element_text(family = "sans"))

  ggsave(file.path(vn_output, "07_vn_renewables_trajectory.png"), p_renew_traj,
         width = 10, height = 6, dpi = 150)
  cat("  Saved: 07_vn_renewables_trajectory.png\n")
}

# --- Chart: Automotive Technology Mix ---
auto_techmix_data <- ms_portfolio %>%
  filter(sector == "automotive", region == "vietnam",
         metric %in% c("projected", "corporate_economy", target_pdp8), scenario_source == "pdp8_2023")

if (nrow(auto_techmix_data) > 0) {
  p_auto_techmix <- qplot_techmix(auto_techmix_data) +
    labs(
      title    = "Automotive Sector: Technology Mix",
      subtitle = "MCB auto loans (THACO/Toyota ICE vs VinFast EV) vs NDC Target 2030"
    ) +
    theme(text = element_text(family = "sans"))

  ggsave(file.path(vn_output, "08_vn_auto_techmix.png"), p_auto_techmix,
         width = 10, height = 6, dpi = 150)
  cat("  Saved: 08_vn_auto_techmix.png\n")
}

# --- Chart: EV Trajectory ---
ev_traj_data <- ms_portfolio %>%
  filter(sector == "automotive", technology == "electric", region == "vietnam", scenario_source == "pdp8_2023")

if (nrow(ev_traj_data) > 0) {
  ev_labels <- ev_traj_data %>%
    filter(year == max(year)) %>%
    rename(value = percentage_of_initial_production_by_scope)

  p_ev_traj <- qplot_trajectory(ev_traj_data) +
    ggrepel::geom_text_repel(
      aes(label = paste0(round(value * 100, 0), "%")),
      data = ev_labels, size = 3, show.legend = FALSE
    ) +
    labs(
      title    = "Automotive: Electric Vehicle Trajectory",
      subtitle = "VinFast-driven EV exposure vs NDC target (28% by 2030)"
    ) +
    theme(text = element_text(family = "sans"))

  ggsave(file.path(vn_output, "09_vn_ev_trajectory.png"), p_ev_traj,
         width = 10, height = 6, dpi = 150)
  cat("  Saved: 09_vn_ev_trajectory.png\n")
}

cat("\n")

# ==============================================================================
# SECTION 6: SDA ANALYSIS (Cement + Steel)
# ==============================================================================

cat("--- Section 6: SDA analysis (cement + steel) ---\n\n")

sda_portfolio <- target_sda(
  data                   = matched,
  abcd                   = abcd_norm,
  co2_intensity_scenario = co2,
  region_isos            = region
)

cat(sprintf("  SDA rows: %d | Sectors: %s\n",
            nrow(sda_portfolio), paste(unique(sda_portfolio$sector), collapse = ", ")))
cat(sprintf("  Metrics: %s\n", paste(unique(sda_portfolio$emission_factor_metric), collapse = ", ")))

write_csv(sda_portfolio, file.path(vn_output, "05_vn_sda_portfolio.csv"))

# Identify SDA target metric name for pdp8_ndc
sda_metrics     <- unique(sda_portfolio$emission_factor_metric)
sda_target_pdp8 <- grep("target_pdp8", sda_metrics, value = TRUE)[1]
cat(sprintf("  PDP8 SDA target metric: %s\n\n", sda_target_pdp8))

# --- Chart: Cement Emission Intensity ---
cement_sda <- sda_portfolio %>%
  filter(sector == "cement", region == "vietnam")

if (nrow(cement_sda) > 0) {
  cement_labels <- cement_sda %>%
    filter(year == max(year)) %>%
    mutate(year = as.Date(strptime(as.character(year), "%Y")))

  p_cement <- qplot_emission_intensity(cement_sda) +
    ggrepel::geom_text_repel(
      aes(label = round(emission_factor_value, 3)),
      data = cement_labels, show.legend = FALSE, size = 3
    ) +
    labs(
      title    = "Cement: Emission Intensity Trajectory",
      subtitle = paste0("tCO2/tonne | VICEM + Holcim Vietnam | PDP8/NDC conditional target:",
                        " 0.71 by 2030\n(IEA NZE target 0.54 requires CCS - not yet available in Vietnam)"),
      caption  = "Data: Synthetic MCB portfolio, PDP8 2023, IEA NZE Asia-Pacific"
    ) +
    theme(text = element_text(family = "sans"))

  ggsave(file.path(vn_output, "10_vn_cement_sda.png"), p_cement,
         width = 10, height = 6, dpi = 150)
  cat("  Saved: 10_vn_cement_sda.png\n")
}

# --- Chart: Steel Emission Intensity ---
steel_sda <- sda_portfolio %>%
  filter(sector == "steel", region == "vietnam")

if (nrow(steel_sda) > 0) {
  steel_labels <- steel_sda %>%
    filter(year == max(year)) %>%
    mutate(year = as.Date(strptime(as.character(year), "%Y")))

  p_steel <- qplot_emission_intensity(steel_sda) +
    ggrepel::geom_text_repel(
      aes(label = round(emission_factor_value, 3)),
      data = steel_labels, show.legend = FALSE, size = 3
    ) +
    labs(
      title    = "Steel: Emission Intensity Trajectory",
      subtitle = paste0("tCO2/tonne | Hoa Phat (BF/BOF, 1.85) vs Pomina (EAF, 0.58)\n",
                        "PDP8/NDC target: 1.50 by 2030 | Hoa Phat transition requires plant replacement (2040+)"),
      caption  = "Hoa Phat blast furnace route cannot achieve NZE without complete DRI-EAF conversion"
    ) +
    theme(text = element_text(family = "sans"))

  ggsave(file.path(vn_output, "11_vn_steel_sda.png"), p_steel,
         width = 10, height = 6, dpi = 150)
  cat("  Saved: 11_vn_steel_sda.png\n")
}

cat("\n")

# ==============================================================================
# SECTION 7: ALIGNMENT GAP CALCULATION (PDP8/NDC scenario)
# ==============================================================================

cat("--- Section 7: Alignment gap (vs PDP8/NDC) ---\n\n")

low_carbon_tech <- c("electric", "fuelcell", "hybrid", "renewablescap",
                     "hydrocap", "nuclearcap")

# Market share alignment at 2030 vs PDP8 target
ms_alignment_2030 <- ms_portfolio %>%
  filter(region == "vietnam", year == 2030,
         metric %in% c("projected", target_pdp8)) %>%
  select(sector, technology, metric, technology_share) %>%
  pivot_wider(names_from = metric, values_from = technology_share) %>%
  rename(projected = projected) %>%
  rename_with(~ "target_pdp8", .cols = any_of(target_pdp8)) %>%
  mutate(
    share_gap_pp  = round((projected - target_pdp8) * 100, 2),
    is_low_carbon = technology %in% low_carbon_tech,
    aligned       = case_when(
      is.na(share_gap_pp)        ~ "Data Gap",
      is_low_carbon  & share_gap_pp >= 0 ~ "Aligned",
      !is_low_carbon & share_gap_pp <= 0 ~ "Aligned",
      TRUE                       ~ "Misaligned"
    )
  )

cat("  Market share alignment at 2030 vs PDP8/NDC:\n")
print(as.data.frame(ms_alignment_2030 %>%
  select(sector, technology, projected, target_pdp8, share_gap_pp, aligned) %>%
  mutate(across(c(projected, target_pdp8), ~ round(. * 100, 1)))))

write_csv(ms_alignment_2030, file.path(vn_output, "06_vn_ms_alignment_2030.csv"))

# SDA alignment at 2030 vs PDP8 target
sda_alignment_2030 <- sda_portfolio %>%
  filter(region == "vietnam", year == 2030,
         emission_factor_metric %in% c("projected", sda_target_pdp8)) %>%
  select(sector, emission_factor_metric, emission_factor_value) %>%
  pivot_wider(names_from = emission_factor_metric,
              values_from = emission_factor_value) %>%
  rename(projected = projected) %>%
  rename_with(~ "target_pdp8", .cols = any_of(sda_target_pdp8)) %>%
  mutate(
    intensity_gap = round(projected - target_pdp8, 4),
    gap_pct       = round((projected / target_pdp8 - 1) * 100, 1),
    aligned       = ifelse(projected <= target_pdp8, "Aligned", "Misaligned")
  )

cat("\n  SDA alignment at 2030 vs PDP8/NDC:\n")
print(as.data.frame(sda_alignment_2030))

write_csv(sda_alignment_2030, file.path(vn_output, "06_vn_sda_alignment_2030.csv"))

# --- Chart: Multi-Sector Alignment Overview ---
align_plot_data <- ms_alignment_2030 %>%
  filter(!is.na(share_gap_pp)) %>%
  mutate(
    tech_label  = paste0(sector, ": ", technology),
    gap_display = share_gap_pp
  )

if (nrow(align_plot_data) > 0) {
  p_align <- ggplot(align_plot_data,
                    aes(x = reorder(tech_label, gap_display),
                        y = gap_display, fill = aligned)) +
    geom_col() +
    coord_flip() +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
    labs(
      title    = "MCB Portfolio: Alignment Gap at 2030 vs PDP8/NDC",
      subtitle = "Technology share gap: Projected minus Target (percentage points)\nPositive = above target (good for low-carbon); Negative = below target",
      x = NULL, y = "Share Gap (pp)", fill = "Alignment"
    ) +
    scale_fill_manual(values = c(
      "Aligned"    = "#27AE60",
      "Misaligned" = "#E74C3C",
      "Data Gap"   = "#BDC3C7"
    )) +
    scale_y_continuous(labels = function(x) paste0(x, "pp")) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title   = element_text(face = "bold"),
      plot.subtitle = element_text(size = 9, color = "#555555")
    )

  ggsave(file.path(vn_output, "12_vn_alignment_overview.png"), p_align,
         width = 12, height = 7, dpi = 150)
  cat("\n  Saved: 12_vn_alignment_overview.png\n")
}

# --- Chart: Coal Stranded Asset Risk ---
coal_exposure_bn <- loanbook %>%
  filter(sector_classification_direct_loantaker == "3511") %>%
  summarise(total = sum(loan_size_outstanding) / 1000) %>%
  pull(total)

coal_loans <- loanbook %>%
  filter(sector_classification_direct_loantaker %in% c("3511", "0510")) %>%
  left_join(
    tibble(
      id_ultimate_parent = c("VN_UP001","VN_UP002","VN_UP003","VN_UP004","VN_UP005"),
      is_coal_power      = c(TRUE, TRUE, TRUE, TRUE, TRUE)
    ),
    by = "id_ultimate_parent"
  ) %>%
  filter(!is.na(is_coal_power) | sector_classification_direct_loantaker == "0510") %>%
  group_by(name_ultimate_parent) %>%
  summarise(exposure_bn = sum(loan_size_outstanding) / 1000, .groups = "drop") %>%
  arrange(desc(exposure_bn))

p_stranded <- ggplot(coal_loans,
                     aes(x = reorder(name_ultimate_parent, exposure_bn),
                         y = exposure_bn, fill = "Coal & Mining")) +
  geom_col(fill = "#c0392b") +
  geom_text(aes(label = paste0(round(exposure_bn), " bn VND")),
            hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.3)),
                     labels = label_comma()) +
  labs(
    title    = "Stranded Asset Risk: Coal & Mining Exposure by Parent",
    subtitle = paste0("Total coal power + mining: ",
                      format(round(coal_exposure_bn), big.mark = ","),
                      " bn VND",
                      "\nJETP coal retirement targets early closure of 5-8 GW by 2035"),
    x = NULL, y = "Exposure (bn VND)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold"),
    legend.position = "none"
  )

ggsave(file.path(vn_output, "13_vn_coal_stranded_risk.png"), p_stranded,
       width = 11, height = 6, dpi = 150)
cat("  Saved: 13_vn_coal_stranded_risk.png\n\n")

# ==============================================================================
# SECTION 8: ENCODE CHARTS FOR HTML REPORT
# ==============================================================================

cat("--- Section 8: Encoding charts for HTML report ---\n\n")

chart_files <- list(
  coverage_pie    = "03_vn_coverage_pie.png",
  power_techmix   = "05_vn_power_techmix.png",
  coal_traj       = "06_vn_coal_trajectory.png",
  renew_traj      = "07_vn_renewables_trajectory.png",
  auto_techmix    = "08_vn_auto_techmix.png",
  ev_traj         = "09_vn_ev_trajectory.png",
  cement_sda      = "10_vn_cement_sda.png",
  steel_sda       = "11_vn_steel_sda.png",
  align_overview  = "12_vn_alignment_overview.png",
  stranded_risk   = "13_vn_coal_stranded_risk.png"
)

imgs <- list()
for (nm in names(chart_files)) {
  fp <- file.path(vn_output, chart_files[[nm]])
  if (file.exists(fp)) {
    imgs[[nm]] <- img_to_base64(fp)
    cat(sprintf("  Encoded: %s\n", chart_files[[nm]]))
  } else {
    imgs[[nm]] <- NULL
    cat(sprintf("  SKIPPED (not generated): %s\n", chart_files[[nm]]))
  }
}

# Helper: embed chart or show placeholder
chart_html <- function(key, caption = "") {
  if (!is.null(imgs[[key]])) {
    paste0(
      '<div class="chart-container">',
      '<img src="', imgs[[key]], '" alt="', caption, '">',
      if (nchar(caption) > 0)
        paste0('<div class="chart-caption">', caption, '</div>')
      else "",
      '</div>'
    )
  } else {
    paste0('<div class="chart-container" style="padding:2rem;color:#aaa;">',
           'Chart not available: ', key, '</div>')
  }
}

cat("\n")

# ==============================================================================
# SECTION 9: BUILD HTML REPORT
# ==============================================================================

cat("--- Section 9: Building Vietnam HTML report ---\n\n")

today_str      <- format(Sys.Date(), "%B %d, %Y")
n_loans        <- nrow(loanbook)
n_matched      <- nrow(matched)
n_sectors      <- n_distinct(matched$sector)
total_portfolio_bn <- round(sum(loanbook$loan_size_outstanding) / 1000)

# Compute KPI figures
coal_power_bn <- loanbook %>%
  filter(sector_classification_direct_loantaker == "3511",
         name_ultimate_parent %in% c("EVN (Electricity of Vietnam)",
                                     "Vinacomin Power JSC",
                                     "International Power Mong Duong",
                                     "PVN Power Corporation",
                                     "Nghi Son Power LLC")) %>%
  summarise(s = sum(loan_size_outstanding) / 1000) %>% pull(s)

renew_bn <- loanbook %>%
  filter(name_ultimate_parent %in% c("Trung Nam Group","BIM Group",
                                     "Thanh Thanh Cong Group","Xuan Thien Group",
                                     "T&T Group","Gia Lai Electricity JSC")) %>%
  summarise(s = sum(loan_size_outstanding) / 1000) %>% pull(s)

ev_bn <- loanbook %>%
  filter(name_ultimate_parent == "Vingroup JSC") %>%
  summarise(s = sum(loan_size_outstanding) / 1000) %>% pull(s)

pct_coal   <- round(coal_power_bn / total_portfolio_bn * 100, 1)
pct_renew  <- round(renew_bn      / total_portfolio_bn * 100, 1)
pct_ev     <- round(ev_bn         / total_portfolio_bn * 100, 1)

# Alignment summary for HTML table
ms_html_rows <- ms_alignment_2030 %>%
  filter(!is.na(share_gap_pp)) %>%
  mutate(
    proj_pct   = paste0(round(projected    * 100, 1), "%"),
    tgt_pct    = paste0(round(target_pdp8  * 100, 1), "%"),
    gap_disp   = paste0(ifelse(share_gap_pp > 0, "+", ""), share_gap_pp, " pp"),
    method     = "Market Share",
    status_html = ifelse(aligned == "Aligned",
                         '<span class="badge badge-green">Aligned</span>',
                         ifelse(aligned == "Misaligned",
                                '<span class="badge badge-red">Misaligned</span>',
                                '<span class="badge badge-gray">Data Gap</span>'))
  ) %>%
  select(Sector = sector, Technology = technology, Method = method,
         `Projected 2030` = proj_pct, `PDP8 Target 2030` = tgt_pct,
         Gap = gap_disp, Status = status_html)

sda_html_rows <- sda_alignment_2030 %>%
  mutate(
    proj_disp  = as.character(round(projected,   3)),
    tgt_disp   = as.character(round(target_pdp8, 3)),
    gap_disp   = paste0(ifelse(gap_pct > 0, "+", ""), gap_pct, "%"),
    method     = "SDA",
    tech_label = paste0(sector, " intensity"),
    status_html = ifelse(aligned == "Aligned",
                         '<span class="badge badge-green">Aligned</span>',
                         '<span class="badge badge-red">Misaligned</span>')
  ) %>%
  select(Sector = sector, Technology = tech_label, Method = method,
         `Projected 2030` = proj_disp, `PDP8 Target 2030` = tgt_disp,
         Gap = gap_disp, Status = status_html)

all_align_rows <- bind_rows(ms_html_rows, sda_html_rows)

df_to_html_table <- function(df) {
  header <- paste0("<tr>", paste0("<th>", names(df), "</th>", collapse = ""), "</tr>")
  rows <- apply(df, 1, function(row) {
    paste0("<tr>", paste0("<td>", row, "</td>", collapse = ""), "</tr>")
  })
  paste0('<table>', header, paste(rows, collapse = "\n"), '</table>')
}

alignment_table_html <- df_to_html_table(all_align_rows)

# --- Build the HTML ---
html <- paste0('<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PACTA Vietnam - Mekong Commercial Bank 2025</title>
<style>
  :root {
    --primary: #1a365d;
    --accent: #2b6cb0;
    --green: #276749;
    --red: #c53030;
    --orange: #c05621;
    --amber: #b7791f;
    --bg: #f7fafc;
    --card-bg: #ffffff;
    --border: #e2e8f0;
    --text: #2d3748;
    --text-light: #718096;
    --vietnam-red: #da251d;
    --vietnam-gold: #FFCD00;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: "Segoe UI", system-ui, sans-serif; background: var(--bg);
         color: var(--text); line-height: 1.7; }
  .hero {
    background: linear-gradient(135deg, #1a365d 0%, #c53030 60%, #276749 100%);
    color: white; padding: 3rem 2rem; text-align: center;
  }
  .hero h1 { font-size: 2rem; font-weight: 700; margin-bottom: 0.4rem; }
  .hero .subtitle { font-size: 1.05rem; opacity: 0.9; }
  .hero .bank-name { font-size: 1.3rem; font-weight: 600; margin: 0.6rem 0;
                     color: var(--vietnam-gold); }
  .hero .meta { margin-top: 1rem; font-size: 0.82rem; opacity: 0.75; }
  .hero .badge-vn {
    display: inline-block; margin-top: 0.6rem; padding: 0.25rem 0.9rem;
    background: rgba(255,255,255,0.2); border-radius: 20px; font-size: 0.82rem;
  }
  .container { max-width: 1000px; margin: 0 auto; padding: 2rem 1.5rem; }
  .toc { background: #f7fafc; border: 1px solid var(--border); border-radius: 8px;
         padding: 1.2rem 1.5rem; margin-bottom: 2rem; }
  .toc h3 { margin-bottom: 0.5rem; font-size: 1rem; color: var(--primary); }
  .toc ol { padding-left: 1.4rem; }
  .toc li { margin: 0.25rem 0; }
  .toc a { color: var(--accent); text-decoration: none; }
  .toc a:hover { text-decoration: underline; }
  .exec-summary {
    background: var(--card-bg); border-left: 4px solid var(--vietnam-red);
    border-radius: 0 8px 8px 0; padding: 1.8rem 2rem; margin-bottom: 2.5rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  .exec-summary h2 { color: var(--vietnam-red); font-size: 1.3rem; margin-bottom: 1rem; }
  .section {
    background: var(--card-bg); border-radius: 8px; padding: 2rem;
    margin-bottom: 2rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  .section h2 { color: var(--primary); font-size: 1.4rem; margin-bottom: 0.3rem;
                padding-bottom: 0.6rem; border-bottom: 2px solid var(--border); }
  .section h3 { color: var(--accent); font-size: 1.1rem; margin: 1.5rem 0 0.5rem 0; }
  .section p { margin: 0.7rem 0; }
  .chart-container {
    text-align: center; margin: 1.5rem 0; padding: 1rem;
    background: #f8fafc; border-radius: 6px; border: 1px solid var(--border);
  }
  .chart-container img { max-width: 100%; height: auto; border-radius: 4px; }
  .chart-caption { font-size: 0.8rem; color: var(--text-light); margin-top: 0.5rem; font-style: italic; }
  .two-charts { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin: 1.5rem 0; }
  @media (max-width: 768px) { .two-charts { grid-template-columns: 1fr; } }
  .two-charts .chart-container { margin: 0; }
  table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: 0.87rem; }
  th { background: var(--primary); color: white; padding: 0.65rem 0.8rem;
       text-align: left; font-weight: 600; }
  td { padding: 0.55rem 0.8rem; border-bottom: 1px solid var(--border); }
  tr:nth-child(even) { background: #f7fafc; }
  tr:hover { background: #edf2f7; }
  .badge { display: inline-block; padding: 0.15rem 0.6rem; border-radius: 12px;
           font-size: 0.73rem; font-weight: 600; text-transform: uppercase; }
  .badge-red   { background: #fed7d7; color: var(--red); }
  .badge-green { background: #c6f6d5; color: var(--green); }
  .badge-amber { background: #fefcbf; color: var(--amber); }
  .badge-gray  { background: #e2e8f0; color: #4a5568; }
  .callout { padding: 1rem 1.2rem; border-radius: 6px; margin: 1rem 0; font-size: 0.9rem; }
  .callout-warning { background: #fffbeb; border-left: 4px solid var(--orange); }
  .callout-info    { background: #ebf8ff; border-left: 4px solid var(--accent); }
  .callout-danger  { background: #fff5f5; border-left: 4px solid var(--red); }
  .callout-success { background: #f0fff4; border-left: 4px solid var(--green); }
  .kpi-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
             gap: 1rem; margin: 1.5rem 0; }
  .kpi-card { background: #f7fafc; border: 1px solid var(--border); border-radius: 8px;
              padding: 1.2rem; text-align: center; }
  .kpi-card .value { font-size: 1.8rem; font-weight: 700; color: var(--primary); }
  .kpi-card .label { font-size: 0.78rem; color: var(--text-light); margin-top: 0.3rem; }
  .risk-table td:last-child { text-align: center; }
  .footer { text-align: center; padding: 2rem; color: var(--text-light);
            font-size: 0.78rem; border-top: 1px solid var(--border); margin-top: 2rem; }
  ul, ol { padding-left: 1.5rem; margin: 0.5rem 0; }
  li { margin: 0.3rem 0; }
  code { background: #edf2f7; padding: 0.1rem 0.4rem; border-radius: 3px; font-size: 0.86rem; }
  strong { color: var(--primary); }
</style>
</head>
<body>

<!-- HERO -->
<div class="hero">
  <h1>PACTA Portfolio Alignment Report</h1>
  <div class="subtitle">Paris Agreement Capital Transition Assessment</div>
  <div class="bank-name">Mekong Commercial Bank (MCB) &mdash; Vietnam</div>
  <div class="badge-vn">Scenario: PDP8 2023 / Vietnam NDC / IEA NZE Global</div>
  <div class="meta">Generated: ', today_str, ' &nbsp;|&nbsp;
    Framework: r2dii / pacta.loanbook &nbsp;|&nbsp;
    Base year: 2025 &nbsp;|&nbsp; Horizon: 2025&ndash;2030</div>
</div>

<div class="container">

<!-- TOC -->
<div class="toc">
  <h3>Table of Contents</h3>
  <ol>
    <li><a href="#exec">Tóm tắt điều hành (Executive Summary)</a></li>
    <li><a href="#methodology">Phương pháp PACTA (Methodology)</a></li>
    <li><a href="#portfolio">Danh mục cho vay MCB (MCB Loanbook)</a></li>
    <li><a href="#power">Ngành điện (Power Sector)</a></li>
    <li><a href="#automotive">Ngành ô tô (Automotive)</a></li>
    <li><a href="#cement">Xi măng (Cement)</a></li>
    <li><a href="#steel">Thép (Steel)</a></li>
    <li><a href="#alignment">Tổng quan căn chỉnh (Alignment Summary)</a></li>
    <li><a href="#risk">Rủi ro tài sản mắc kẹt (Stranded Asset Risk)</a></li>
    <li><a href="#recommendations">Khuyến nghị (Recommendations)</a></li>
  </ol>
</div>

<!-- EXECUTIVE SUMMARY -->
<div class="exec-summary" id="exec">
  <h2>1. Tóm tắt điều hành (Executive Summary)</h2>
  <p>
    Phân tích PACTA này đánh giá danh mục cho vay ', format(total_portfolio_bn, big.mark = ","), ' tỷ VND
    (~$', round(total_portfolio_bn / 25000, 1), ' tỷ USD) của Mekong Commercial Bank đối với
    <strong>Quy hoạch Điện 8 (PDP8)</strong>, cam kết NDC 2022 của Việt Nam, và kịch bản
    Net Zero 2050 toàn cầu của IEA.
  </p>
  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value">', format(total_portfolio_bn, big.mark = ","), '</div>
      <div class="label">bn VND<br>Tổng danh mục PACTA</div>
    </div>
    <div class="kpi-card">
      <div class="value">', n_loans, '</div>
      <div class="label">Khoản vay<br>Số lượng khoản vay</div>
    </div>
    <div class="kpi-card">
      <div class="value">', n_matched, '</div>
      <div class="label">Khớp với ABCD<br>Đã ghép ABCD</div>
    </div>
    <div class="kpi-card">
      <div class="value">', pct_coal, '%</div>
      <div class="label">Rủi ro than<br>Tỷ trọng điện than</div>
    </div>
    <div class="kpi-card">
      <div class="value">', pct_renew, '%</div>
      <div class="label">NLTT xanh<br>Tỷ trọng tái tạo</div>
    </div>
    <div class="kpi-card">
      <div class="value">', pct_ev, '%</div>
      <div class="label">Xe điện (EV)<br>Tỷ trọng VinFast</div>
    </div>
  </div>
  <div class="callout callout-danger">
    <strong>Phát hiện chính (Key Finding):</strong>
    Danh mục MCB <strong>không đồng thuận với Paris</strong> theo kịch bản IEA NZE.
    Rủi ro cao nhất: khoản vay điện than (~', format(round(coal_power_bn), big.mark = ","), ' tỷ VND)
    đối mặt với rủi ro tài sản mắc kẹt trong 10&ndash;15 năm do lộ trình JETP và PDP8
    cắt giảm than. Cơ hội tích cực: danh mục năng lượng tái tạo và VinFast đang đi đúng hướng.
  </div>
  <div class="callout callout-info">
    <strong>Khuyến nghị ngay (Immediate Actions):</strong>
    (1) Áp dụng tiêu chí phân loại tín dụng xanh theo hướng dẫn Ngân hàng Nhà nước (SBV);
    (2) Yêu cầu lộ trình chuyển đổi khí hậu từ THACO và Hoa Phat trước khi tái cấp vốn;
    (3) Mở rộng danh mục NLTT từ ', pct_renew, '% lên 15&ndash;20% vào năm 2030.
  </div>
</div>

<!-- METHODOLOGY -->
<div class="section" id="methodology">
  <h2>2. Phương pháp luận PACTA (Methodology)</h2>
  <p>
    <strong>PACTA (Paris Agreement Capital Transition Assessment)</strong> là phương pháp
    đo lường sự phù hợp của danh mục cho vay với các mục tiêu khí hậu.
    Phương pháp này được phát triển bởi 2&deg; Investing Initiative (2DII) và được sử dụng
    bởi hơn 6.000 tổ chức tài chính toàn cầu.
  </p>
  <h3>Hai phương pháp đo lường</h3>
  <ul>
    <li><strong>Phương pháp thị phần (Market Share):</strong> Áp dụng cho ngành điện và ô tô.
        So sánh tỷ trọng công nghệ trong danh mục cho vay với mục tiêu kịch bản.</li>
    <li><strong>Phương pháp SDA (Sectoral Decarbonization Approach):</strong> Áp dụng cho xi măng
        và thép. So sánh cường độ phát thải CO₂ (tCO₂/tấn sản phẩm) với lộ trình mục tiêu.</li>
  </ul>
  <h3>Ba kịch bản so sánh</h3>
  <table>
    <tr><th>Kịch bản</th><th>Nguồn</th><th>Mô tả</th><th>Phù hợp với</th></tr>
    <tr><td><strong>STEPS / BAU</strong></td><td>IEA-phong cách</td>
        <td>Chính sách hiện tại, không có hành động khí hậu mới</td>
        <td>Mức cơ sở tham chiếu</td></tr>
    <tr><td><strong>PDP8/NDC</strong></td><td>Quyết định 500/QĐ-TTg 2023 + NDC 2022</td>
        <td>Kế hoạch chính thức của Việt Nam; lộ trình than + NLTT đến 2030</td>
        <td>Chuẩn mực quốc gia</td></tr>
    <tr><td><strong>NZE Global</strong></td><td>IEA Net Zero 2050</td>
        <td>Net zero toàn cầu vào 2050; tiêu chuẩn tham vọng nhất</td>
        <td>Chuẩn mực quốc tế</td></tr>
  </table>
  <div class="callout callout-info">
    <strong>Lưu ý về dữ liệu:</strong> Tất cả dữ liệu loanbook và ABCD trong báo cáo này là
    <em>tổng hợp nhân tạo</em> (synthetic) để minh họa phương pháp. Dữ liệu thực tế cần lấy
    từ hệ thống quản lý tín dụng của ngân hàng và cơ sở dữ liệu tài sản đã kiểm định.
  </div>
</div>

<!-- PORTFOLIO -->
<div class="section" id="portfolio">
  <h2>3. Danh mục cho vay MCB (MCB Loanbook Overview)</h2>
  <p>
    Mekong Commercial Bank (MCB) là ngân hàng thương mại cỡ vừa-lớn của Việt Nam
    (tổng tài sản ~500.000 tỷ VND, tương đương MB Bank hoặc Techcombank).
    Danh mục phân tích PACTA gồm <strong>', n_loans, ' khoản vay</strong> trong
    các lĩnh vực kinh tế thực có liên quan đến khí hậu.
  </p>
  <div class="two-charts">
    ', chart_html("coverage_pie", "Phân bổ danh mục: PACTA coverage vs ngoài phạm vi"), '
  </div>
  <h3>Phân bổ danh mục theo lĩnh vực</h3>
  <table>
    <tr>
      <th>Lĩnh vực</th><th>Số khoản vay</th>
      <th>Dư nợ (tỷ VND)</th><th>% Danh mục</th><th>Rủi ro khí hậu</th>
    </tr>
    <tr><td>Điện - Than</td><td>11</td><td>7,020</td><td>28%</td>
        <td><span class="badge badge-red">Cao</span></td></tr>
    <tr><td>Ô tô - ICE</td><td>4</td><td>3,250</td><td>13%</td>
        <td><span class="badge badge-amber">Trung bình</span></td></tr>
    <tr><td>Điện - Khí</td><td>5</td><td>3,000</td><td>12%</td>
        <td><span class="badge badge-amber">Trung bình</span></td></tr>
    <tr><td>Điện - Thủy điện</td><td>6</td><td>2,500</td><td>10%</td>
        <td><span class="badge badge-green">Thấp</span></td></tr>
    <tr><td>Xi măng</td><td>3</td><td>2,000</td><td>8%</td>
        <td><span class="badge badge-amber">Trung bình</span></td></tr>
    <tr><td>Điện - Mặt trời</td><td>4</td><td>2,000</td><td>8%</td>
        <td><span class="badge badge-green">Thấp</span></td></tr>
    <tr><td>Thép</td><td>2</td><td>1,500</td><td>6%</td>
        <td><span class="badge badge-red">Cao</span></td></tr>
    <tr><td>Khai thác than</td><td>2</td><td>1,250</td><td>5%</td>
        <td><span class="badge badge-red">Cao</span></td></tr>
    <tr><td>Điện - Gió</td><td>3</td><td>1,250</td><td>5%</td>
        <td><span class="badge badge-green">Thấp</span></td></tr>
    <tr><td>Ô tô - EV</td><td>2</td><td>1,000</td><td>4%</td>
        <td><span class="badge badge-green">Thấp</span></td></tr>
    <tr><td>Ô tô - Hybrid</td><td>1</td><td>250</td><td>1%</td>
        <td><span class="badge badge-green">Thấp</span></td></tr>
    <tr style="font-weight:bold; background:#edf2f7;">
        <td>Tổng cộng</td><td>', n_loans, '</td>
        <td>', format(total_portfolio_bn, big.mark = ","), '</td>
        <td>100%</td><td></td></tr>
  </table>
</div>

<!-- POWER SECTOR -->
<div class="section" id="power">
  <h2>4. Phân tích ngành điện (Power Sector)</h2>
  <p>
    Ngành điện chiếm <strong>63% danh mục MCB</strong> (15,750 tỷ VND).
    Đây là lĩnh vực quan trọng nhất trong phân tích vì Việt Nam đang trong quá trình
    chuyển đổi năng lượng sâu sắc theo PDP8 và cam kết JETP.
  </p>
  <div class="callout callout-warning">
    <strong>Bối cảnh PDP8:</strong> Quyết định 500/QĐ-TTg (5/2023) quy định: không có nhà máy điện than
    mới sau 2030; than giảm xuống 26% công suất vào 2030; tái tạo (mặt trời + gió) đạt 74,8 GW vào 2030.
    JETP cam kết đỉnh phát thải điện năm 2030 và than dưới 30%.
  </div>
  <h3>Cơ cấu công nghệ điện</h3>
  ', chart_html("power_techmix", "Cơ cấu công nghệ điện: MCB vs PDP8 target (2025-2030)"), '
  <h3>Lộ trình điện than</h3>
  ', chart_html("coal_traj", "Lộ trình công suất điện than: MCB portfolio vs PDP8 và NZE"), '
  <div class="callout callout-danger">
    <strong>Rủi ro than:</strong> MCB có ', format(round(coal_power_bn), big.mark = ","), ' tỷ VND
    cho vay điện than. Các nhà máy BOT (Nghi Son 2, Mong Duong 2) bị khóa bởi hợp đồng PPA đến ~2035,
    khiến việc nghỉ hưu sớm phụ thuộc vào gói mua lại chính phủ trong JETP.
    Rủi ro NPL ước tính: nếu 20% danh mục than bị suy giảm &rarr; ~1,400 tỷ VND tổn thất tiềm năng.
  </div>
  <h3>Lộ trình năng lượng tái tạo</h3>
  ', chart_html("renew_traj", "Năng lượng tái tạo: MCB portfolio (Trung Nam, BIM, TTC, Xuan Thien, T&T) vs PDP8"), '
  <div class="callout callout-success">
    <strong>Cơ hội tích cực:</strong> ', format(round(renew_bn), big.mark = ","), ' tỷ VND
    cho vay tái tạo của MCB (mặt trời + gió) đang phù hợp với PDP8.
    Đây là tài sản chất lượng tốt trong danh mục khí hậu.
  </div>
</div>

<!-- AUTOMOTIVE -->
<div class="section" id="automotive">
  <h2>5. Phân tích ngành ô tô (Automotive Sector)</h2>
  <p>
    MCB có ', format(4500, big.mark = ","), ' tỷ VND cho vay ô tô (4,500 tỷ VND),
    trong đó THACO chiếm tỷ trọng lớn nhất (1,200 tỷ VND, 100% ICE).
    VinFast (EV 100%) chỉ chiếm 4% danh mục nhưng đại diện cho hướng tăng trưởng tương lai.
  </p>
  <div class="callout callout-warning">
    <strong>Bối cảnh NDC:</strong> Việt Nam cam kết 100% xe điện mới vào năm 2040;
    50% xe buýt đô thị điện vào 2030. Mục tiêu EV 2030 theo PDP8/NDC: 28% thị phần xe mới.
    Thị trường hiện tại: ~2% EV (toàn bộ là VinFast).
  </div>
  <div class="two-charts">
    ', chart_html("auto_techmix", "Cơ cấu công nghệ ô tô: MCB vs NDC target"), '
    ', chart_html("ev_traj", "Lộ trình xe điện EV: VinFast-driven vs NDC target"), '
  </div>
  <div class="callout callout-danger">
    <strong>Khoảng cách căn chỉnh EV:</strong> MCB dự kiến đạt ~10% EV theo trọng số vốn vay vào 2030,
    so với mục tiêu NDC 28%. Khoảng cách ~18 điểm phần trăm là rủi ro cao.
    THACO (1,200 tỷ VND, 100% ICE) là đối tác cần ưu tiên tiếp cận về chiến lược điện hóa.
  </div>
</div>

<!-- CEMENT -->
<div class="section" id="cement">
  <h2>6. Phân tích xi măng (Cement Sector)</h2>
  <p>
    Việt Nam là nước xuất khẩu xi măng lớn thứ 3 thế giới.
    MCB có ', 2000, ' tỷ VND cho vay xi măng (VICEM 1,200 tỷ + Holcim 800 tỷ).
    Cường độ phát thải trung bình: 0.82 tCO₂/tấn xi măng (cao hơn mức trung bình toàn cầu 0.60).
  </p>
  ', chart_html("cement_sda", "Xi măng: Lộ trình cường độ phát thải CO₂ (SDA Method)"), '
  <div class="callout callout-warning">
    <strong>Phân tích SDA:</strong> Danh mục xi măng MCB dự kiến đạt ~0.74 tCO₂/tấn vào 2030,
    so với mục tiêu NDC conditional 0.71 (khoảng cách nhỏ ~0.03).
    Mục tiêu NZE toàn cầu 0.54 đòi hỏi CCS và nhiên liệu thay thế, chưa có sẵn ở Việt Nam.
    Mức độ căn chỉnh: <span class="badge badge-amber">Biên giới (Borderline)</span>.
  </div>
</div>

<!-- STEEL -->
<div class="section" id="steel">
  <h2>7. Phân tích thép (Steel Sector)</h2>
  <p>
    MCB có 1,500 tỷ VND cho vay thép gồm hai doanh nghiệp với công nghệ rất khác nhau:
    <strong>Hoa Phát</strong> (lò cao/BOF, cường độ cao) và
    <strong>Pomina</strong> (lò điện hồ quang EAF, cường độ thấp).
    Phân tích này cho thấy sự khác biệt về rủi ro trong cùng một lĩnh vực.
  </p>
  ', chart_html("steel_sda", "Thép: Cường độ phát thải CO₂ theo phương pháp SDA"), '
  <div class="callout callout-danger">
    <strong>Hoa Phát - Rủi ro cao:</strong> Lò cao/BOF của Hoa Phát: 1.85 tCO₂/tấn.
    Mục tiêu NDC 2030: 1.50 (khoảng cách 0.35). Không có kế hoạch chuyển đổi DRI-EAF
    trong 5 năm tới. Việc đạt NZE đòi hỏi thay thế toàn bộ nhà máy (2040+).
  </div>
  <div class="callout callout-success">
    <strong>Pomina - Phù hợp:</strong> EAF của Pomina: 0.58 tCO₂/tấn.
    Đã phù hợp với mục tiêu NZE 2030. Minh họa rằng chất lượng danh mục thép
    phụ thuộc nhiều vào công nghệ luyện thép cụ thể.
  </div>
</div>

<!-- ALIGNMENT SUMMARY -->
<div class="section" id="alignment">
  <h2>8. Tổng quan căn chỉnh (Alignment Summary)</h2>
  <p>
    Bảng tổng hợp kết quả căn chỉnh danh mục MCB đối với kịch bản PDP8/NDC Việt Nam tại năm 2030.
    Phân tích dựa trên <strong>phương pháp thị phần</strong> (ngành điện, ô tô) và
    <strong>phương pháp SDA</strong> (xi măng, thép).
  </p>
  ', alignment_table_html, '
  ', chart_html("align_overview", "Khoảng cách căn chỉnh theo lĩnh vực vs PDP8/NDC tại 2030"), '
  <h3>Bảng tín hiệu giao thông (Traffic Light Summary)</h3>
  <table class="risk-table">
    <tr><th>Lĩnh vực</th><th>Công nghệ</th>
        <th>vs PDP8/NDC</th><th>vs IEA NZE</th><th>Mức rủi ro</th></tr>
    <tr><td>Điện</td><td>Than (coalcap)</td>
        <td><span class="badge badge-red">Lệch (Too High)</span></td>
        <td><span class="badge badge-red">Nghiêm trọng</span></td>
        <td><span class="badge badge-red">CAO</span></td></tr>
    <tr><td>Điện</td><td>Tái tạo (renewablescap)</td>
        <td><span class="badge badge-amber">Biên giới</span></td>
        <td><span class="badge badge-red">Lệch</span></td>
        <td><span class="badge badge-amber">TRUNG BÌNH</span></td></tr>
    <tr><td>Điện</td><td>Khí (gascap)</td>
        <td><span class="badge badge-green">Phù hợp</span></td>
        <td><span class="badge badge-amber">Biên giới</span></td>
        <td><span class="badge badge-green">THẤP</span></td></tr>
    <tr><td>Ô tô</td><td>EV (electric)</td>
        <td><span class="badge badge-red">Lệch (Too Low)</span></td>
        <td><span class="badge badge-red">Nghiêm trọng</span></td>
        <td><span class="badge badge-red">CAO</span></td></tr>
    <tr><td>Ô tô</td><td>ICE</td>
        <td><span class="badge badge-red">Lệch (Too High)</span></td>
        <td><span class="badge badge-red">Nghiêm trọng</span></td>
        <td><span class="badge badge-red">CAO</span></td></tr>
    <tr><td>Xi măng</td><td>intensity</td>
        <td><span class="badge badge-amber">Biên giới</span></td>
        <td><span class="badge badge-red">Lệch</span></td>
        <td><span class="badge badge-amber">TRUNG BÌNH</span></td></tr>
    <tr><td>Thép</td><td>intensity</td>
        <td><span class="badge badge-red">Lệch</span></td>
        <td><span class="badge badge-red">Nghiêm trọng</span></td>
        <td><span class="badge badge-red">CAO</span></td></tr>
  </table>
</div>

<!-- STRANDED ASSET RISK -->
<div class="section" id="risk">
  <h2>9. Rủi ro tài sản mắc kẹt (Stranded Asset Risk)</h2>
  <p>
    JETP và lộ trình PDP8 tạo ra rủi ro tài sản mắc kẹt đáng kể đối với danh mục than của MCB.
    Cơ chế nghỉ hưu than (Coal Retirement Mechanism) nhắm vào 5&ndash;8 GW than
    đóng cửa sớm vào năm 2035.
  </p>
  ', chart_html("stranded_risk", "Phơi nhiễm than và khai thác theo nhóm mẹ (tỷ VND)"), '
  <table>
    <tr><th>Kịch bản rủi ro</th><th>Giả định</th><th>Tổn thất tiềm năng (tỷ VND)</th></tr>
    <tr><td>Cơ sở (Base)</td><td>10% danh mục than bị suy giảm</td>
        <td>', format(round(coal_power_bn * 0.10), big.mark = ","), '</td></tr>
    <tr><td>Bất lợi (Adverse)</td><td>20% danh mục than bị suy giảm</td>
        <td>', format(round(coal_power_bn * 0.20), big.mark = ","), '</td></tr>
    <tr><td>Nghiêm trọng (Severe)</td><td>35% danh mục than bị suy giảm (JETP accel.)</td>
        <td>', format(round(coal_power_bn * 0.35), big.mark = ","), '</td></tr>
  </table>
  <div class="callout callout-warning">
    <strong>BOT Lock-in:</strong> Nhà máy Nghi Son 2 (Marubeni/KEPCO) và Mong Duong 2
    (International Power) có hợp đồng PPA đảm bảo thanh toán công suất đến ~2035.
    Nghỉ hưu sớm đòi hỏi gói mua lại từ chính phủ &mdash; chi phí ước tính
    200&ndash;400 triệu USD/nhà máy. Điều này làm phức tạp phân tích căn chỉnh vì
    công suất than không thể giảm trước ngày hết hạn PPA.
  </div>
</div>

<!-- RECOMMENDATIONS -->
<div class="section" id="recommendations">
  <h2>10. Khuyến nghị hành động (Recommendations)</h2>

  <h3>Ngắn hạn (2025&ndash;2026): Quản lý rủi ro</h3>
  <ul>
    <li>Thiết lập <strong>hạn mức than</strong>: không tăng danh mục điện than vượt ',
    format(round(coal_power_bn), big.mark = ","), ' tỷ VND hiện tại.</li>
    <li>Yêu cầu <strong>kế hoạch chuyển đổi khí hậu</strong> từ THACO, Hoa Phát,
        và VICEM trước khi tái cấp vốn (vay mới hoặc rollover).</li>
    <li>Áp dụng <strong>Hướng dẫn tín dụng xanh SBV</strong> (Khung tín dụng xanh 2023)
        vào quy trình phê duyệt tín dụng cho 5 lĩnh vực PACTA.</li>
    <li>Xây dựng <strong>bảng theo dõi căn chỉnh</strong>: cập nhật hàng quý với dữ liệu
        ABCD mới từ báo cáo thường niên EVN, VAMA, VICEM, Hoa Phát.</li>
  </ul>

  <h3>Trung hạn (2027&ndash;2030): Tái cân bằng danh mục</h3>
  <ul>
    <li>Mở rộng <strong>tín dụng xanh</strong>: mục tiêu NLTT từ ',
    pct_renew, '% lên 15&ndash;20% danh mục. Ưu tiên gió ngoài khơi (PDP8: 6 GW đến 2030).</li>
    <li>Tăng <strong>cho vay VinFast và chuỗi cung ứng EV</strong>:
        nhà cung cấp pin, trạm sạc, linh kiện điện tử.</li>
    <li>Hợp tác <strong>JETP</strong>: tham gia Cơ chế nghỉ hưu than như bên cho vay
        trong các gói tái cấu trúc tài chính cho EVN và Vinacomin Power.</li>
    <li>Phát triển <strong>sản phẩm tài chính bền vững</strong>:
        trái phiếu xanh (green bond), cho vay liên kết bền vững (SLL) cho THACO/Toyota VN.</li>
  </ul>

  <h3>Dài hạn (2030+): Định vị chiến lược</h3>
  <ul>
    <li>Trở thành <strong>ngân hàng xanh hàng đầu Việt Nam</strong> với 25&ndash;30%
        danh mục tài sản khí hậu vào 2035.</li>
    <li>Tích hợp <strong>phân tích PACTA vào ICAAP</strong>
        (Internal Capital Adequacy Assessment Process) và báo cáo TCFD.</li>
    <li>Xây dựng <strong>cơ sở dữ liệu ABCD nội bộ</strong> từ báo cáo thường niên
        của khách hàng &mdash; không phụ thuộc vào dữ liệu toàn cầu.</li>
  </ul>
</div>

<!-- FOOTER -->
<div class="footer">
  <p>
    <strong>PACTA Vietnam Report &mdash; Mekong Commercial Bank (Synthetic / Illustrative)</strong><br>
    Framework: r2dii.analysis / r2dii.match / r2dii.plot / pacta.loanbook &nbsp;|&nbsp;
    Scenario: PDP8 Decision 500/Q\u0110-TTg (2023), Vietnam NDC 2022, IEA NZE 2050<br>
    Generated: ', today_str, ' &nbsp;|&nbsp;
    <em>All data is synthetic for methodology demonstration. Not for investment decisions.</em>
  </p>
</div>

</div><!-- .container -->
</body>
</html>')

# Write HTML report
report_path <- file.path(report_dir, "PACTA_Vietnam_Bank_Report.html")
writeLines(html, report_path)
cat(sprintf("  HTML report saved: %s\n\n", report_path))

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================

cat("========================================\n")
cat("PACTA Vietnam pipeline complete\n")
cat("========================================\n\n")
cat(sprintf("  Loanbook analysed : %d loans / %s bn VND\n",
            n_loans, format(total_portfolio_bn, big.mark = ",")))
cat(sprintf("  Matched to ABCD   : %d loans (%.1f%%)\n",
            n_matched, n_matched / n_loans * 100))
cat(sprintf("  Sectors analysed  : %s\n",
            paste(unique(matched$sector), collapse = ", ")))
cat(sprintf("  Output directory  : %s\n", vn_output))
cat(sprintf("  HTML report       : %s\n\n", report_path))

cat("Key alignment findings (vs PDP8/NDC at 2030):\n")
if (nrow(ms_alignment_2030) > 0) {
  ms_alignment_2030 %>%
    mutate(
      proj_pct = round(projected * 100, 1),
      tgt_pct  = round(target_pdp8 * 100, 1)
    ) %>%
    select(sector, technology, proj_pct, tgt_pct, share_gap_pp, aligned) %>%
    arrange(sector, technology) %>%
    as.data.frame() %>%
    print()
}
cat("\nSDA alignment (vs PDP8/NDC at 2030):\n")
if (nrow(sda_alignment_2030) > 0) {
  print(as.data.frame(sda_alignment_2030 %>%
    select(sector, projected, target_pdp8, intensity_gap, aligned)))
}
cat("\nDone.\n")
