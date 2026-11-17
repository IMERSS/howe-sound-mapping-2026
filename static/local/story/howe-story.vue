<fluid-import src="../../bioreportr/sfc/bioreportr-storyPage.vue"></fluid-import>
<!-- The story's data files, as its bioreportr.yaml names them - written by src/js/storyBuild.js -->
<fluid-import src="../../story/bioreportr-storyData.vue"></fluid-import>
<!-- The atlas's panel, tiles and tooltips, and the panes shared with the other bioReportR stories - In Memoriam, Lost
     Plants and Protected Areas - each rendering its section from its own template, see paneComponent in the front
     matter of content/story/Traces.Rmd, LostPlants.Rmd and Protected.Rmd -->
<fluid-import src="../../bioreportr/sfc/bioreportr-atlasPanel.vue"></fluid-import>
<fluid-import src="../../bioreportr/sfc/bioreportr-storyPageTraces.vue"></fluid-import>
<fluid-import src="../../bioreportr/sfc/bioreportr-storyPageLostPlants.vue"></fluid-import>
<fluid-import src="../../bioreportr/sfc/bioreportr-storyPageProtectedAreas.vue"></fluid-import>
<!-- The Regional Diversity pane, whose biogeoclimatic units are listed as chips - see content/story/Vascular_BEC.Rmd -->
<fluid-import src="howe-becPane.vue"></fluid-import>
<!-- The iNaturalist panels of the Top Contributions pane -->
<script src="%@imerss/inat-components/dist/standalone.min.js" fluid-client data-fl-scope="global"></script>
<script>
"use strict";

// The story page of the Átl’ḵa7tsem/Howe Sound vascular plant report. Its atlas and the panes it shares with the other
// bioReportR stories are layers of the story page defined in static/bioreportr/sfc, given this story's settings here.
// Its paths are relative to the story page, served at /story/, whose panes are written by src/js/storyBuild.js into
// static/story
// noinspection ES6ConvertVarToLetConst // otherwise this is a duplicate on minifying
var howe = fluid.registerNamespace("howe");
fluid.registerNamespace("howe.story");

// The proportion of the maximum count shown by each cell of the map's grid is scaled by a Weibull distribution, so
// that the few cells with very many observations do not wash out the rest - as the Saanich Peninsula's story scales it
howe.story.weibullCount = (x, maxCount) => maxCount < 200 ? x : 1 - Math.exp(-Math.pow(x / 0.012, 0.5));

howe.story.inverseWeibullCount = (x, maxCount) => maxCount < 200 ? x : 0.012 * Math.pow(-Math.log(1 - x), 1 / 0.5);

// Whether the map follows the filtered records - on every pane but History, whose map is fixed on the centre of the grid
// of all its records, set in scripts/Historical_analysis_mapbox.R, so that it holds still as the years advance
howe.story.followRecords = activePaneKey => activePaneKey !== "History";

// The predicates of the query description language by which a record is a sighting of its plant - all but the species
// list of the 2020 UNESCO nomination of the biosphere region, entered as pseudo-records all dated 2020-07-01 at one
// place. They remain among the records shown, but are not sightings: they count neither towards extirpation
// probability nor towards the history of a plant's records - as scripts/prepare_ultimate_list.R leaves them out
// of the EP of the summary
howe.story.sightingPredicates = [{not: {field: "datasetName", op: "contains", value: "UNESCO Nomination"}}];

fluid.def("howe.story", {
    $layers: ["bioreportr.storyPage", "bioreportr.storyData", "bioreportr.atlasPanel", "bioreportr.storyPageTraces", "bioreportr.storyPageLostPlants",
        "bioreportr.storyPageProtectedAreas"],
    // The 2020 UNESCO nomination's species list is not a sighting - see howe.story.sightingPredicates
    sightingPredicates: howe.story.sightingPredicates,
    // The species of the Community Science pane, which open on the atlas, are those of the place and taxon of its panels
    // - see paneOverrides below
    inatSpeciesQuery: {place_id: 121270, taxon_id: 211194},
    // The one field of the curation history, the notes of the compiler of the checklist, written into the history by
    // scripts/prepare_curation_history.R - see the curation section of scripts/project.R
    curationHistorySources: [
        {field: "notes", source: "Andrew Simon", label: "Compiler's notes", cite: "Simon"}
    ],
    gridResolution: 1000,
    // The regions which may filter the records - a category of protected area is matched through rows of the region
    // index giving each area the label of its category, see GroupField in scripts/intersectShapes.R
    regionFilterFieldNames: ["BEC", "ProtectedArea", "KBA"],
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
    // The Download list panel names the story's whole area so, and its files so - see bioreportr-list.vue
    list: {
        $component: {
            areaName: "the whole Átl’ḵa7tsem/Howe Sound Biosphere Region",
            // The stem of each downloaded checklist's file name, in plain letters
            fileStem: "Flora-of-the-Howe-Sound-Biosphere"
        }
    },
    paneOverrides: {
        Traces: {
            visibleMap: true
        },
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
            countTransform: "howe.story.weibullCount",
            inverseCountTransform: "howe.story.inverseWeibullCount",
            // The History pane's map stays on its own view while its slider plays, rather than following each year's records
            zoomToObsBounds: "$compute:howe.story.followRecords({storyPage}.activePaneKey)"
        }
    }
});
</script>
