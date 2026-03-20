# ==============================================================================
# generate_vietnam_data.R
# Generates all synthetic Vietnam PACTA input data for Mekong Commercial Bank
#
# Outputs (written to data/):
#   vietnam_loanbook.csv       - 43-loan synthetic MCB loanbook
#   vietnam_abcd.csv           - Asset-based company data (~192 rows)
#   vietnam_scenario_ms.csv    - Market share scenario (power + automotive)
#   vietnam_scenario_co2.csv   - CO2 intensity scenario (cement + steel)
#   vietnam_region_isos.csv    - VN country-region mapping
#
# Run from project root:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" data/generate_vietnam_data.R
# ==============================================================================

library(dplyr)
library(readr)
library(tidyr)

dir.create("data", showWarnings = FALSE)

cat("==============================================\n")
cat("Generating Vietnam synthetic PACTA datasets\n")
cat("==============================================\n\n")

# ==============================================================================
# SECTION A: LOANBOOK (43 loans for Mekong Commercial Bank)
# All loan_size values in VND millions.
# 25,000 bn VND total = 25,000,000 mn VND portfolio.
# credit_limit = outstanding * 1.2 (synthetic).
# sector_classification_system = "ISIC" (VSIC 2018 is structurally ISIC Rev.4).
# ==============================================================================

cat("--- A: Building loanbook ---\n")

# ISIC Rev.4 codes with letter-section prefix, as used in r2dii.data::sector_classifications:
#   D3511 = electricity generation (power)
#   C2910 = manufacture of motor vehicles (automotive)
#   C2394 = manufacture of cement (cement)
#   C2410 = manufacture of basic iron and steel (steel)
#   B0510 = mining of hard coal (coal)
# ISIC Rev.4 code → PACTA sector lookup (letter-prefixed, r2dii.data format)
isic_power      <- "D3511"   # electricity generation
isic_automotive <- "C2910"   # manufacture of motor vehicles
isic_cement     <- "C2394"   # manufacture of cement
isic_steel      <- "C2410"   # manufacture of basic iron and steel
isic_coal       <- "B0510"   # mining of hard coal

make_loan <- function(id_loan, id_dt, name_dt, id_up, name_up, outstanding, isic_code,
                      lei = NA_character_, isin = NA_character_) {
  tibble(
    id_loan                              = id_loan,
    id_direct_loantaker                  = id_dt,
    name_direct_loantaker                = name_dt,
    id_ultimate_parent                   = id_up,
    name_ultimate_parent                 = name_up,
    loan_size_outstanding                = outstanding,
    loan_size_outstanding_currency       = "VND",
    loan_size_credit_limit               = round(outstanding * 1.2),
    loan_size_credit_limit_currency      = "VND",
    sector_classification_system         = "ISIC",
    sector_classification_direct_loantaker = as.character(isic_code),
    lei_direct_loantaker                 = lei,
    isin_direct_loantaker                = isin
  )
}

vietnam_loanbook <- bind_rows(

  # --- Power - Coal (11 loans, ~7,020 bn VND) ---
  make_loan("VN_L001","VN_C001","Nhiet Dien Vinh Tan 1 JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",800000,isic_power),
  make_loan("VN_L002","VN_C002","Nhiet Dien Vinh Tan 4 JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",650000,isic_power),
  make_loan("VN_L003","VN_C003","Nhiet Dien Duyen Hai 1 JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",720000,isic_power),
  make_loan("VN_L004","VN_C004","Nhiet Dien Duyen Hai 3 JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",540000,isic_power),
  make_loan("VN_L005","VN_C005","Nhiet Dien Mong Duong 1 JSC",
            "VN_UP002","Vinacomin Power JSC",480000,isic_power),
  make_loan("VN_L006","VN_C006","Nhiet Dien Mong Duong 2 LLC",
            "VN_UP003","International Power Mong Duong",620000,isic_power),
  make_loan("VN_L007","VN_C007","Nhiet Dien Uong Bi JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",380000,isic_power),
  make_loan("VN_L008","VN_C008","Nhiet Dien Cam Pha JSC",
            "VN_UP002","Vinacomin Power JSC",430000,isic_power),
  make_loan("VN_L009","VN_C009","Nhiet Dien Vung Ang 1 JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",590000,isic_power),
  make_loan("VN_L010","VN_C010","Nhiet Dien Thai Binh 2 JSC",
            "VN_UP004","PVN Power Corporation",780000,isic_power),
  make_loan("VN_L011","VN_C011","Nhiet Dien Nghi Son 2 LLC",
            "VN_UP005","Nghi Son Power LLC",1030000,isic_power),

  # --- Power - Gas (5 loans, ~3,000 bn VND) ---
  make_loan("VN_L012","VN_C012","PV Power Ca Mau JSC",
            "VN_UP004","PVN Power Corporation",520000,isic_power),
  make_loan("VN_L013","VN_C013","PV Power Nhon Trach 1 JSC",
            "VN_UP004","PVN Power Corporation",480000,isic_power),
  make_loan("VN_L014","VN_C014","PV Power Nhon Trach 3-4 JSC",
            "VN_UP004","PVN Power Corporation",750000,isic_power),
  make_loan("VN_L015","VN_C015","Dung Quat LNG Power JSC",
            "VN_UP006","Dung Quat LNG Power Consortium",680000,isic_power),
  make_loan("VN_L016","VN_C016","EVN Phu My Gas Power JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",570000,isic_power),

  # --- Power - Hydro (6 loans, ~2,500 bn VND) ---
  make_loan("VN_L017","VN_C017","EVN Hydro Song Ba Ha JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",350000,isic_power),
  make_loan("VN_L018","VN_C018","EVN Hydro Tri An JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",420000,isic_power),
  make_loan("VN_L019","VN_C019","Dak Drinh Hydro Power JSC",
            "VN_UP007","Vietnam Hydropower JSC",380000,isic_power),
  make_loan("VN_L020","VN_C020","Song Con 2 Hydro JSC",
            "VN_UP007","Vietnam Hydropower JSC",310000,isic_power),
  make_loan("VN_L021","VN_C021","Bac Me Hydro Power JSC",
            "VN_UP007","Vietnam Hydropower JSC",290000,isic_power),
  make_loan("VN_L022","VN_C022","Lai Chau Hydro Power JSC",
            "VN_UP001","EVN (Electricity of Vietnam)",750000,isic_power),

  # --- Power - Solar (4 loans, ~2,000 bn VND) ---
  make_loan("VN_L023","VN_C023","Trung Nam Solar Ninh Thuan JSC",
            "VN_UP008","Trung Nam Group",450000,isic_power),
  make_loan("VN_L024","VN_C024","BIM Solar Ninh Thuan JSC",
            "VN_UP009","BIM Group",380000,isic_power),
  make_loan("VN_L025","VN_C025","TTC Solar Tay Ninh JSC",
            "VN_UP010","Thanh Thanh Cong Group",520000,isic_power),
  make_loan("VN_L026","VN_C026","Xuan Thien Solar Dak Lak JSC",
            "VN_UP011","Xuan Thien Group",650000,isic_power),

  # --- Power - Wind (3 loans, ~1,250 bn VND) ---
  make_loan("VN_L027","VN_C027","Trung Nam Wind Ninh Thuan JSC",
            "VN_UP008","Trung Nam Group",420000,isic_power),
  make_loan("VN_L028","VN_C028","T&T Bac Lieu Wind Power JSC",
            "VN_UP012","T&T Group",480000,isic_power),
  make_loan("VN_L029","VN_C029","Gia Lai Wind Power JSC",
            "VN_UP013","Gia Lai Electricity JSC",350000,isic_power),

  # --- Automotive - ICE (4 loans, ~3,250 bn VND) ---
  make_loan("VN_L030","VN_C030","THACO Truong Hai Auto Corp",
            "VN_UP014","THACO Industries",1200000,isic_automotive),
  make_loan("VN_L031","VN_C031","Toyota Vietnam Co Ltd",
            "VN_UP015","Toyota Motor Corporation",850000,isic_automotive),
  make_loan("VN_L032","VN_C032","Ford Vietnam Ltd",
            "VN_UP016","Ford Motor Company",650000,isic_automotive),
  make_loan("VN_L033","VN_C033","Hyundai Thanh Cong Vietnam",
            "VN_UP017","Hyundai Motor Company",550000,isic_automotive),

  # --- Automotive - EV (2 loans, ~1,000 bn VND) ---
  make_loan("VN_L034","VN_C034","VinFast Auto JSC",
            "VN_UP018","Vingroup JSC",750000,isic_automotive),
  make_loan("VN_L035","VN_C035","VinFast Trading and Service LLC",
            "VN_UP018","Vingroup JSC",250000,isic_automotive),

  # --- Automotive - Hybrid (1 loan, ~250 bn VND) ---
  make_loan("VN_L036","VN_C036","Honda Vietnam Auto JSC",
            "VN_UP019","Honda Motor Co Ltd",250000,isic_automotive),

  # --- Cement (3 loans, ~2,000 bn VND) ---
  make_loan("VN_L037","VN_C037","VICEM Ha Tien 1 JSC",
            "VN_UP020","VICEM",680000,isic_cement),
  make_loan("VN_L038","VN_C038","VICEM Bim Son JSC",
            "VN_UP020","VICEM",520000,isic_cement),
  make_loan("VN_L039","VN_C039","Holcim Vietnam Ltd",
            "VN_UP021","Holcim Group",800000,isic_cement),

  # --- Steel (2 loans, ~1,500 bn VND) ---
  make_loan("VN_L040","VN_C040","Hoa Phat Dung Quat Steel JSC",
            "VN_UP022","Hoa Phat Group JSC",900000,isic_steel),
  make_loan("VN_L041","VN_C041","Pomina Steel Corp",
            "VN_UP023","Pomina Group",600000,isic_steel),

  # --- Coal Mining (2 loans, ~1,250 bn VND) ---
  make_loan("VN_L042","VN_C042","Vinacomin TKV JSC",
            "VN_UP024","Vietnam National Coal-Mineral Industries Group",850000,isic_coal),
  make_loan("VN_L043","VN_C043","Dong Bac Corporation",
            "VN_UP025","Dong Bac Corporation",400000,isic_coal)
)

cat(sprintf("  Loanbook: %d rows | Total: %s bn VND\n",
            nrow(vietnam_loanbook),
            format(sum(vietnam_loanbook$loan_size_outstanding) / 1000, big.mark = ",")))
write_csv(vietnam_loanbook, "data/vietnam_loanbook.csv")
cat("  Saved: data/vietnam_loanbook.csv\n\n")

# ==============================================================================
# SECTION B: ABCD (Asset-Based Company Data)
# company_id, name_company, lei, sector, technology, production_unit,
# year, production, emission_factor, plant_location, is_ultimate_owner,
# emission_factor_unit
#
# name_company = name_ultimate_parent in loanbook (enables matching at UP level)
# All power companies: is_ultimate_owner = TRUE
# BOT coal (Nghi Son, Int'l Power Mong Duong): flat capacity through 2035 lock-in
# Production units: power=MW, automotive=vehicles, cement/steel/coal=tonnes
# ==============================================================================

cat("--- B: Building ABCD ---\n")

years <- 2025:2030

make_abcd <- function(company_id, name_company, sector, technology, production_unit,
                      productions, emission_factors = rep(NA_real_, 6),
                      plant_location = "VN", is_ultimate_owner = TRUE,
                      emission_factor_unit = NA_character_) {
  tibble(
    company_id           = company_id,
    name_company         = name_company,
    lei                  = NA_character_,
    sector               = sector,
    technology           = technology,
    production_unit      = production_unit,
    year                 = years,
    production           = productions,
    emission_factor      = emission_factors,
    plant_location       = plant_location,
    is_ultimate_owner    = is_ultimate_owner,
    emission_factor_unit = emission_factor_unit
  )
}

# --- Power Sector ---

# EVN: largest power company; coal (declining), gas (Phu My, stable), hydro (stable)
evn_coal <- make_abcd(
  "VN_ABCD_001", "EVN (Electricity of Vietnam)", "power", "coalcap", "MW",
  c(12500, 12500, 12000, 11800, 11500, 11000)
)
evn_gas <- make_abcd(
  "VN_ABCD_001", "EVN (Electricity of Vietnam)", "power", "gascap", "MW",
  c(1500, 1520, 1540, 1560, 1580, 1600)
)
evn_hydro <- make_abcd(
  "VN_ABCD_001", "EVN (Electricity of Vietnam)", "power", "hydrocap", "MW",
  c(7800, 7850, 7900, 7950, 8000, 8100)
)

# Vinacomin Power: coal (declining)
vinacomin_power_coal <- make_abcd(
  "VN_ABCD_002", "Vinacomin Power JSC", "power", "coalcap", "MW",
  c(2600, 2580, 2550, 2500, 2460, 2400)
)

# International Power Mong Duong: BOT coal (flat - PPA lock-in to ~2035)
intl_power_coal <- make_abcd(
  "VN_ABCD_003", "International Power Mong Duong", "power", "coalcap", "MW",
  c(1200, 1200, 1200, 1200, 1200, 1200),
  is_ultimate_owner = FALSE
)

# PVN Power: coal (Thai Binh 2, flat) + gas (Ca Mau, Nhon Trach, growing)
pvn_coal <- make_abcd(
  "VN_ABCD_004", "PVN Power Corporation", "power", "coalcap", "MW",
  c(600, 600, 600, 600, 600, 600)
)
pvn_gas <- make_abcd(
  "VN_ABCD_004", "PVN Power Corporation", "power", "gascap", "MW",
  c(4200, 4500, 5200, 5800, 6200, 6800)
)

# Nghi Son Power: BOT coal (flat - Marubeni/KEPCO PPA to ~2035)
nghi_son_coal <- make_abcd(
  "VN_ABCD_005", "Nghi Son Power LLC", "power", "coalcap", "MW",
  c(1200, 1200, 1200, 1200, 1200, 1200),
  is_ultimate_owner = FALSE
)

# Dung Quat LNG: new gas (under construction, phased commissioning 2027-2028)
dung_quat_gas <- make_abcd(
  "VN_ABCD_006", "Dung Quat LNG Power Consortium", "power", "gascap", "MW",
  c(0, 0, 400, 680, 750, 750)
)

# Vietnam Hydropower JSC (VHP): hydro (stable, minor small-hydro additions)
vhp_hydro <- make_abcd(
  "VN_ABCD_007", "Vietnam Hydropower JSC", "power", "hydrocap", "MW",
  c(2400, 2420, 2450, 2500, 2550, 2600)
)

# Trung Nam Group: renewables (solar + wind combined; strong growth per PDP8)
trung_nam_renew <- make_abcd(
  "VN_ABCD_008", "Trung Nam Group", "power", "renewablescap", "MW",
  c(1050, 1350, 1600, 1900, 2200, 2500)
)

# BIM Group: solar renewables
bim_renew <- make_abcd(
  "VN_ABCD_009", "BIM Group", "power", "renewablescap", "MW",
  c(380, 420, 460, 510, 560, 600)
)

# Thanh Thanh Cong (TTC) Group: solar renewables
ttc_renew <- make_abcd(
  "VN_ABCD_010", "Thanh Thanh Cong Group", "power", "renewablescap", "MW",
  c(520, 580, 640, 700, 760, 800)
)

# Xuan Thien Group: solar renewables (Dak Lak projects)
xuan_thien_renew <- make_abcd(
  "VN_ABCD_011", "Xuan Thien Group", "power", "renewablescap", "MW",
  c(650, 730, 810, 880, 950, 1000)
)

# T&T Group: wind renewables (Bac Lieu offshore wind)
tt_renew <- make_abcd(
  "VN_ABCD_012", "T&T Group", "power", "renewablescap", "MW",
  c(480, 560, 640, 700, 760, 800)
)

# Gia Lai Electricity JSC: wind renewables (Central Highlands)
gialai_renew <- make_abcd(
  "VN_ABCD_013", "Gia Lai Electricity JSC", "power", "renewablescap", "MW",
  c(350, 380, 410, 450, 480, 500)
)

# --- Automotive Sector ---

# THACO Industries: ICE dominant (Kia, Mazda, Peugeot assembly), no EV plans
thaco_ice <- make_abcd(
  "VN_ABCD_014", "THACO Industries", "automotive", "ice", "vehicles",
  c(120000, 125000, 128000, 130000, 130000, 128000)
)

# Toyota Motor Corporation: ICE declining + hybrid growing
toyota_ice <- make_abcd(
  "VN_ABCD_015", "Toyota Motor Corporation", "automotive", "ice", "vehicles",
  c(62000, 60000, 58000, 56000, 54000, 50000)
)
toyota_hybrid <- make_abcd(
  "VN_ABCD_015", "Toyota Motor Corporation", "automotive", "hybrid", "vehicles",
  c(2000, 4000, 6000, 8000, 10000, 14000)
)

# Ford Motor Company: 100% ICE
ford_ice <- make_abcd(
  "VN_ABCD_016", "Ford Motor Company", "automotive", "ice", "vehicles",
  c(50000, 51000, 52000, 52000, 51000, 50000)
)

# Hyundai Motor Company: ICE (assembly + distribution)
hyundai_ice <- make_abcd(
  "VN_ABCD_017", "Hyundai Motor Company", "automotive", "ice", "vehicles",
  c(45000, 45000, 44000, 43000, 42000, 40000)
)

# Vingroup JSC (VinFast): 100% EV; ambitious growth trajectory
vingroup_ev <- make_abcd(
  "VN_ABCD_018", "Vingroup JSC", "automotive", "electric", "vehicles",
  c(45000, 70000, 100000, 130000, 160000, 200000)
)

# Honda Motor Co Ltd: hybrid (HEV cars; motorbike segment excluded)
honda_hybrid <- make_abcd(
  "VN_ABCD_019", "Honda Motor Co Ltd", "automotive", "hybrid", "vehicles",
  c(18000, 19000, 20000, 20000, 21000, 22000)
)

# --- Cement Sector (tonnes/year) ---
# Emission factors in tCO2/tonne of cement

vicem_cement <- make_abcd(
  "VN_ABCD_020", "VICEM", "cement", "integrated facility", "tonnes",
  c(12500000, 12500000, 12800000, 13000000, 13000000, 13200000),
  emission_factors = c(0.82, 0.806, 0.791, 0.776, 0.760, 0.745),
  emission_factor_unit = "tonnes of CO2 per tonne"
)

holcim_cement <- make_abcd(
  "VN_ABCD_021", "Holcim Group", "cement", "integrated facility", "tonnes",
  c(7000000, 7100000, 7200000, 7300000, 7400000, 7500000),
  emission_factors = c(0.72, 0.706, 0.693, 0.679, 0.666, 0.653),
  emission_factor_unit = "tonnes of CO2 per tonne"
)

# --- Steel Sector (tonnes/year) ---
# Hoa Phat: blast furnace / basic oxygen furnace (high emissions)
hoa_phat_steel <- make_abcd(
  "VN_ABCD_022", "Hoa Phat Group JSC", "steel", "open_hearth", "tonnes",
  c(7500000, 7700000, 7900000, 8100000, 8300000, 8500000),
  emission_factors = c(1.85, 1.84, 1.83, 1.82, 1.81, 1.80),
  emission_factor_unit = "tonnes of CO2 per tonne"
)

# Pomina: electric arc furnace (lower emissions; scrap-based)
pomina_steel <- make_abcd(
  "VN_ABCD_023", "Pomina Group", "steel", "electric", "tonnes",
  c(1200000, 1260000, 1320000, 1380000, 1440000, 1500000),
  emission_factors = c(0.58, 0.566, 0.554, 0.541, 0.529, 0.517),
  emission_factor_unit = "tonnes of CO2 per tonne"
)

# --- Coal Mining Sector (tonnes/year) ---
# Note: coal mining is not processed by standard target_market_share() or
# target_sda() in this pipeline. Included for custom coal analysis only.

tkv_coal <- make_abcd(
  "VN_ABCD_024", "Vietnam National Coal-Mineral Industries Group", "coal", "thermal coal", "tonnes",
  c(36000000, 35500000, 35000000, 34000000, 33000000, 31000000)
)

dong_bac_coal <- make_abcd(
  "VN_ABCD_025", "Dong Bac Corporation", "coal", "thermal coal", "tonnes",
  c(4000000, 3900000, 3800000, 3700000, 3600000, 3500000)
)

vietnam_abcd <- bind_rows(
  evn_coal, evn_gas, evn_hydro,
  vinacomin_power_coal,
  intl_power_coal,
  pvn_coal, pvn_gas,
  nghi_son_coal,
  dung_quat_gas,
  vhp_hydro,
  trung_nam_renew,
  bim_renew,
  ttc_renew,
  xuan_thien_renew,
  tt_renew,
  gialai_renew,
  thaco_ice,
  toyota_ice, toyota_hybrid,
  ford_ice,
  hyundai_ice,
  vingroup_ev,
  honda_hybrid,
  vicem_cement, holcim_cement,
  hoa_phat_steel, pomina_steel,
  tkv_coal, dong_bac_coal
)

cat(sprintf("  ABCD: %d rows | Sectors: %s\n",
            nrow(vietnam_abcd),
            paste(unique(vietnam_abcd$sector), collapse = ", ")))
write_csv(vietnam_abcd, "data/vietnam_abcd.csv")
cat("  Saved: data/vietnam_abcd.csv\n\n")

# ==============================================================================
# SECTION C: MARKET SHARE SCENARIO (Power + Automotive)
# Three scenarios:
#   "steps"      - BAU / Stated Policies (no further climate action)
#   "pdp8_ndc"   - Vietnam PDP8 + NDC (primary domestic benchmark)
#   "nze_global" - Approximate IEA NZE global pathway (aspirational)
#
# Columns: scenario_source, scenario, sector, technology, region, year, smsp, tmsr
#   smsp = Sector Market Share Pathway (technology share of total sector capacity)
#   tmsr = Technology Market Share Ratio (production ratio vs 2025 base)
# ==============================================================================

cat("--- C: Building market share scenario ---\n")

# Helper: interpolate smsp linearly, compute tmsr relative to 2025
make_ms_scenario <- function(scenario_source, scenario, sector, technology, region,
                             smsp_vals, tmsr_vals) {
  tibble(
    scenario_source = scenario_source,
    scenario        = scenario,
    sector          = sector,
    technology      = technology,
    region          = region,
    year            = years,
    smsp            = smsp_vals,
    tmsr            = tmsr_vals
  )
}

# ---- Power - PDP8/NDC (Vietnam primary scenario) ----
# SMSP from plan §5.3.1; TMSR from plan §5.3.1 table
pdp8_power <- bind_rows(
  make_ms_scenario("pdp8_2023","pdp8_ndc","power","coalcap","vietnam",
    smsp_vals = c(0.32, 0.31, 0.30, 0.29, 0.28, 0.26),
    tmsr_vals = c(1.00, 1.00, 0.97, 0.94, 0.90, 0.87)),
  make_ms_scenario("pdp8_2023","pdp8_ndc","power","gascap","vietnam",
    smsp_vals = c(0.12, 0.13, 0.14, 0.15, 0.16, 0.17),
    tmsr_vals = c(1.00, 1.12, 1.28, 1.46, 1.65, 1.88)),
  make_ms_scenario("pdp8_2023","pdp8_ndc","power","hydrocap","vietnam",
    smsp_vals = c(0.26, 0.25, 0.24, 0.23, 0.22, 0.21),
    tmsr_vals = c(1.00, 1.00, 1.02, 1.04, 1.05, 1.07)),
  make_ms_scenario("pdp8_2023","pdp8_ndc","power","renewablescap","vietnam",
    smsp_vals = c(0.26, 0.28, 0.30, 0.31, 0.32, 0.34),
    tmsr_vals = c(1.00, 1.18, 1.40, 1.65, 1.95, 2.30)),
  make_ms_scenario("pdp8_2023","pdp8_ndc","power","oilcap","vietnam",
    smsp_vals = c(0.04, 0.03, 0.02, 0.02, 0.02, 0.02),
    tmsr_vals = c(1.00, 0.90, 0.80, 0.75, 0.70, 0.65))
)

# ---- Automotive - PDP8/NDC ----
# Vietnam total car market: 620k (2025) → 800k (2030)
# SMSP from plan §5.3.2; TMSR computed from market growth × share shift
total_mkt <- c(620000, 650000, 680000, 720000, 760000, 800000)
ice_prod   <- total_mkt * c(0.95, 0.91, 0.85, 0.78, 0.70, 0.60)
ev_prod    <- total_mkt * c(0.02, 0.05, 0.09, 0.14, 0.20, 0.28)
hyb_prod   <- total_mkt * c(0.03, 0.04, 0.06, 0.08, 0.10, 0.12)

pdp8_auto <- bind_rows(
  make_ms_scenario("pdp8_2023","pdp8_ndc","automotive","ice","vietnam",
    smsp_vals = c(0.95, 0.91, 0.85, 0.78, 0.70, 0.60),
    tmsr_vals = round(ice_prod / ice_prod[1], 4)),
  make_ms_scenario("pdp8_2023","pdp8_ndc","automotive","electric","vietnam",
    smsp_vals = c(0.02, 0.05, 0.09, 0.14, 0.20, 0.28),
    tmsr_vals = round(ev_prod / ev_prod[1], 4)),
  make_ms_scenario("pdp8_2023","pdp8_ndc","automotive","hybrid","vietnam",
    smsp_vals = c(0.03, 0.04, 0.06, 0.08, 0.10, 0.12),
    tmsr_vals = round(hyb_prod / hyb_prod[1], 4))
)

# ---- Power - BAU/STEPS (no further ambition beyond 2025 stated policies) ----
steps_power <- bind_rows(
  make_ms_scenario("steps_2023","steps","power","coalcap","vietnam",
    smsp_vals = c(0.32, 0.32, 0.31, 0.30, 0.30, 0.29),
    tmsr_vals = c(1.00, 1.02, 1.03, 1.04, 1.04, 1.05)),
  make_ms_scenario("steps_2023","steps","power","gascap","vietnam",
    smsp_vals = c(0.12, 0.12, 0.13, 0.13, 0.14, 0.14),
    tmsr_vals = c(1.00, 1.05, 1.10, 1.15, 1.20, 1.25)),
  make_ms_scenario("steps_2023","steps","power","hydrocap","vietnam",
    smsp_vals = c(0.26, 0.25, 0.25, 0.25, 0.24, 0.24),
    tmsr_vals = c(1.00, 1.00, 1.01, 1.02, 1.03, 1.04)),
  make_ms_scenario("steps_2023","steps","power","renewablescap","vietnam",
    smsp_vals = c(0.26, 0.27, 0.28, 0.29, 0.30, 0.31),
    tmsr_vals = c(1.00, 1.10, 1.20, 1.30, 1.40, 1.50)),
  make_ms_scenario("steps_2023","steps","power","oilcap","vietnam",
    smsp_vals = c(0.04, 0.04, 0.03, 0.03, 0.02, 0.02),
    tmsr_vals = c(1.00, 1.00, 0.95, 0.90, 0.85, 0.80))
)

# ---- Automotive - BAU/STEPS (slow EV uptake) ----
ice_steps   <- total_mkt * c(0.95, 0.94, 0.93, 0.91, 0.89, 0.87)
ev_steps    <- total_mkt * c(0.02, 0.02, 0.03, 0.04, 0.05, 0.06)
hyb_steps   <- total_mkt * c(0.03, 0.04, 0.04, 0.05, 0.06, 0.07)

steps_auto <- bind_rows(
  make_ms_scenario("steps_2023","steps","automotive","ice","vietnam",
    smsp_vals = c(0.95, 0.94, 0.93, 0.91, 0.89, 0.87),
    tmsr_vals = round(ice_steps / ice_steps[1], 4)),
  make_ms_scenario("steps_2023","steps","automotive","electric","vietnam",
    smsp_vals = c(0.02, 0.02, 0.03, 0.04, 0.05, 0.06),
    tmsr_vals = round(ev_steps / ev_steps[1], 4)),
  make_ms_scenario("steps_2023","steps","automotive","hybrid","vietnam",
    smsp_vals = c(0.03, 0.04, 0.04, 0.05, 0.06, 0.07),
    tmsr_vals = round(hyb_steps / hyb_steps[1], 4))
)

# ---- Power - NZE Global (IEA Net Zero approximation for Vietnam/Asia-Pac) ----
nze_power <- bind_rows(
  make_ms_scenario("nze_2023","nze_global","power","coalcap","vietnam",
    smsp_vals = c(0.32, 0.29, 0.25, 0.20, 0.15, 0.10),
    tmsr_vals = c(1.00, 0.90, 0.77, 0.60, 0.44, 0.28)),
  make_ms_scenario("nze_2023","nze_global","power","gascap","vietnam",
    smsp_vals = c(0.12, 0.13, 0.14, 0.14, 0.14, 0.14),
    tmsr_vals = c(1.00, 1.10, 1.20, 1.22, 1.24, 1.25)),
  make_ms_scenario("nze_2023","nze_global","power","hydrocap","vietnam",
    smsp_vals = c(0.26, 0.24, 0.22, 0.21, 0.20, 0.19),
    tmsr_vals = c(1.00, 1.00, 1.02, 1.04, 1.05, 1.06)),
  make_ms_scenario("nze_2023","nze_global","power","renewablescap","vietnam",
    smsp_vals = c(0.26, 0.30, 0.37, 0.44, 0.50, 0.56),
    tmsr_vals = c(1.00, 1.30, 1.80, 2.40, 3.10, 3.80)),
  make_ms_scenario("nze_2023","nze_global","power","oilcap","vietnam",
    smsp_vals = c(0.04, 0.04, 0.02, 0.01, 0.01, 0.01),
    tmsr_vals = c(1.00, 0.90, 0.60, 0.35, 0.20, 0.10))
)

# ---- Automotive - NZE Global (aggressive EV push) ----
ice_nze   <- total_mkt * c(0.95, 0.86, 0.75, 0.62, 0.50, 0.40)
ev_nze    <- total_mkt * c(0.02, 0.08, 0.17, 0.28, 0.40, 0.50)
hyb_nze   <- total_mkt * c(0.03, 0.06, 0.08, 0.10, 0.10, 0.10)

nze_auto <- bind_rows(
  make_ms_scenario("nze_2023","nze_global","automotive","ice","vietnam",
    smsp_vals = c(0.95, 0.86, 0.75, 0.62, 0.50, 0.40),
    tmsr_vals = round(ice_nze / ice_nze[1], 4)),
  make_ms_scenario("nze_2023","nze_global","automotive","electric","vietnam",
    smsp_vals = c(0.02, 0.08, 0.17, 0.28, 0.40, 0.50),
    tmsr_vals = round(ev_nze / ev_nze[1], 4)),
  make_ms_scenario("nze_2023","nze_global","automotive","hybrid","vietnam",
    smsp_vals = c(0.03, 0.06, 0.08, 0.10, 0.10, 0.10),
    tmsr_vals = round(hyb_nze / hyb_nze[1], 4))
)

vietnam_scenario_ms <- bind_rows(
  pdp8_power, pdp8_auto,
  steps_power, steps_auto,
  nze_power, nze_auto
)

cat(sprintf("  Market share scenario: %d rows | Scenarios: %s\n",
            nrow(vietnam_scenario_ms),
            paste(unique(vietnam_scenario_ms$scenario), collapse = ", ")))
write_csv(vietnam_scenario_ms, "data/vietnam_scenario_ms.csv")
cat("  Saved: data/vietnam_scenario_ms.csv\n\n")

# ==============================================================================
# SECTION D: CO2 INTENSITY SCENARIO (Cement + Steel)
# Columns: scenario_source, scenario, sector, region, year,
#          emission_factor_unit, emission_factor_value
#
# Three scenarios per sector:
#   "steps"      - BAU (0.5%/yr improvement, operational efficiency only)
#   "pdp8_ndc"   - NDC conditional (2.9%/yr decline, 0.82→0.71 by 2030 cement)
#   "nze_global" - IEA NZE global target (requires CCS; aspirational for Vietnam)
# ==============================================================================

cat("--- D: Building CO2 intensity scenario ---\n")

make_co2_scenario <- function(scenario_source, scenario, sector, region, ef_values,
                              ef_unit = "tonnes of CO2 per tonne") {
  tibble(
    scenario_source      = scenario_source,
    scenario             = scenario,
    sector               = sector,
    region               = region,
    year                 = years,
    emission_factor_unit = ef_unit,
    emission_factor_value = ef_values
  )
}

# Cement CO2 intensity (tCO2/tonne cement)
# BAU: 0.5%/yr; NDC conditional: linear 0.82→0.71; NZE: 0.54 by 2030
cement_bau   <- seq(0.820, 0.820 * 0.975, length.out = 6)  # ~0.5%/yr * 5 steps
cement_ndc   <- seq(0.820, 0.710, length.out = 6)           # plan §5.3.3
cement_nze   <- seq(0.820, 0.540, length.out = 6)           # IEA NZE Asia-Pac

# Steel CO2 intensity (tCO2/tonne steel)
# BAU: slight improvement 1.75→1.65; NDC: 1.75→1.50; NZE: 1.75→1.30
steel_bau  <- seq(1.750, 1.650, length.out = 6)
steel_ndc  <- seq(1.750, 1.500, length.out = 6)
steel_nze  <- seq(1.750, 1.300, length.out = 6)

vietnam_scenario_co2 <- bind_rows(
  # Cement
  make_co2_scenario("pdp8_2023","steps",    "cement","vietnam", round(cement_bau, 4)),
  make_co2_scenario("pdp8_2023","pdp8_ndc", "cement","vietnam", round(cement_ndc, 4)),
  make_co2_scenario("nze_2023", "nze_global","cement","vietnam", round(cement_nze, 4)),
  # Steel
  make_co2_scenario("pdp8_2023","steps",    "steel","vietnam", round(steel_bau, 4)),
  make_co2_scenario("pdp8_2023","pdp8_ndc", "steel","vietnam", round(steel_ndc, 4)),
  make_co2_scenario("nze_2023", "nze_global","steel","vietnam", round(steel_nze, 4))
)

cat(sprintf("  CO2 intensity scenario: %d rows | Scenarios: %s\n",
            nrow(vietnam_scenario_co2),
            paste(unique(vietnam_scenario_co2$scenario), collapse = ", ")))
write_csv(vietnam_scenario_co2, "data/vietnam_scenario_co2.csv")
cat("  Saved: data/vietnam_scenario_co2.csv\n\n")

# ==============================================================================
# SECTION E: REGION ISOs
# Maps ISO country code "vn" (lowercase) to named PACTA regions.
# Required by target_market_share() and target_sda() for filtering.
# ==============================================================================

cat("--- E: Building region ISOs ---\n")

# source column must match scenario_source values in scenario tables.
# Repeat each region triple for every scenario_source.
vietnam_region_isos <- bind_rows(
  tibble(region = c("global","vietnam","asia_pacific"), isos = "vn", source = "pdp8_2023"),
  tibble(region = c("global","vietnam","asia_pacific"), isos = "vn", source = "steps_2023"),
  tibble(region = c("global","vietnam","asia_pacific"), isos = "vn", source = "nze_2023")
)

cat(sprintf("  Region ISOs: %d rows\n", nrow(vietnam_region_isos)))
write_csv(vietnam_region_isos, "data/vietnam_region_isos.csv")
cat("  Saved: data/vietnam_region_isos.csv\n\n")

# ==============================================================================
# VALIDATION SUMMARY
# ==============================================================================

cat("==============================================\n")
cat("Validation summary\n")
cat("==============================================\n\n")

# Loanbook sector totals
loan_summary <- vietnam_loanbook %>%
  mutate(pacta_sector = case_when(
    sector_classification_direct_loantaker == "D3511" ~ "power",
    sector_classification_direct_loantaker == "C2910" ~ "automotive",
    sector_classification_direct_loantaker == "C2394" ~ "cement",
    sector_classification_direct_loantaker == "C2410" ~ "steel",
    sector_classification_direct_loantaker == "B0510" ~ "coal",
    TRUE ~ "other"
  )) %>%
  group_by(pacta_sector) %>%
  summarise(
    n_loans        = n(),
    total_bn_vnd   = sum(loan_size_outstanding) / 1000,
    pct_portfolio  = round(sum(loan_size_outstanding) / sum(vietnam_loanbook$loan_size_outstanding) * 100, 1),
    .groups = "drop"
  ) %>%
  arrange(desc(total_bn_vnd))
cat("Loanbook by sector:\n")
print(as.data.frame(loan_summary))

# ABCD company count
abcd_summary <- vietnam_abcd %>%
  group_by(sector, technology) %>%
  summarise(n_companies = n_distinct(company_id), n_rows = n(), .groups = "drop") %>%
  arrange(sector, technology)
cat("\nABCD sector × technology:\n")
print(as.data.frame(abcd_summary))

# Confirm all ultimate parents in loanbook have a matching ABCD company
up_names <- unique(vietnam_loanbook$name_ultimate_parent)
abcd_names <- unique(vietnam_abcd$name_company)
missing <- setdiff(up_names, abcd_names)
if (length(missing) == 0) {
  cat("\nAll 25 ultimate parents have a matching ABCD company. PASS.\n")
} else {
  cat("\nWARNING: Ultimate parents without ABCD match:\n")
  print(missing)
}

cat("\nData generation complete.\n")
