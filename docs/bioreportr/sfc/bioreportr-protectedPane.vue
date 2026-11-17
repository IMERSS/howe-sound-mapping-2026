<script src="../js/story.js"></script>
<fluid-import src="bioreportr-atlasPanel.vue"></fluid-import>
<script>
"use strict";

// The Protected Areas pane of a story, assessing its native flora against its protected areas and Key Biodiversity
// Areas. Everything it shows follows the one selection of the story page,
// selectedRegion - all the protected areas when none is selected, a category, an individual area, all the KBAs or a
// KBA:
//   - the map, drawn by the pane's region handler from scripts/Protected_map_mapbox.R, holds each shape once, with a
//     layer for each category drawn from them by a filter - clicking an area or a KBA selects it, and a card
//     describes it as it is hovered or tapped
//   - the map's legend selects a category
//   - the pane's text opens with a card summarising the selection, and the area below the map holds a chart of the
//     categories, or of the areas within the selected one - both written as HTML by the script, as a card or chart
//     for each selection, of which the one for the selection is shown by bioreportr.protectedAreas.showSelection. Their
//     rows and links select what they name
//   - the records and the checklist are filtered to the selection, and a smaller panel of the plant chosen in the
//     checklist gives its records within it
// The behaviour is configured onto the story page, as its member protectedAreas, by the layer
// bioreportr.storyPageProtectedAreas, defined in bioreportr-storyPageProtectedAreas.vue, which a project names in the
// $layers of its <project>-story.vue, together with bioreportr.atlasPanel, whose helpers it uses. The project's story also names the fields of the records which
// may filter them, its regionFilterFieldNames, among which are "ProtectedArea" and "KBA" - see GroupField in
// scripts/intersectShapes.R

// noinspection ES6ConvertVarToLetConst // otherwise this is a duplicate on minifying
var bioreportr = fluid.registerNamespace("bioreportr");
// noinspection ES6ConvertVarToLetConst // otherwise this is a duplicate on minifying
var hortis = fluid.registerNamespace("hortis");
fluid.registerNamespace("bioreportr.protectedAreas");

fluid.def("bioreportr.protectedAreas", {
    $layers: "fluid.component",
    // Whether the pane keeps only the records which can be mapped, leaving out the species known only from records
    // without a position, e.g. those of lists, which would leave the map nothing to fit when chosen. Named once, as
    // protectedMappedOnly in the settings of the project's bioreportr.yaml, which scripts/Protected_map_mapbox.R reads
    // too, so that the pane's summaries agree
    mappedOnly: "{storyPage}.protectedMappedOnly",
    active: "$compute:bioreportr.storyPage.isActive({storyPage}.activePaneKey, Protected)",
    // Bound once the map is ready - see bioreportr.keepBinding
    hoverBinding: {$transient: null, dispose: "bioreportr.unbind"},
    hover: `$effect:bioreportr.keepBinding({self}, hoverBinding, bioreportr.protectedAreas.bindCards, {storyPage},
        {storyPage}.map.readyMap, {storyPage}.mapData, {global})`,
    selects: {
        $bindable: {
            bind: "bioreportr.protectedAreas.bindSelects({storyPage}, {global})",
            unbind: "bioreportr.unbind({boundValue})"
        }
    },
    shown: "$effect:bioreportr.protectedAreas.showSelection({storyPage}.selectedRegion, {self}.baseRegion, {self}.active, {global})",
    // The plant chosen in the checklist, with its records within the selected region, shown in a smaller panel beside
    // the chart, in place of the atlas's
    regionRecords: "$compute:bioreportr.atlas.taxonRecords({storyPage}.pkg, {storyPage}.finalFilteredObs, {storyPage}.checklistTaxon, {storyPage}.sightingPredicates)",
    panelMarkup: "$compute:bioreportr.protectedAreas.panelMarkup({storyPage}.checklistTaxon, {self}.regionRecords, {storyPage}.selectedRegion, {storyPage}.statusLabels)",
    // The native species reported in no protected area, and the ids of the native species, those of conservation
    // concern and those reported within a KBA - see bioreportr.protectedAreas.regionFilter
    // They are derived only once the pane is first shown, or a selection needs them - see the story page's activatedPanes
    taxonSets: "$compute:bioreportr.protectedAreas.taxonSetsWhenNeeded({storyPage}, {storyPage}.activatedPanes, {storyPage}.selectedRegion)",
    // The area, group or other region of the selection, without any subset of its species - outlined on the map, marked
    // in the legend, and summarised by the card and chart shown
    baseRegion: "$compute:bioreportr.protectedAreas.baseRegion({storyPage}.selectedRegion)",
    // Whether the map's grid is shown - by the active pane, or while the unprotected diversity is selected here. Read
    // by the map, which is configured by the project's <project>-story.vue
    gridVisible: "$compute:bioreportr.protectedAreas.gridVisible({storyPage}.activePane.visibleGrid, {storyPage}.activePaneKey, {self}.baseRegion)"
});

// The selection of the native species reported in no protected area, as the script names it in its card, chart and
// tab, and of all the protected areas together, whose card is the overview - see scripts/Protected_map_mapbox.R
bioreportr.protectedAreas.unprotected = "Unprotected native plant diversity";
bioreportr.protectedAreas.allAreas = "Protected areas";

// The subsets of the species of a region which a figure of its card may select, in a selection such as
// "Regional park · species of conservation concern", by the set of taxa of bioreportr.protectedAreas.taxonSets they keep
bioreportr.protectedAreas.subsets = {
    "native species": "native",
    "species of conservation concern": "concern",
    "within Key Biodiversity Areas": "kba",
    "found in no other category": "unique"
};

/**
 * Parse a selection into its region and any subset of that region's species.
 * @param {String|null} selectedRegion - The selection, e.g. "Mount Work Regional Park · native species"
 * @return {{region: String|null, subset: String|undefined}} The region, and the key of the subset if any
 */
bioreportr.protectedAreas.parseSelection = function (selectedRegion) {
    const parts = (selectedRegion || "").split(" \u00b7 ");
    const subset = parts.length > 1 ? bioreportr.protectedAreas.subsets[fluid.peek(parts)] : undefined;
    return subset ? {region: parts.slice(0, -1).join(" \u00b7 "), subset} : {region: selectedRegion || null};
};

// The region of a selection, by whose card and chart it is shown - all the protected areas being shown by the overview
bioreportr.protectedAreas.baseRegion = function (selectedRegion) {
    const region = bioreportr.protectedAreas.parseSelection(selectedRegion).region;
    return region === bioreportr.protectedAreas.allAreas ? null : region;
};

/**
 * Compute the sets of taxa by which the pane selects some of the species of a region, once the pane is first shown or
 * the selection, e.g. held in the URL, needs them - until then they are empty. The story page's members are read
 * within, rather than as arguments, so that none of them is derived until then.
 * @param {bioreportr.storyPage} storyPage - The story page
 * @param {Object<String, Boolean>} activatedPanes - The panes which have been shown
 * @param {String|null} selectedRegion - The selection, as held in the URL, if any
 * @return {Object} The sets - see bioreportr.protectedAreas.taxonSets
 */
bioreportr.protectedAreas.taxonSetsWhenNeeded = function (storyPage, activatedPanes, selectedRegion) {
    const {region, subset} = bioreportr.protectedAreas.parseSelection(selectedRegion);
    const needed = activatedPanes.Protected || !!subset || region === bioreportr.protectedAreas.unprotected;
    const empty = new Set();
    return needed ? bioreportr.protectedAreas.taxonSets(storyPage.pkg, storyPage.taxa.rowById, storyPage.regionIndirectionRows) :
        {unprotected: empty, native: empty, concern: empty, kba: empty, unique: {}};
};

/**
 * Compute the sets of taxa by which the pane selects some of the species of a region.
 * @param {VizPackage} pkg - The data package
 * @param {Object<String, TaxonRow>} rowById - Map of taxon id to taxon row
 * @param {Object[]} indirectionRows - The rows of the region indirection table
 * @return {Object} Members `unprotected`, `native`, `concern` and `kba`, each a Set of taxon ids, and `unique`, a map
 * of each category of protected area to the Set of the native taxa reported in that category alone
 */
bioreportr.protectedAreas.taxonSets = function (pkg, rowById, indirectionRows) {
    const bareRowById = fluid.unwrapProxy(rowById);
    const isNative = id => {
        const taxon = bareRowById[id];
        return !!taxon && taxon.introduction_status === "native" && String(taxon.inSummary) === "1";
    };
    const idsWhere = predicates => new Set(hortis.distinctObs(pkg, hortis.selectObs(pkg, predicates), "iNaturalistTaxonId"));
    const protectedIds = idsWhere([{field: "ProtectedArea", op: "notNull"}]);
    const native = [...idsWhere([])].filter(isNative);
    return {
        unprotected: new Set(native.filter(id => !protectedIds.has(id))),
        native: new Set(native),
        concern: new Set(native.filter(id => bareRowById[id].provincial_concern === "concern")),
        // A story whose records lie in no KBA, e.g. Galiano Island's, has no KBA field, and a query of a field which the
        // package lacks fails
        kba: pkg.tables.obs.columns.KBA ? idsWhere([{field: "KBA", op: "notNull"}]) : new Set(),
        unique: bioreportr.protectedAreas.uniqueByCategory(pkg, native, indirectionRows)
    };
};

/**
 * Find the native taxa reported within the protected areas of only one category.
 * @param {VizPackage} pkg - The data package
 * @param {String[]} native - The ids of the native taxa
 * @param {Object[]} indirectionRows - The rows of the region indirection table
 * @return {Object<String, Set<String>>} Map of each category to the ids of the taxa reported in it alone
 */
bioreportr.protectedAreas.uniqueByCategory = function (pkg, native, indirectionRows) {
    const categories = new Set(indirectionRows.filter(row => row.regionField === "Protected").map(row => row.label));
    const categoryById = {};
    indirectionRows.forEach(row => {
        if (row.regionField === "ProtectedArea" && categories.has(row.label)) {
            categoryById[row.id] = row.label;
        }
    });
    const isNative = new Set(native);
    const categoriesOf = {};
    hortis.countObsByPair(pkg, hortis.selectAllObs(pkg), "iNaturalistTaxonId", "ProtectedArea").forEach(([id, area]) => {
        const category = categoryById[area];
        if (category && isNative.has(id)) {
            (categoriesOf[id] = categoriesOf[id] || new Set()).add(category);
        }
    });
    const togo = {};
    Object.entries(categoriesOf).forEach(([id, found]) => {
        if (found.size === 1) {
            const [category] = found;
            (togo[category] = togo[category] || new Set()).add(id);
        }
    });
    return togo;
};

/**
 * Compute the predicates of the selection of a region by the Protected Areas pane, which may also select all the
 * protected areas, or the native species reported in none, and a subset of the species of a region.
 * @param {String|null} selectedRegion - The selection, as held in the URL, if any
 * @param {Object[]} indirectionRows - The rows of the region indirection table
 * @param {String[]} fieldNames - The fields of regions which may be selected
 * @param {Object} taxonSets - The sets of taxa, as computed by bioreportr.protectedAreas.taxonSets
 * @param {String} activePaneKey - The key of the active pane
 * @param {Boolean} mappedOnly - Whether the pane keeps only the records which can be mapped
 * @return {Object[]} The predicates
 */
bioreportr.protectedAreas.regionPredicates = function (selectedRegion, indirectionRows, fieldNames, taxonSets, activePaneKey, mappedOnly) {
    const {region, subset} = bioreportr.protectedAreas.parseSelection(selectedRegion);
    const inSet = set => ({field: "iNaturalistTaxonId", op: "in", value: [...set]});
    const regionPredicates = region === bioreportr.protectedAreas.allAreas ? [{field: "ProtectedArea", op: "notNull"}] :
        region === bioreportr.protectedAreas.unprotected ? [inSet(taxonSets.unprotected)] :
            bioreportr.regionSelectionPredicates(region, indirectionRows, fieldNames);
    const set = subset === "unique" ? taxonSets.unique[region] || new Set() : taxonSets[subset];
    const subsetPredicates = subset ? [inSet(set)] : [];
    const isProtected = activePaneKey === "Protected";
    const nativePredicates = isProtected ? [inSet(taxonSets.native)] : [];
    const mappedPredicates = isProtected && mappedOnly ? hortis.mappedPredicates : [];
    return [...regionPredicates, ...subsetPredicates, ...nativePredicates, ...mappedPredicates];
};

// The map's grid of records, hidden on this pane, shows where the native species outside protected areas grow when
// they are selected
bioreportr.protectedAreas.gridVisible = (visibleGrid, activePaneKey, baseRegion) =>
    !!visibleGrid || activePaneKey === "Protected" && baseRegion === bioreportr.protectedAreas.unprotected;

// The pane's section, rendered from the template below
fluid.def("bioreportr.protectedPane", {
    $layers: "fluid.component"
});

/** The Protected Areas pane, whose chart and map select categories and individual areas **/

/**
 * Render the smaller panel of the plant chosen in the checklist which the pane shows beside its chart - its photo, names
 * and status, and its records within the selected region, or anywhere if none is selected - without the atlas's charts
 * of its history.
 * @param {TaxonRow|null} taxon - The chosen plant
 * @param {Object[]} records - Its dated records within the selected region, in date order
 * @param {String|null} region - The selected region, if any
 * @param {Object<String, String>} statusLabels - The label of each reporting status - see bioreportr.atlas.statusLabel
 * @return {String} The panel's markup, empty if no plant with records there is chosen
 */
bioreportr.protectedAreas.panelMarkup = function (taxon, records, region, statusLabels) {
    let togo = "";
    if (taxon && records.length > 0) {
        // The unprotected diversity is not a place, so it is named alone rather than as the place "In" which records lie
        const within = region && !region.startsWith(bioreportr.protectedAreas.unprotected) ? "In " : "";
        const where = region ? `<div class="mxcw-pa-taxon-region">${within}${hortis.dataTable.encode(region)}</div>` : "";
        togo = `<div class="mxcw-solow-taxon-pane mxcw-atlas-taxon-pane mxcw-pa-taxon-pane">
  <div class="mxcw-taxon-image">${hortis.renderTaxonImage(taxon.iNaturalistTaxonImage, taxon.id)}</div>
  <div class="mxcw-taxon-info">
    <div class="mxcw-taxon-name">${hortis.dataTable.encode((taxon.scientificName || taxon.iNaturalistTaxonName) + (taxon.commonName ? ` (${taxon.commonName})` : ""))}</div>
    <div class="mxcw-atlas-facts">
      ${where}
      <dl class="mxcw-taxon-fields">
        ${bioreportr.atlas.field("Status", bioreportr.atlas.statusLabel(taxon.reportingStatus, statusLabels))}
        <dt>Records:</dt> <dd>${bioreportr.formatCount(records.length)}</dd>
        <dt>First seen:</dt> <dd>${bioreportr.eventDay(records[0].eventDate)}</dd>
        <dt>Last seen:</dt> <dd>${bioreportr.eventDay(fluid.peek(records).eventDate)}</dd>
        ${bioreportr.atlas.statusFields(taxon)}
      </dl>
    </div>
  </div>
</div>`;
    }
    return togo;
};

/**
 * Choose the panel of the plant chosen in the checklist for the pane shown - this pane's smaller one, or else the
 * atlas's.
 * @param {String} activePaneKey - The pane shown
 * @param {String} atlasMarkup - The atlas's panel
 * @param {String} protectedMarkup - This pane's panel
 * @return {String} The markup of the panel
 */
bioreportr.protectedAreas.choosePanel = (activePaneKey, atlasMarkup, protectedMarkup) =>
    activePaneKey === "Protected" ? protectedMarkup : atlasMarkup;

// The panel is shown on the atlas and on this pane, while a plant with records is chosen
bioreportr.protectedAreas.panelVisible = (markup, activePaneKey) => !!markup && (activePaneKey === "Status" || activePaneKey === "Protected");

/**
 * Whether the Protected Areas pane is the one shown - read from the page, since the cards are shown from map events.
 * @param {Document} dokkument - The page
 * @return {Boolean} Whether its section is shown
 */
bioreportr.protectedAreas.isShown = function (dokkument) {
    const section = dokkument.querySelector(".mxcw-paneKey-Protected");
    return !!(section && section.offsetParent);
};

/**
 * Show a card describing each individual area as the pointer passes over it, or as it is tapped on a touch screen,
 * while the pane is shown. The card's markup is the property `card` given to the area's shape by scripts/Protected_map_mapbox.R.
 * MapLibre takes the touches made on the map for its own gestures, so that a tap sends neither a mouse movement nor
 * a click - the tap is recognised from the pointer events, as bioreportr.solowMapLayer.bindHover does, and also selects
 * the area tapped, as a click does.
 * @param {bioreportr.storyPage} storyPage - The story page, whose selected region a tap sets
 * @param {maplibregl.Map} map - The story's map, once ready
 * @param {Object} mapData - The story's map data, whose style holds the areas' layers
 * @param {Window} window - The window holding the map
 * @return {Binding|null} The binding, removed should the map or its data change - see bioreportr.binding
 */
bioreportr.protectedAreas.bindCards = function (storyPage, map, mapData, window) {
    if (!map || !mapData) {
        return null;
    }
    const binding = bioreportr.binding();
    // The layers whose shapes carry cards, in sources named "... .cards" - see regions_to_mapbox_source
    const cardLayers = mapData.style.layers.filter(layer => layer.type === "fill" && layer.source?.endsWith(".cards"))
        .map(layer => layer.id);
    const card = binding.element(window.document.createElement("div"));
    card.className = "mxcw-pa-card";
    card.hidden = true;
    map.getContainer().appendChild(card);
    let shown = null;
    // The layers with cards, found once the map's style holds them
    let ids = [];
    // Returns the id of the area shown, if any
    const show = event => {
        if (ids.length === 0) {
            ids = cardLayers.filter(id => map.getLayer(id));
        }
        // The topmost shape under the pointer, so that a KBA is described rather than the area beneath it
        const feature = bioreportr.protectedAreas.isShown(window.document) && ids.length &&
            map.queryRenderedFeatures(event.point, {layers: ids})[0];
        const id = feature ? feature.properties.region : null;
        if (id !== shown) {
            card.innerHTML = id ? feature.properties.card : "";
            shown = id;
        }
        card.hidden = !id;
        if (id) {
            const {width, height} = map.getContainer().getBoundingClientRect();
            card.style.left = Math.max(8, Math.min(event.point.x + 16, width - card.offsetWidth - 8)) + "px";
            card.style.top = Math.max(8, Math.min(event.point.y + 16, height - card.offsetHeight - 8)) + "px";
        }
        return id;
    };
    // At most once a frame, since finding the area under the pointer is costly over so many layers
    let pending = null;
    binding.onMap(map, "mousemove", event => {
        if (pending === null) {
            window.requestAnimationFrame(() => {
                const latest = pending;
                pending = null;
                show(latest);
            });
        }
        pending = event;
    });
    const container = map.getContainer();
    let start = null;
    binding.listen(container, "pointerdown", event => {
        start = event.pointerType === "touch" && event.isPrimary ?
            {id: event.pointerId, x: event.clientX, y: event.clientY, time: event.timeStamp} : null;
    }, true);
    binding.listen(container, "pointerup", event => {
        const tap = start;
        start = null;
        if (tap && event.pointerId === tap.id && event.timeStamp - tap.time <= bioreportr.solowMapLayer.tapDuration &&
            Math.hypot(event.clientX - tap.x, event.clientY - tap.y) <= bioreportr.solowMapLayer.tapSlop) {
            const rect = map.getCanvas().getBoundingClientRect();
            const id = show({point: {x: event.clientX - rect.left, y: event.clientY - rect.top}});
            // A proposed KBA has a card but no records, so is not selected
            if (id && !id.startsWith("Proposed KBA:")) {
                bioreportr.storyPage.selectRegion(storyPage, id);
            }
        }
    }, true);
    binding.listen(container, "pointercancel", () => {
        start = null;
    }, true);
    binding.listen(map.getCanvas(), "mouseleave", () => {
        card.hidden = true;
        shown = null;
    });
    return binding;
};

/**
 * Make the rows of the charts and the links of the summaries select what they name, as the map's legend and its
 * shapes do - by click, or by Enter or Space from the keyboard. A row of a chart which is already selected clears the
 * selection, as a row of the legend does; a link, e.g. back to all the protected areas, always selects what it names,
 * all of them if it names nothing.
 * @param {bioreportr.storyPage} storyPage - The story page, whose selected region they set
 * @param {Window} window - The window holding the page
 * @return {Binding} The binding - see bioreportr.binding
 */
bioreportr.protectedAreas.bindSelects = function (storyPage, window) {
    const dokkument = window.document;
    const binding = bioreportr.binding();
    const select = target => {
        const row = target.closest?.(".mxcw-pa-row[data-region]");
        const link = target.closest?.("[data-select]");
        if (link && link.matches(".mxcw-pa-stat") && link.getAttribute("aria-pressed") === "true") {
            // A selected figure returns to all the species of its region
            bioreportr.storyPage.selectRegion(storyPage, bioreportr.protectedAreas.baseRegion(link.dataset.select));
        } else if (row) {
            bioreportr.storyPage.selectRegion(storyPage, row.getAttribute("aria-pressed") === "true" ? null : row.dataset.region);
        } else if (link) {
            bioreportr.storyPage.selectRegion(storyPage, link.dataset.select || null);
        }
        return !!(row || link);
    };
    binding.listen(dokkument, "click", event => select(event.target));
    binding.listen(dokkument, "keydown", event => {
        if ((event.key === "Enter" || event.key === " ") && select(event.target)) {
            event.preventDefault();
        }
    });
    return binding;
};

/**
 * Choose the view of a selection among those of a container - the one for the selection itself; failing that, the one
 * listing it among its members, e.g. the chart of an area's category; failing that, the view of no selection.
 * @param {Element[]} views - The views, each with a `data-key`, and any `data-members` as a JSON array
 * @param {String|null} selectedRegion - The selection, if any
 * @return {Element|undefined} The view to be shown
 */
bioreportr.protectedAreas.viewFor = function (views, selectedRegion) {
    const members = view => JSON.parse(view.dataset.members || "[]");
    return selectedRegion && (views.find(view => view.dataset.key === selectedRegion) ||
        views.find(view => members(view).includes(selectedRegion))) || views.find(view => view.dataset.key === "");
};

/**
 * Show, in the summaries of the pane's text and the charts beneath the map, the view of the selection - see
 * bioreportr.protectedAreas.viewFor - bringing a newly shown summary into view, and mark the selected row of a chart, tab
 * and figure.
 * @param {String|null} selectedRegion - The selection, if any
 * @param {String|null} baseRegion - Its region, without any subset of its species, whose views are shown
 * @param {Boolean} active - Whether the pane is shown, when its views are rendered
 * @param {Window} window - The window holding the page
 */
bioreportr.protectedAreas.showSelection = function (selectedRegion, baseRegion, active, window) {
    if (active) {
        window.setTimeout(() => {
            const dokkument = window.document;
            dokkument.querySelectorAll(".mxcw-pa-views").forEach(container => {
                const views = [...container.children].filter(view => view.dataset.key !== undefined);
                const shown = bioreportr.protectedAreas.viewFor(views, baseRegion);
                const changed = shown && shown.hidden;
                views.forEach(view => {
                    view.hidden = view !== shown;
                });
                if (changed && container.classList.contains("mxcw-pa-summaries")) {
                    shown.scrollIntoView({block: "nearest", behavior: "smooth"});
                }
            });
            dokkument.querySelectorAll(".mxcw-pa-row[data-region]").forEach(row => {
                row.setAttribute("aria-pressed", String(row.dataset.region === baseRegion));
            });
            // The tab of the unprotected diversity while any of it is selected, and otherwise that of all the protected
            // areas; and the selected figure of a card
            const unprotected = baseRegion === bioreportr.protectedAreas.unprotected;
            dokkument.querySelectorAll(".mxcw-pa-stat[data-select]").forEach(stat => {
                stat.setAttribute("aria-pressed", String(stat.dataset.select === selectedRegion));
            });
            dokkument.querySelectorAll(".mxcw-pa-tab").forEach(tab => {
                tab.setAttribute("aria-pressed", String(unprotected === (tab.dataset.select === bioreportr.protectedAreas.unprotected)));
            });
        }, 0);
    }
};
</script>

<style>
/* The data area below the map, while this pane is shown: the panel of the plant chosen in the checklist on the left,
   while one is chosen, and the chart on the right, or across the whole width, with the records' bar beneath both as on
   the other panes. As on the atlas while it shows a plant, the map and this area are given default heights, which the
   resize bar between them may change, since neither is !important - the shared rule which would shrink the area to
   the records' bar while they are collapsed leaves alone a pane showing widgets of its own there, see
   imerss-viz-story.css */
.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) {
    --pa-data-height: 300px;
}

.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-map {
    /* Less the resize bar beneath it, as on the atlas */
    height: calc(100% - var(--pa-data-height) - 14px);
}

.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data {
    height: var(--pa-data-height);
    min-height: 0;
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    /* The records' bar, collapsed, has a strip of the same height as on the other panes - see
       --mxcw-records-header-height in imerss-viz-story.css */
    grid-template-rows: minmax(0, 1fr) 40px;
    grid-template-areas: "chart" "records";
    align-items: stretch;
}

.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data:has(> .mxcw-atlas-has-taxon) {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    grid-template-areas: "taxon chart" "records records";
}

/* With the records open, they share the area with the panel and the chart */
.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data:has(> .mxcw-obs-table-holder:not(.mxcw-records-collapsed)) {
    grid-template-rows: minmax(0, 1fr) 220px;
    row-gap: 8px;
}

/* Open, the records fill their strip, whatever height the bar between a taxon panel and the records, hidden here, last
   gave them */
.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data > .mxcw-obs-table-holder:not(.mxcw-records-collapsed) {
    align-self: stretch;
    height: auto !important;
    display: flex;
    flex-direction: column;
}

.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data > .mxcw-obs-table-holder:not(.mxcw-records-collapsed) > .mxcw-obs-table {
    flex: 1 1 0;
    min-height: 0;
}

/* The plant's panel and the chart's card are inset alike from the column's edges and the map, with an even gutter
   between them, and are of the same height */
.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data > .mxcw-atlas-has-taxon {
    grid-area: taxon;
    height: auto;
    min-height: 0;
    margin: 8px 4px 0 8px;
    overflow: hidden;
}

.mxcw-data:has(> .mxcw-atlas-has-taxon) .mxcw-dataPane-Protected .mxcw-pa-chart {
    margin-left: 4px;
}

.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data > .resize-bar {
    display: none;
}

.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data > .mxcw-obs-table-holder {
    grid-area: records;
    min-height: 0;
}

/* Collapsed, the bar is centred in its strip, as on the other panes */
.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)) > .mxcw-data > .mxcw-obs-table-holder.mxcw-records-collapsed {
    align-self: center;
    height: 32px;
}

.mxcw-dataPane-Protected {
    grid-area: chart;
    min-width: 0;
    min-height: 0;
    overflow: hidden;
}

/* The wrappers of the chart fill its cell, within which it scrolls */
.mxcw-dataPane-Protected > div,
.mxcw-dataPane-Protected .mxcw-dataPane-widgets {
    height: 100%;
}

/* With the records open, the area grows as the atlas's does, leaving the map the same height, and the records fill a
   strip of the same height as the atlas's at the foot of the column, beneath the panel and the chart - unless the
   resize bar has since given the map and the area heights of their own */
.imerss-main .mxcw-leftPane.mxcw-leftPane:has(.mxcw-dataPane-Protected:not(.fl-hidden)):has(.mxcw-obs-table-holder:not(.mxcw-records-collapsed)) {
    --pa-data-height: calc(100% - 222px);
}

/* The smaller panel of the plant, giving only its names, status and records within the selected region */
.mxcw-pa-taxon-pane .mxcw-taxon-fields {
    margin: 4px 0 0;
}

/* With no chart of the plant's history beside its facts, they take the panel's whole width, as a dl of two columns */
.mxcw-atlas-taxon-pane.mxcw-pa-taxon-pane .mxcw-taxon-info {
    grid-template-columns: minmax(0, 1fr);
    grid-template-rows: auto auto;
    align-content: start;
}

.mxcw-pa-taxon-pane .mxcw-atlas-facts dl {
    display: grid;
    grid-template-columns: max-content minmax(0, 1fr);
    gap: 1px 8px;
}

.mxcw-pa-taxon-pane .mxcw-atlas-facts dd {
    margin: 0;
}

/* The plant's conservation status, the longest of its facts, runs beneath its label across the panel's width - see
   bioreportr.atlas.statusFields */
.mxcw-pa-taxon-pane .mxcw-atlas-facts dt:has(+ dd.mxcw-taxon-status),
.mxcw-pa-taxon-pane .mxcw-atlas-facts dd.mxcw-taxon-status {
    grid-column: 1 / -1;
}

.mxcw-pa-taxon-region {
    margin-top: 2px;
    font-size: var(--story-small);
    font-style: italic;
}

/* Beside the panel the chart is narrow, so its names give way and its counts of areas are left out */
.mxcw-pa-chart {
    container-type: inline-size;
}

@container (max-width: 440px) {
    /* Outweighing the chart's own columns below */
    .mxcw-pa-chart ul.mxcw-pa-rows {
        grid-template-columns: minmax(0, 1.3fr) minmax(40px, 1fr) max-content;
        column-gap: 8px;
    }

    .mxcw-pa-chart .mxcw-pa-name {
        overflow: hidden;
        white-space: nowrap;
        text-overflow: ellipsis;
    }

    .mxcw-pa-chart .mxcw-pa-name small {
        display: none;
    }
}

/* The charts beneath the map, one shown at a time - see bioreportr.protectedAreas.showSelection */
.mxcw-pa-charts {
    height: 100%;
}

.mxcw-pa-chart[hidden] {
    display: none;
}

.mxcw-pa-chart .mxcw-pa-back {
    margin-right: 10px;
}

/* Shown in the data area below the map - see mxcw-data-pane-html in src/js/storyBuild.js */
/* A dark card, as the site's tiles and map cards are, set apart from the column's teal on which the records' bar sits,
   and inset as that bar is */
.mxcw-pa-chart {
    box-sizing: border-box;
    height: calc(100% - 8px);
    margin: 8px 8px 0;
    padding: 8px 14px;
    overflow: auto;
    color: #eefaff;
    background: #0d3040;
    border: 1px solid rgba(74, 154, 170, 0.45);
    border-radius: var(--data-table-radius, 8px);
}

.mxcw-pa-chart figcaption {
    margin-bottom: 4px;
    font-size: var(--story-data);
    font-weight: 700;
    color: #eefaff;
}

.mxcw-pa-chart .mxcw-pa-rows {
    list-style: none;
    margin: 0;
    padding: 0;
    display: grid;
    grid-template-columns: max-content minmax(80px, 1fr) max-content;
    column-gap: 10px;
    row-gap: 3px;
    align-items: center;
    font-size: var(--story-data);
}

.mxcw-pa-row {
    display: grid;
    grid-column: 1 / -1;
    grid-template-columns: subgrid;
    align-items: center;
    margin: 0 -6px;
    padding: 2px 6px;
    border-radius: 6px;
    outline: 1px solid transparent;
}

.mxcw-pa-row[data-region] {
    cursor: pointer;
}

.mxcw-pa-row[data-region]:hover,
.mxcw-pa-row[data-region]:focus-visible {
    background: rgba(168, 200, 208, 0.1);
}

.mxcw-pa-row[aria-pressed="true"] {
    background: rgba(253, 242, 206, 0.12);
    outline-color: #FDF2CE;
}

/* The card summarising the selection at the head of the pane's text - see bioreportr.protectedAreas.showSelection. Its
   colour is that of the selected category, or the KBAs' */
.mxcw-pa-summaries {
    margin: 0.4em 0 1em;
}

.mxcw-pa-card-summary {
    padding: 10px 12px 12px;
    background: #0d3040;
    border-top: 3px solid var(--pa-colour);
    border-radius: var(--data-table-radius, 8px);
}

.mxcw-pa-card-summary[hidden] {
    display: none;
}

/* The tabs at the top right of the card, of all the protected areas and of the native plant diversity outside them,
   the selected one joined to the card beneath */
.mxcw-pa-tabs {
    display: flex;
    justify-content: flex-end;
    gap: 4px;
}

.mxcw-pa-tab {
    padding: 4px 10px;
    font-size: var(--story-small);
    color: #a8c8d0;
    cursor: pointer;
    background: rgba(13, 48, 64, 0.55);
    border-radius: 6px 6px 0 0;
}

.mxcw-pa-tab:hover,
.mxcw-pa-tab:focus-visible {
    color: #eefaff;
}

.mxcw-pa-tab[aria-pressed="true"] {
    color: #eefaff;
    background: #0d3040;
}

.mxcw-pa-tabs ~ .mxcw-pa-card-summary {
    border-top-right-radius: 0;
}

.mxcw-pa-crumbs {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-bottom: 8px;
}

.mxcw-sectionColumn .mxcw-pa-summary-title {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 0;
    font-size: var(--story-body);
    color: #eefaff;
}

.mxcw-pa-summary-title::before {
    content: "";
    flex: none;
    width: 11px;
    height: 11px;
    border-radius: 2px;
    background: var(--pa-colour);
}

.mxcw-sectionColumn .mxcw-pa-summary-subtitle {
    margin: 2px 0 8px 19px;
    font-size: var(--story-small);
    color: #a8c8d0;
}

.mxcw-sectionColumn .mxcw-pa-summary-text {
    margin: 0 0 10px;
    font-size: var(--story-data);
    line-height: 1.45;
    color: #c4dbe2;
}

/* The links of the summaries and charts, which select what they name - see bioreportr.protectedAreas.bindSelects */
.mxcw-pa-link {
    cursor: pointer;
    color: #eefaff;
    text-decoration: underline dotted;
    text-underline-offset: 3px;
}

.mxcw-pa-link:hover,
.mxcw-pa-link:focus-visible {
    text-decoration-style: solid;
}

.mxcw-pa-crumbs .mxcw-pa-link,
.mxcw-pa-back {
    display: inline-block;
    padding: 1px 6px;
    font-size: var(--story-small);
    font-weight: 400;
    color: #a8c8d0;
    text-decoration: none;
    border: 1px solid rgba(168, 200, 208, 0.35);
    border-radius: 5px;
}

.mxcw-pa-crumbs .mxcw-pa-link:hover,
.mxcw-pa-crumbs .mxcw-pa-link:focus-visible,
.mxcw-pa-back:hover,
.mxcw-pa-back:focus-visible {
    color: #eefaff;
    background: rgba(168, 200, 208, 0.12);
}

/* The panel's figures, each a number over its meaning, in a grid as wide as the column allows */
.mxcw-pa-stats {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(118px, 1fr));
    gap: 8px 12px;
}

.mxcw-pa-stat {
    display: flex;
    flex-direction: column;
    line-height: 1.25;
}

.mxcw-pa-stat b {
    font-size: 20px;
    color: #eefaff;
}

.mxcw-pa-stat span {
    font-size: var(--story-small);
    color: #a8c8d0;
}

/* The figures of the unprotected diversity, each selecting its species, as the rows of a legend do */
.mxcw-pa-stat[data-select] {
    padding: 4px 8px;
    margin: -4px -8px;
    cursor: pointer;
    border-radius: 6px;
    border: 1px solid transparent;
}

.mxcw-pa-stat[data-select]:hover,
.mxcw-pa-stat[data-select]:focus-visible {
    background: rgba(168, 200, 208, 0.1);
}

.mxcw-pa-stat[data-select][aria-pressed="true"] {
    background: rgba(224, 122, 95, 0.16);
    border-color: var(--pa-colour);
}

.mxcw-pa-richest-holder {
    margin-top: 10px;
    padding-top: 8px;
    border-top: 1px solid rgba(168, 200, 208, 0.25);
    font-size: var(--story-small);
}

.mxcw-pa-richest-title {
    color: #a8c8d0;
}

.mxcw-sectionColumn .mxcw-pa-richest {
    margin: 4px 0 0;
    padding-left: 1.3em;
}

.mxcw-pa-richest li {
    margin: 0;
    color: #eefaff;
}

.mxcw-pa-richest li b {
    margin-left: 6px;
    color: #FDF2CE;
}

/* The card describing an individual area on the map, framed as the map's other cards - hidden by its attribute, which
   its display would otherwise override */
.mxcw-pa-card[hidden] {
    display: none;
}

.mxcw-pa-card {
    position: absolute;
    z-index: 3;
    pointer-events: none;
    display: flex;
    flex-direction: column;
    gap: 2px;
    max-width: 260px;
    padding: 8px 12px;
    color: #eefaff;
    font-size: var(--story-data);
    line-height: 1.35;
    background: #0d3040;
    border: 1px solid #4a9aaa;
    border-radius: 8px;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
}

.mxcw-pa-card-name {
    font-weight: 700;
}

.mxcw-pa-card-category {
    color: #a8c8d0;
}

.mxcw-pa-card-category::before {
    content: "";
    display: inline-block;
    width: 9px;
    height: 9px;
    margin-right: 6px;
    border-radius: 2px;
    background: var(--pa-colour);
}

.mxcw-pa-card-kba {
    --pa-colour: #FDF2CE;
}

.mxcw-pa-card-owner {
    font-size: var(--story-small);
    color: #a8c8d0;
}

.mxcw-pa-card-count b {
    color: #FDF2CE;
}

.mxcw-pa-name {
    color: #eefaff;
    line-height: 1.2;
}

.mxcw-pa-name small {
    font-size: var(--story-small);
    color: #a8c8d0;
    white-space: nowrap;
}

.mxcw-pa-track {
    height: 10px;
    border-radius: 5px;
    background: rgba(168, 200, 208, 0.12);
    overflow: hidden;
}

.mxcw-pa-bar {
    display: block;
    height: 100%;
    border-radius: 5px;
    background: var(--pa-colour);
}

.mxcw-pa-count {
    text-align: right;
    font-variant-numeric: tabular-nums;
    font-weight: 700;
    color: #eefaff;
}

/* The KBAs overlap the protected areas, so their row is set apart below the categories */
.mxcw-pa-kba .mxcw-pa-name,
.mxcw-pa-kba .mxcw-pa-track,
.mxcw-pa-kba .mxcw-pa-count {
    margin-top: 6px;
    padding-top: 0;
}

.mxcw-pa-kba .mxcw-pa-name {
    color: #FDF2CE;
}

.mxcw-pa-kba .mxcw-pa-bar {
    background: repeating-linear-gradient(135deg, #FDF2CE 0 4px, rgba(253, 242, 206, 0.55) 4px 7px);
}

/* The native species outside every protected area, the remainder of the flora, set apart as the KBAs are */
.mxcw-pa-unprotected .mxcw-pa-name,
.mxcw-pa-unprotected .mxcw-pa-track,
.mxcw-pa-unprotected .mxcw-pa-count {
    margin-top: 6px;
}

.mxcw-pa-unprotected .mxcw-pa-name {
    color: #f2b8a6;
}

</style>

<!-- The <template> block below is written by src/js/storyBuild.js and must not be edited here: it holds the section
     knitted from each project's content/story/Protected.Rmd, whose front matter names bioreportr.protectedPane as its
     paneComponent - so that it holds the section of whichever project was built last. Edit the R Markdown and knit it,
     then run "npm run story", which replaces everything between <template> and </template> and nothing else in this
     file. The markup is a template, which may bind members of bioreportr.protectedPane with @{...} - written in the R Markdown
     as raw HTML, e.g. `<span>@{count}</span>`{=html}, which pandoc leaves as it is -->
<template>
<div id="native-plant-diversity-within-protected-areas" class="section level2 mxcw-paneKey-Protected"><h2>Native plant diversity within protected areas</h2><div class="mxcw-sectionInner"><div class="mxcw-sectionColumn">



<div class="mxcw-pa-summaries mxcw-pa-views">
<nav class="mxcw-pa-tabs">
<span class="mxcw-pa-tab" data-select="" role="button" tabindex="0">All protected areas</span>
<span class="mxcw-pa-tab" data-select="Unprotected native plant diversity" role="button" tabindex="0">Unprotected native plant diversity</span>
</nav>
<section class="mxcw-pa-card-summary" data-key="" style="--pa-colour: #eefaff">
<h3 class="mxcw-pa-summary-title">All protected and conserved areas</h3>
<p class="mxcw-pa-summary-text">Of the 782 native vascular plants known from the region, 569 (73%) have been recorded in at least one protected or conserved area, from provincial parks and ecological reserves to old growth management areas and private conservation lands. The remaining 213 are so far known only from outside protected areas.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>42</b>
<span>areas in 11 categories</span>
</div>
<div class="mxcw-pa-stat">
<b>61,585</b>
<span>hectares</span>
</div>
<div class="mxcw-pa-stat" data-select="Protected areas · native species" role="button" tabindex="0">
<b>569</b>
<span>native species · 73% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Protected areas · species of conservation concern" role="button" tabindex="0">
<b>5</b>
<span>of the 17 species of conservation concern</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Unprotected native plant diversity" hidden style="--pa-colour: #e07a5f">
<h3 class="mxcw-pa-summary-title">Unprotected native plant diversity</h3>
<p class="mxcw-pa-summary-subtitle">213 species · 994 records</p>
<p class="mxcw-pa-summary-text">213 native plants (27% of the region's native flora) have so far been recorded only outside protected and conserved areas. The grid on the map shows where they have been found—places protection has yet to reach, or species still to be looked for within the protected areas.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Unprotected native plant diversity" role="button" tabindex="0">
<b>213</b>
<span>native species · 27% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Unprotected native plant diversity · species of conservation concern" role="button" tabindex="0">
<b>12</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat" data-select="Unprotected native plant diversity · within Key Biodiversity Areas" role="button" tabindex="0">
<b>80</b>
<span>recorded within a Key Biodiversity Area</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Ecological reserve" hidden style="--pa-colour: #decb90">
<h3 class="mxcw-pa-summary-title">Ecological reserves</h3>
<p class="mxcw-pa-summary-subtitle">2 areas · 444 hectares</p>
<p class="mxcw-pa-summary-text">37 of the region's 782 native vascular plants (5%) have been recorded in ecological reserves.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Ecological reserve · native species" role="button" tabindex="0">
<b>37</b>
<span>native species · 5% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat" data-select="Ecological reserve · found in no other category" role="button" tabindex="0">
<b>3</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>192</b>
<span>native plant records</span>
</div>
</div>
<div class="mxcw-pa-richest-holder">
<span class="mxcw-pa-richest-title">Richest in native species</span>
<ol class="mxcw-pa-richest">
<li>
<span class="mxcw-pa-link" data-select="Bowen Island Ecological Reserve" role="button" tabindex="0">Bowen Island Ecological Reserve</span>
<b>37</b>
</li>
</ol>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Protected area" hidden style="--pa-colour: #5a96d2">
<h3 class="mxcw-pa-summary-title">Protected area</h3>
<p class="mxcw-pa-summary-subtitle">1 area · 2 hectares</p>
<p class="mxcw-pa-summary-text">12 of the region's 782 native vascular plants (2%) have been recorded in the protected area.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Protected area · native species" role="button" tabindex="0">
<b>12</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>16</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Provincial park" hidden style="--pa-colour: #8cc084">
<h3 class="mxcw-pa-summary-title">Provincial parks</h3>
<p class="mxcw-pa-summary-subtitle">14 areas · 43,492 hectares</p>
<p class="mxcw-pa-summary-text">489 of the region's 782 native vascular plants (63%) have been recorded in provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Provincial park · native species" role="button" tabindex="0">
<b>489</b>
<span>native species · 63% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Provincial park · species of conservation concern" role="button" tabindex="0">
<b>5</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat" data-select="Provincial park · found in no other category" role="button" tabindex="0">
<b>250</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>18,045</b>
<span>native plant records</span>
</div>
</div>
<div class="mxcw-pa-richest-holder">
<span class="mxcw-pa-richest-title">Richest in native species</span>
<ol class="mxcw-pa-richest">
<li>
<span class="mxcw-pa-link" data-select="Garibaldi Park" role="button" tabindex="0">Garibaldi Park</span>
<b>330</b>
</li>
<li>
<span class="mxcw-pa-link" data-select="Cypress Park" role="button" tabindex="0">Cypress Park</span>
<b>251</b>
</li>
<li>
<span class="mxcw-pa-link" data-select="Alice Lake Park" role="button" tabindex="0">Alice Lake Park</span>
<b>132</b>
</li>
</ol>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Conservancy" hidden style="--pa-colour: #4fae98">
<h3 class="mxcw-pa-summary-title">Conservancy</h3>
<p class="mxcw-pa-summary-subtitle">1 area · 728 hectares</p>
<p class="mxcw-pa-summary-text">21 of the region's 782 native vascular plants (3%) have been recorded in the conservancy.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Conservancy · native species" role="button" tabindex="0">
<b>21</b>
<span>native species · 3% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>31</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Migratory bird sanctuary" hidden style="--pa-colour: #9fd0e0">
<h3 class="mxcw-pa-summary-title">Migratory bird sanctuary</h3>
<p class="mxcw-pa-summary-subtitle">1 area · 1 hectares</p>
<p class="mxcw-pa-summary-text">1 of the region's 782 native vascular plants (0%) have been recorded in the migratory bird sanctuary.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Migratory bird sanctuary · native species" role="button" tabindex="0">
<b>1</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat" data-select="Migratory bird sanctuary · found in no other category" role="button" tabindex="0">
<b>1</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>1</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Wildlife management area" hidden style="--pa-colour: #7c86c9">
<h3 class="mxcw-pa-summary-title">Wildlife management area</h3>
<p class="mxcw-pa-summary-subtitle">1 area · 663 hectares</p>
<p class="mxcw-pa-summary-text">159 of the region's 782 native vascular plants (20%) have been recorded in the wildlife management area.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Wildlife management area · native species" role="button" tabindex="0">
<b>159</b>
<span>native species · 20% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Wildlife management area · species of conservation concern" role="button" tabindex="0">
<b>2</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat" data-select="Wildlife management area · found in no other category" role="button" tabindex="0">
<b>47</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>1,751</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Wildlife habitat area" hidden style="--pa-colour: #b6c7e8">
<h3 class="mxcw-pa-summary-title">Wildlife habitat areas</h3>
<p class="mxcw-pa-summary-subtitle">1 area · 2,078 hectares</p>
<p class="mxcw-pa-summary-text">12 of the region's 782 native vascular plants (2%) have been recorded in wildlife habitat areas.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Wildlife habitat area · native species" role="button" tabindex="0">
<b>12</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>15</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Old growth management area" hidden style="--pa-colour: #c2a878">
<h3 class="mxcw-pa-summary-title">Old growth management areas</h3>
<p class="mxcw-pa-summary-subtitle">1 area · 8,119 hectares</p>
<p class="mxcw-pa-summary-text">154 of the region's 782 native vascular plants (20%) have been recorded in old growth management areas.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Old growth management area · native species" role="button" tabindex="0">
<b>154</b>
<span>native species · 20% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Old growth management area · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat" data-select="Old growth management area · found in no other category" role="button" tabindex="0">
<b>8</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>614</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Wildland zone" hidden style="--pa-colour: #9fb28a">
<h3 class="mxcw-pa-summary-title">Sea to sky wildland zones</h3>
<p class="mxcw-pa-summary-subtitle">1 area · 5,031 hectares</p>
<p class="mxcw-pa-summary-text">61 of the region's 782 native vascular plants (8%) have been recorded in the Sea to Sky wildland zones.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Wildland zone · native species" role="button" tabindex="0">
<b>61</b>
<span>native species · 8% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Wildland zone · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>132</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Other effective conservation measure" hidden style="--pa-colour: #c9c2b0">
<h3 class="mxcw-pa-summary-title">Other effective conservation measures</h3>
<p class="mxcw-pa-summary-subtitle">10 areas · 830 hectares</p>
<p class="mxcw-pa-summary-text">12 of the region's 782 native vascular plants (2%) have been recorded in other effective conservation measures.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Other effective conservation measure · native species" role="button" tabindex="0">
<b>12</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>15</b>
<span>native plant records</span>
</div>
</div>
<div class="mxcw-pa-richest-holder">
<span class="mxcw-pa-richest-title">Richest in native species</span>
<ol class="mxcw-pa-richest">
<li>
<span class="mxcw-pa-link" data-select="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Dorman Point)" role="button" tabindex="0">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Dorman Point)</span>
<b>6</b>
</li>
<li>
<span class="mxcw-pa-link" data-select="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Queen Charlotte Channel)" role="button" tabindex="0">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Queen Charlotte Channel)</span>
<b>4</b>
</li>
<li>
<span class="mxcw-pa-link" data-select="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Anvil Island)" role="button" tabindex="0">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Anvil Island)</span>
<b>1</b>
</li>
</ol>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Private conservation land" hidden style="--pa-colour: #a593d8">
<h3 class="mxcw-pa-summary-title">Private conservation lands</h3>
<p class="mxcw-pa-summary-subtitle">9 areas · 197 hectares</p>
<p class="mxcw-pa-summary-text">87 of the region's 782 native vascular plants (11%) have been recorded in private conservation lands.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Private conservation land · native species" role="button" tabindex="0">
<b>87</b>
<span>native species · 11% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Private conservation land · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat" data-select="Private conservation land · found in no other category" role="button" tabindex="0">
<b>13</b>
<span>species found in no other category</span>
</div>
<div class="mxcw-pa-stat">
<b>313</b>
<span>native plant records</span>
</div>
</div>
<div class="mxcw-pa-richest-holder">
<span class="mxcw-pa-richest-title">Richest in native species</span>
<ol class="mxcw-pa-richest">
<li>
<span class="mxcw-pa-link" data-select="Cape Roger Curtis Park" role="button" tabindex="0">Cape Roger Curtis Park</span>
<b>45</b>
</li>
<li>
<span class="mxcw-pa-link" data-select="Fairy Fen Nature Reserve" role="button" tabindex="0">Fairy Fen Nature Reserve</span>
<b>18</b>
</li>
<li>
<span class="mxcw-pa-link" data-select="Sandy Beach Nature Reserve" role="button" tabindex="0">Sandy Beach Nature Reserve</span>
<b>17</b>
</li>
</ol>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Alice Lake Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Alice Lake Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 412 hectares</p>
<p class="mxcw-pa-summary-text">132 native plants have been recorded in Alice Lake Park, 17% of the region's native flora—3rd among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Alice Lake Park · native species" role="button" tabindex="0">
<b>132</b>
<span>native species · 17% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Alice Lake Park · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>1,660</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Apodaca Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Apodaca Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 12 hectares</p>
<p class="mxcw-pa-summary-text">58 native plants have been recorded in Apodaca Park, 7% of the region's native flora—6th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Apodaca Park · native species" role="button" tabindex="0">
<b>58</b>
<span>native species · 7% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>259</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Baynes Island Ecological Reserve" hidden style="--pa-colour: #decb90">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Ecological reserve" role="button" tabindex="0">↑ Ecological reserves</span>
</nav>
<h3 class="mxcw-pa-summary-title">Baynes Island Ecological Reserve</h3>
<p class="mxcw-pa-summary-subtitle">Ecological reserve · 45 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in Baynes Island Ecological Reserve.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Bowen Island Ecological Reserve" hidden style="--pa-colour: #decb90">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Ecological reserve" role="button" tabindex="0">↑ Ecological reserves</span>
</nav>
<h3 class="mxcw-pa-summary-title">Bowen Island Ecological Reserve</h3>
<p class="mxcw-pa-summary-subtitle">Ecological reserve · 400 hectares</p>
<p class="mxcw-pa-summary-text">37 native plants have been recorded in Bowen Island Ecological Reserve, 5% of the region's native flora—the most of the 2 ecological reserves.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Bowen Island Ecological Reserve · native species" role="button" tabindex="0">
<b>37</b>
<span>native species · 5% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>192</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Brackendale Eagles Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Brackendale Eagles Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 765 hectares</p>
<p class="mxcw-pa-summary-text">9 native plants have been recorded in Brackendale Eagles Park, 1% of the region's native flora—14th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Brackendale Eagles Park · native species" role="button" tabindex="0">
<b>9</b>
<span>native species · 1% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Brackendale Eagles Park · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>13</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Brigade Bluffs Nature Reserve" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">Brigade Bluffs Nature Reserve</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · Islands Trust Conservancy · 5 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in Brigade Bluffs Nature Reserve.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Cape Roger Curtis Park" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">Cape Roger Curtis Park</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · Bowen Island Conservancy · 13 hectares</p>
<p class="mxcw-pa-summary-text">45 native plants have been recorded in Cape Roger Curtis Park, 6% of the region's native flora—the most of the 9 private conservation lands.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Cape Roger Curtis Park · native species" role="button" tabindex="0">
<b>45</b>
<span>native species · 6% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>118</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Christie Islet Migratory Bird Sanctuary" hidden style="--pa-colour: #9fd0e0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Migratory bird sanctuary" role="button" tabindex="0">↑ Migratory bird sanctuary</span>
</nav>
<h3 class="mxcw-pa-summary-title">Christie Islet Migratory Bird Sanctuary</h3>
<p class="mxcw-pa-summary-subtitle">Migratory bird sanctuary · 1 hectares</p>
<p class="mxcw-pa-summary-text">1 native plant has been recorded in Christie Islet Migratory Bird Sanctuary, 0% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Christie Islet Migratory Bird Sanctuary · native species" role="button" tabindex="0">
<b>1</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>1</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Cypress Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Cypress Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 2,605 hectares</p>
<p class="mxcw-pa-summary-text">251 native plants have been recorded in Cypress Park, 32% of the region's native flora—2nd among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Cypress Park · native species" role="button" tabindex="0">
<b>251</b>
<span>native species · 32% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Cypress Park · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>8,302</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="David Otter Nature Reserve" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">David Otter Nature Reserve</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · Islands Trust Conservancy · 2 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in David Otter Nature Reserve.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Este-Tiwilh/Sigurd Creek Conservancy" hidden style="--pa-colour: #4fae98">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Conservancy" role="button" tabindex="0">↑ Conservancy</span>
</nav>
<h3 class="mxcw-pa-summary-title">Este-Tiwilh/Sigurd Creek Conservancy</h3>
<p class="mxcw-pa-summary-subtitle">Conservancy · 728 hectares</p>
<p class="mxcw-pa-summary-text">21 native plants have been recorded in Este-Tiwilh/Sigurd Creek Conservancy, 3% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Este-Tiwilh/Sigurd Creek Conservancy · native species" role="button" tabindex="0">
<b>21</b>
<span>native species · 3% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>31</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Fairy Fen Nature Reserve" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">Fairy Fen Nature Reserve</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · Islands Trust Conservancy · 18 hectares</p>
<p class="mxcw-pa-summary-text">18 native plants have been recorded in Fairy Fen Nature Reserve, 2% of the region's native flora—2nd among the 9 private conservation lands.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Fairy Fen Nature Reserve · native species" role="button" tabindex="0">
<b>18</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>33</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Garibaldi Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Garibaldi Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 23,018 hectares</p>
<p class="mxcw-pa-summary-text">330 native plants have been recorded in Garibaldi Park, 42% of the region's native flora—the most of the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Garibaldi Park · native species" role="button" tabindex="0">
<b>330</b>
<span>native species · 42% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Garibaldi Park · species of conservation concern" role="button" tabindex="0">
<b>3</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>4,415</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Halkett Bay Marine Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Halkett Bay Marine Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 448 hectares</p>
<p class="mxcw-pa-summary-text">39 native plants have been recorded in Halkett Bay Marine Park, 5% of the region's native flora—10th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Halkett Bay Marine Park · native species" role="button" tabindex="0">
<b>39</b>
<span>native species · 5% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>225</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Long Bay Wetland Nature Reserve" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">Long Bay Wetland Nature Reserve</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · Islands Trust Conservancy · 37 hectares</p>
<p class="mxcw-pa-summary-text">6 native plants have been recorded in Long Bay Wetland Nature Reserve, 1% of the region's native flora—7th among the 9 private conservation lands.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Long Bay Wetland Nature Reserve · native species" role="button" tabindex="0">
<b>6</b>
<span>native species · 1% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>9</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Mt. Artaban" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">Mt. Artaban</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · Islands Trust Conservancy · 102 hectares</p>
<p class="mxcw-pa-summary-text">10 native plants have been recorded in Mt. Artaban, 1% of the region's native flora—6th among the 9 private conservation lands.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Mt. Artaban · native species" role="button" tabindex="0">
<b>10</b>
<span>native species · 1% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>19</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Murrin Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Murrin Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 32 hectares</p>
<p class="mxcw-pa-summary-text">50 native plants have been recorded in Murrin Park, 6% of the region's native flora—9th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Murrin Park · native species" role="button" tabindex="0">
<b>50</b>
<span>native species · 6% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>328</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Old Growth Management Areas (Mapped Legal)" hidden style="--pa-colour: #c2a878">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Old growth management area" role="button" tabindex="0">↑ Old growth management areas</span>
</nav>
<h3 class="mxcw-pa-summary-title">Old Growth Management Areas (Mapped Legal)</h3>
<p class="mxcw-pa-summary-subtitle">Old growth management area · 8,119 hectares</p>
<p class="mxcw-pa-summary-text">154 native plants have been recorded in Old Growth Management Areas (Mapped Legal), 20% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Old Growth Management Areas (Mapped Legal) · native species" role="button" tabindex="0">
<b>154</b>
<span>native species · 20% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Old Growth Management Areas (Mapped Legal) · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>614</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Pinecone Burke Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Pinecone Burke Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 2,612 hectares</p>
<p class="mxcw-pa-summary-text">25 native plants have been recorded in Pinecone Burke Park, 3% of the region's native flora—12th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Pinecone Burke Park · native species" role="button" tabindex="0">
<b>25</b>
<span>native species · 3% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>44</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Plumper Cove Marine Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Plumper Cove Marine Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 66 hectares</p>
<p class="mxcw-pa-summary-text">56 native plants have been recorded in Plumper Cove Marine Park, 7% of the region's native flora—7th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Plumper Cove Marine Park · native species" role="button" tabindex="0">
<b>56</b>
<span>native species · 7% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>843</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Porteau Cove Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Porteau Cove Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 58 hectares</p>
<p class="mxcw-pa-summary-text">69 native plants have been recorded in Porteau Cove Park, 9% of the region's native flora—5th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Porteau Cove Park · native species" role="button" tabindex="0">
<b>69</b>
<span>native species · 9% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>436</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Sandy Beach Nature Reserve" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">Sandy Beach Nature Reserve</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · Islands Trust Conservancy · 4 hectares</p>
<p class="mxcw-pa-summary-text">17 native plants have been recorded in Sandy Beach Nature Reserve, 2% of the region's native flora—3rd among the 9 private conservation lands.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Sandy Beach Nature Reserve · native species" role="button" tabindex="0">
<b>17</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>70</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Sea To Sky Wildland Zones" hidden style="--pa-colour: #9fb28a">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Wildland zone" role="button" tabindex="0">↑ Sea to sky wildland zones</span>
</nav>
<h3 class="mxcw-pa-summary-title">Sea To Sky Wildland Zones</h3>
<p class="mxcw-pa-summary-subtitle">Wildland zone · 5,031 hectares</p>
<p class="mxcw-pa-summary-text">61 native plants have been recorded in Sea To Sky Wildland Zones, 8% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Sea To Sky Wildland Zones · native species" role="button" tabindex="0">
<b>61</b>
<span>native species · 8% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Sea To Sky Wildland Zones · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>132</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Shannon Falls Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Shannon Falls Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 91 hectares</p>
<p class="mxcw-pa-summary-text">54 native plants have been recorded in Shannon Falls Park, 7% of the region's native flora—8th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Shannon Falls Park · native species" role="button" tabindex="0">
<b>54</b>
<span>native species · 7% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>348</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Singing Woods Nature Reserve" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">Singing Woods Nature Reserve</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · Islands Trust Conservancy · 9 hectares</p>
<p class="mxcw-pa-summary-text">17 native plants have been recorded in Singing Woods Nature Reserve, 2% of the region's native flora—3rd among the 9 private conservation lands.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Singing Woods Nature Reserve · native species" role="button" tabindex="0">
<b>17</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>35</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Skwelwil'Em Squamish Estuary" hidden style="--pa-colour: #7c86c9">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Wildlife management area" role="button" tabindex="0">↑ Wildlife management area</span>
</nav>
<h3 class="mxcw-pa-summary-title">Skwelwil'Em Squamish Estuary</h3>
<p class="mxcw-pa-summary-subtitle">Wildlife management area · 663 hectares</p>
<p class="mxcw-pa-summary-text">159 native plants have been recorded in Skwelwil'Em Squamish Estuary, 20% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Skwelwil'Em Squamish Estuary · native species" role="button" tabindex="0">
<b>159</b>
<span>native species · 20% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Skwelwil'Em Squamish Estuary · species of conservation concern" role="button" tabindex="0">
<b>2</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>1,751</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Squamish Estuary" hidden style="--pa-colour: #a593d8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Private conservation land" role="button" tabindex="0">↑ Private conservation lands</span>
</nav>
<h3 class="mxcw-pa-summary-title">Squamish Estuary</h3>
<p class="mxcw-pa-summary-subtitle">Private conservation land · The Nature Trust of British Columbia · 6 hectares</p>
<p class="mxcw-pa-summary-text">12 native plants have been recorded in Squamish Estuary, 2% of the region's native flora—5th among the 9 private conservation lands.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Squamish Estuary · native species" role="button" tabindex="0">
<b>12</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Squamish Estuary · species of conservation concern" role="button" tabindex="0">
<b>1</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>29</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Stawamus Chief Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Stawamus Chief Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 530 hectares</p>
<p class="mxcw-pa-summary-text">103 native plants have been recorded in Stawamus Chief Park, 13% of the region's native flora—4th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Stawamus Chief Park · native species" role="button" tabindex="0">
<b>103</b>
<span>native species · 13% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>1,101</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Stawamus Chief Protected Area" hidden style="--pa-colour: #5a96d2">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Protected area" role="button" tabindex="0">↑ Protected area</span>
</nav>
<h3 class="mxcw-pa-summary-title">Stawamus Chief Protected Area</h3>
<p class="mxcw-pa-summary-subtitle">Protected area · 2 hectares</p>
<p class="mxcw-pa-summary-text">12 native plants have been recorded in Stawamus Chief Protected Area, 2% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Stawamus Chief Protected Area · native species" role="button" tabindex="0">
<b>12</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>16</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Anvil Island)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Anvil Island)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 48 hectares</p>
<p class="mxcw-pa-summary-text">1 native plant has been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Anvil Island), 0% of the region's native flora—3rd among the 10 other effective conservation measures.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Anvil Island) · native species" role="button" tabindex="0">
<b>1</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>1</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Bowyer Island)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Bowyer Island)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 58 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Bowyer Island).</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Brunswick Point)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Brunswick Point)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 29 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Brunswick Point).</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Defence Islands)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Defence Islands)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 68 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Defence Islands).</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Dorman Point)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Dorman Point)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 18 hectares</p>
<p class="mxcw-pa-summary-text">6 native plants have been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Dorman Point), 1% of the region's native flora—the most of the 10 other effective conservation measures.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Dorman Point) · native species" role="button" tabindex="0">
<b>6</b>
<span>native species · 1% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>8</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (East Defence Islands)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (East Defence Islands)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 27 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (East Defence Islands).</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Halkett Point)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Halkett Point)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 1 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Halkett Point).</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Lions Bay and Kelvin Grove)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Lions Bay and Kelvin Grove)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 115 hectares</p>
<p class="mxcw-pa-summary-text">1 native plant has been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Lions Bay and Kelvin Grove), 0% of the region's native flora—3rd among the 10 other effective conservation measures.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Lions Bay and Kelvin Grove) · native species" role="button" tabindex="0">
<b>1</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>2</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Lost Reef)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Lost Reef)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 32 hectares</p>
<p class="mxcw-pa-summary-text">No native plants have yet been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Lost Reef).</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat">
<b>0</b>
<span>native species · 0% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Queen Charlotte Channel)" hidden style="--pa-colour: #c9c2b0">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Other effective conservation measure" role="button" tabindex="0">↑ Other effective conservation measures</span>
</nav>
<h3 class="mxcw-pa-summary-title">Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Queen Charlotte Channel)</h3>
<p class="mxcw-pa-summary-subtitle">Other effective conservation measure · 435 hectares</p>
<p class="mxcw-pa-summary-text">4 native plants have been recorded in Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Queen Charlotte Channel), 1% of the region's native flora—2nd among the 10 other effective conservation measures.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Strait of Georgia and Howe Sound Glass Sponge Reef Closure (Queen Charlotte Channel) · native species" role="button" tabindex="0">
<b>4</b>
<span>native species · 1% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>4</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Tantalus Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Tantalus Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 10,809 hectares</p>
<p class="mxcw-pa-summary-text">36 native plants have been recorded in Tantalus Park, 5% of the region's native flora—11th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Tantalus Park · native species" role="button" tabindex="0">
<b>36</b>
<span>native species · 5% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>61</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Tetrahedron Park" hidden style="--pa-colour: #8cc084">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Provincial park" role="button" tabindex="0">↑ Provincial parks</span>
</nav>
<h3 class="mxcw-pa-summary-title">Tetrahedron Park</h3>
<p class="mxcw-pa-summary-subtitle">Provincial park · 2,035 hectares</p>
<p class="mxcw-pa-summary-text">10 native plants have been recorded in Tetrahedron Park, 1% of the region's native flora—13th among the 14 provincial parks.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Tetrahedron Park · native species" role="button" tabindex="0">
<b>10</b>
<span>native species · 1% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>10</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Wildlife Habitat Areas" hidden style="--pa-colour: #b6c7e8">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Wildlife habitat area" role="button" tabindex="0">↑ Wildlife habitat areas</span>
</nav>
<h3 class="mxcw-pa-summary-title">Wildlife Habitat Areas</h3>
<p class="mxcw-pa-summary-subtitle">Wildlife habitat area · 2,078 hectares</p>
<p class="mxcw-pa-summary-text">12 native plants have been recorded in Wildlife Habitat Areas, 2% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Wildlife Habitat Areas · native species" role="button" tabindex="0">
<b>12</b>
<span>native species · 2% of the native flora</span>
</div>
<div class="mxcw-pa-stat">
<b>0</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>15</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Published Key Biodiversity Areas" hidden style="--pa-colour: #FDF2CE">
<h3 class="mxcw-pa-summary-title">Key Biodiversity Areas</h3>
<p class="mxcw-pa-summary-subtitle">2 published, 2 of them globally significant · 0 proposed · 23,630 hectares</p>
<p class="mxcw-pa-summary-text">Key Biodiversity Areas mark the places that matter most for the persistence of species and ecosystems. The region holds 2 published Key Biodiversity Areas, identified chiefly for the birds that gather in Howe Sound and along the Squamish River. 399 of the region's 782 native vascular plants (51%) have been recorded within them.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Published Key Biodiversity Areas · native species" role="button" tabindex="0">
<b>399</b>
<span>native species · 51% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Published Key Biodiversity Areas · species of conservation concern" role="button" tabindex="0">
<b>7</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>10,123</b>
<span>native plant records</span>
</div>
</div>
<div class="mxcw-pa-richest-holder">
<span class="mxcw-pa-richest-title">Richest in native species</span>
<ol class="mxcw-pa-richest">
<li>
<span class="mxcw-pa-link" data-select="English Bay, Burrard Inlet and Howe Sound" role="button" tabindex="0">English Bay, Burrard Inlet and Howe Sound</span>
<b>305</b>
</li>
<li>
<span class="mxcw-pa-link" data-select="Squamish River" role="button" tabindex="0">Squamish River</span>
<b>245</b>
</li>
</ol>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="English Bay, Burrard Inlet and Howe Sound" hidden style="--pa-colour: #FDF2CE">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Published Key Biodiversity Areas" role="button" tabindex="0">↑ Key Biodiversity Areas</span>
</nav>
<h3 class="mxcw-pa-summary-title">English Bay, Burrard Inlet and Howe Sound</h3>
<p class="mxcw-pa-summary-subtitle">Key Biodiversity Area · Globally significant for birds · 21,366 hectares</p>
<p class="mxcw-pa-summary-text">305 native plants have been recorded in English Bay, Burrard Inlet and Howe Sound, 39% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="English Bay, Burrard Inlet and Howe Sound · native species" role="button" tabindex="0">
<b>305</b>
<span>native species · 39% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="English Bay, Burrard Inlet and Howe Sound · species of conservation concern" role="button" tabindex="0">
<b>5</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>5,961</b>
<span>native plant records</span>
</div>
</div>
</section>
<section class="mxcw-pa-card-summary" data-key="Squamish River" hidden style="--pa-colour: #FDF2CE">
<nav class="mxcw-pa-crumbs">
<span class="mxcw-pa-link" data-select="Published Key Biodiversity Areas" role="button" tabindex="0">↑ Key Biodiversity Areas</span>
</nav>
<h3 class="mxcw-pa-summary-title">Squamish River</h3>
<p class="mxcw-pa-summary-subtitle">Key Biodiversity Area · Globally significant for nonvascular plants, birds · 2,264 hectares</p>
<p class="mxcw-pa-summary-text">245 native plants have been recorded in Squamish River, 31% of the region's native flora.</p>
<div class="mxcw-pa-stats">
<div class="mxcw-pa-stat" data-select="Squamish River · native species" role="button" tabindex="0">
<b>245</b>
<span>native species · 31% of the native flora</span>
</div>
<div class="mxcw-pa-stat" data-select="Squamish River · species of conservation concern" role="button" tabindex="0">
<b>3</b>
<span>species of conservation concern</span>
</div>
<div class="mxcw-pa-stat">
<b>4,162</b>
<span>native plant records</span>
</div>
</div>
</section>
</div>

<p>This is a preliminary assessment. Sampling effort is uneven across
the region and the records have gaps, but it offers a starting point for
tracking how well the region’s plant diversity is protected. You can
help improve it by sharing your observations with the <a href="https://www.inaturalist.org/projects/atl-ka7tsem-howe-sound-biosphere-region">Átl’ḵa7tsem/Howe
Sound Biosphere Region iNaturalist project</a>.</p>
<p>The map shows protected and conserved areas by category. Click an
area on the map or in the chart to see the plants recorded there, or a
category in the legend or the chart to see those recorded across all its
areas. Key Biodiversity Areas are outlined in cream. Choose
<em>Unprotected native plant diversity</em> to see where the native
plants not yet found in any protected area have been recorded.</p>
<p>Protected areas are from the <a href="https://www.canada.ca/en/environment-climate-change/services/national-wildlife-areas/protected-conserved-areas-database.html">Canadian
Protected and Conserved Areas Database</a> (Environment and Climate
Change Canada), and Key Biodiversity Areas from <a href="https://kbacanada.org/">KBA Canada</a> (CC BY-NC-SA 4.0).</p>
</div></div></div>
</template>
