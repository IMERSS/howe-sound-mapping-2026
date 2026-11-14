# Fetch the Key Biodiversity Areas of Átl’ḵa7tsem/Howe Sound, and write them as the shapes from which the Protected Areas
# pane draws them and against which intersectShapes.R labels each record - as the W̱SÁNEĆ/Saanich Peninsula's
# scripts/fetch_protected_areas.R writes its own.
#
# Source, queried for the region's bounding box and clipped to its boundary:
#   - KBA Canada published and candidate (proposed) Key Biodiversity Areas, served by NatureServe Canada,
#     CC BY-NC-SA 4.0
#
# Run by hand when the source is to be refreshed - never as a step of the build. It writes
#   spatial_data/vectors/KBA/KBA.geojson - one polygon per published KBA, with its name, code and criteria, and the
#     label of all of them together
#   spatial_data/vectors/KBA/KBA_proposed.geojson - one point per proposed KBA, with its name and stage of review

library(dplyr)
library(sf)
library(stringr)

source("scripts/utils.R")

sf::sf_use_s2(FALSE)

boundary <- st_union(st_transform(mx_read("spatial_data/vectors/Howe_Sound"), 4326))
bbox <- st_bbox(boundary)
envelope <- paste(bbox[c("xmin", "ymin", "xmax", "ymax")], collapse = ",")

arcgis_query <- function (service) {
  url <- str_glue("{service}/query?where=1%3D1&geometry={envelope}&geometryType=esriGeometryEnvelope&inSR=4326",
                  "&spatialRel=esriSpatialRelIntersects&outFields=*&outSR=4326&f=geojson")
  wg("Fetching {service}")
  st_make_valid(st_read(url, quiet = TRUE))
}

clip <- function (shapes) {
  clipped <- suppressWarnings(st_intersection(shapes, boundary))
  clipped <- clipped[!st_is_empty(clipped), ]
  st_collection_extract(clipped, "POLYGON")
}

kba.service <- "https://gis.natureserve.ca/arcgis/rest/services/EBAR-KBA"

published <- arcgis_query(str_glue("{kba.service}/KBA_Accepted_Sites/FeatureServer/0")) %>%
  transmute(name = nationalname, code = sitecode, status = "Published", stage = "Published",
            criteria = criteriasummary_en)
candidate <- arcgis_query(str_glue("{kba.service}/KBA_InProgress_Sites/FeatureServer/0"))
# A query finding no proposed KBAs returns shapes without any of the service's fields
candidate <- `if`(nrow(candidate) == 0,
  st_sf(name = character(), code = character(), status = character(), stage = character(), criteria = character(),
        geometry = st_sfc(crs = 4326)),
  candidate %>% transmute(name = nationalname, code = sitecode, status = "Proposed", stage = sitestatus_en,
                          criteria = NA_character_))

# Each KBA also carries the label of all the published KBAs together, the "KBAs" region of intersectShapes.R
kbas <- published %>% clip() %>%
  group_by(name, code, status, stage, criteria) %>% summarise(.groups = "drop") %>%
  mutate(all = "Published Key Biodiversity Areas")
wg("Writing {nrow(kbas)} published Key Biodiversity Areas")

dir.create("spatial_data/vectors/KBA", showWarnings = FALSE)
st_write(kbas, "spatial_data/vectors/KBA/KBA.geojson", delete_dsn = TRUE, quiet = TRUE)

# The boundaries of proposed KBAs are not public until they are published - KBA Canada gives only a point for each
proposed <- candidate[lengths(suppressMessages(st_intersects(candidate, boundary))) > 0, ]
wg("Writing {nrow(proposed)} proposed Key Biodiversity Areas, as points")
st_write(proposed, "spatial_data/vectors/KBA/KBA_proposed.geojson", delete_dsn = TRUE, quiet = TRUE)
