# Vietnam Bank PACTA Scenario: Implementation Plan

> **Status:** Draft — ready for implementation
> **Author:** Allotrope VC / Tung
> **Last updated:** 2026-03-20
> **Purpose:** End-to-end blueprint for running a Vietnam-specific PACTA alignment analysis using a synthetic commercial bank loanbook, Vietnam market asset data, and adapted global climate scenarios.

---

## Table of Contents

1. [Background & Objectives](#1-background--objectives)
2. [Vietnam Energy & Climate Context](#2-vietnam-energy--climate-context)
3. [Synthetic Vietnam Bank Loanbook Design](#3-synthetic-vietnam-bank-loanbook-design)
4. [Synthetic ABCD (Asset-Based Company Data)](#4-synthetic-abcd-asset-based-company-data)
5. [Scenario Selection & Vietnam Adaptation](#5-scenario-selection--vietnam-adaptation)
6. [Data Pipeline: Generation & Formatting](#6-data-pipeline-generation--formatting)
7. [Running the PACTA Analysis](#7-running-the-pacta-analysis)
8. [Expected Outputs & Interpretation](#8-expected-outputs--interpretation)
9. [Visualization & Reporting for a Vietnam Bank Audience](#9-visualization--reporting-for-a-vietnam-bank-audience)
10. [Gaps, Workarounds & Known Limitations](#10-gaps-workarounds--known-limitations)
11. [Implementation Roadmap](#11-implementation-roadmap)

---

## 1. Background & Objectives

### 1.1 What This Demonstrates

This plan builds a **Vietnam-specific PACTA scenario** on top of the existing `pacta-vietnam` pipeline (`scripts/pacta_synthesis.R`). Rather than using the generic `r2dii.data::loanbook_demo` (which contains fictional European companies), we replace both the loanbook and the ABCD asset data with Vietnam-realistic synthetic datasets, and we adapt global climate scenarios to reflect Vietnam's energy transition trajectory under:

- **Power Development Plan 8 (PDP8)** — Vietnam's binding electricity sector roadmap to 2030 and orientation to 2050
- **Vietnam's 2022 Updated NDC** — 43.5% GHG reduction vs. BAU by 2030 (conditional on international support)
- **Glasgow commitment (COP26)** — Vietnam's net-zero by 2050 pledge
- **IEA global scenarios** — as global benchmarks for comparison

### 1.2 Target Audience

A senior lending officer or ESG/risk team at a mid-sized Vietnamese commercial bank (e.g., BIDV, Vietcombank, VietinBank, Techcombank, or MB Bank) who wants to understand how their loan portfolio aligns with Paris Agreement goals and Vietnam's national climate commitments.

### 1.3 What the Existing Repo Covers

The existing `scripts/pacta_synthesis.R` pipeline demonstrates:
- Fuzzy matching of loanbook borrowers to ABCD company data (`r2dii.match`)
- Market share alignment targets for power and automotive sectors
- SDA emission intensity targets for cement and steel
- HTML report generation with embedded charts

**What it does NOT cover (addressed in this plan):**
- Vietnam-specific company names, sector codes, or loan sizes in VND
- Vietnam electricity production data (EVN, private IPPs, etc.)
- Vietnam power scenario pathways (PDP8, NDC)
- VSIC → PACTA sector code mapping
- Vietnam auto market specifics (THACO, VinFast, Toyota Vietnam)
- Coal mining sector (Vinacomin/TKV) — present in Vietnam but absent from demo

---

## 2. Vietnam Energy & Climate Context

### 2.1 Current Energy Mix (2023 Baseline)

| Technology | Installed Capacity (GW) | Share of Generation |
|---|---|---|
| Coal | ~26 GW | ~45% of electricity output |
| Gas (combined cycle) | ~8 GW | ~15% |
| Hydropower (large) | ~22 GW | ~28% |
| Solar (utility + rooftop) | ~19 GW | ~8–10% |
| Wind (onshore) | ~5 GW | ~2–3% |
| Oil/diesel (peaking) | ~2 GW | <1% |
| Nuclear | 0 GW (cancelled 2016, revived 2024–2026 policy discussion) | 0% |

Key insight: Vietnam is one of Southeast Asia's most coal-heavy grids, but added more solar capacity between 2019–2021 than any other Southeast Asian country.

### 2.2 Power Development Plan 8 (PDP8) — Approved May 2023

PDP8 is Vietnam's official power sector investment roadmap and the authoritative domestic scenario for climate alignment. Key targets:

**By 2030:**
- Total capacity: 150–160 GW
- Coal: capped at 30.2 GW (no new coal after 2030, existing plants phase out by 2040–2050)
- Gas (LNG): 22.4 GW (import-dependent, transition fuel)
- Onshore wind: 21.9 GW (from ~5 GW today — 4× growth)
- Offshore wind: 6 GW (first large-scale offshore)
- Solar: 46.9 GW utility + rooftop (from ~19 GW — 2.5× growth)
- Hydropower: 29.3 GW (mostly existing)

**By 2050 (orientation):**
- Coal: 0 GW (complete phase-out)
- Offshore wind: 70–79 GW
- Onshore wind: 60–77 GW
- Solar: 168–189 GW (dominant source)
- Green hydrogen: 5–10 GW by 2035

**Implied technology share trajectory (generation, not capacity):**

| Technology | 2025 share | 2030 target | 2050 target |
|---|---|---|---|
| Coal | ~40% | ~30% | 0% |
| Gas | ~15% | ~20% (LNG transition) | <5% |
| Hydro | ~25% | ~18% | ~10% |
| Solar | ~12% | ~20% | ~40% |
| Wind | ~4% | ~12% | ~40% |
| Nuclear | 0% | 0% | 3–5% (aspirational) |

### 2.3 Vietnam's NDC (2022 Update)

- **Unconditional target:** 15.8% GHG reduction vs BAU by 2030 (domestic resources only)
- **Conditional target:** 43.5% GHG reduction vs BAU by 2030 (with international finance/technology)
- **Energy sector** accounts for ~65% of Vietnam's total emissions — the dominant target
- **Transport sector:** EV penetration target of 100% new car sales by 2040 (aligned with ASEAN EV goal); 50% of urban buses electric by 2030
- **Industry:** No specific cement/steel emission intensity target in NDC; general "best available technology" requirement

### 2.4 Key Climate Finance Context

- Vietnam signed the **Just Energy Transition Partnership (JETP)** in December 2022 — $15.5B commitment from G7+EU to accelerate coal phase-down and renewables scale-up
- The **Coal Retirement Mechanism** under JETP targets early closure of 5–8 GW of coal capacity by 2035
- Under JETP, Vietnam committed to peak power sector emissions by 2030 and reduce coal power share to below 30% by 2030
- **Implications for bank lending:** Coal project financing risk is rising fast (stranded asset risk within 10–15 years); renewable project finance is policy-favored

### 2.5 Automotive Sector Context

| Company | Role | EV/ICE position |
|---|---|---|
| Vingroup / VinFast | Domestic OEM | 100% EV (launched 2021) |
| THACO (Trường Hải Auto) | Largest auto assembler/dealer | ~95% ICE (Kia, Mazda, Peugeot) |
| Toyota Vietnam | Assembly + distribution | ~98% ICE, token HEV |
| Ford Vietnam | Assembly | 100% ICE |
| Honda Vietnam | Primarily motorbikes, some cars | 99% ICE |
| Hyundai Thanh Cong | Assembly + distribution | ICE + some FCEV/BEV imported |

Vietnam had ~600,000 new car registrations in 2023. EV penetration is ~2% (led entirely by VinFast). The government offers tax incentives to EV buyers through 2027. VinFast targets 50,000 domestic deliveries/year by 2026.

### 2.6 Industrial Sectors

**Cement:**
- Vietnam is the world's 3rd largest cement exporter
- Key players: VICEM (state, ~27% market share), Ha Tien 1, Holcim Vietnam, INSEE Vietnam (Siam City Cement)
- Average emission intensity: ~0.80–0.85 tCO2/t cement (above global average of 0.6)
- No domestic cement decarbonization roadmap beyond general NDC commitments

**Steel:**
- Hoa Phat Group (largest domestic producer, ~8 Mt/year, uses blast furnace/BOF — high emission intensity ~1.8 tCO2/t)
- Formosa Ha Tinh Steel (Taiwanese FDI, integrated mill, ~7 Mt/year)
- VietSteel / Pomina (EAF, lower emissions ~0.6 tCO2/t)
- Industry emission intensity: ~1.5–1.8 tCO2/t for majority of output

**Coal Mining:**
- Vinacomin (TKV — Vietnam National Coal and Mineral Industries Group): state monopoly for domestic coal
- Dong Bac Corporation: second state coal producer
- 2023 output: ~40 Mt/year (domestic hard coal)
- Vietnam also imports ~60 Mt/year for power and steel — imported coal not directly in TKV's scope

---

## 3. Synthetic Vietnam Bank Loanbook Design

### 3.1 Bank Profile

**Fictional bank name:** Mekong Commercial Bank (MCB) — synthetic, not a real institution
**Bank type:** Mid-large Vietnamese commercial bank, state-influenced
**Total assets:** ~500,000 billion VND (~$20B USD) — comparable to MB Bank or Techcombank
**Climate-relevant loan portfolio:** ~25,000 billion VND — the portion covered by PACTA (~5% of assets, realistic for commercial real economy lending)
**Currency:** VND (Vietnamese Dong). 1 USD ≈ 25,000 VND as of 2025 baseline.
**PACTA base year:** 2025
**Horizon:** 5 years (2025–2030)

### 3.2 Portfolio Sector Weights

This allocation reflects a realistic Vietnamese bank's corporate lending book with emphasis on energy infrastructure (state-directed lending), industrial borrowers, and emerging auto/EV exposure:

| PACTA Sector | % of Portfolio | Total Exposure (bn VND) | Rationale |
|---|---|---|---|
| Power — Coal | 28% | 7,000 | Largest single block; legacy state-directed loans to EVN coal subsidiaries and IPPs |
| Power — Gas | 12% | 3,000 | LNG power plants (PVN Power, BOT projects) |
| Power — Hydro | 10% | 2,500 | Existing large hydro (EVN Hydro, regional dams) |
| Power — Solar | 8% | 2,000 | Utility-scale solar IPPs (Feed-in Tariff era loans, 2019–2021 boom) |
| Power — Wind | 5% | 1,250 | Onshore wind (Trung Nam, BIM, T&T Group projects) |
| Automotive — ICE | 13% | 3,250 | THACO group, Toyota Vietnam assembly |
| Automotive — EV | 4% | 1,000 | VinFast loans (manufacturing facilities + dealer financing) |
| Automotive — Hybrid | 1% | 250 | Minor — Toyota hybrid models |
| Cement | 8% | 2,000 | VICEM subsidiaries, Ha Tien 1 |
| Steel | 6% | 1,500 | Hoa Phat, Pomina |
| Coal Mining | 5% | 1,250 | Vinacomin (TKV) |
| **Total** | **100%** | **25,000** | |

### 3.3 Loanbook: Full Borrower List

The loanbook CSV should have one row per loan. The following 40 loans cover the synthetic MCB portfolio. All amounts in VND millions.

#### Power — Coal (28%, 7,000 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L001 | VN_C001 | Nhiet Dien Vinh Tan 1 JSC | VN_UP001 | EVN (Electricity of Vietnam) | 800,000 | VSIC | 3511 |
| VN_L002 | VN_C002 | Nhiet Dien Vinh Tan 4 JSC | VN_UP001 | EVN (Electricity of Vietnam) | 650,000 | VSIC | 3511 |
| VN_L003 | VN_C003 | Nhiet Dien Duyen Hai 1 JSC | VN_UP001 | EVN (Electricity of Vietnam) | 720,000 | VSIC | 3511 |
| VN_L004 | VN_C004 | Nhiet Dien Duyen Hai 3 JSC | VN_UP001 | EVN (Electricity of Vietnam) | 540,000 | VSIC | 3511 |
| VN_L005 | VN_C005 | Nhiet Dien Mong Duong 1 JSC | VN_UP002 | Vinacomin Power JSC | 480,000 | VSIC | 3511 |
| VN_L006 | VN_C006 | Nhiet Dien Mong Duong 2 LLC | VN_UP003 | International Power Mong Duong | 620,000 | VSIC | 3511 |
| VN_L007 | VN_C007 | Nhiet Dien Uong Bi JSC | VN_UP001 | EVN (Electricity of Vietnam) | 380,000 | VSIC | 3511 |
| VN_L008 | VN_C008 | Nhiet Dien Cam Pha JSC | VN_UP002 | Vinacomin Power JSC | 430,000 | VSIC | 3511 |
| VN_L009 | VN_C009 | Nhiet Dien Vung Ang 1 JSC | VN_UP001 | EVN (Electricity of Vietnam) | 590,000 | VSIC | 3511 |
| VN_L010 | VN_C010 | Nhiet Dien Thai Binh 2 JSC | VN_UP004 | PVN Power Corporation | 780,000 | VSIC | 3511 |
| VN_L011 | VN_C011 | Nhiet Dien Nghi Son 2 LLC | VN_UP005 | Nghi Son Power LLC (Marubeni/KEPCO BOT) | 1,030,000 | VSIC | 3511 |

#### Power — Gas (12%, 3,000 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L012 | VN_C012 | PV Power Ca Mau JSC | VN_UP004 | PVN Power Corporation | 520,000 | VSIC | 3511 |
| VN_L013 | VN_C013 | PV Power Nhon Trach 1 JSC | VN_UP004 | PVN Power Corporation | 480,000 | VSIC | 3511 |
| VN_L014 | VN_C014 | PV Power Nhon Trach 3-4 JSC | VN_UP004 | PVN Power Corporation | 750,000 | VSIC | 3511 |
| VN_L015 | VN_C015 | Dung Quat LNG Power JSC | VN_UP006 | Dung Quat LNG Power Consortium | 680,000 | VSIC | 3511 |
| VN_L016 | VN_C016 | EVN Phu My Gas Power JSC | VN_UP001 | EVN (Electricity of Vietnam) | 570,000 | VSIC | 3511 |

#### Power — Hydro (10%, 2,500 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L017 | VN_C017 | EVN Hydro Song Ba Ha JSC | VN_UP001 | EVN (Electricity of Vietnam) | 350,000 | VSIC | 3511 |
| VN_L018 | VN_C018 | EVN Hydro Tri An JSC | VN_UP001 | EVN (Electricity of Vietnam) | 420,000 | VSIC | 3511 |
| VN_L019 | VN_C019 | Dak Drinh Hydro Power JSC | VN_UP007 | Vietnam Hydropower JSC (VHP) | 380,000 | VSIC | 3511 |
| VN_L020 | VN_C020 | Song Con 2 Hydro JSC | VN_UP007 | Vietnam Hydropower JSC (VHP) | 310,000 | VSIC | 3511 |
| VN_L021 | VN_C021 | Bac Me Hydro Power JSC | VN_UP007 | Vietnam Hydropower JSC (VHP) | 290,000 | VSIC | 3511 |
| VN_L022 | VN_C022 | Lai Chau Hydro Power JSC | VN_UP001 | EVN (Electricity of Vietnam) | 750,000 | VSIC | 3511 |

#### Power — Solar (8%, 2,000 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L023 | VN_C023 | Trung Nam Solar Ninh Thuan JSC | VN_UP008 | Trung Nam Group | 450,000 | VSIC | 3511 |
| VN_L024 | VN_C024 | BIM Solar Ninh Thuan JSC | VN_UP009 | BIM Group | 380,000 | VSIC | 3511 |
| VN_L025 | VN_C025 | TTC Solar Tay Ninh JSC | VN_UP010 | Thanh Thanh Cong (TTC) Group | 520,000 | VSIC | 3511 |
| VN_L026 | VN_C026 | Xuan Thien Solar Dak Lak JSC | VN_UP011 | Xuan Thien Group | 650,000 | VSIC | 3511 |

#### Power — Wind (5%, 1,250 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L027 | VN_C027 | Trung Nam Wind Ninh Thuan JSC | VN_UP008 | Trung Nam Group | 420,000 | VSIC | 3511 |
| VN_L028 | VN_C028 | T&T Bac Lieu Wind Power JSC | VN_UP012 | T&T Group | 480,000 | VSIC | 3511 |
| VN_L029 | VN_C029 | Gia Lai Wind Power JSC | VN_UP013 | Gia Lai Electricity JSC | 350,000 | VSIC | 3511 |

#### Automotive — ICE (13%, 3,250 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L030 | VN_C030 | THACO Truong Hai Auto Corp | VN_UP014 | THACO Industries | 1,200,000 | VSIC | 2910 |
| VN_L031 | VN_C031 | Toyota Vietnam Co. Ltd | VN_UP015 | Toyota Motor Corporation | 850,000 | VSIC | 2910 |
| VN_L032 | VN_C032 | Ford Vietnam Ltd | VN_UP016 | Ford Motor Company | 650,000 | VSIC | 2910 |
| VN_L033 | VN_C033 | Hyundai Thanh Cong Vietnam | VN_UP017 | Hyundai Motor Company | 550,000 | VSIC | 2910 |

#### Automotive — EV (4%, 1,000 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L034 | VN_C034 | VinFast Auto JSC | VN_UP018 | Vingroup JSC | 750,000 | VSIC | 2910 |
| VN_L035 | VN_C035 | VinFast Trading and Service LLC | VN_UP018 | Vingroup JSC | 250,000 | VSIC | 2910 |

#### Automotive — Hybrid (1%, 250 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L036 | VN_C036 | Honda Vietnam Auto JSC | VN_UP019 | Honda Motor Co. Ltd | 250,000 | VSIC | 2910 |

#### Cement (8%, 2,000 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L037 | VN_C037 | VICEM Ha Tien 1 JSC | VN_UP020 | VICEM (Vietnam Cement Industries Corp) | 680,000 | VSIC | 2394 |
| VN_L038 | VN_C038 | VICEM Bim Son JSC | VN_UP020 | VICEM (Vietnam Cement Industries Corp) | 520,000 | VSIC | 2394 |
| VN_L039 | VN_C039 | Holcim Vietnam Ltd | VN_UP021 | Holcim Group | 800,000 | VSIC | 2394 |

#### Steel (6%, 1,500 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L040 | VN_C040 | Hoa Phat Dung Quat Steel JSC | VN_UP022 | Hoa Phat Group JSC | 900,000 | VSIC | 2410 |
| VN_L041 | VN_C041 | Pomina Steel Corp | VN_UP023 | Pomina Group | 600,000 | VSIC | 2410 |

#### Coal Mining (5%, 1,250 bn VND)

| id_loan | id_direct_loantaker | name_direct_loantaker | id_ultimate_parent | name_ultimate_parent | loan_size_outstanding | sector_classification_system | sector_classification_direct_loantaker |
|---|---|---|---|---|---|---|---|
| VN_L042 | VN_C042 | Vinacomin - TKV JSC | VN_UP024 | Vietnam National Coal-Mineral Industries Group | 850,000 | VSIC | 0510 |
| VN_L043 | VN_C043 | Dong Bac Corporation | VN_UP025 | Dong Bac Corporation | 400,000 | VSIC | 0510 |

### 3.4 Additional Required Loanbook Columns

For PACTA compatibility, add these columns with the following values:

```
loan_size_outstanding_currency = "VND"
loan_size_credit_limit = loan_size_outstanding * 1.2  (synthetic)
loan_size_credit_limit_currency = "VND"
lei_direct_loantaker = NA  (not available for Vietnamese companies in global LEI registry)
isin_direct_loantaker = NA  (most are unlisted or SOEs)
```

---

## 4. Synthetic ABCD (Asset-Based Company Data)

The ABCD dataset maps individual companies to their physical assets, production capacity, and forward-looking production plans. This is the most labor-intensive dataset to construct for Vietnam because no off-the-shelf ABCD from Asset Impact covers Vietnamese entities adequately.

### 4.1 ABCD Schema

Each row represents one company × technology × year combination:

```
company_id, name_company, lei, sector, technology, production_unit, year, production, emission_factor, plant_location, is_ultimate_owner, emission_factor_unit
```

### 4.2 Technology Mapping

| PACTA Sector | PACTA Technology | Vietnam Equivalent | Production Unit |
|---|---|---|---|
| power | coalcap | Coal thermal plants (Vinh Tan, Duyen Hai, etc.) | MW |
| power | gascap | Gas combined-cycle (Ca Mau, Nhon Trach, Phu My) | MW |
| power | hydrocap | Large hydro (Lai Chau, Tri An, Song Ba Ha) | MW |
| power | renewablescap | Solar + wind (Trung Nam, BIM, T&T) | MW |
| power | oilcap | Oil/diesel peaking (minor) | MW |
| automotive | ice | ICE passenger vehicles (THACO, Toyota VN, Ford VN) | # vehicles |
| automotive | electric | BEV (VinFast) | # vehicles |
| automotive | hybrid | HEV (Honda VN) | # vehicles |
| cement | integrated facility | VICEM, Holcim, Ha Tien (all wet/dry process) | tonnes per year |
| steel | electric | EAF (Pomina, VietSteel) | tonnes per year |
| steel | open_hearth | BOF/BF integrated (Hoa Phat Dung Quat, Formosa) | tonnes per year |
| coal | thermal coal | Vinacomin / TKV domestic extraction | tonnes per year |

### 4.3 Power Sector ABCD (Representative entries, MW capacity, 2025–2030)

The forward-looking production plan encodes how each company's capacity is expected to change, incorporating PDP8 targets and JETP coal retirement schedules.

**Coal companies** (declining capacity trajectory, reflecting PDP8 coal cap):

| company_id | name_company | technology | year | production (MW) | Trajectory logic |
|---|---|---|---|---|---|
| VN_ABCD_001 | EVN (Electricity of Vietnam) | coalcap | 2025 | 12,500 | EVN's coal-attributed capacity (Vinh Tan + Duyen Hai + Uong Bi + Vung Ang) |
| VN_ABCD_001 | EVN (Electricity of Vietnam) | coalcap | 2026 | 12,500 | Stable (no new coal commissioned) |
| VN_ABCD_001 | EVN (Electricity of Vietnam) | coalcap | 2027 | 12,000 | Minor retirement (Uong Bi Unit 1 life-end) |
| VN_ABCD_001 | EVN (Electricity of Vietnam) | coalcap | 2028 | 11,800 | |
| VN_ABCD_001 | EVN (Electricity of Vietnam) | coalcap | 2029 | 11,500 | |
| VN_ABCD_001 | EVN (Electricity of Vietnam) | coalcap | 2030 | 11,000 | PDP8 no-new-coal ceiling |

**Vinacomin Power:**

| company_id | name_company | technology | year | production (MW) |
|---|---|---|---|---|
| VN_ABCD_002 | Vinacomin Power JSC | coalcap | 2025 | 2,600 |
| ... | ... | ... | 2030 | 2,400 |

**BOT coal (Nghi Son 2 — Marubeni/KEPCO):**

| company_id | name_company | technology | year | production (MW) |
|---|---|---|---|---|
| VN_ABCD_005 | Nghi Son Power LLC | coalcap | 2025 | 1,200 |
| ... | ... | ... | 2030 | 1,200 | (BOT contract locks capacity through 2035) |

**Gas companies** (slight growth to 2030, then plateau):

| company_id | name_company | technology | year | production (MW) |
|---|---|---|---|---|
| VN_ABCD_006 | PVN Power Corporation | gascap | 2025 | 4,200 |
| VN_ABCD_006 | PVN Power Corporation | gascap | 2026 | 4,500 |
| VN_ABCD_006 | PVN Power Corporation | gascap | 2027 | 5,200 | (Nhon Trach 3 online) |
| VN_ABCD_006 | PVN Power Corporation | gascap | 2028 | 5,800 | (Nhon Trach 4 online) |
| VN_ABCD_006 | PVN Power Corporation | gascap | 2029 | 6,200 | |
| VN_ABCD_006 | PVN Power Corporation | gascap | 2030 | 6,800 | |

**Renewable companies** (strong growth trajectory):

| company_id | name_company | technology | year | production (MW) |
|---|---|---|---|---|
| VN_ABCD_008 | Trung Nam Group | renewablescap | 2025 | 1,050 | (700 MW solar + 350 MW wind) |
| VN_ABCD_008 | Trung Nam Group | renewablescap | 2026 | 1,350 | +300 MW wind under construction |
| VN_ABCD_008 | Trung Nam Group | renewablescap | 2027 | 1,600 | |
| VN_ABCD_008 | Trung Nam Group | renewablescap | 2028 | 1,900 | |
| VN_ABCD_008 | Trung Nam Group | renewablescap | 2029 | 2,200 | |
| VN_ABCD_008 | Trung Nam Group | renewablescap | 2030 | 2,500 | |

Repeat for: BIM Group, TTC Group, Xuan Thien Group, T&T Group.

**Hydropower** (stable — most large sites already built):

| company_id | name_company | technology | year | production (MW) |
|---|---|---|---|---|
| VN_ABCD_010 | EVN (Electricity of Vietnam) — Hydro | hydrocap | 2025 | 7,800 |
| ... | ... | ... | 2030 | 8,100 | (+300 MW small hydro additions) |
| VN_ABCD_011 | Vietnam Hydropower JSC (VHP) | hydrocap | 2025 | 2,400 |
| ... | ... | ... | 2030 | 2,600 | |

**Emission factors for power:** Use `NA` (not applicable) for all power technologies — PACTA uses MW capacity, not CO2 intensity, for the market share method in power.

### 4.4 Automotive Sector ABCD (# vehicles, 2025–2030)

**THACO** (ICE dominant, no announced EV plans):

| year | ice production | electric | hybrid |
|---|---|---|---|
| 2025 | 120,000 | 0 | 0 |
| 2026 | 125,000 | 0 | 0 |
| 2027 | 128,000 | 0 | 0 |
| 2028 | 130,000 | 0 | 0 |
| 2029 | 130,000 | 0 | 0 |
| 2030 | 128,000 | 0 | 0 |

**Toyota Vietnam** (ICE + minor hybrid introduction):

| year | ice | hybrid |
|---|---|---|
| 2025 | 62,000 | 2,000 |
| 2026 | 60,000 | 4,000 |
| 2027 | 58,000 | 6,000 |
| 2028 | 56,000 | 8,000 |
| 2029 | 54,000 | 10,000 |
| 2030 | 50,000 | 14,000 |

**VinFast** (100% EV, strong growth trajectory):

| year | electric |
|---|---|
| 2025 | 45,000 |
| 2026 | 70,000 |
| 2027 | 100,000 |
| 2028 | 130,000 |
| 2029 | 160,000 |
| 2030 | 200,000 |

Note: VinFast's 2030 projection is ambitious but consistent with their stated plans. Actual delivery may be lower. Use a conservative case (50% discount) in sensitivity analysis.

**Ford Vietnam, Hyundai Thanh Cong:** Similar structure, 100% ICE, gradual sales stabilization.

**Honda Vietnam Auto JSC** (primarily hybrid, small car volumes):

| year | hybrid |
|---|---|
| 2025 | 18,000 |
| 2030 | 22,000 |

### 4.5 Cement Sector ABCD (tonnes/year, 2025–2030)

| company_id | name_company | technology | year | production (Mt/yr) | emission_factor (tCO2/t) |
|---|---|---|---|---|---|
| VN_ABCD_020 | VICEM | integrated facility | 2025 | 12.5 | 0.82 |
| VN_ABCD_020 | VICEM | integrated facility | 2026 | 12.5 | 0.80 |
| VN_ABCD_020 | VICEM | integrated facility | 2027 | 12.8 | 0.79 |
| VN_ABCD_020 | VICEM | integrated facility | 2028 | 13.0 | 0.78 |
| VN_ABCD_020 | VICEM | integrated facility | 2029 | 13.0 | 0.77 |
| VN_ABCD_020 | VICEM | integrated facility | 2030 | 13.2 | 0.76 |
| VN_ABCD_021 | Holcim Vietnam | integrated facility | 2025 | 7.0 | 0.72 | (newer, more efficient kiln) |
| ... | ... | ... | 2030 | 7.5 | 0.65 | |

**Emission factor trend:** Gradual improvement from clinker ratio reduction and some alternative fuels co-processing. PDP8 does not mandate specific cement decarbonization; assume ~1% per year emission intensity improvement from operational efficiency only.

### 4.6 Steel Sector ABCD

| company_id | name_company | technology | year | production (Mt/yr) | emission_factor (tCO2/t steel) |
|---|---|---|---|---|---|
| VN_ABCD_022 | Hoa Phat Dung Quat Steel JSC | open_hearth | 2025 | 7.5 | 1.85 |
| VN_ABCD_022 | Hoa Phat Dung Quat Steel JSC | open_hearth | 2030 | 8.5 | 1.80 |
| VN_ABCD_023 | Pomina Steel Corp | electric | 2025 | 1.2 | 0.58 |
| VN_ABCD_023 | Pomina Steel Corp | electric | 2030 | 1.5 | 0.50 |

**Note:** Hoa Phat's blast furnace/BOF route has very high emissions. Green steel transition (DRI-EAF or hydrogen) is not in their announced 5-year plan — major alignment gap expected.

### 4.7 Coal Mining ABCD

| company_id | name_company | technology | year | production (Mt/yr) | emission_factor |
|---|---|---|---|---|---|
| VN_ABCD_024 | Vinacomin (TKV) | thermal coal | 2025 | 36.0 | NA |
| VN_ABCD_024 | Vinacomin (TKV) | thermal coal | 2026 | 35.5 | NA |
| VN_ABCD_024 | Vinacomin (TKV) | thermal coal | 2027 | 35.0 | NA |
| VN_ABCD_024 | Vinacomin (TKV) | thermal coal | 2028 | 34.0 | NA |
| VN_ABCD_024 | Vinacomin (TKV) | thermal coal | 2029 | 33.0 | NA |
| VN_ABCD_024 | Vinacomin (TKV) | thermal coal | 2030 | 31.0 | NA |
| VN_ABCD_025 | Dong Bac Corporation | thermal coal | 2025 | 4.0 | NA |
| ... | ... | ... | 2030 | 3.5 | NA |

### 4.8 Plant Location Codes

Use ISO 3166-1 alpha-2: `VN` for all Vietnamese domestic operations. For BOT projects with foreign parent (Nghi Son 2: Japan/Korea parent), set `plant_location = "VN"` and `is_ultimate_owner = FALSE` for the local entity.

---

## 5. Scenario Selection & Vietnam Adaptation

### 5.1 Global Scenarios Available in PACTA

| Scenario | Source | Coverage | Character |
|---|---|---|---|
| IEA NZE 2050 | IEA World Energy Outlook | Global | Most ambitious — net zero by 2050 |
| IEA SDS (Sustainable Dev.) | IEA WEO | Global | Below 2°C pathway |
| IEA STEPS (Stated Policies) | IEA WEO | Global | Current policies extended |
| NGFS Net Zero 2050 | NGFS | Global | 1.5°C with carbon capture |
| NGFS Current Policies | NGFS | Global | No new climate action |
| NGFS NDC | NGFS | Global | Nationally determined contributions |

For the Vietnam scenario, **use three scenarios** to show the range:

1. **Benchmark (global):** IEA STEPS — what happens with current global policies (no further ambition)
2. **Paris-aligned (global):** IEA NZE 2050 — what global net zero requires
3. **Vietnam-specific:** PDP8 scenario — what Vietnam's own plan says (custom-built, see §5.3)

### 5.2 Scenario Data Format Required by PACTA

**Market share scenario** (`scenario` table structure):

```
scenario_source, scenario, sector, technology, region, year, smsp, tmsr
```

Where:
- `smsp` = Sector Market Share Pathway — target share of that technology in total sector production
- `tmsr` = Technology Market Share Ratio — change in absolute production vs base year
- `region` = geographic scope (use `"global"` for IEA scenarios; add `"asia_pacific"` if available)

**CO2 intensity scenario** (`co2_intensity_scenario` table structure):

```
scenario_source, scenario, sector, region, year, emission_factor_unit, emission_factor_value
```

### 5.3 Vietnam PDP8 Scenario: Custom Construction

The PDP8 scenario does not exist as a downloadable PACTA scenario file. It must be constructed manually based on the capacity targets published in Decision 500/QD-TTg (May 2023). This is the single most important Vietnam-specific input.

#### 5.3.1 Power Technology Mix Pathway (SMSP — share of total capacity)

Base: 2025 installed capacity ≈ 80 GW total

| Technology | 2025 | 2026 | 2027 | 2028 | 2029 | 2030 | Source |
|---|---|---|---|---|---|---|---|
| coalcap | 32% | 31% | 30% | 29% | 28% | 26% | PDP8 coal cap 30.2 GW / 116 GW 2030 total |
| gascap | 12% | 13% | 14% | 15% | 16% | 17% | PDP8 gas 22.4 GW / 116 GW |
| hydrocap | 26% | 25% | 24% | 23% | 22% | 21% | PDP8 hydro 29.3 GW, stable |
| renewablescap | 26% | 28% | 30% | 31% | 32% | 34% | PDP8 solar 46.9 + wind 27.9 = 74.8 GW |
| oilcap | 4% | 3% | 2% | 2% | 2% | 2% | Peakers, slowly retired |

Convert to TMSR (ratio vs 2025 base):

| Technology | 2025 | 2026 | 2027 | 2028 | 2029 | 2030 |
|---|---|---|---|---|---|---|
| coalcap | 1.00 | 1.00 | 0.97 | 0.94 | 0.90 | 0.87 | (cap, no growth) |
| gascap | 1.00 | 1.12 | 1.28 | 1.46 | 1.65 | 1.88 | (growth to LNG) |
| hydrocap | 1.00 | 1.00 | 1.02 | 1.04 | 1.05 | 1.07 | (minor small hydro additions) |
| renewablescap | 1.00 | 1.18 | 1.40 | 1.65 | 1.95 | 2.30 | (aggressive buildout) |
| oilcap | 1.00 | 0.90 | 0.80 | 0.75 | 0.70 | 0.65 | (retire peakers) |

#### 5.3.2 Automotive Technology Mix Pathway (Vietnam NDC-aligned)

Base: Vietnam total new car market 2025 ≈ 620,000 vehicles/year

| Technology | 2025 | 2026 | 2027 | 2028 | 2029 | 2030 | Source |
|---|---|---|---|---|---|---|---|
| ice | 95% | 91% | 85% | 78% | 70% | 60% | NDC target 100% EV sales by 2040; gradual path |
| electric | 2% | 5% | 9% | 14% | 20% | 28% | VinFast + new entrants |
| hybrid | 3% | 4% | 6% | 8% | 10% | 12% | Bridge technology |

#### 5.3.3 Cement CO2 Intensity Pathway (Vietnam BAU vs Efficiency)

Vietnam has no binding cement decarbonization roadmap separate from NDC's general 15.8% target. Construct two sub-pathways:

- **BAU:** 0.5% annual intensity reduction (operational efficiency only) → 0.82 → 0.78 tCO2/t by 2030
- **NDC conditional:** 2% annual intensity reduction (alternative fuels, clinker substitution) → 0.82 → 0.71 tCO2/t by 2030
- **IEA NZE global:** 0.54 tCO2/t by 2030 (requires CCS + green hydrogen — not currently available in Vietnam)

For the PACTA `co2_intensity_scenario` table, encode the NDC conditional pathway as `scenario = "pdp8_ndc"`.

#### 5.3.4 Steel CO2 Intensity Pathway

| Scenario | 2025 | 2030 | 2035 | 2050 |
|---|---|---|---|---|
| Vietnam BAU | 1.75 | 1.65 | 1.55 | 1.40 |
| NDC conditional | 1.75 | 1.50 | 1.30 | 0.90 |
| IEA NZE global | 1.75 | 1.30 | 0.80 | 0.10 |

Hoa Phat's blast furnace route cannot achieve NZE targets without complete plant replacement (2040+ timeframe). This will generate the largest alignment gap in the analysis.

### 5.4 Region Mapping

PACTA uses `region_isos` to map ISO country codes to scenario regions. Vietnam (`VN`) maps to:
- `"asia_pacific"` in IEA WEO scenarios
- `"non-OECD Asia"` in NGFS scenarios
- `"global"` (fallback, always required)

**Action required:** Create a custom `region_isos_vietnam` table that maps `"VN"` to `"vietnam"` as a custom region when using the PDP8 scenario, and add `region = "vietnam"` rows to the scenario tables.

```r
# Custom region mapping for Vietnam PDP8 scenario
region_isos_vietnam <- tibble(
  region = c("global", "vietnam", "asia_pacific"),
  isos   = c("vn",     "vn",      "vn")
)
```

---

## 6. Data Pipeline: Generation & Formatting

### 6.1 File Structure

Create the following new directories and files within the repo:

```
pacta-vietnam/
├── data/
│   ├── vietnam_loanbook.csv          # 43-row synthetic MCB loanbook
│   ├── vietnam_abcd.csv              # ~1,500-row ABCD (43 companies × ~6 techs × 6 years)
│   ├── vietnam_scenario_ms.csv       # Market share scenario (power + automotive)
│   ├── vietnam_scenario_co2.csv      # CO2 intensity scenario (cement + steel)
│   └── vietnam_region_isos.csv       # VN country-region mapping
├── scripts/
│   └── pacta_vietnam_scenario.R      # New script: full Vietnam pipeline
└── plans/
    └── vietnam_bank_pacta_scenario_plan.md   # This document
```

### 6.2 Data Generation Script (`data/generate_vietnam_data.R`)

Write a standalone R script that generates all five CSV files from inline data structures. This ensures reproducibility — no external data sources required. Key sections:

```r
# ============================================================
# generate_vietnam_data.R
# Generates all synthetic Vietnam PACTA input data
# ============================================================

library(dplyr)
library(readr)

# SECTION A: Loanbook
# -----------------------------------------------------------
vietnam_loanbook <- tribble(
  ~id_loan,  ~id_direct_loantaker, ~name_direct_loantaker,
  ~id_ultimate_parent, ~name_ultimate_parent,
  ~loan_size_outstanding, ~loan_size_outstanding_currency,
  ~loan_size_credit_limit, ~loan_size_credit_limit_currency,
  ~sector_classification_system, ~sector_classification_direct_loantaker,
  ~lei_direct_loantaker, ~isin_direct_loantaker,
  # Power - Coal
  "VN_L001", "VN_C001", "Nhiet Dien Vinh Tan 1 JSC",
    "VN_UP001", "EVN (Electricity of Vietnam)",
    800000000, "VND", 960000000, "VND",
    "VSIC", "3511", NA, NA,
  # ... (all 43 loans)
)
write_csv(vietnam_loanbook, "data/vietnam_loanbook.csv")

# SECTION B: ABCD
# -----------------------------------------------------------
# Use expand.grid() to generate year × company × technology combinations
years <- 2025:2030

evn_coal <- tibble(
  company_id = "VN_ABCD_001",
  name_company = "EVN (Electricity of Vietnam)",
  lei = NA,
  sector = "power",
  technology = "coalcap",
  production_unit = "MW",
  year = years,
  production = c(12500, 12500, 12000, 11800, 11500, 11000),
  emission_factor = NA,
  plant_location = "VN",
  is_ultimate_owner = TRUE,
  emission_factor_unit = NA
)
# ... (all company/technology combinations)

vietnam_abcd <- bind_rows(evn_coal, evn_gas, evn_hydro, evn_solar, ...)
write_csv(vietnam_abcd, "data/vietnam_abcd.csv")

# SECTION C: Market Share Scenario (PDP8)
# -----------------------------------------------------------
pdp8_power_smsp <- tribble(
  ~scenario_source, ~scenario,   ~sector,      ~technology,    ~region,    ~year, ~smsp,  ~tmsr,
  "pdp8_2023",      "pdp8_ndc",  "power",      "coalcap",      "vietnam",  2025,  0.32,   1.00,
  "pdp8_2023",      "pdp8_ndc",  "power",      "coalcap",      "vietnam",  2030,  0.26,   0.87,
  # ... (all tech × year combinations, interpolated for intermediate years)
)

# SECTION D: CO2 Intensity Scenario
# -----------------------------------------------------------
pdp8_co2 <- tribble(
  ~scenario_source, ~scenario,   ~sector,   ~region,    ~year, ~emission_factor_unit,           ~emission_factor_value,
  "pdp8_2023",      "pdp8_ndc",  "cement",  "vietnam",  2025,  "tonnes of CO2 per tonne",       0.82,
  "pdp8_2023",      "pdp8_ndc",  "cement",  "vietnam",  2030,  "tonnes of CO2 per tonne",       0.71,
  # ... steel rows
)

# SECTION E: Region ISOs
region_isos_vn <- tibble(
  region = c("global", "vietnam", "asia_pacific"),
  isos   = c("vn",     "vn",      "vn")
)
write_csv(region_isos_vn, "data/vietnam_region_isos.csv")
```

### 6.3 VSIC → PACTA Sector Mapping

PACTA's `sector_classifications` reference table uses NACE, ISIC, and NAICS codes. Vietnam's VSIC 2018 is structurally based on ISIC Rev.4, so most codes map directly. Key mappings needed:

| VSIC Code | VSIC Description | PACTA Sector |
|---|---|---|
| 3511 | Production of electric power | power |
| 2910 | Manufacture of motor vehicles | automotive |
| 2394 | Manufacture of cement, lime and plaster | cement |
| 2410 | Manufacture of basic iron and steel | steel |
| 0510 | Mining of hard coal | coal |
| 0610 | Extraction of crude petroleum | oil and gas |
| 5110 | Passenger air transport | aviation |

**Implementation:** Two options:
1. **Use ISIC codes directly** in the loanbook (since VSIC ≈ ISIC Rev.4), setting `sector_classification_system = "ISIC"` — this works with `r2dii.data::sector_classifications` without modification.
2. **Create a custom `sector_classifications` extension** that adds `code_system = "VSIC"` rows mirroring ISIC Rev.4.

**Recommended:** Option 1 (use ISIC codes). VSIC 3511 = ISIC 3511. Change column to `sector_classification_system = "ISIC"` in the loanbook. Verify each sector code maps correctly before running.

---

## 7. Running the PACTA Analysis

### 7.1 Vietnam Pipeline Script (`scripts/pacta_vietnam_scenario.R`)

Adapt `scripts/pacta_synthesis.R` with these changes:

```r
# ============================================================
# pacta_vietnam_scenario.R
# Full Vietnam-specific PACTA pipeline
# ============================================================
# Run: Rscript scripts/pacta_vietnam_scenario.R

library(pacta.loanbook)
library(r2dii.data)
library(r2dii.match)
library(r2dii.analysis)
library(r2dii.plot)
library(dplyr); library(tidyr); library(ggplot2)
library(scales); library(ggrepel); library(readr)

# STEP 1: Load Vietnam data (not demo data)
loanbook <- read_csv("data/vietnam_loanbook.csv")
abcd     <- read_csv("data/vietnam_abcd.csv")
scenario <- read_csv("data/vietnam_scenario_ms.csv")     # PDP8 market share scenario
co2      <- read_csv("data/vietnam_scenario_co2.csv")    # PDP8 CO2 intensity scenario
region   <- read_csv("data/vietnam_region_isos.csv")

# STEP 2: Sector pre-join (using ISIC codes)
# Replace sector_classification_system with "ISIC" if using VSIC codes as ISIC
loanbook_classified <- loanbook %>%
  mutate(sector_classification_direct_loantaker =
           as.character(sector_classification_direct_loantaker)) %>%
  left_join(sector_classifications, by = c(
    "sector_classification_system" = "code_system",
    "sector_classification_direct_loantaker" = "code"
  )) %>%
  rename(sector_classified = sector, borderline_classified = borderline)

# STEP 3: Matching (Vietnamese company names with diacritic handling)
# CRITICAL: Set min_score = 0.7 initially for Vietnamese names.
# Vietnamese diacritics (Vinh Tân vs Vinh Tan) will cause fuzzy score drops.
# Strategy: Use ASCII-normalized names in both loanbook and ABCD, then
# apply the diacritic-normalized original names as display labels.

# Normalize diacritics in both tables before matching:
library(stringi)
loanbook_norm <- loanbook_classified %>%
  mutate(name_direct_loantaker_orig = name_direct_loantaker,
         name_direct_loantaker = stri_trans_general(name_direct_loantaker, "Latin-ASCII"))
abcd_norm <- abcd %>%
  mutate(name_company_orig = name_company,
         name_company = stri_trans_general(name_company, "Latin-ASCII"))

matched_raw <- match_name(loanbook_norm, abcd_norm, min_score = 0.8, by_sector = TRUE)

# Manual review: write to CSV, check Vietnamese company matches
write_csv(matched_raw, "data/vietnam_matched_for_review.csv")

# After review: re-import and prioritize
# (For the synthetic dataset, since names are designed to match, proceed directly)
matched_prioritized <- prioritize(matched_raw)

# STEP 4: Market Share Targets
ms_targets_portfolio <- target_market_share(
  data        = matched_prioritized,
  abcd        = abcd_norm,
  scenario    = scenario,
  region_isos = region
)
ms_targets_company <- target_market_share(
  data             = matched_prioritized,
  abcd             = abcd_norm,
  scenario         = scenario,
  region_isos      = region,
  by_company       = TRUE,
  weight_production = FALSE
)

# STEP 5: SDA Targets
sda_targets <- target_sda(
  data                   = matched_prioritized,
  abcd                   = abcd_norm,
  co2_intensity_scenario = co2,
  region_isos            = region
)

# STEP 6: Alignment calculations
# Use "pdp8_ndc" scenario name throughout
# (metric names will follow the pattern: target_pdp8_ndc, adjusted_scenario_pdp8_ndc)
# Always inspect unique(sda_targets$emission_factor_metric) before filtering
```

### 7.2 Three-Scenario Comparison Run

Run the analysis three times, loading different scenario tables:

```r
# Scenario 1: IEA STEPS (global current policies benchmark)
scenario_steps <- read_csv("data/iea_weo_steps_2023.csv")
ms_steps <- target_market_share(data = matched_prioritized, abcd = abcd_norm,
                                 scenario = scenario_steps, region_isos = region)

# Scenario 2: IEA NZE (Paris-aligned benchmark)
scenario_nze <- read_csv("data/iea_weo_nze_2023.csv")
ms_nze <- target_market_share(data = matched_prioritized, abcd = abcd_norm,
                               scenario = scenario_nze, region_isos = region)

# Scenario 3: Vietnam PDP8/NDC (custom domestic scenario)
scenario_pdp8 <- read_csv("data/vietnam_scenario_ms.csv")
ms_pdp8 <- target_market_share(data = matched_prioritized, abcd = abcd_norm,
                                scenario = scenario_pdp8, region_isos = region)

# Combine for comparison
ms_all <- bind_rows(
  ms_steps %>% mutate(scenario_label = "IEA STEPS"),
  ms_nze   %>% mutate(scenario_label = "IEA NZE"),
  ms_pdp8  %>% mutate(scenario_label = "Vietnam PDP8/NDC")
)
```

### 7.3 Critical Pre-Run Checks

Before executing, verify:

1. **Schema check:** `names(vietnam_loanbook)` matches required columns from `r2dii.data::loanbook_demo`
2. **Sector code check:** All ISIC codes in `loanbook$sector_classification_direct_loantaker` appear in `sector_classifications$code` (for system = "ISIC")
3. **ABCD sector/tech check:** All `sector × technology` combinations in `vietnam_abcd` are valid PACTA combinations (reference `r2dii.data::abcd_demo` for valid pairs)
4. **Scenario year range:** Scenario table covers 2025–2030 (PACTA needs base year + forecast horizon)
5. **Region match:** `region_isos` contains a row for `"vn"` (lowercase ISO code) in at least the `"global"` region

---

## 8. Expected Outputs & Interpretation

### 8.1 Power Sector — Market Share Results

**Projected trajectory** (MCB portfolio):
- Coal share: declining from ~45% → ~38% by 2030 (because MCB has large coal loans, but EVN's coal capacity is only marginally declining, while EVN's gas and renewables are growing faster → coal loses share)
- Renewable share: growing from ~26% → ~34% (driven by Trung Nam, BIM, TTC, Xuan Thien growth plans)

**Versus PDP8/NDC scenario targets:**
- Coal: MCB's projected coal share may **exceed** PDP8 targets if BOT coal plants (Nghi Son 2) maintain capacity per contract
- Renewables: MCB's projected renewables share may **fall short** of PDP8's 34% target if private IPP growth is slower than projected
- Gas: likely roughly aligned (MCB has PVN Power loans covering the LNG expansion)

**Expected result:** Partial alignment — coal misaligned (too high), renewables borderline, gas aligned.

**Versus IEA NZE:**
- Coal: severely misaligned (NZE requires near-zero coal by 2040; MCB's coal loans undermine this)
- Renewables: misaligned (NZE requires faster buildout than PDP8)
- **Verdict:** MCB portfolio is NOT Paris-aligned under IEA NZE — expected and instructive finding.

### 8.2 Automotive Sector — Market Share Results

**Projected trajectory:**
- THACO + Toyota + Ford dominate MCB's auto exposure → ICE share ~95% of portfolio-weighted production
- VinFast loans are small (4% exposure) relative to THACO (13%)
- EV share: projected ~8–10% by 2030 (weighted by loan size, not units)

**Versus PDP8/NDC targets:**
- PDP8/NDC requires 28% EV share by 2030
- MCB projected: ~10%
- **Gap:** -18pp EV share — major misalignment

**Versus IEA NZE:**
- NZE requires ~50% EV by 2030 globally
- **Gap:** >-40pp — very large

**Engagement opportunity:** The auto analysis identifies THACO as the most important borrower to engage on electrification strategy. Toyota's hybrid expansion is the best transition signal.

### 8.3 Cement Sector — SDA Results

- VICEM + Holcim projected intensity: ~0.80 tCO2/t by 2025, declining to ~0.74 by 2030
- PDP8/NDC conditional target: ~0.71 by 2030
- IEA NZE target: ~0.54 by 2030
- **Result vs PDP8:** Marginally misaligned (gap ~0.03 tCO2/t)
- **Result vs NZE:** Significantly misaligned (gap ~0.20 tCO2/t — requires CCS not available in Vietnam)

### 8.4 Steel Sector — SDA Results

- Hoa Phat projected: 1.85 tCO2/t (BF/BOF route, no planned DRI/EAF transition)
- PDP8/NDC target: 1.50 by 2030
- IEA NZE target: 1.30 by 2030
- **Gap vs PDP8:** -0.35 tCO2/t — major misalignment
- **Gap vs NZE:** -0.55 tCO2/t — critical misalignment

Pomina (EAF route): ~0.58 tCO2/t — already roughly aligned with NZE 2030 target. Demonstrates that MCB's steel exposure quality depends heavily on which steelmaker.

### 8.5 Coal Mining — Coal Sector

MCB loans to TKV/Vinacomin and Dong Bac: thermal coal production declining ~14% by 2030 (from 40 Mt to 35 Mt).

**Versus IEA NZE:** NZE requires halving global thermal coal production by 2030. Vietnam domestic coal production declining only ~14% = severely misaligned. However, Vietnam coal is mainly consumed domestically — the link to global coal demand curves is indirect.

### 8.6 Alignment Summary Table (Expected)

| Sector | Technology | Scenario | Gap Direction | Magnitude | Risk Level |
|---|---|---|---|---|---|
| Power | coal | PDP8 | Misaligned (too much) | +2–4pp share | HIGH |
| Power | renewables | PDP8 | Borderline | ±1–2pp | MEDIUM |
| Power | coal | IEA NZE | Severely misaligned | +15–20pp | CRITICAL |
| Automotive | electric | PDP8 | Misaligned (too little) | -15–20pp | HIGH |
| Automotive | ice | PDP8 | Misaligned (too much) | +15–20pp | HIGH |
| Cement | — | PDP8 | Marginally misaligned | +0.03 tCO2/t | LOW |
| Cement | — | IEA NZE | Severely misaligned | +0.20 tCO2/t | HIGH |
| Steel | — | PDP8 | Major misalignment | +0.35 tCO2/t | HIGH |
| Coal | — | IEA NZE | Severe | -50% target not met | CRITICAL |

---

## 9. Visualization & Reporting for a Vietnam Bank Audience

### 9.1 Key Charts to Produce

Adapt the existing `pacta_synthesis.R` visualization section with Vietnam-specific labels, colors, and context:

**Chart 1: Portfolio Coverage Map**
- Pie chart: % of total exposure covered by PACTA analysis vs. not-in-scope
- Expected: ~85–90% coverage (Vietnam bank books are concentrated in PACTA-relevant sectors)
- Label in Vietnamese: "Danh mục được phân tích theo PACTA" / "Ngoài phạm vi"

**Chart 2: Power Technology Mix (3 scenarios)**
- `qplot_techmix()` adapted for PDP8 scenario data
- Show 2025 base vs 2030 target
- Overlay MCB projected mix vs PDP8 target vs NZE target
- Add callout annotation: "PDP8 yêu cầu giảm than xuống 26% vào năm 2030"

**Chart 3: Coal Capacity Trajectory**
- Line chart: MCB portfolio's coal capacity projection vs PDP8 coal ceiling vs NZE phase-down
- Use `qplot_trajectory()` filtered to `technology == "coalcap"`
- Critical chart — most important for JETP/ESG context

**Chart 4: Renewables Buildout Trajectory**
- MCB's renewables exposure vs PDP8 target vs NZE target
- Show how MCB's solar/wind loans help (positive story)

**Chart 5: Automotive Technology Mix**
- Three-scenario comparison for 2030 auto mix
- Highlight VinFast's role (positive) and THACO's ICE concentration (risk)

**Chart 6: Cement Emission Intensity**
- `qplot_emission_intensity()` for cement
- Show MCB trajectory vs PDP8 conditional target vs NZE target

**Chart 7: Steel Emission Intensity**
- Show Hoa Phat (BF/BOF, high) vs Pomina (EAF, aligned)
- Disaggregate by company to show within-sector diversity

**Chart 8: Multi-Sector Alignment Overview**
- Traffic light / heatmap format
- Rows: sector/technology pairs; Columns: PDP8, NZE
- Color: green (aligned), amber (borderline), red (misaligned)

**Chart 9: Borrower-Level Heatmap (Top 10 by Exposure)**
- X-axis: top borrowers ranked by loan size
- Y-axis: sector/technology
- Cell color: alignment status
- Useful for loan officer action planning

### 9.2 Report Structure (for Vietnam Bank Stakeholders)

Produce a Vietnamese-language-compatible HTML report with 12 sections:

1. **Tóm tắt điều hành (Executive Summary):** One-page alignment verdict with traffic light summary
2. **Bối cảnh phương pháp luận PACTA (Methodology):** What PACTA measures, why it matters for Vietnam banks
3. **Bối cảnh Việt Nam (Vietnam Context):** PDP8, NDC, JETP commitments and timelines
4. **Danh mục cho vay của MCB (MCB Loanbook):** Sector breakdown, coverage statistics
5. **Phân tích ngành điện (Power Sector):** Coal/gas/renewable trajectory vs PDP8 and NZE
6. **Phân tích ngành ô tô (Automotive):** ICE vs EV projection vs NDC targets
7. **Phân tích xi măng (Cement):** Emission intensity trajectories
8. **Phân tích thép (Steel):** Emission intensity by technology type
9. **Phân tích than (Coal Mining):** Production trajectory vs global phase-down
10. **Phân tích cấp độ doanh nghiệp (Company-Level):** Top 10 misaligned borrowers
11. **Khuyến nghị hành động (Recommendations):** Borrower engagement, new credit criteria, portfolio rebalancing
12. **Phụ lục (Appendices):** Data dictionary, matched loans list, methodology notes

### 9.3 Key Messages for Vietnam Bank Audience

Frame the results around three local banking priorities:

**1. Regulatory risk:** The State Bank of Vietnam (SBV) is developing green credit guidelines (2023 Green Credit framework). PACTA results show which loans will face increasing regulatory scrutiny.

**2. Stranded asset risk:** Coal loans to EVN, Vinacomin, and BOT projects carry 10–15 year stranded asset risk as JETP coal retirement programs accelerate. Quantify: MCB has 7,000 bn VND in coal exposure; if 20% becomes impaired → 1,400 bn VND NPL risk.

**3. Green opportunity:** MCB's solar and wind loans (3,250 bn VND combined) are already aligned with PDP8. Opportunity to grow green lending to 15–20% of portfolio by 2030 (from current ~13%).

---

## 10. Gaps, Workarounds & Known Limitations

### 10.1 No Off-the-Shelf Vietnam ABCD

**Problem:** Asset Impact (the primary ABCD provider for global PACTA) does not cover Vietnamese companies comprehensively. EVN, PVN, THACO, and VinFast are not in the demo `abcd_demo` dataset.

**Workaround:** Build custom ABCD from public sources:
- EVN Annual Report (installed capacity by power plant, 5-year investment plan)
- PDP8 Annex tables (commissioned capacity by technology and year)
- VAMA (Vietnam Automobile Manufacturers' Association) annual production statistics
- VICEM and Hoa Phat annual reports (production volume and capex plans)
- TKV Annual Report (coal production tonnage and mine development plans)

**Quality flag:** Mark all custom ABCD rows with `data_source = "mcb_synthetic_2025"` in a custom metadata column. Do not present results as if they came from audited asset-level data.

### 10.2 Vietnamese Name Matching Challenges

**Problem:** Vietnamese company names contain diacritical marks (Nhà máy Nhiệt điện Vĩnh Tân). Fuzzy string matching degrades sharply when encoding differs between loanbook (bank system may strip diacritics) and ABCD (constructed with diacritics or vice versa).

**Workaround:** ASCII-normalize all names before calling `match_name()` using `stringi::stri_trans_general(name, "Latin-ASCII")`. Apply consistently to both loanbook and ABCD. Store original names separately for display purposes. Consider adding a manual name correction table (`overrides.csv`) for known company aliases (e.g., "EVN" → "Electricity of Vietnam").

### 10.3 Currency (VND) — No Impact on Analysis

PACTA's alignment calculations are ratio-based (technology share, emission intensity). The absolute loan amounts in VND are used only for loan-size weighting in the matching step. No currency conversion is needed. However, all chart labels should display amounts in billion VND (bn VND) or trillion VND (nghìn tỷ đồng) — not USD — to make results meaningful to Vietnamese bank executives.

### 10.4 BOT Coal Contract Lock-In

**Problem:** BOT coal projects (e.g., Nghi Son 2 — Marubeni/KEPCO) have long-term power purchase agreements (PPAs) with EVN that guarantee capacity payments until ~2035. The ABCD data should NOT show declining capacity for these plants before 2035, even if global scenarios require coal phase-out.

**Workaround:** In the ABCD for BOT coal, set flat capacity through the PPA expiry year, then model a cliff-edge decline. Add a footnote in the report: "BOT coal plants have contracted PPA obligations that prevent early retirement without government buyout. Alignment is legally constrained, not just financially."

### 10.5 No Vietnam-Specific IEA Scenario Data

**Problem:** IEA NZE and STEPS scenarios are published at global, regional (Asia Pacific), or select-country (India, China, US, EU, Indonesia) levels. Vietnam-specific IEA pathways do not exist in publicly available PACTA scenario files.

**Workaround A:** Use `region = "asia_pacific"` as the closest IEA region for Vietnam when running IEA scenarios. This introduces noise (Asia Pacific includes China/India/Japan/Korea with different energy mixes), but provides a reasonable global benchmark.

**Workaround B:** Use the PDP8 custom scenario as the primary Vietnam alignment benchmark. IEA NZE serves as the "aspirational global" comparison only.

**Workaround C (advanced):** Construct a `vietnam_nze` scenario by scaling IEA NZE Asia Pacific pathway to Vietnam's power sector size using PDP8 capacity data. This is more rigorous but requires additional modeling.

### 10.6 SDA Method Not Ideal for Coal Mining

**Problem:** PACTA's coal mining analysis uses absolute production levels (market share method, not SDA). This works for power and automotive but coal mining requires tracking production decline rate against global demand curves.

**Workaround:** For coal mining, compute the **portfolio coal production trajectory** (from ABCD weighted by loan size) and compare against:
- NGFS NZ2050 coal demand curve for Asia-Pacific
- IEA NZE coal demand curve

Present as a custom "coal production corridor" chart rather than using `target_market_share()` directly, since Vietnam domestic coal (thermal) isn't in the standard PACTA coal scenario technology definitions.

### 10.7 VinFast Data Uncertainty

**Problem:** VinFast's actual production and delivery data are uncertain. The company has faced production ramp-up challenges. Their stated 2030 targets (200,000 vehicles/year Vietnam domestic) may be optimistic.

**Workaround:** Run **two versions** of the automotive ABCD:
- **Base case:** VinFast as stated plans (200,000 EV/year by 2030)
- **Conservative case:** VinFast at 50% of stated plans (100,000 EV/year by 2030)

Show both in the automotive trajectory chart. Demonstrates sensitivity of portfolio alignment to a single large borrower.

### 10.8 Upstream vs. Downstream Lending

**Problem:** PACTA is designed for **corporate loans** to producers (power companies, car manufacturers). Vietnamese banks also lend to:
- Project finance for power plants (SPV loans) — PACTA can handle these
- Coal traders / commodity financing — not in PACTA scope
- Retail auto loans for individual car buyers — not in PACTA scope
- Real estate loans to coal-dependent industrial zones — not in PACTA scope

**Limitation:** The PACTA analysis covers only the corporate lending book's climate-relevant portion. Retail, real estate, and commodity segments require separate climate risk frameworks.

---

## 11. Implementation Roadmap

### Phase 1: Data Construction (Weeks 1–3)

**Week 1:**
- [ ] Write `data/generate_vietnam_data.R` — generates all 5 input CSVs
- [ ] Complete loanbook (43 loans), verify schema matches `loanbook_demo`
- [ ] Complete ABCD (all companies × 6 years × relevant technologies), verify sector/tech pairs

**Week 2:**
- [ ] Construct PDP8 market share scenario (power + automotive) — interpolate yearly values
- [ ] Construct PDP8 CO2 intensity scenario (cement + steel)
- [ ] Build region_isos_vietnam table; verify "vn" maps to both "vietnam" and "global" regions
- [ ] Test all CSVs with `readr::problems()` to catch format issues

**Week 3:**
- [ ] VSIC → ISIC mapping validation: run each sector code through `sector_classifications` and confirm match
- [ ] ASCII normalization of all company names
- [ ] Manual name alignment table (`overrides.csv`) for any company name variant known to cause matching failures

### Phase 2: Pipeline Development (Weeks 4–6)

**Week 4:**
- [ ] Write `scripts/pacta_vietnam_scenario.R` — adapt `pacta_synthesis.R` for Vietnam data
- [ ] Run Phase 1 (data load + sector pre-join) — verify loanbook_classified has correct sector columns
- [ ] Run Phase 2 (matching) — inspect matched_raw, check match scores, identify failures

**Week 5:**
- [ ] Manual review of matches scoring < 1.0 (expected: many, given Vietnam name complexity)
- [ ] Run Phase 3 (market share targets for power + automotive with PDP8 scenario)
- [ ] Run Phase 4 (SDA targets for cement + steel with PDP8 CO2 scenario)
- [ ] Verify output structure: `unique(ms_targets$metric)` and `unique(sda_targets$emission_factor_metric)`

**Week 6:**
- [ ] Alignment gap calculations (projected vs target_pdp8_ndc)
- [ ] Three-scenario comparison run (STEPS, NZE, PDP8)
- [ ] Debug any NA issues (likely in power sector at 2026+ if ABCD projection years don't extend far enough)

### Phase 3: Visualization & Report (Weeks 7–9)

**Week 7:**
- [ ] Charts 1–4: Coverage, Power tech mix, Coal trajectory, Renewables trajectory
- [ ] Charts 5–7: Auto tech mix, Cement SDA, Steel SDA
- [ ] Charts 8–9: Multi-sector overview, Borrower heatmap

**Week 8:**
- [ ] Draft HTML report structure (12 sections from §9.2)
- [ ] Embed all charts as base64 PNG (using existing `img_to_base64()` helper)
- [ ] Write Vietnam-specific interpretive text for each section
- [ ] Add PDP8 and JETP context callouts

**Week 9:**
- [ ] Internal review with PACTA methodology check
- [ ] Sensitivity analysis: VinFast conservative case, JETP coal retirement acceleration
- [ ] Final HTML report output: `reports/PACTA_Vietnam_Bank_Report.html`
- [ ] Save company-level results for borrower engagement workbook

### Phase 4: Optional Extensions (Weeks 10+)

- [ ] **R Markdown version:** Convert `pacta_vietnam_scenario.R` to `.Rmd` literate notebook for internal knowledge transfer
- [ ] **Shiny dashboard:** Interactive sector/technology/scenario explorer for non-technical bank staff
- [ ] **Oil & gas sector:** Add PVN upstream (PetroVietnam Exploration and Production) to loanbook and ABCD
- [ ] **Quarterly rerun framework:** Schedule script to update with new EVN capacity addition reports each quarter
- [ ] **SBV regulatory mapping:** Map PACTA results to the State Bank of Vietnam's green credit classification taxonomy (Circular 17/2022/TT-NHNN)
- [ ] **Physical risk overlay:** Add coastal/flood exposure flag to power plant locations (Vinh Tan, Duyen Hai, Ca Mau — all in high climate-physical-risk zones)

---

## Appendix A: Key Data Sources

| Data | Source | URL / Reference |
|---|---|---|
| PDP8 capacity targets | Vietnamese Ministry of Industry and Trade | Decision 500/QD-TTg, May 2023 |
| Vietnam NDC 2022 | UNFCCC Vietnam submission | https://unfccc.int/documents/461551 |
| EVN capacity statistics | EVN Annual Report 2023 | https://www.evn.com.vn |
| VAMA auto sales | Vietnam Automobile Manufacturers' Association | https://www.vama.org.vn |
| TKV coal production | Vinacomin Annual Report | https://www.vinacomin.vn |
| VICEM cement production | VICEM Annual Report | https://www.vicem.vn |
| Hoa Phat steel | Hoa Phat Group Annual Report | https://hoaphat.com.vn |
| JETP Vietnam commitments | COP26 JETP declaration | https://www.iea.org/news/viet-nam-partnership-for-just-energy-transition |
| IEA WEO scenarios | IEA World Energy Outlook 2023 | https://www.iea.org/reports/world-energy-outlook-2023 |
| NGFS scenarios | NGFS Scenario Explorer | https://www.ngfs.net/ngfs-scenarios-portal |
| PACTA methodology | RMI/2DII | https://pacta.rmi.org/pacta-for-banks-2020 |
| r2dii packages | CRAN / GitHub | https://rmi-pacta.github.io/pacta.loanbook |
| SBV green credit taxonomy | State Bank of Vietnam | Circular 17/2022/TT-NHNN |

---

## Appendix B: R Package Requirements

All packages from the existing environment plus:

```r
install.packages(c(
  "pacta.loanbook",   # core PACTA pipeline
  "r2dii.plot",       # standardized PACTA charts
  "stringi",          # Vietnamese diacritic normalization (NEW)
  "dplyr",
  "tidyr",
  "ggplot2",
  "ggrepel",
  "scales",
  "readr",
  "base64enc"
), lib = Sys.getenv("R_LIBS_USER"))
```

Note: `stringi` is the key new dependency for Vietnamese text normalization. It handles Unicode diacritic stripping far more reliably than `iconv()` or `gsub()` approaches.

---

## Appendix C: Glossary (English / Vietnamese)

| English | Vietnamese | Definition |
|---|---|---|
| PACTA | PACTA | Paris Agreement Capital Transition Assessment |
| Loanbook | Danh mục cho vay | Bank's portfolio of outstanding loans |
| ABCD | Dữ liệu tài sản | Asset-Based Company Data — physical production data |
| Market Share method | Phương pháp thị phần | Alignment via technology share of total sector production |
| SDA | Phương pháp cường độ phát thải | Sectoral Decarbonization Approach — emission intensity targets |
| Alignment | Tương thích khí hậu | Portfolio consistency with climate scenario targets |
| Misalignment | Không tương thích | Portfolio trajectory worse than climate scenario |
| Technology mix | Cơ cấu công nghệ | Share of each technology in total sector output |
| Emission intensity | Cường độ phát thải | CO2 emissions per unit of production |
| Scenario | Kịch bản | Climate pathway showing how sector must evolve |
| PDP8 | QHĐ VIII (Quy hoạch điện VIII) | Vietnam Power Development Plan 8 |
| NDC | NDC / Đóng góp do quốc gia tự quyết định | Nationally Determined Contribution |
| JETP | Đối tác chuyển đổi năng lượng công bằng | Just Energy Transition Partnership |
| Coal phase-down | Giảm dần điện than | Reducing coal power capacity over time |
| Stranded asset | Tài sản mắc kẹt | Asset that loses value before end of useful life due to energy transition |
| BOT | BOT (Xây dựng - Khai thác - Chuyển giao) | Build-Operate-Transfer power project |
| IPP | Nhà sản xuất điện độc lập | Independent Power Producer |

---

*End of Vietnam Bank PACTA Scenario Implementation Plan*
*Next step: Begin Phase 1, Week 1 — write `data/generate_vietnam_data.R`*
