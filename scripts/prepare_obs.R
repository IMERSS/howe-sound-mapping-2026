library(dplyr)
library(stringr)
library(sf)

source("scripts/utils.R")

# Reduce columns in obs data for visualisation

# The records of the 2020 UNESCO nomination's species list are kept among those shown - the story counts them as no
# sightings, by its isSighting in static/local/story/howe-story.vue
rawObs <- timedFread("tabular_data/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16.csv")

filtered <- rawObs %>% select(-c(day, month, year, phylum, kingdom, class, order, family, linkName, basisOfRecord,
                                 scientificNameAuthorship, taxonRank, establishmentMeans, provincialStatus,
                                 country, countryCode, stateProvince, occurrenceStatus))
# datasetName and collectionCode are kept - scripts/prepare_summary.R reads the dataset of each record from the labels

emptyCols <- colSums(is.na(filtered)) == nrow(filtered)

emptyColNames = names(emptyCols[emptyCols])
cat("Removing ", length(emptyColNames), " empty columns ", paste(emptyColNames, collapse = ", "))

filtered <- filtered[!emptyCols]

# obscured coordinates have not survived in this dataset
# filtered$decimalLatitude[filtered$coordinates_obscured == TRUE] <- NA
# filtered$decimalLongitude[filtered$coordinates_obscured == TRUE] <- NA

# filtered <- filtered %>% select(-c(coordinates_obscured))

rawAssigned <- timedFread("tabular_data/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-assigned.csv")

assigned <- rawAssigned %>% select(c(scientificName, iNaturalistTaxonId))

withId <- merge(filtered, assigned, by.x = "taxonName", by.y = "scientificName")

withId <- withId %>% filter(!is.na(iNaturalistTaxonId) & iNaturalistTaxonId != 0)

# The client's observations table takes its column order from this data - scientificName then occurrenceID lead, taxonName comes last
withId <- withId %>% relocate(scientificName, occurrenceID) %>% relocate(taxonName, .after = last_col())

timedWrite(withId, "tabular_data/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-orig.csv")



