<script>
"use strict";

// The atlas's panel of the plant or group chosen in the checklist: its photo, names, status and dates, and a chart of the
// history of its records by decade or by month, with the notes on it - as the W̱SÁNEĆ/Saanich Peninsula's atlas has it in
// saanich.js. The Protected Areas pane shows a smaller panel built from the same helpers - see howe-protectedPane.vue

// noinspection ES6ConvertVarToLetConst // otherwise this is a duplicate on minifying
var howe = fluid.registerNamespace("howe");
fluid.registerNamespace("howe.atlas");

// The atlas's panel, laid over the story page by howe-story.vue - it is shown on the atlas, and the Protected Areas pane
// shows its own smaller one in its place, as chosen by howe.protectedAreas.choosePanel
fluid.def("howe.atlasPanel", {
    $layers: "fluid.component",
    // The plant or group chosen in the checklist, and its dated records
    checklistTaxon: "$compute:howe.atlas.resolveTaxon({self}.taxa.rowById, {self}.checklist.search.filterState)",
    atlasRecords: "$compute:howe.atlas.taxonRecords({self}.obsRows, {self}.taxa.rowById, {self}.checklistTaxon)",
    atlasPanelMarkup: `$compute:howe.atlas.panelMarkup({self}.checklistTaxon, {self}.atlasRecords,
        {self}.curation.historyById, {self}.curationHistorySources, {self}.curation.byTaxon, {self}.recordAnnotations)`,
    // The extirpation risk pane shows the same panel of its chosen plant, with its regional EP - as the W̱SÁNEĆ/Saanich
    // Peninsula's does
    solowDatedObs: "$compute:howe.atlas.dated({self}.solowTaxonObs)",
    // The populations mapped by the extirpation risk pane are drawn from dated records alone, since an undated record
    // gives no time of sighting for its population's EP - the records table still lists every record
    solowEPObs: "$compute:howe.atlas.datedEPObs({self}.solowTaxonObs, {self}.recordAnnotations)",
    // The map pans and zooms to the records of the plant chosen in the extirpation risk pane's table
    fitToSolowTaxon: "$effect:howe.atlas.fitToTaxon({self}.map.readyMap, {self}.solowTaxa.selectedTaxon, {self}.obsRows, {self}.map.zoomDuration, {self}.activePaneKey)",
    solowTaxonPanel: {
        $component: {
            markup: `$compute:howe.atlas.panelMarkup({storyPage}.solowTaxa.selectedTaxon, {storyPage}.solowDatedObs,
                {storyPage}.curation.historyById, {storyPage}.curationHistorySources, {storyPage}.curation.byTaxon, {storyPage}.recordAnnotations, solow)`
        }
    },
    // The tiles of the atlas's three groups of species, placed in its section, each selecting its group - as the
    // W̱SÁNEĆ/Saanich Peninsula's atlas has them
    statusById: "$compute:hortis.reportingStatusById({self}.taxa.rowById)",
    atlasTiles: "$compute:howe.atlas.tilesMarkup({self}.taxa.allRows, {self}.statusById, {self}.selectedStatus)",
    sectionInserts: "$compute:howe.atlas.sectionInserts({self}.atlasTiles)",
    paneClick: "$method:howe.atlas.paneClick({self}, {0}:event)",
    // A click anywhere on a row of the checklist chooses its taxon, as a click on one of its names does
    checklistRowClick: "$effect:howe.atlas.bindRowClick({self}, {global})",
    // The checklist shows each species' reporting status by an icon - see howe.atlas.checklistDecoration
    checklist: {
        $component: {
            decorate: "howe.atlas.checklistDecoration"
        }
    },
    // The species of the Community Science pane open on the atlas - see howe.inatSpecies
    inatSpeciesClick: "$effect:howe.inatSpecies.bind({self}, {global})",
    // The dated records of each taxon, from which the groups' summaries are drawn
    byTaxon: "$compute:howe.atlas.groupRecords({self}.obsRows)",
    // Summaries of each group of species, shown when hovering over its tile or its row of the map's legend
    statusTooltip: {
        $component: {
            $layers: "hortis.withTooltip",
            cache: "$compute:howe.statusTooltip.makeCache({storyPage}.taxa.allRows)",
            renderTooltip: `$method:howe.statusTooltip.render({storyPage}.taxa.allRows, {storyPage}.statusById, {storyPage}.byTaxon,
                {self}.cache, {0}:status)`,
            hover: {
                $bindable: {
                    bind: "howe.statusTooltip.bind({self}, {global}.document)",
                    unbind: "howe.statusTooltip.unbind({boundValue})"
                }
            }
        }
    }
});

/**
 * Fit the map to the records with coordinates of the plant chosen in the extirpation risk pane, as the W̱SÁNEĆ/Saanich
 * Peninsula's saanich.fitToTaxon does.
 * @param {maplibregl.Map} map - The story's map, once its style has applied
 * @param {TaxonRow|null} taxon - The plant chosen, if any
 * @param {Object[]} obsRows - All records
 * @param {Number} duration - The duration in milliseconds of the map's smooth move to the records
 * @param {String} activePaneKey - The key of the pane shown - the map is fitted only on the extirpation risk pane
 */
howe.atlas.fitToTaxon = function (map, taxon, obsRows, duration, activePaneKey) {
    if (taxon && activePaneKey === "Solow") {
        const points = bioreportr.solowObsForTaxon(obsRows, taxon).map(bioreportr.obsPoint).filter(point => point);
        if (points.length > 0) {
            hortis.libreMap.afterLayout(map, () => {
                // The map may only just have been shown, in a pane which hid it
                map.resize();
                const bounds = points.reduce((box, point) => box.extend(point), new maplibregl.LngLatBounds(points[0], points[0]));
                map.fitBounds(bounds, {padding: 80, maxZoom: 11, duration, essential: true});
            });
        }
    }
};

// The dated records of a plant, as the panel charts them
// - sightings, leaving out the 2020 UNESCO nomination's species list, which gives no date of sighting
howe.atlas.dated = records => records.filter(record => record.eventDate && !howe.atlas.isListRecord(record));

/**
 * Whether a record is one of the species list of the 2020 UNESCO nomination of the biosphere region, entered as
 * pseudo-records all dated 2020-07-01 at one place. They remain among the records shown, but are not sightings: they
 * count neither towards extirpation probability nor towards the history of a plant's records - as
 * scripts/rebuild_howe_ultimate_list.py leaves them out of the EP of the summary.
 * @param {Object} record - A record
 * @return {Boolean} `true` if the record is one of the nomination's species list
 */
howe.atlas.isListRecord = record => /UNESCO Nomination/.test(record.datasetName || "");

// The records which are sightings of a plant - all but those of the nomination's species list
howe.atlas.sightings = records => records.filter(record => !howe.atlas.isListRecord(record));

// The records from which the extirpation risk pane's populations are drawn - those counted towards EP, as
// bioreportr.solowObsForEP chooses them, which are sightings and also have a date
howe.atlas.datedEPObs = (records, annotations) => howe.atlas.dated(howe.atlas.sightings(bioreportr.solowObsForEP(records, annotations)));

/**
 * Decorate a checklist row with an icon of its taxon's reporting status, as hortis.blitzChecklistDecoration does, but
 * referring to the icons by the ids the story page gives them, which carry the prefix `imerss-i-` - as the
 * W̱SÁNEĆ/Saanich Peninsula's saanich.checklistDecoration does. Without it the icons refer to symbols which don't
 * exist, and show nothing.
 * @param {TaxonRow} row - The checklist's taxon row
 * @return {VNode|null} The icon, or null if the taxon has no reporting status
 */
howe.atlas.checklistDecoration = function (row) {
    const node = hortis.blitzChecklistDecoration(row);
    const use = node?.children.find(child => child.tag === "use");
    if (use && !use.attrs.href.startsWith("#imerss-i-")) {
        use.attrs.href = "#imerss-i-" + use.attrs.href.substring(1);
    }
    return node;
};

// The story pages whose checklist rows already choose their taxa
howe.atlas.rowClickBound = new WeakSet();

/**
 * Let a click anywhere on a row of the checklist - on the separator between its names, or the space beside them -
 * choose its taxon, as hortis.checklist.click does only for a click on one of its names, by passing it on to the
 * row's first name.
 * @param {howe.story} storyPage - The story page
 * @param {Window} window - The window holding the story page
 */
howe.atlas.bindRowClick = function (storyPage, window) {
    if (!howe.atlas.rowClickBound.has(storyPage)) {
        howe.atlas.rowClickBound.add(storyPage);
        window.document.addEventListener("click", event => {
            const row = event.target.matches?.("li.checklist-row") ? event.target : null;
            const name = row && [...row.children].find(child => child.matches("p[data-row-id]"));
            if (name) {
                name.click();
            }
        });
    }
};

/** The atlas's tiles of the three groups of species **/

// The year from which a record counts as recent, the baseline of sightings since 2000 - as on the W̱SÁNEĆ/Saanich Peninsula
howe.atlas.recentYear = 2000;

// Each tile is a link which selects its group
howe.atlas.tiles = [{
    status: "confirmed",
    name: "Confirmed",
    meaning: "Reported historically and found again since 2000."
}, {
    status: "unconfirmed",
    name: "Historical",
    meaning: "Reported in the past but not recorded since 2000."
}, {
    status: "new",
    name: "Newly reported",
    meaning: "Added new to the flora from recent reports."
}];

/**
 * Find the taxa of the summary holding a reporting status.
 * @param {TaxonRow[]} taxaRows - All taxa
 * @param {Object<String, String>} statusById - The reporting status of each taxon, by id - see hortis.reportingStatusById
 * @param {String} status - The reporting status
 * @return {TaxonRow[]} The taxa
 */
howe.atlas.taxaOfStatus = function (taxaRows, statusById, status) {
    return taxaRows.filter(taxon => taxon.inSummary && statusById[taxon.id] === status);
};

/**
 * Render the tile for one group of species.
 * @param {Object} tile - One entry of `howe.atlas.tiles`
 * @param {TaxonRow[]} taxa - The species of this group
 * @param {Boolean} pressed - Whether the group is selected
 * @return {String} The markup for the tile
 */
howe.atlas.renderTile = function (tile, taxa, pressed) {
    return `<button type="button" class="howe-status-link howe-status-tile" data-status="${tile.status}" aria-pressed="${pressed}" style="--tip-colour:${bioreportr.statusColours[tile.status]}">
        <span class="howe-tile-name">${tile.name}</span>
        <span class="howe-tile-count">${bioreportr.formatCount(taxa.length)} <small>species</small></span>
        <span class="howe-tile-meaning">${tile.meaning}</span>
    </button>`;
};

/**
 * Render the tiles of the three groups of species, computed from the site's data.
 * @param {TaxonRow[]} taxaRows - All taxa
 * @param {Object<String, String>} statusById - The reporting status of each taxon, by id
 * @param {String|null} selectedStatus - The selected group, if any
 * @return {String} The markup of the tiles
 */
howe.atlas.tilesMarkup = function (taxaRows, statusById, selectedStatus) {
    return howe.atlas.tiles.map(tile => howe.atlas.renderTile(tile, howe.atlas.taxaOfStatus(taxaRows, statusById, tile.status),
        tile.status === selectedStatus)).join("");
};

howe.atlas.sectionInserts = tiles => ({"howe-status-tiles": tiles});

/**
 * Select the group of a tile clicked in the atlas's section, or clear it if it is already selected.
 * @param {howe.story} storyPage - The story page
 * @param {Event} event - The click
 */
howe.atlas.paneClick = function (storyPage, event) {
    const tile = event.target.closest(".howe-status-link");
    // A plant of the Lost Plants gallery opens the extirpation risk pane on it - see howe-lostPlantsPane.vue
    const card = event.target.closest(".howe-lost-card");
    if (tile) {
        const status = tile.dataset.status;
        storyPage.selectedStatus = storyPage.selectedStatus === status ? null : status;
    } else if (card) {
        const dokkument = event.target.ownerDocument;
        howe.lostPlants.showTaxon(storyPage, card.dataset.taxonId, "Solow", dokkument, dokkument.defaultView);
    }
};

/**
 * Group the dated sightings by taxon - the records of the In Memoriam timeline and of the summaries of the atlas's
 * groups, which leave out the nomination's species list - see howe.atlas.isListRecord.
 * @param {Object[]} obsRows - All records
 * @return {Map<String, Object[]>} The dated records of each taxon, by id
 */
howe.atlas.groupRecords = function (obsRows) {
    const byTaxon = new Map();
    // The nomination's species list is no sighting, so has no place in the history of a plant's records
    obsRows.forEach(obs => {
        if (obs.eventDate && !howe.atlas.isListRecord(obs)) {
            const records = byTaxon.get(obs.iNaturalistTaxonId) || [];
            records.push(obs);
            byTaxon.set(obs.iNaturalistTaxonId, records);
        }
    });
    return byTaxon;
};

/** The species of the Community Science pane, which open on the atlas - as the W̱SÁNEĆ/Saanich Peninsula's do **/

fluid.registerNamespace("howe.inatSpecies");

// The query of the Community Science pane's panels - its place and taxon, see paneOverrides in howe-story.vue
howe.inatSpecies.query = {placeId: 121270, taxonId: 211194};
howe.inatSpecies.lookup = null;

/**
 * Look up the iNaturalist taxa of the species shown by the Community Science pane's panels, which name each by its
 * common name alone, by the same query the panels make. Made once, on the first click.
 * @param {Window} window - The window holding the story page
 * @return {Promise<Map<String, Object>>} Map of lower-cased common name to the taxon's `id` and scientific `name`
 */
howe.inatSpecies.byName = function (window) {
    if (!howe.inatSpecies.lookup) {
        const {placeId, taxonId} = howe.inatSpecies.query;
        howe.inatSpecies.lookup = window.fetch(`https://api.inaturalist.org/v1/observations/species_counts?verifiable=true&place_id=${placeId}&taxon_id=${taxonId}&per_page=500`)
            .then(response => response.json())
            .then(data => new Map(data.results.filter(result => result.taxon.preferred_common_name)
                .map(result => [result.taxon.preferred_common_name.toLowerCase(), {id: String(result.taxon.id), name: result.taxon.name}])));
    }
    return howe.inatSpecies.lookup;
};

/**
 * Find the atlas's taxon for a species of iNaturalist - the same taxon, or else the atlas's taxon of that scientific name
 * or one beneath it.
 * @param {Object<String, TaxonRow>} rowById - The atlas's taxa
 * @param {Object} taxon - The iNaturalist taxon, with its `id` and scientific `name`
 * @return {TaxonRow|undefined} The atlas's taxon, preferring one of its summary
 */
howe.inatSpecies.atlasRow = function (rowById, taxon) {
    if (rowById[taxon.id]) {
        return rowById[taxon.id];
    }
    const named = Object.values(rowById).filter(row => {
        const scientific = row.scientificName || "";
        return scientific === taxon.name || scientific.startsWith(taxon.name + " ");
    });
    return named.find(row => row.inSummary) || named[0];
};

/**
 * Open the atlas on the species of a card of the Community Science pane, if it is one of the atlas's taxa. The plant is
 * kept as the pane changes, which would otherwise clear it - see howe.story.clearTaxonOnPaneChange.
 * @param {howe.story} storyPage - The story page
 * @param {HTMLElement} card - The card clicked
 * @param {Window} window - The window holding the story page
 */
howe.inatSpecies.open = function (storyPage, card, window) {
    const name = card.querySelector(".inat-observation-label-title")?.textContent.trim().toLowerCase();
    if (name) {
        howe.inatSpecies.byName(window).then(byName => {
            const taxon = byName.get(name);
            const row = taxon && howe.inatSpecies.atlasRow(storyPage.taxa.rowById, taxon);
            if (row) {
                bioreportr.storyPage.keepTaxon.add(storyPage);
                window.location.hash = "pane:Status&taxon:" + row.id;
            }
        }, error => console.error("Could not look up the species of the Community Science pane", error));
    }
};

/**
 * Whether a card of the Community Science pane stands for a species, as do those of its "Most common" tab, rather than
 * an observation.
 * @param {Element} card - The card
 * @return {Boolean} `true` if the card is shown under the "Most common" tab
 */
howe.inatSpecies.isSpeciesCard = function (card) {
    const tab = [...card.closest(".mxcw-inat-components").querySelectorAll("li")].find(item => /selected/.test(item.className));
    return !!tab && tab.textContent.trim() === "Most common";
};

// The story pages whose Community Science cards already open their species
howe.inatSpecies.bound = new WeakSet();

/**
 * Listen for clicks on the cards of the Community Science pane, which the iNaturalist panels render outside the story
 * page's own handling of clicks in its panes. Only the cards of "Most common" are species, which open the atlas - those
 * of "Recent" and "Most favourited" are observations, whose own handler opens them on iNaturalist.
 * @param {howe.story} storyPage - The story page
 * @param {Window} window - The window holding the story page
 */
howe.inatSpecies.bind = function (storyPage, window) {
    if (!howe.inatSpecies.bound.has(storyPage)) {
        howe.inatSpecies.bound.add(storyPage);
        // Caught as it descends, before the card's own handler
        window.document.addEventListener("click", event => {
            const card = event.target.closest?.(".mxcw-inat-components article");
            if (card && howe.inatSpecies.isSpeciesCard(card)) {
                event.preventDefault();
                event.stopPropagation();
                howe.inatSpecies.open(storyPage, card, window);
            }
        }, true);
    }
};

/** Summaries of the groups of species, shown on hovering over a tile or a row of the map's legend **/

fluid.registerNamespace("howe.statusTooltip");

howe.statusTooltip.frame = (name, count, body) =>
    `<div class="mxcw-tip-title">${name} <span>${bioreportr.formatCount(count)} species</span></div>${body}`;

howe.firstRecorder = record => (record.recordedBy || "Unknown").split(";")[0].trim() || "Unknown";

// The five recorders to whom the most of a list of records are owed
howe.statusTooltip.topRecorders = function (records) {
    const counts = {};
    records.forEach(record => {
        const recorder = howe.firstRecorder(record);
        counts[recorder] = (counts[recorder] || 0) + 1;
    });
    return Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, 5);
};

howe.statusTooltip.isRecent = record => parseInt(record.eventDate, 10) >= howe.atlas.recentYear;

howe.statusTooltip.renderers = {
    // When each historically reported species was first found again since 2000, and who found the most of them again
    confirmed: function (taxa, byTaxon) {
        const refound = taxa.map(taxon => (byTaxon.get(taxon.id) || []).slice().sort(bioreportr.obsDateComparator)
            .find(howe.statusTooltip.isRecent)).filter(record => record);
        return howe.statusTooltip.frame("Confirmed", taxa.length,
            bioreportr.tip.heading("Observers who found the most species again") + bioreportr.tip.bars(howe.statusTooltip.topRecorders(refound)));
    },
    // Each species' first record, among those made in recent years
    new: function (taxa, byTaxon) {
        const firsts = taxa.map(taxon => (byTaxon.get(taxon.id) || []).slice().sort(bioreportr.obsDateComparator)[0])
            .filter(record => record && howe.statusTooltip.isRecent(record));
        return howe.statusTooltip.frame("Newly reported", taxa.length,
            bioreportr.tip.heading(`Observers with most added records since ${howe.atlas.recentYear}`) + bioreportr.tip.bars(howe.statusTooltip.topRecorders(firsts)));
    },
    unconfirmed: function (taxa, byTaxon) {
        const records = taxa.map(taxon => (byTaxon.get(taxon.id) || []).slice().sort(bioreportr.obsDateComparator)).filter(list => list.length > 0);
        const withLocality = records.filter(list => list.some(record => record.locality)).length;
        const withSpecimen = records.filter(list => list.some(record => /specimen/i.test(record.basisOfRecord))).length;
        return howe.statusTooltip.frame("Historical", taxa.length,
            bioreportr.tip.heading("Last recorded by") + bioreportr.tip.bars(howe.statusTooltip.topRecorders(records.map(list => fluid.peek(list)))) +
            `<div class="mxcw-tip-note">${withLocality} species have a recorded locality to search, and ${withSpecimen} have a specimen to consult.</div>`);
    }
};

/**
 * Render the summary of a group of species. Each summary is rendered once, since it depends only on the site's data.
 * @param {TaxonRow[]} taxaRows - All taxa
 * @param {Object<String, String>} statusById - The reporting status of each taxon, by id
 * @param {Map<String, Object[]>} byTaxon - Dated records indexed by taxon id
 * @param {Object<String, String>} cache - The summaries already rendered, by status
 * @param {String} status - The group's reporting status
 * @return {String|null} The summary's markup, or null if there is no such group
 */
howe.statusTooltip.render = function (taxaRows, statusById, byTaxon, cache, status) {
    const renderer = howe.statusTooltip.renderers[status];
    if (renderer && !cache[status]) {
        cache[status] = `<div class="howe-tip howe-tip-visible" style="--tip-colour:${bioreportr.statusColours[status]}">` +
            renderer(howe.atlas.taxaOfStatus(taxaRows, statusById, status), byTaxon) + "</div>";
    }
    return cache[status] || null;
};

howe.statusTooltip.makeCache = () => ({});

/**
 * Find which group of species an element in the page refers to, if any - a tile of the atlas or a row of the legend
 * of a map coloured by status.
 * @param {Element} element - The element under the pointer
 * @return {String|null} The group's reporting status, or null if there is none
 */
howe.statusTooltip.statusFor = function (element) {
    const link = element.closest?.(".howe-status-link");
    const row = element.closest?.(".mxcw-map .mxcw-region-legend [data-selects=\"status\"]");
    return link ? link.dataset.status : row ? row.dataset.key : null;
};

/**
 * Report the group of species under the pointer to the tooltip. The listeners are bound to the document, since the
 * tiles and the legend are rerendered beneath them.
 * @param {fluid.component} that - The tooltip, a hortis.withTooltip
 * @param {Document} dokkument - The document
 * @return {Object} A record of the listeners, to be supplied to `howe.statusTooltip.unbind`
 */
howe.statusTooltip.bind = function (that, dokkument) {
    const move = event => that.hoverAt(howe.statusTooltip.statusFor(event.target), event);
    const leave = event => {
        if (!event.relatedTarget || !howe.statusTooltip.statusFor(event.relatedTarget)) {
            that.hoverAt(null);
        }
    };
    dokkument.addEventListener("mousemove", move);
    dokkument.addEventListener("mouseout", leave);
    return {dokkument, move, leave};
};

howe.statusTooltip.unbind = function (record) {
    record.dokkument.removeEventListener("mousemove", record.move);
    record.dokkument.removeEventListener("mouseout", record.leave);
};

/**
 * Resolve the taxon chosen in the checklist's search, whose state held in the URL records only its id.
 * @param {Object<String, TaxonRow>} rowById - Taxon rows indexed by id
 * @param {Object|null} search - The search's state, a taxon row or a record holding its `id`
 * @return {TaxonRow|null} The taxon's row, or null if none is chosen
 */
howe.atlas.resolveTaxon = function (rowById, search) {
    return search && rowById[search.id] || null;
};

// Howe's summary reports a species as "confirmed", "reported" (historically, not yet found again) or "new <year>", the
// year of its first report
howe.atlas.statusLabels = {confirmed: "Confirmed", reported: "Historical", unconfirmed: "Historical", new: "New"};

howe.atlas.statusLabel = status => {
    const [kind, year] = String(status || "").split(" ");
    const label = howe.atlas.statusLabels[kind];
    return label && year ? `${label} (${year})` : label;
};

howe.atlas.field = (label, value) => value ? `<dt>${label}:</dt> <dd>${hortis.dataTable.encode(value)}</dd>` : "";

/**
 * Find the dated sightings of a taxon and of any taxa beneath it, in date order - leaving out the 2020 UNESCO
 * nomination's species list.
 * @param {Object[]} obsRows - All records
 * @param {Object<String, TaxonRow>} rowById - Taxon rows indexed by id
 * @param {TaxonRow|null} taxon - The selected taxon
 * @return {Object[]} The records found
 */
howe.atlas.taxonRecords = function (obsRows, rowById, taxon) {
    const isWithin = id => {
        let within = false;
        for (let row = rowById[id]; row && !within; row = row.parent) {
            within = row === taxon;
        }
        return within;
    };
    // The nomination's species list is no sighting, so gives no date of first or last sighting - see howe.atlas.isListRecord
    return taxon ? obsRows.filter(obs => obs.eventDate && !howe.atlas.isListRecord(obs) && isWithin(obs.iNaturalistTaxonId)).sort(bioreportr.obsDateComparator) : [];
};

/**
 * Render the panel of the plant or group chosen in the checklist - or, in the extirpation risk pane, of the plant chosen
 * for its analysis, which also gives its regional EP.
 * @param {TaxonRow|null} taxon - The chosen taxon
 * @param {Object[]} records - Its dated records
 * @param {Object<String, Object>} [historyById] - The history of the curatorial notes on each taxon, by id
 * @param {Object[]} [sources] - The sources of that history, oldest first - see bioreportr.curationForm.historyMarkup
 * @param {Object<String, CurationNote[]>} [byTaxon] - The notes added through the site on each taxon, by id
 * @param {Object<String, Object>} [annotations] - The annotations of records, by occurrenceID
 * @param {String} [context] - "atlas", or "solow" for the extirpation risk pane - which also names the panel's tabs,
 * so that those of the two panes are chosen apart
 * @return {String} The panel's markup, empty if no taxon with records is chosen
 */
howe.atlas.panelMarkup = function (taxon, records, historyById, sources, byTaxon, annotations, context = "atlas") {
    let togo = "";
    if (taxon && records.length > 0) {
        togo = `<div class="mxcw-solow-taxon-pane howe-atlas-taxon-pane">
  <div class="mxcw-taxon-image">${hortis.renderTaxonImage(taxon.iNaturalistTaxonImage, taxon.id)}</div>
  <div class="mxcw-taxon-info">
    <div class="mxcw-taxon-name">${hortis.dataTable.encode((taxon.scientificName || taxon.iNaturalistTaxonName) + (taxon.commonName ? ` (${taxon.commonName})` : ""))}</div>
    <div class="howe-atlas-facts">
      <dl class="mxcw-taxon-fields">
        <dt>Date first seen:</dt> <dd>${bioreportr.eventDay(records[0].eventDate)}</dd>
        <dt>Date last seen:</dt> <dd>${bioreportr.eventDay(fluid.peek(records).eventDate)}</dd>
        <dt>Total records:</dt> <dd>${bioreportr.formatCount(records.length)}</dd>
        ${howe.atlas.field("Status", howe.atlas.statusLabel(taxon.reportingStatus))}
      ${context === "solow" ? howe.atlas.field("Regional EP", taxon.solow_EP) : ""}
      </dl>
      ${bioreportr.georefNote(records)}
    </div>
    ${howe.atlas.historyMarkup(records, context + "-" + taxon.id, howe.atlas.notesMarkup(taxon, records, historyById, sources, byTaxon, annotations))}
  </div>
</div>`;
    }
    return togo;
};

/** The history of a plant's records, charted in the atlas's panel - only there, since the extirpation risk pane's panel
    has no room for it beside its slider **/

// The first decade charted, that of the earliest records of the flora, so that every plant is charted on the same span
howe.atlas.firstDecade = 1850;

howe.atlas.monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
    "October", "November", "December"];

/**
 * Count the records of a plant in each decade from `howe.atlas.firstDecade` to the present, and in each month.
 * @param {Object[]} records - The plant's dated records
 * @param {Number} [thisYear] - The present year
 * @return {Object} Members `decades`, {decade, count}[], and `months`, Number[12]
 */
howe.atlas.history = function (records, thisYear = new Date().getFullYear()) {
    const first = howe.atlas.firstDecade;
    const decades = [];
    for (let decade = first; decade <= thisYear; decade += 10) {
        decades.push({decade, count: 0});
    }
    const months = new Array(12).fill(0);
    records.forEach(record => {
        const [year, month] = String(record.eventDate).split("-").map(Number);
        const index = Math.floor((year - first) / 10);
        if (index >= 0 && index < decades.length) {
            ++decades[index].count;
        }
        if (month >= 1 && month <= 12) {
            ++months[month - 1];
        }
    });
    return {decades, months};
};

/**
 * Render a row of columns, each showing its value on hovering.
 * @param {Object[]} columns - The columns, each with `value`, `title`, and `label`, shown beneath it if not empty
 * @param {String} kind - The kind of chart, which names its class
 * @return {String} The markup of the chart
 */
howe.atlas.columns = function (columns, kind) {
    // On a square root scale, so that the few records of earlier decades still show beside the many of recent ones
    const max = Math.sqrt(Math.max(...columns.map(column => column.value), 1));
    const slots = columns.map(column => `<span class="howe-history-slot" title="${column.title}">` +
        `<span class="howe-history-bar${column.value ? "" : " howe-history-empty"}" style="height:${Math.sqrt(column.value) / max * 100}%"></span>` +
        `<span class="howe-history-label">${column.label}</span></span>`).join("");
    return `<div class="howe-history-chart howe-history-${kind}">${slots}</div>`;
};

/**
 * Render the history of a plant's observations - how many were made in each decade, and in each month of the year - as
 * one chart at a time, chosen by its tabs. The tabs are radio buttons, so that they work without script, the chart shown
 * being picked by CSS - see the styles in this file.
 * @param {Object[]} records - The plant's dated records
 * @param {String} taxonId - The plant's id, naming its tabs apart from any other panel's
 * @return {String} The markup of the charts and their tabs
 */
howe.atlas.historyMarkup = function (records, taxonId, notes = "") {
    const {decades, months} = howe.atlas.history(records);
    const count = n => bioreportr.formatCount(n) + (n === 1 ? " report" : " reports");
    const decadeColumns = decades.map(({decade, count: n}) => ({value: n, title: `${decade}s: ${count(n)}`,
        label: decade % 50 === 0 ? String(decade) : ""}));
    const monthColumns = months.map((n, month) => ({value: n, title: `${howe.atlas.monthNames[month]}: ${count(n)}`,
        label: howe.atlas.monthNames[month][0]}));
    const name = "howe-history-" + taxonId;
    const tab = (kind, label, title, checked) => `<input type="radio" class="howe-history-${kind}-tab" id="${name}-${kind}" name="${name}"${checked ? " checked" : ""}>` +
        `<label for="${name}-${kind}" title="${title}">${label}</label>`;
    return `<div class="howe-history">
      <div class="howe-history-tabs" role="tablist">${tab("decade", "Decades", "Reports by decade", true)}${tab("month", "Months", "Reports by month", false)}${tab("notes", "Notes", "Annotation history", false)}</div>
      ${howe.atlas.columns(decadeColumns, "decades")}
      ${howe.atlas.columns(monthColumns, "months")}
      <div class="howe-history-notes">${notes}</div>
    </div>`;
};

/**
 * Render the history of the annotations of a plant, shown by the Notes tab of the atlas's panel - any records set aside,
 * e.g. as planted, then its curatorial notes from the earliest account to those added through the site, as the History
 * tab of the curation pane shows them - see bioreportr.curationForm.historyMarkup.
 * @param {TaxonRow} taxon - The plant
 * @param {Object[]} records - Its records
 * @param {Object<String, Object>} historyById - The history of the curatorial notes on each taxon, by id
 * @param {Object[]} sources - The sources of that history, oldest first - see bioreportr.curationForm.historyMarkup
 * @param {Object<String, CurationNote[]>} byTaxon - The notes added through the site on each taxon, by id
 * @param {Object<String, Object>} annotations - The annotations of records, by occurrenceID
 * @return {String} The markup of the history
 */
howe.atlas.notesMarkup = function (taxon, records, historyById, sources, byTaxon, annotations) {
    const setAside = bioreportr.solowAnnotationNote(records, annotations);
    const history = bioreportr.curationForm?.historyMarkup ? bioreportr.curationForm.historyMarkup(taxon, historyById || {}, sources, byTaxon || {}) : "";
    return setAside + history;
};
</script>

<style>
/* The atlas's panel of the chosen plant: its facts, and beside them a chart of the history of its observations, by
   decade or by month as chosen by the chart's tabs - see howe.atlas.historyMarkup. The extirpation risk pane's panel,
   which shares its other styles, has no chart. On a narrow panel the chart falls beneath the facts */
/* The plant's name runs across the top of the panel's column, and beneath it its facts and the chart sit side by side,
   the chart filling the height left to it. Where the column is too narrow for both, the chart falls beneath the facts */
.howe-atlas-taxon-pane .mxcw-taxon-info {
    display: grid;
    grid-template-columns: max-content minmax(0, 1fr);
    grid-template-rows: auto minmax(0, 1fr);
    gap: 4px 20px;
    padding-right: var(--story-gap);
}

.howe-atlas-taxon-pane .mxcw-taxon-name {
    grid-column: 1 / -1;
    padding-bottom: 4px;
}

@container (max-width: 380px) {
    .howe-atlas-taxon-pane .mxcw-taxon-info {
        grid-template-columns: minmax(0, 1fr);
        grid-template-rows: auto;
    }
}

/* On a phone the chart always falls beneath the facts, the panel's column scrolling to it */
@media (max-width: 767.98px) {
    .howe-atlas-taxon-pane .mxcw-taxon-info {
        grid-template-columns: minmax(0, 1fr);
        grid-template-rows: auto;
    }

    .howe-atlas-taxon-pane .howe-history-chart,
    .howe-atlas-taxon-pane .howe-history-notes {
        min-height: 90px;
    }
}

/* The photo yields room to the chart, which it does not share in the extirpation risk pane's panel */
.howe-atlas-taxon-pane .mxcw-taxon-image {
    max-width: 34%;
}

.howe-atlas-facts {
    min-width: 0;
}

/* The column is as wide as the facts - a note beneath them wraps within it rather than widening it */
.howe-atlas-facts > :not(dl) {
    contain: inline-size;
}

/* Dates and counts are kept whole */
.howe-atlas-facts dd {
    white-space: nowrap;
}

.howe-history {
    display: flex;
    flex-direction: column;
    min-width: 0;
    min-height: 0;
}

.howe-history-tabs {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 4px;
    margin-bottom: 8px;
}

.howe-history-heading {
    flex: 0 0 100%;
    margin-bottom: 2px;
    color: #5a7680;
    font-size: 11px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
}

/* The tabs are radio buttons, hidden behind their labels */
.howe-history-tabs input {
    position: absolute;
    opacity: 0;
    pointer-events: none;
}

.howe-history-tabs label {
    padding: 1px 9px;
    border: 1px solid #c9d6dc;
    border-radius: 999px;
    color: #4b778f;
    font-size: 12px;
    cursor: pointer;
}

.howe-history-tabs input:checked + label {
    border-color: #2f7f8f;
    background: #2f7f8f;
    color: #fff;
}

.howe-history-tabs input:focus-visible + label {
    outline: 2px solid #4b778f;
    outline-offset: 1px;
}

.howe-history:has(.howe-history-decade-tab:checked) .howe-history-months,
.howe-history:has(.howe-history-month-tab:checked) .howe-history-decades,
.howe-history:has(.howe-history-notes-tab:checked) .howe-history-chart,
.howe-history:not(:has(.howe-history-notes-tab:checked)) .howe-history-notes {
    display: none;
}

/* The Notes tab's history of the plant's annotations, scrolling within the room the charts take */
.howe-history-notes {
    flex: 1 1 auto;
    min-height: 70px;
    max-height: 150px;
    overflow-y: auto;
    padding-right: 4px;
    color: #1f2a30;
    font-size: 12px;
    line-height: 1.35;
}

.howe-history-notes .mxcw-curation-history {
    margin: 0 0 0 6px;
    padding: 0 0 0 14px;
    border-left: 2px solid rgba(90, 118, 128, 0.35);
    list-style: none;
}

.howe-history-notes .mxcw-curation-history-entry {
    position: relative;
    margin: 0 0 8px;
    list-style: none;
}

.howe-history-notes .mxcw-curation-history-entry::marker {
    content: none;
}

.howe-history-notes .mxcw-curation-history-entry::before {
    content: "";
    position: absolute;
    top: 0.45em;
    left: -19px;
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #5a7680;
}

.howe-history-notes .mxcw-curation-history-site::before {
    background: #e8711a;
}

.howe-history-notes .mxcw-curation-history-head span,
.howe-history-notes .mxcw-curation-history-reviewed,
.howe-history-notes .mxcw-curation-none {
    color: #5a7680;
}

.howe-history-notes .mxcw-curation-history-reviewed {
    margin: 2px 0 0;
}

.howe-history-notes .mxcw-curation-history-text a {
    color: #184e62;
}

.howe-history-notes .mxcw-solow-annotation-note {
    margin: 0 0 6px;
}

.howe-history-chart {
    display: flex;
    gap: 2px;
    flex: 1 1 auto;
    height: auto;
    min-height: 70px;
    max-height: 150px;
    margin-bottom: 16px;
    border-bottom: 1px solid rgba(90, 118, 128, 0.35);
}

.howe-history-slot {
    position: relative;
    flex: 1 1 0;
    min-width: 0;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    height: 100%;
}

.howe-history-bar {
    display: block;
    width: 100%;
    min-height: 2px;
    border-radius: 3px 3px 0 0;
    background: #2f7f8f;
}

.howe-history-bar.howe-history-empty {
    min-height: 0;
}

.howe-history-slot:hover .howe-history-bar {
    background: #184e62;
}

/* The labels hang beneath the axis, outside the chart's height */
.howe-history-label {
    position: absolute;
    top: calc(100% + 2px);
    left: 50%;
    transform: translateX(-50%);
    color: #5a7680;
    font-size: 10px;
    line-height: 1;
    white-space: nowrap;
}

/* The first label is aligned with the chart's edge, which would otherwise cut it off */
.howe-history-slot:first-child .howe-history-label {
    left: 0;
    transform: none;
}

/* The atlas's tiles of its three groups of species, their summaries, and its directions - as the W̱SÁNEĆ/Saanich
   Peninsula's atlas has them */
/* ── Atlas links to status groups ────────────────────────── */

.howe-status-link {
    font-weight: 700;
    text-decoration: underline dotted;
    text-underline-offset: 3px;
    cursor: pointer;
    border-radius: 4px;
    padding: 0 4px;
    margin-left: -4px;
}

.howe-status-link:hover,
.howe-status-link:focus-visible {
    text-decoration-style: solid;
}

.howe-status-link[aria-pressed="true"] {
    color: #0d3040;
    background: #FDF2CE;
    text-decoration: none;
}

/* ── Group summaries in the atlas ────────────────────────── */

.howe-tip {
    position: fixed;
    z-index: 1000;
    width: 300px;
    padding: 12px;
    display: none;
    pointer-events: none;
    color: #eefaff;
    background: #0d3040;
    border: 1px solid #4a9aaa;
    border-radius: 8px;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
    font-size: 12px;
    line-height: 1.35;
}

.howe-tip-visible {
    display: block;
}

/* The group summaries are framed as the summaries of map cells are - see imerss-story.css */
.imerss-tooltip-holder:has(.howe-tip) {
    max-width: none;
    padding: 0;
    border: 1px solid #4a9aaa;
    border-radius: 8px;
    background: #0d3040;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
}

/* The group summaries are placed by the IMERSS framework's tooltip holder, which supplies the frame */
.imerss-tooltip-holder .howe-tip {
    position: static;
    border: 0;
    box-shadow: none;
}

/* ── Atlas tiles for the three groups of species ─────────── */

.howe-status-tiles {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
    gap: var(--story-gap);
    margin: 0 0 0.6em;
}

.howe-status-tile {
    display: flex;
    flex-direction: column;
    min-width: 0;
    margin: 0;
    padding: var(--story-gap);
    text-align: left;
    font-weight: 400;
    color: #eefaff;
    text-decoration: none;
    background: #0d3040;
    border-top: 3px solid var(--tip-colour);
    border-radius: var(--data-table-radius);
    outline: 2px solid transparent;
    outline-offset: -2px;
}

.howe-status-tile:hover,
.howe-status-tile:focus-visible,
.howe-status-tile[aria-pressed="true"] {
    color: #eefaff;
    background: #0d3040;
    outline-color: #FDF2CE;
}

.howe-tile-name {
    font-size: var(--story-data);
    font-weight: 700;
}

.howe-tile-count {
    font-size: 24px;
    font-weight: 700;
    line-height: 1.15;
}

.howe-tile-count small {
    font-size: var(--story-small);
    font-weight: 400;
    color: #a8c8d0;
}

.howe-tile-meaning {
    flex: 1;
    font-size: var(--story-small);
    line-height: 1.3;
    color: #a8c8d0;
    margin-top: 2px;
}

.howe-howto {
    margin-top: 12px;
    padding-top: 10px;
    border-top: 1px solid rgba(168, 200, 208, 0.35);
    color: #c4dbe2;
    font-size: var(--story-body);
    line-height: 1.45;
}

.howe-howto p,
.howe-howto ol {
    margin: 0 0 var(--story-gap);
}

.howe-howto ol {
    padding-left: 1.5em;
}

.howe-howto li {
    margin-bottom: 4px;
}

.howe-howto em,
.howe-howto strong {
    color: #FDF2CE;
}

/* A sentence of a pane's text called out, as the W̱SÁNEĆ/Saanich Peninsula's are */
.howe-callout {
    color: #FDF2CE;
    font-weight: 700;
}

/* The Community Science pane's lead-in, callout and project link are emphasised alike: cream, never bold - as on the
   W̱SÁNEĆ/Saanich Peninsula */
.mxcw-paneKey-TopContributions .mxcw-sectionColumn > p .howe-callout {
    color: #FDF2CE;
    font-weight: 400;
}
</style>
