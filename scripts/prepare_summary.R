library(dplyr)
library(tidyr)
library(stringr)
library(sf)

source("scripts/utils.R")

# reduce columns ready for assignment

rawList <- timedFread("tabular_data/AHSBR_Tracheophyta_ultimate-list_2026-06-16.csv")

# A species is of provincial conservation concern if its BC Conservation Data Centre rank is S3 or rarer across its
# whole range - S1, S2, S3, S2S3, S2? - the Red and Blue lists. A range reaching S4 or S5, e.g. S3S4, is not at risk
# (the Yellow list), and S4 and S5 are secure. Any other rank - SNA, SU, SNR or none - is unknown
provincialConcern <- function (status) {
  rank <- str_trim(str_remove(status, "\\s*\\(.*$"))
  digits <- str_extract_all(rank, "(?<=S)\\d")
  sapply(seq_along(rank), function (i) {
    d <- as.integer(digits[[i]])
    `if`(is.na(rank[i]) || !str_detect(rank[i], "^S\\d") || length(d) == 0, "unknown",
         `if`(max(d) <= 3, "concern", "secure"))
  })
}
rawList$provincial_concern <- provincialConcern(rawList$provincial_conservation_status)
wg("{sum(rawList$provincial_concern == 'concern')} species of provincial conservation concern")
reducedList <- rawList %>% select(c("taxonName", "introduction_status", "occurrence_status", "infrataxon_status", "provincial_concern", "provenance_status", "solow_EP", "phylum"))
reducedList <- reducedList %>% rename("reportingStatus" = "occurrence_status", "scientificName" = "taxonName")

timedWrite(reducedList, "tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-orig.csv")

# Next: node node_modules/imerss-bioinfo/src/assignBNames.js tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-orig.csv --DwCA --swaps tabular_data/taxon-swaps.csv
