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
        {self}.curation.historyById, {self}.curationHistorySources, {self}.curation.byTaxon, {self}.recordAnnotations)`
});

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
 * Find the dated records of a taxon and of any taxa beneath it, in date order.
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
    return taxon ? obsRows.filter(obs => obs.eventDate && isWithin(obs.iNaturalistTaxonId)).sort(bioreportr.obsDateComparator) : [];
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
</style>
