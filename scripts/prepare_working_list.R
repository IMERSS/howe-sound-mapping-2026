library(dplyr)
library(stringr)

source("scripts/utils.R")
source("scripts/project.R")

# Prepare this project's working list - the taxa its curators set aside from the checklist, with the reasons and flags
# by which the shared scripts/prepare_curation_history.R and scripts/prepare_excluded_taxa.R describe them, as they read
# the working list of checklist-catalogue-alignment-workflow for the W̱SÁNEĆ/Saanich Peninsula.
#
# The input is the review key of the Átl’ḵa7tsem/Howe Sound review of vascular plant names in adfsimon-bioinfo
# (Howe_Sound/consolidate_records/Plantae_et_Chromista/vascular_plants/keys/review.key.csv), copied into tabular_data
# and named reviewKey in bioreportr-prep.yaml. Each row matches a name reported for the region to the accepted name it
# is carried to; a row with no accepted name was dropped from the checklist, with the reviewer's reason as its note.
# Each such row is set aside here as excluded, flagged by its reason:
#   persisting or waif  - "non-established", "domesticated plant"
#   planted             - "apparently planted"
#   doubtful            - "misreported"
# A dropped name whose reason is none of these - e.g. "confirm variety", "possibly introduced", or none at all - is
# left out, since this project's review does not track taxa under review.
#
# Run by hand when the review key is refreshed, before scripts/prepare_curation_history.R and
# scripts/prepare_excluded_taxa.R - never as a step of the build. Until the whole curation workflow is brought into this
# repository, this adapts its output to the inputs the shared scripts accept

settings <- project$curation
review_key <- timedFread(file.path("tabular_data", config$reviewKey))
working_file <- file.path("tabular_data", config$workingList)

flag <- function (test) ifelse(test, "yes", "no")

dropped <- review_key %>%
  filter(is.na(Matched.Taxon) | str_trim(Matched.Taxon) == "") %>%
  mutate(reason = str_squish(coalesce(Notes, "")),
         is_persisting_or_waif = flag(str_detect(reason, regex("non-established|domesticated", ignore_case = TRUE))),
         is_planted = flag(str_detect(reason, regex("planted", ignore_case = TRUE))),
         is_doubtful = flag(str_detect(reason, regex("misreported", ignore_case = TRUE)))) %>%
  filter(is_persisting_or_waif == "yes" | is_planted == "yes" | is_doubtful == "yes")

working <- dropped %>%
  transmute(
    !!settings$nameColumn := str_squish(Taxon),
    !!settings$idColumn := NA_character_,
    common_name = NA_character_, family = NA_character_, introduction_status = NA_character_, confidence = NA_character_,
    n_total = NA_integer_, n_research_grade = NA_integer_, first_record_date = NA_character_, last_record_date = NA_character_,
    review_status = "complete",
    is_doubtful, is_persisting_or_waif, is_planted,
    notes = reason
  )
wg("Setting aside {nrow(working)} of the {nrow(review_key %>% filter(is.na(Matched.Taxon) | str_trim(Matched.Taxon) == ''))} names the review dropped")

timedWrite(working, working_file)
