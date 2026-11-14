library(dplyr)
library(stringr)
library(sf)

source("scripts/utils.R")

assignedTaxa <-    timedFread("tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-assigned-taxa.csv")
assignedSummary <- timedFread("tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-assigned.csv")
assignedSummary$inSummary = 1

# Each species' provincial concern is that judged from its rank by prepare_summary.R, which writes the -orig summary -
# taken from there, so that a change to the judgement needs no fresh assignment of names
origSummary <- timedFread("tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-orig.csv")
assignedSummary$provincial_concern <- origSummary$provincial_concern[match(assignedSummary$scientificName, origSummary$scientificName)]

assignedSummaryDupes <- assignedSummary %>%
  group_by(iNaturalistTaxonId) %>%
  filter(n() > 1)

if (nrow(assignedSummaryDupes > 0)) {
  cat("Warning, there were ", nrow(assignedSummaryDupes), "duplicate entries found in the summary")
  assignedSummaryDupes$scientificName
  timedWrite(assignedSummaryDupes, "tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-assigned-dupes.csv")
  
  toRemove <- assignedSummaryDupes
  
  assignedSummary <- assignedSummary %>%
    anti_join(toRemove %>% select(scientificName, iNaturalistTaxonId), 
              by = c("scientificName", "iNaturalistTaxonId"))
}

merged <- assignedTaxa %>%
  full_join(assignedSummary %>% select(-c("iNaturalistTaxonName")), by = c("id" = "iNaturalistTaxonId"))

merged <- merged %>% select(-c("kingdom", "phylum", "class", "order", "infraorder", "superfamily", "subfamily", "genus", "family",
                               "subphylum", "subclass", "superorder", "tribe"))

# Many EP are missing
merged <- merged %>% mutate(solow_EP = coalesce(solow_EP, 0))

timedWrite(merged, "tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-prepared-taxa.csv")
