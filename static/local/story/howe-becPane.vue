<script>
"use strict";

// The Regional Diversity pane of the Átl’ḵa7tsem/Howe Sound story - its section, knitted from content/story/Vascular_BEC.Rmd,
// lists the biogeoclimatic units of each zone as chips, each selecting its unit as a click on the map does. The chip of
// the selected unit is marked

// noinspection ES6ConvertVarToLetConst // otherwise this is a duplicate on minifying
var howe = fluid.registerNamespace("howe");
fluid.registerNamespace("howe.becPane");

// The units listed as chips - see the chunk of content/story/Vascular_BEC.Rmd which writes them
howe.becPane.units = ["CWHxm1", "CWHdm", "CWHvm1", "CWHvm2", "CWHds1", "CWHms1", "MHmm1", "MHmm2", "CMAunp"];

fluid.def("howe.becPane", {
    $layers: "fluid.component",
    // Whether each unit is the one selected, by its code
    selected: "$compute:howe.becPane.selected({storyPage}.selectedRegion)"
});

/**
 * Mark which unit is selected.
 * @param {String|null} selectedRegion - The selected region, if any
 * @return {Object<String, Boolean>} Whether each unit is the one selected, by its code
 */
howe.becPane.selected = selectedRegion => Object.fromEntries(howe.becPane.units.map(unit => [unit, unit === selectedRegion]));
</script>

<style>
/* The pane's heading and text, as those of the other panes beside the map - the Atlas and Find the Plants - in the
   shared reading panes of imerss-story.css */
.mxcw-paneKey-Vascular_BEC h2 {
    color: #a8c8d0;
    font-size: var(--story-small);
    font-weight: 400;
    letter-spacing: 0.3em;
    text-transform: uppercase;
    margin: 0.5rem 0 var(--story-gap);
}

.mxcw-paneKey-Vascular_BEC .mxcw-sectionColumn > p {
    margin: 0 auto var(--story-gap);
    padding: 0;
    color: #d6e8ee;
    font-size: var(--story-tool-text);
    line-height: 1.4;
    text-align: center;
    text-wrap: pretty;
}

/* The zones of the region, centred beneath the pane's centred text: each zone's name above the chips of its units */
.howe-bec-zones {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin: 2px auto var(--story-gap);
    padding-top: 12px;
    border-top: 1px solid rgba(168, 200, 208, 0.25);
}

.howe-bec-zone {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
}

.howe-bec-zone-name {
    font-size: var(--story-small);
    letter-spacing: 0.08em;
    text-transform: uppercase;
    line-height: 1.3;
    color: #a8c8d0;
}

/* At most three chips a line, so that a zone of many units wraps evenly rather than leaving one alone */
.howe-bec-chips {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 6px;
    max-width: 17.5rem;
}

/* A unit's chip, its dot the unit's colour on the map - outweighing the shared style of links in a pane's text */
.mxcw-paneKey-Vascular_BEC a.howe-bec-chip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 3px 10px 3px 8px;
    font-size: var(--story-small);
    font-weight: 700;
    line-height: 1.3;
    color: #eefaff;
    text-decoration: none;
    background: #0d3040;
    border: 1px solid rgba(168, 200, 208, 0.35);
    border-radius: 999px;
    transition: border-color 150ms, background-color 150ms;
}

.howe-bec-chip::before {
    content: "";
    width: 10px;
    height: 10px;
    flex: none;
    border-radius: 50%;
    background: var(--bec-colour);
    box-shadow: 0 0 0 1px rgba(238, 250, 255, 0.35);
}

.mxcw-paneKey-Vascular_BEC a.howe-bec-chip:hover,
.mxcw-paneKey-Vascular_BEC a.howe-bec-chip:focus-visible {
    color: #eefaff;
    border-color: #FDF2CE;
}

.mxcw-paneKey-Vascular_BEC a.howe-bec-chip.howe-bec-chip-selected {
    color: #0d3040;
    background: #FDF2CE;
    border-color: #FDF2CE;
}

</style>

<!-- The <template> block below is written by src/js/storyBuild.js and must not be edited here: it holds the section
     knitted from content/story/Vascular_BEC.Rmd, whose front matter names howe.becPane as its paneComponent. Edit the
     R Markdown and knit it, then run "npm run story", which replaces everything between <template> and </template>
     and nothing else in this file. The markup is a template, which may bind members of howe.becPane with @{...} -
     written in the R Markdown as raw HTML, which pandoc leaves as it is -->
<template>
<div id="howe-sounds-vascular-plant-diversity" class="section level2 mxcw-paneKey-Vascular_BEC"><h2>Howe Sound’s vascular plant diversity</h2><div class="mxcw-sectionInner"><div class="mxcw-sectionColumn">

<p>Over one thousand vascular plant species are known to occur within
the Átl’ḵa7tsem/Howe Sound Biosphere, represented by 66611 occurrence
records. This diverse flora spans nine biogeoclimatic units, from
lowland coastal western hemlock forests and associated woodland
communities to high elevation subalpine and alpine plant
communities.</p>


<p>Explore the region’s flora by selecting a biogeoclimatic unit, here
or on the map:</p>
<div class="howe-bec-zones"><div class="howe-bec-zone"><span class="howe-bec-zone-name">Coastal Western Hemlock</span><span class="howe-bec-chips"><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:CWHxm1" style="--bec-colour: #440154" title="Eastern Very Dry Maritime Coastal Western Hemlock Zone" @class="howe-bec-chip-selected:@{selected.CWHxm1}">CWHxm1</a><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:CWHdm" style="--bec-colour: #472D7B" title="Dry Maritime Coastal Western Hemlock Zone" @class="howe-bec-chip-selected:@{selected.CWHdm}">CWHdm</a><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:CWHvm1" style="--bec-colour: #2C728E" title="Submontane Very Wet Maritime Coastal Western Hemlock Zone" @class="howe-bec-chip-selected:@{selected.CWHvm1}">CWHvm1</a><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:CWHvm2" style="--bec-colour: #3B528B" title="Montane Very Wet Maritime Coastal Western Hemlock Zone" @class="howe-bec-chip-selected:@{selected.CWHvm2}">CWHvm2</a><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:CWHds1" style="--bec-colour: #21908C" title="Southern Dry Submaritime Coastal Western Hemlock Zone" @class="howe-bec-chip-selected:@{selected.CWHds1}">CWHds1</a><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:CWHms1" style="--bec-colour: #27AD81" title="Southern Moist Submaritime Coastal Western Hemlock Zone" @class="howe-bec-chip-selected:@{selected.CWHms1}">CWHms1</a></span></div><div class="howe-bec-zone"><span class="howe-bec-zone-name">Mountain Hemlock</span><span class="howe-bec-chips"><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:MHmm1" style="--bec-colour: #5DC863" title="Windward Moist Maritime Mountain Hemlock Zone" @class="howe-bec-chip-selected:@{selected.MHmm1}">MHmm1</a><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:MHmm2" style="--bec-colour: #AADC32" title="Leeward Moist Maritime Mountain Hemlock Zone" @class="howe-bec-chip-selected:@{selected.MHmm2}">MHmm2</a></span></div><div class="howe-bec-zone"><span class="howe-bec-zone-name">Coastal Mountain-heather Alpine</span><span class="howe-bec-chips"><a class="howe-bec-chip" href="#pane:Vascular_BEC&region:CMAunp" style="--bec-colour: #FDE725" title="Coastal Mountain Heather Alpine Zone" @class="howe-bec-chip-selected:@{selected.CMAunp}">CMAunp</a></span></div></div>
</div></div></div>
</template>
