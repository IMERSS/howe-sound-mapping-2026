library(dplyr)
library(stringr)

source("scripts/utils.R")
source("scripts/project.R")

# Build the ultimate checklist and catalogue of the Átl’ḵa7tsem/Howe Sound Biosphere's vascular plants from the synthesis
# of its Biodiversity Review in adfsimon-bioinfo, replacing the Galiano-derived list - the first step of the project's
# data preparation, before scripts/prepare_summary.R and scripts/prepare_obs.R. Its sources are named in
# bioreportr-prep.yaml, and its settings, e.g. the period of Solow's analysis, in project$ultimate of scripts/project.R.
# Ported from the former Python script scripts/rebuild_howe_ultimate_list.py, whose output it reproduces, so that the
# whole of the project's data is prepared in R

settings <- project$ultimate
source_file <- function (name) file.path(settings$sourceRoot, config[[name]])

# Every column is read as text, and "NA" as an empty field, as the sources write no missing values otherwise. fread
# leaves doubled the quotes escaped within a quoted field which also holds the separator, e.g. a locality
# "Black Tusk, The: original label reads ""Black Tusk Ridge""", which are undoubled here
read_text <- function (file) {
  frame <- timedFread(file, colClasses = "character", na.strings = NULL)
  frame[] <- lapply(frame, function (column) {
    column <- ifelse(is.na(column) | column == "NA", "", column)
    str_replace_all(column, fixed('""'), '"')
  })
  frame
}

synthesis <- read_text(source_file("synthesisSummary"))
review <- read_text(source_file("reviewSummary"))
catalogue <- read_text(source_file("consolidatedRecords"))

# The entries of the synthesis with no reporting status are stubs not yet resolved to a taxon, and are set aside
isStub <- synthesis$reportingStatus == ""
stubs <- synthesis[isStub, ]
summary <- synthesis[!isStub, ]

# The catalogue's records are named as the summary names their taxa
catalogue$taxonName <- unname(ifelse(catalogue$scientificName %in% names(settings$renames),
  settings$renames[catalogue$scientificName], catalogue$scientificName))

# Taxa recorded in the catalogue but missing from the synthesis are restored from the summary of the 2024 review
missing <- sort(setdiff(catalogue$taxonName, summary$scientificName), method = "radix")
restored <- review[review$scientificName %in% missing, names(summary)]
summary <- rbind(summary, restored)
# Sorted by name, a hybrid's sign aside, in the order of the characters' code points
summary <- summary[order(str_replace(summary$scientificName, fixed("× "), ""), method = "radix"), ]
wg("{nrow(stubs)} stubs set aside | restored from the 2024 review: {paste(restored$scientificName, collapse = ', ')}")
wg("Catalogue taxa with no summary entry, dropped by prepare_obs.R: {paste(sort(setdiff(catalogue$taxonName, summary$scientificName), method = 'radix'), collapse = ', ')}")
catalogue$linkName <- catalogue$taxonName

# The records of a dataset which is a species list rather than sightings, which count in no analysis of sightings
listOnly <- str_detect(catalogue$datasetName, settings$listOnlyDatasets)
wg("{sum(listOnly)} records of a species list rather than sightings are excluded from Solow's analysis")

# Solow's (1993) Bayes factor for a taxon's persistence, from the distinct dates of its sightings - as
# bioreportr.solowBayesFactor in static/bioreportr/js/solow.js computes it. A last sighting at or after the end of the
# period is the strongest evidence that the population persists
solow <- function (years, dates) {
  dated <- !is.na(years)
  sightings <- years[dated][!duplicated(dates[dated])]
  n <- length(sightings)
  if (n == 0) {
    return(c(solow_BF = NA, solow_EP = NA, solow_PP = NA))
  }
  T <- settings$analysisYear - settings$baselineYear
  tn <- max(sightings) - settings$baselineYear
  B <- if (tn >= T) Inf else if (tn <= 0) 0 else if (n == 1) 1 / log(T / tn) else (n - 1) / ((T / tn) ^ (n - 1) - 1)
  PP <- if (is.infinite(B)) 1 else B / (1 + B)
  c(solow_BF = if (is.infinite(B)) Inf else round(B, 3), solow_EP = round(1 - PP, 3), solow_PP = round(PP, 3))
}
years <- suppressWarnings(as.numeric(substr(catalogue$eventDate, 1, 4)))
sighted <- catalogue[!listOnly, ]
sightedYears <- years[!listOnly]
solowByTaxon <- do.call(rbind, lapply(split(seq_len(nrow(sighted)), sighted$taxonName), function (rows) {
  solow(sightedYears[rows], sighted$eventDate[rows])
}))

# A taxon is vouchered if any record of it is a preserved specimen
vouchered <- unique(catalogue$taxonName[catalogue$basisOfRecord %in% c("PRESERVED_SPECIMEN", "PreservedSpecimen")])

# A species is of provincial concern if its BC Conservation Data Centre rank is S1 to S3 - refined by
# scripts/prepare_summary.R, which judges the whole of a range
provincialConcern <- function (status) {
  status <- str_trim(status)
  digit <- suppressWarnings(as.integer(substr(status, 2, 2)))
  ifelse(str_detect(status, "^S\\d"), ifelse(digit <= 3, "concern", "secure"), "unknown")
}

ranks <- c("kingdom", "phylum", "subphylum", "superclass", "class", "subclass", "superorder", "order", "suborder",
           "superfamily", "family", "subfamily", "tribe", "hybrid", "subspecies", "variety")
# The provincial status of taxa whose rank or its year in the synthesis is out of date is corrected
corrections <- read_text(file.path("tabular_data", config$provincialStatusCorrections))
corrected <- match(summary$scientificName, corrections$taxonName)
summary$provincialStatus <- ifelse(is.na(corrected), summary$provincialStatus, corrections$provincial_conservation_status[corrected])
wg("{sum(!is.na(corrected))} provincial statuses corrected")

list <- data.frame(taxonName = summary$scientificName, taxon_author = summary$scientificNameAuthorship,
  subtaxon_author = summary$subtaxonAuthorship, commonName = summary$commonName, check.names = FALSE)
list[ranks] <- summary[ranks]
list <- cbind(list, data.frame(
  introduction_status = summary$establishmentMeans,
  provincial_conservation_status = summary$provincialStatus,
  national_conservation_status = summary$nationalStatus,
  occurrence_status = summary$reportingStatus,
  observation = summary$iNatObservationStatus,
  last_record_date = summary$lastReported,
  last_record_observer = summary$lastReportedBy,
  # sic - the column's name as the checklist has always had it
  last_record_soruce = summary$lastReportedSource,
  last_record_ID = summary$lastReportedCollectionNumber,
  gbif_ID = summary$lastReportedGBIF,
  first_record_date = summary$firstReported,
  first_record_observer = summary$firstReportedBy,
  linkTaxonID = "",
  notes = summary$notes,
  ID = summary$ID,
  stats_code = summary$statsCode,
  linkName = summary$scientificName))
list$graminoid_status <- ifelse(list$family %in% c("Poaceae", "Cyperaceae", "Juncaceae", "Typhaceae"), "graminoid", "non-graminoid")
list$infrataxon_status <- ifelse(str_detect(list$taxonName, " (?:ssp|subsp|var)\\. "), "infrataxon", "non-infrataxon")
list$provincial_concern <- provincialConcern(list$provincial_conservation_status)
list$national_concern <- ifelse(str_trim(list$national_conservation_status) != "", "concern", "unknown")
list$provenance_status <- ifelse(list$taxonName %in% vouchered, "voucher",
  ifelse(list$taxonName %in% catalogue$taxonName, "no_voucher", "unknown"))
solowRows <- match(list$taxonName, rownames(solowByTaxon))
list$solow_BF <- ifelse(is.infinite(solowByTaxon[solowRows, "solow_BF"]), "Inf", solowByTaxon[solowRows, "solow_BF"])
list$solow_EP <- solowByTaxon[solowRows, "solow_EP"]
list$solow_PP <- solowByTaxon[solowRows, "solow_PP"]

timedWrite(list, file.path("tabular_data", config$list))
timedWrite(stubs, file.path("tabular_data", config$unresolvedStubs))
timedWrite(catalogue, "tabular_data/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16.csv")

# Next: scripts/prepare_summary.R
