Clicking a taxon in the checklist now filters by it, and the resulting state matched an autocomplete pick on everything I compared. It isn't live on the site yet: the code is in imerss-bioinfo's source, and Howe's `static/js` bundles still need rebuilding. I tested with bundles built in the scratchpad from current imerss-bioinfo source.

## Where the state lives
The one source of truth is the **`filterState` signal on the search component**, `checklist.search.filterState`, which holds the taxon row.
- **The signal itself:** it's defined on `hortis.autocompleteFilter` in `filters.js`.
- **How it becomes a global filter:** `withSingleSearch` gives the search the `hortis.autocompleteTaxonObsFilter` grade, which makes it a `hortis.obsFilter`. `hortis.combinedFilterInput` finds it that way, and the result flows on to `finalFilteredObs`, `taxaFromObs` and `rowFocus`, which redraws the checklist.
- **A second copy:** the text in the search box lives separately, in the autocomplete widget's private Preact state.
- **Not involved:** `selectedId` on `hortis.layoutHolder` drives the `checklist-selected` outline, but nothing in `imerss-bioinfo/src/client/js/new` or Howe's reknit code sets it. An autocomplete pick leaves it null, so a click does too.

## What I changed from your draft
**No new event was needed.** `hortis.bindTaxonHover` (`imerss-new.js:494`) already fires `taxonSelect` when a row's `<p>` is clicked, and nothing was listening. The checklist inherits it through `withHolder`, `layoutHolder` and `withTaxonHover`, so your listener went where you proposed, on that event.

| File | Change |
|---|---|
| `new/newChecklist.js` | `withSingleSearch` listens to `taxonSelect` and turns the id into a row |
| `new/filters.js` | new `hortis.autocompleteFilter.select` |
| `autocomplete.js` | new `hortis.autocomplete.setSelection` |
| Howe `static/css/imerss-viz-story.css` | pointer cursor on checklist rows |

## The awkward parts
1. **The widget has no API:** `accessibleAutocomplete()` returns nothing, so `that.widget` is always `undefined`. `setSelection` reaches for Preact 8's `_component` on the widget's root node, which is the one real hack here. It relies on the pinned 2.0.4 version.
2. **Why not just set the input's text:** the widget checks the input every 100ms and treats any change as typing, which would run a search and could open the menu. Simulating an `input` event instead would leave `options` empty, so the code shows "No results found" on focus.
3. **Row ids are strings:** `data-row-id` and `row.id` are both strings, so the strict comparison in `filterObsBySingleTaxon` works. That only holds as long as the row is looked up through `rowById`.

## How I checked it
I loaded the page fresh twice, picking *Sagittaria latifolia* from the dropdown one time and clicking its row the other, and compared after focus had moved away. There were **no differences** across:
- the filter row (same object as `rowById` and `idToEntry` hold)
- the input text and all the widget state fields
- the ✕ button's visibility and the record count
- the filtered observations and the rendered checklist HTML

Clicking a family and then a genus also worked, and Reset filters cleared everything, with no page errors. ESLint is clean on the three imerss-bioinfo files.

## Suggested refactorings
1. **Move the state up (most valuable):** put a `selectedTaxon` signal on the checklist or `vizLoader`, with the search box and checklist both as clients. At the moment a row click has to go through a component that's really a search box, repurposed as a filter.
2. **Make the widget text follow the state:** an effect from `filterState` to the widget would remove the setter from callers and could also replace the `.val("")` in `reset`.
3. **Replace or wrap the widget:** this is the only way to remove the `_component` hack, for example with a small controlled autocomplete, as the library has no API for it.
4. **Split `bindTaxonHover`:** its own TODO says it does both hover and click. The `taxonSelect` comment, "ignored if not selectable", is also now out of date.
5. **Remove `defeatSearchSelect`:** it exists because an effect can't be overridden. Making `selectEffect` a grade-level option or a listener would remove the need for it.

## Issues you may want to act on
- **The search's ✕ doesn't work:** at 1400px `.autocomplete__wrapper` sits on top of it, so clicks never reach it. It failed the same way on the old bundles, so it isn't new, but click-to-filter will make people reach for it more. For now, only Reset filters clears the search, and it also clears every other filter. It's probably a small stacking fix; I can do that if you like.
- **Tooltip lingers:** after a click, the taxon's tooltip stays until the pointer moves, because the row was redrawn underneath it. Setting `hoverId` to null in the listener would fix it.
- **Dragging to select text:** dragging across a name to copy it will probably also count as a click and apply the filter, though I didn't test this.

## Getting it live
Build imerss-bioinfo, then run `npm run build` in Howe. This brings in **other imerss-bioinfo changes** as well, such as `filterSummary` in `imerss-blitz.js`, because Howe's bundles are behind.

I tested that combination, but only this flow, so check the rest of the site afterwards. `imerss-viz.js` differs from Howe's copy only by the checklist selector, so your Carto key work looks safe. Nothing is committed in either repo, and imerss-bioinfo's `docs/` is untouched by me.
