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

# As on the W̱SÁNEĆ/Saanich Peninsula, a species is historical - "reported" - if it was reported in the past but has not
# been recorded since 2000, and confirmed if it has been found again since then. A historically reported species with
# a dated record since 2000 is therefore confirmed. The species list of the 2020 UNESCO nomination, entered as
# pseudo-records dated 2020-07-01, is no sighting and does not count
catalogue <- timedFread("tabular_data/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-labels.csv")
sightedSince2000 <- unique(catalogue$taxonName[!grepl("UNESCO Nomination", catalogue$datasetName) &
  suppressWarnings(as.integer(substr(as.character(catalogue$eventDate), 1, 4))) >= 2000])
refound <- rawList$occurrence_status == "reported" & rawList$taxonName %in% sightedSince2000
wg("{sum(refound)} historically reported species found again since 2000 are confirmed: {paste(rawList$taxonName[refound], collapse = ', ')}")
rawList$occurrence_status[refound] <- "confirmed"
wg("{sum(rawList$provincial_concern == 'concern')} species of provincial conservation concern")
# Each taxon's conservation status, shown in its panel on the site as the W̱SÁNEĆ/Saanich Peninsula's are: its provincial
# rank of the BC Conservation Data Centre, as the list holds it, and from the rankings of adfsimon-bioinfo's synthesis,
# named in bioreportr-prep.yaml, its BC list, its national status as assessed by COSEWIC and its listing under the Species
# at Risk Act - each with the year of its assessment, e.g. "Endangered (2004)", "S1: Endangered (2005)"
source("scripts/project.R")
rankings <- timedFread(file.path("tabular_data", config$rankings))
year_of <- function (date) str_extract(as.character(date), "\\d{4}")
dated <- function (status, date) ifelse(is.na(status) | status %in% c("", "NA"), "",
  ifelse(is.na(year_of(date)), status, paste0(status, " (", year_of(date), ")")))
ranking <- rankings[match(rawList$taxonName, rankings$scientificName), ]
rawList$provincial_status <- rawList$provincial_conservation_status
rawList$bc_list <- ifelse(is.na(ranking$bc_list) | ranking$bc_list == "NA", "", ranking$bc_list)
rawList$national_status <- dated(ranking$national_status, ranking$`COSEWIC Date`)
rawList$sara_status <- ifelse(rawList$national_status == "" | is.na(ranking$SARA_status) | ranking$SARA_status %in% c("", "NA"), "",
  paste0("S", ranking$`SARA Schedule`, ": ", dated(ranking$SARA_status, ranking$`SARA Date`)))

reducedList <- rawList %>% select(c("taxonName", "introduction_status", "occurrence_status", "infrataxon_status", "provincial_concern", "provenance_status", "solow_EP", "phylum",
                                    "provincial_status", "bc_list", "national_status", "sara_status"))
reducedList <- reducedList %>% rename("reportingStatus" = "occurrence_status", "scientificName" = "taxonName")

timedWrite(reducedList, "tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-orig.csv")

# Next: node node_modules/imerss-bioinfo/src/assignBNames.js tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-orig.csv --DwCA --swaps tabular_data/taxon-swaps.csv
