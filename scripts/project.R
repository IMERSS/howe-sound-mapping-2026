# The settings, beyond its data files named in bioreportr.yaml and bioreportr-prep.yaml, of the Átl’ḵa7tsem/Howe Sound project read by the shared scripts of the bioReportR framework, such as
# scripts/intersectShapes.R and scripts/Protected_map_mapbox.R. This file is the project's own, and is not copied by
# copyFrameworkOut.sh

# The project's data files: those its story page reads, named in bioreportr.yaml, and those which only prepare them,
# named in bioreportr-prep.yaml
config <- c(yaml::read_yaml("bioreportr.yaml")$data, yaml::read_yaml("bioreportr-prep.yaml")$data)

project <- list(
  # The settings of scripts/prepare_ultimate_list.R, which builds the ultimate checklist and catalogue from the synthesis
  # of the Átl’ḵa7tsem/Howe Sound Biodiversity Review in adfsimon-bioinfo, whose files are named in bioreportr-prep.yaml
  ultimate = list(
    # Where adfsimon-bioinfo is checked out, relative to this project
    sourceRoot = "../adfsimon-bioinfo",
    # The period of Solow's (1993) analysis of each taxon's sightings: from its baseline year to its analysis year
    baselineYear = 1897,
    analysisYear = 2024,
    # Names of the catalogue's records which differ from those of the summary, as the summary names them
    renames = c("Heterocodon rariflorum" = "Heterocodon rariflorus", "Ranunculus aquatilis" = "Ranunculus aquatilis complex"),
    # The records of a dataset which is a species list rather than sightings - the appendix of the 2020 UNESCO
    # nomination, entered as 583 pseudo-records dated 2020-07-01 at one placeholder coordinate. They stay in the
    # catalogue and are shown, but count in no Solow analysis - the story counts them as no sightings either, by its
    # isSighting in static/local/story/howe-story.vue
    listOnlyDatasets = "UNESCO Nomination"
  ),
  # The source catalogue, whose records are labelled with the regions they fall in
  obsFile = file.path("tabular_data", config$catalogue),
  # The index of the shapes the records are intersected with - see spatial_data/vectors
  shapeIndexFile = file.path("tabular_data", config$shapeIndex),
  # Records with no genus are dropped too
  filterObs = function (obs) obs %>% filter(!is.na(genus)),
  # The summary of the catalogue's taxa
  summaryFile = file.path("tabular_data", config$summary),
  # The settings of the curation history and of the taxa kept off the checklist, read by
  # scripts/prepare_curation_history.R and scripts/prepare_excluded_taxa.R. The notes of this project's checklist, and
  # the reasons of its review for setting taxa aside, are the compiler's own, unsigned, in one column each - so there
  # are no reviewers' initials to spell out and no reviewers to name. The working list is prepared from the review by
  # scripts/prepare_working_list.R
  curation = list(
    # The columns of the checklist naming each taxon, and giving its iNaturalist id
    nameColumn = "taxonName",
    idColumn = "linkTaxonID",
    # The one field of the history, as curationHistorySources in howe-story.vue names it, from the checklist's notes
    history = list(notes = "notes"),
    expandInitials = character(0),
    reviewedBy = NULL,
    reviewers = c(),
    automatic = c(),
    # The flags of the working list by which the review excludes a taxon, each with the label shown for it
    flags = c(is_doubtful = "doubtful", is_persisting_or_waif = "persisting or waif", is_planted = "planted")
  ),
  # The settings of the Protected Areas pane's map and summaries, read by scripts/Protected_map_mapbox.R
  protected = list(
    # The categories of protected area, in the order of precedence of scripts/prepare_protected_areas.R, coloured from
    # the site's own: its blue, sand and purple, softened greens and teal, set on the dark satellite base - with muted
    # tones for the land-use designations and other effective conservation measures which the region has besides
    palette = data.frame(
      category = c("Ecological reserve", "Protected area", "Provincial park", "Conservancy", "Migratory bird sanctuary",
                   "Wildlife management area", "Wildlife habitat area", "Old growth management area", "Wildland zone",
                   "Other effective conservation measure", "Private conservation land"),
      color = c("#decb90", "#5a96d2", "#8cc084", "#4fae98", "#9fd0e0",
                "#7c86c9", "#b6c7e8", "#c2a878", "#9fb28a",
                "#c9c2b0", "#a593d8")
    ),
    # Each category in the plural, as it opens a sentence
    categoryPlural = c("Ecological reserve" = "Ecological reserves", "Protected area" = "The protected area",
      "Provincial park" = "Provincial parks", "Conservancy" = "The conservancy",
      "Migratory bird sanctuary" = "The migratory bird sanctuary", "Wildlife management area" = "The wildlife management area",
      "Wildlife habitat area" = "Wildlife habitat areas", "Old growth management area" = "Old growth management areas",
      "Wildland zone" = "The Sea to Sky wildland zones",
      "Other effective conservation measure" = "Other effective conservation measures",
      "Private conservation land" = "Private conservation lands"),
    # The biosphere region's boundary, framing the study area
    boundary = function () mx_read("spatial_data/vectors/Howe_Sound"),
    view = list(lon = -123.2194, lat = 49.66076, zoom = 8.5),
    # The wording of the summaries, where it is not the default - see default.text in scripts/Protected_map_mapbox.R
    text = list(
      overview = function (v) str_glue("Of the {v$stats$species} native vascular plants known from the region, ",
        "{v$stats$protected} ({v$stats$protected.percent}%) have been recorded in at least one protected or ",
        "conserved area, from provincial parks and ecological reserves to old growth management areas and private ",
        "conservation lands. The remaining {v$stats$unprotected} are so far known only from outside protected areas."),
      kbas = function (v) str_glue("Key Biodiversity Areas mark the places that matter most for the persistence of species and ",
        "ecosystems. The region holds {v$published} published Key Biodiversity Areas, identified chiefly for the birds that ",
        "gather in Howe Sound and along the Squamish River. {v$stats$kba} of the region's ",
        "{v$stats$species} native vascular plants ({v$percent(v$stats$kba)}%) have been recorded within them.")
    )
  )
)
