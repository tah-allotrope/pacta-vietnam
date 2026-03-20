suppressPackageStartupMessages({
  library(pacta.loanbook); library(r2dii.data); library(r2dii.match)
  library(r2dii.analysis); library(dplyr); library(readr); library(stringi)
})
loanbook <- read_csv("data/vietnam_loanbook.csv", show_col_types=FALSE)
abcd     <- read_csv("data/vietnam_abcd.csv",     show_col_types=FALSE)
scenario <- read_csv("data/vietnam_scenario_ms.csv", show_col_types=FALSE)
region   <- read_csv("data/vietnam_region_isos.csv", show_col_types=FALSE)

lb_c <- loanbook %>%
  mutate(sector_classification_direct_loantaker=as.character(sector_classification_direct_loantaker)) %>%
  left_join(sector_classifications, by=c("sector_classification_system"="code_system","sector_classification_direct_loantaker"="code")) %>%
  rename(sector_classified=sector, borderline_classified=borderline)
lb_n <- lb_c %>%
  mutate(name_direct_loantaker=stri_trans_general(name_direct_loantaker,"Latin-ASCII"),
         name_ultimate_parent=stri_trans_general(name_ultimate_parent,"Latin-ASCII"))
abcd_n <- abcd %>% mutate(name_company=stri_trans_general(name_company,"Latin-ASCII"))
matched <- prioritize(match_name(lb_n, abcd_n, by_sector=TRUE, min_score=0.8))
matched_ms <- matched %>% select(-any_of(c("sector_classified","borderline_classified")))
ms <- target_market_share(data=matched_ms, abcd=abcd_n, scenario=scenario, region_isos=region)

writeLines(paste("Total MS rows:", nrow(ms)))
writeLines("region x metric combinations:")
print(as.data.frame(ms %>% distinct(region, metric) %>% arrange(region, metric)))
writeLines("power rows by region:")
print(as.data.frame(ms %>% filter(sector=="power") %>% distinct(region, metric)))
