# Prepare the protected and conserved areas of Átl’ḵa7tsem/Howe Sound as the shapes from which the Protected Areas
# pane is drawn and against which intersectShapes.R labels each record, in the same form as the Saanich Peninsula's
# scripts/fetch_protected_areas.R writes them.
#
# Source: the areas of the Canadian Protected and Conserved Areas Database (CPCAD), Environment and Climate Change
# Canada, as compiled for the region in 2024 - spatial_data/vectors/Protected_Areas/AHSBR_vascular_plant_diversity_x_protected_areas.shp
#
# Run by hand when the source is to be refreshed - never as a step of the build. It writes
#   spatial_data/vectors/Protected_Areas/Protected_Areas.geojson - one polygon per area, without overlaps, with its
#     name, its owner, its type as recorded in CPCAD and its category, which give the "ProtectedArea" region of
#     intersectShapes.R and its "Protected" group

library(dplyr)
library(sf)
library(stringr)

source("scripts/utils.R")

sf::sf_use_s2(FALSE)

source.areas <- st_make_valid(mx_read("spatial_data/vectors/Protected_Areas/AHSBR_vascular_plant_diversity_x_protected_areas.shp"))

# The categories shown on the map, in order of precedence: where areas overlap, the earlier category keeps the ground
categories <- c(
  "Ecological reserve",
  "Protected area",
  "Provincial park",
  "Conservancy",
  "Migratory bird sanctuary",
  "Wildlife management area",
  "Wildlife habitat area",
  "Old growth management area",
  "Wildland zone",
  "Other effective conservation measure",
  "Private conservation land"
)

categorise <- function (type) {
  case_when(
    type == "Ecological Reserve" ~ "Ecological reserve",
    type == "Protected Area" ~ "Protected area",
    type == "A - Park" ~ "Provincial park",
    type == "Conservancy" ~ "Conservancy",
    type == "Migratory Bird Sanctuary" ~ "Migratory bird sanctuary",
    type == "Wildlife Management Area" ~ "Wildlife management area",
    type == "Wildlife Habitat Areas" ~ "Wildlife habitat area",
    str_detect(type, "^Old Growth Management") ~ "Old growth management area",
    str_detect(type, "Wildland") ~ "Wildland zone",
    type == "Other Effective Area-Based Conservation Measure" ~ "Other effective conservation measure",
    str_detect(type, "Private") ~ "Private conservation land",
    TRUE ~ NA_character_
  )
}

areas <- source.areas %>%
  transmute(name = prtctdA, owner = str_remove(OWNER_E, " \\(Lead Organization\\)$"), type = prtctAT,
            category = categorise(prtctAT))

unknown <- unique(areas$type[is.na(areas$category)])
if (length(unknown) > 0) {
  wg("Warning: protected area types not given a category: {paste(unknown, collapse = ', ')}")
}
areas <- areas %>% filter(!is.na(category))

# Remove overlaps so that each point of ground falls in one area, the first in order of precedence, and the
# intersection of each record with the areas is unambiguous
# Within a category, larger areas first - measured in BC Albers, since st_area of longitude/latitude needs lwgeom
areas <- areas[order(match(areas$category, categories), -as.numeric(st_area(st_transform(areas, 3005)))), ]
claimed <- NULL
pieces <- list()
for (i in seq_len(nrow(areas))) {
  area <- areas[i, ]
  if (!is.null(claimed)) {
    area <- suppressWarnings(st_difference(area, claimed))
  }
  if (nrow(area) > 0 && !all(st_is_empty(area))) {
    area <- st_collection_extract(area, "POLYGON")
    pieces[[length(pieces) + 1]] <- area
    claimed <- `if`(is.null(claimed), st_union(area), st_union(c(claimed, st_union(area))))
  }
}
areas <- do.call(rbind, pieces)
areas <- areas %>% group_by(name, owner, type, category) %>% summarise(.groups = "drop")
wg("Writing {nrow(areas)} protected and conserved areas")

st_write(areas, "spatial_data/vectors/Protected_Areas/Protected_Areas.geojson", delete_dsn = TRUE, quiet = TRUE)
