<fluid-import src="../../bioreportr/sfc/bioreportr-storyPage.vue"></fluid-import>
<fluid-import src="howe-atlasPanel.vue"></fluid-import>
<fluid-import src="howe-protectedPane.vue"></fluid-import>
<!-- The iNaturalist panels of the Top Contributions pane -->
<script src="%@imerss/inat-components/dist/standalone.min.js" fluid-client data-fl-scope="global"></script>
<script>
"use strict";

// The story page of the Átl’ḵa7tsem/Howe Sound vascular plant report. Its paths are relative to the story page,
// served at /story/, whose panes are written by src/js/storyBuild.js into static/story
fluid.def("howe.story", {
    $layers: ["bioreportr.storyPage", "howe.atlasPanel"],
    obsFile: "../local/data/tabular/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-labels.csv",
    obsPlaceholderFile: "../local/data/tabular/placeholder/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-labels.csv",
    taxaFile: "../local/data/tabular/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-prepared-taxa.csv",
    taxaPlaceholderFile: "../local/data/tabular/placeholder/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-prepared-taxa.csv",
    regionIndirectionFile: "../local/data/tabular/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-regionIndirection.csv",
    regionIndirectionPlaceholderFile: "../local/data/tabular/placeholder/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-regionIndirection.csv",
    gridResolution: 1000,
    // The regions which may filter the records - a category of protected area is matched through rows of the region
    // index giving each area the label of its category, see GroupField in scripts/intersectShapes.R
    regionFilterFieldNames: ["BEC", "ProtectedArea"],
    // The Protected Areas pane may also select the native species reported in no protected area, and some of the
    // species of a region - see howe.protectedAreas.regionFilter
    regionFilter: {
        $component: {
            doFilter: `$method:howe.protectedAreas.regionFilter({0}:obsRows, {1}:filterState, {storyPage}.regionIndirection.rows,
                {storyPage}.regionFilterFieldNames, {storyPage}.protectedAreas.taxonSets, {storyPage}.activePaneKey)`
        }
    },
    // The panel of the plant chosen in the checklist - the atlas's, see howe-atlasPanel.vue, or on the Protected Areas
    // pane its smaller one giving the plant's records within the selected region, see howe-protectedPane.vue
    taxonPanel: {
        $component: {
            markup: "$compute:howe.protectedAreas.choosePanel({storyPage}.activePaneKey, {storyPage}.atlasPanelMarkup, {storyPage}.protectedAreas.panelMarkup)"
        }
    },
    taxonPanelVisible: "$compute:howe.protectedAreas.panelVisible({self}.taxonPanel.markup, {self}.activePaneKey)",
    // The Protected Areas pane selects categories from its chart and individual areas from the map, describing each
    // area on hover - see howe-protectedPane.vue
    protectedAreas: {
        $component: {
            $layers: "howe.protectedAreas"
        }
    },
    solowParams: {
        baselineYear: 1897,
        analysisYear: 2024
    },
    taxonColumns: [
        {key: "scientificName", label: "Taxon name"},
        {key: "solow_EP", label: "EP"},
        {key: "infrataxon_status", label: "Infrataxon Status"},
        {key: "introduction_status", label: "Introduction"},
        {key: "provenance_status", label: "Has Voucher"},
        {key: "provincial_concern", label: "Conservation Status"},
        {key: "commonName", label: "Common Name"},
        {key: "reportingStatus", label: "Reporting status"},
        {key: "id", label: "ID"},
        {key: "iNaturalistTaxonName", label: "Link name"}
    ],
    taxaFilterRecords: [
        {filterName: "Infrataxon Status", fieldName: "infrataxon_status", fieldValues: ["infrataxon", "non-infrataxon"]},
        {filterName: "Introduction Status", fieldName: "introduction_status", fieldValues: ["native", "exotic", "unknown"]},
        {filterName: "Provenance Status", fieldName: "provenance_status", fieldValues: ["voucher", "no_voucher", "unknown"]},
        {filterName: "Conservation Status", fieldName: "provincial_concern", fieldValues: ["concern", "secure"]},
        {filterName: "Graminoid status", fieldName: "graminoid", fieldValues: ["graminoid", "non-graminoid"], valueOf: "hortis.graminoidValue"}
    ],
    paneOverrides: {
        Solow: {
            layers: ["reknitr.solowPaneHandler"]
        },
        TopContributions: {
            iNatPanels: [{
                taxon: {
                    id: 211194,
                    str: "Vascular plants"
                },
                place: {
                    id: 121270,
                    str: "howesound"
                },
                features: [{ // recentObservations
                    desc: "This page lists the most recent observations of vascular plants made in the the \xc1tl\u2019\u1e35a7tsem/Howe Sound Biosphere Region. Click on any of them to go to the iNaturalist site for more information."
                }, { // commonTaxa
                    desc: "This page lists the most commonly reported species in \xc1tl\u2019\u1e35a7tsem/Howe Sound. You can use the dropdown at the top right to filter the results to a particular year."
                }, { // favourites
                    desc: "Any time iNaturalist users encounter an observation they like, they can choose to \"favourite\" it. This page lists the most favourited vascular plants observations made in the the \xc1tl\u2019\u1e35a7tsem/Howe Sound Biosphere Region."
                }]
            }]
        },
        History: {
            maxObsCountOverride: 5273,
            sliders: [{widgetId: "speciesPlot", animate: true, delay: 1000}]
        }
    },
    map: {
        $component: {
            $layers: ["hortis.libreMap.withTiles", "hortis.libreMap.esriTiles"],
            // The Protected Areas pane shows the grid of the native species outside protected areas when they are selected
            gridVisible: "{storyPage}.protectedAreas.gridVisible",
            // A selection of some of the species of a region, made by the figures of the Protected Areas pane, outlines
            // and marks the region itself
            highlightRegion: "$effect:bioreportr.storyMap.highlightRegion({self}.readyMap, {storyPage}.protectedAreas.baseRegion, {storyPage}.mapData)",
            legendRowsMarkup: "$compute:bioreportr.storyMap.legendMarkup({self}.legendRows, {storyPage}.selectedStatus, {storyPage}.protectedAreas.baseRegion)"
        }
    }
});
</script>
