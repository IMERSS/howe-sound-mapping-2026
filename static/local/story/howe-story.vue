<fluid-import src="../../bioreportr/sfc/bioreportr-storyPage.vue"></fluid-import>
<!-- The iNaturalist panels of the Top Contributions pane -->
<script src="%@imerss/inat-components/dist/standalone.min.js" fluid-client data-fl-scope="global"></script>
<script>
"use strict";

// The story page of the Átl’ḵa7tsem/Howe Sound vascular plant report. Its paths are relative to the story page,
// served at /story/, whose panes are written by src/js/storyBuild.js into static/story
fluid.def("howe.story", {
    $layers: "bioreportr.storyPage",
    obsFile: "../local/data/tabular/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-labels.csv",
    obsPlaceholderFile: "../local/data/tabular/placeholder/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-labels.csv",
    taxaFile: "../local/data/tabular/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-prepared-taxa.csv",
    taxaPlaceholderFile: "../local/data/tabular/placeholder/AHSBR_Tracheophyta_ultimate-merged-summary_2026-06-16-prepared-taxa.csv",
    regionIndirectionFile: "../local/data/tabular/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-regionIndirection.csv",
    regionIndirectionPlaceholderFile: "../local/data/tabular/placeholder/AHSBR_Tracheophyta_ultimate-catalogue_2026-06-16-selected-regionIndirection.csv",
    gridResolution: 1000,
    regionFilterFieldNames: ["BEC", "Protected"],
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
        Protected: {
            resizeHeight: true
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
            zoomDuration: 0,
            slowZoomDuration: 0
        }
    }
});
</script>
