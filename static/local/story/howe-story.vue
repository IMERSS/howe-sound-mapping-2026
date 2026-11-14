<fluid-import src="../../bioreportr/sfc/bioreportr-storyPage.vue"></fluid-import>
<fluid-import src="howe-atlasPanel.vue"></fluid-import>
<fluid-import src="howe-protectedPane.vue"></fluid-import>
<!-- The iNaturalist panels of the Top Contributions pane -->
<script src="%@imerss/inat-components/dist/standalone.min.js" fluid-client data-fl-scope="global"></script>
<script>
"use strict";

// The story page of the Átl’ḵa7tsem/Howe Sound vascular plant report. Its paths are relative to the story page,
// served at /story/, whose panes are written by src/js/storyBuild.js into static/story
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
    regionFilterFieldNames: ["BEC", "ProtectedArea", "KBA"],
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
    // The plant chosen in the checklist is cleared on moving to another pane, since a plant carried into it could leave
    // that pane's own selection with no records - see howe.story.clearTaxonOnPaneChange
    clearTaxonOnPaneChange: "$effect:howe.story.clearTaxonOnPaneChange({self}, {self}.activePaneKey)",
    // and likewise on moving between the selections of the Protected Areas pane - its tabs, categories, areas and figures
    clearTaxonOnRegionChange: "$effect:howe.story.clearTaxonOnRegionChange({self}, {self}.selectedRegion, {self}.activePaneKey)",
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
            countTransform: "howe.story.weibullCount",
            inverseCountTransform: "howe.story.inverseWeibullCount",
            // The History pane's map stays on its own view while its slider plays, rather than following each year's records
            zoomToObsBounds: "$compute:howe.story.followRecords({storyPage}.activePaneKey)",
            // The Protected Areas pane shows the grid of the native species outside protected areas when they are selected
            gridVisible: "{storyPage}.protectedAreas.gridVisible",
            // A selection of some of the species of a region, made by the figures of the Protected Areas pane, outlines
            // and marks the region itself
            highlightRegion: "$effect:bioreportr.storyMap.highlightRegion({self}.readyMap, {storyPage}.protectedAreas.baseRegion, {storyPage}.mapData)",
            legendRowsMarkup: "$compute:bioreportr.storyMap.legendMarkup({self}.legendRows, {storyPage}.selectedStatus, {storyPage}.protectedAreas.baseRegion)"
        }
    }
});

// The pane last shown by each story page, so that the plant chosen in it is cleared on moving to another
howe.story.lastPaneKey = new WeakMap();

/**
 * Clear the plant chosen in the checklist on moving to another pane. A plant carried into another pane may have no
 * records within that pane's selection - e.g. in the History pane's years before it was first recorded, or in a
 * protected area where it has not been found - leaving the map nothing to show. The plant chosen together with a move
 * to the curation pane, by its speech bubble, is kept - see bioreportr.storyPage.keepTaxon.
 * @param {howe.story} storyPage - The story page
 * @param {String} activePaneKey - The key of the pane shown
 */
howe.story.clearTaxonOnPaneChange = function (storyPage, activePaneKey) {
    const lastPaneKey = howe.story.lastPaneKey.get(storyPage);
    howe.story.lastPaneKey.set(storyPage, activePaneKey);
    if (lastPaneKey !== undefined && lastPaneKey !== activePaneKey && !bioreportr.storyPage.keepTaxon.has(storyPage)) {
        // Deferred since an effect may not write signals
        fluid.invokeLater(() => storyPage.checklist.search.reset());
    }
};

// The selection last made in the Protected Areas pane by each story page, so that the plant chosen is cleared on making another
howe.story.lastRegion = new WeakMap();

/**
 * Clear the plant chosen in the checklist on moving between the selections of the Protected Areas pane, since the plant
 * may not have been recorded within the new one.
 * @param {howe.story} storyPage - The story page
 * @param {String|null} selectedRegion - The selection - a tab, category, area or figure of the pane
 * @param {String} activePaneKey - The key of the pane shown
 */
howe.story.clearTaxonOnRegionChange = function (storyPage, selectedRegion, activePaneKey) {
    const region = selectedRegion || null;
    const had = howe.story.lastRegion.has(storyPage);
    const lastRegion = howe.story.lastRegion.get(storyPage);
    howe.story.lastRegion.set(storyPage, region);
    if (activePaneKey === "Protected" && had && lastRegion !== region) {
        // Deferred since an effect may not write signals
        fluid.invokeLater(() => storyPage.checklist.search.reset());
    }
};
</script>
