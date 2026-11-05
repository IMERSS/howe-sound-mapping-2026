Q: Can we work through this in a very simple case, e.g. for Potentilla villosa which has just 2 observations. The regional EP agrees with the clustered estimate of 0.843 when the radius is 7.5km or greater. How can we justify that the separate EPs for the individual observations end up lower than this (e.g. 0.649) when they are treated as separate populations? Do we correspondingly consider that the PP (probability of presence) would be higher given a sequence of just a single observation? That doesn't seem correct.


## The *Potentilla villosa* numbers
There are two records, both by John Davidson and 5.45 km apart: 1913 and 1917. That's why they merge at 7.5 km but not at 5 km. The window is T = 127 years, and the last sighting is at t = 20 (1917).

The formula compares how likely the sightings are under each of two scenarios:
- **Still present:** each sighting could fall anywhere in the 127 years.
- **Lost:** sightings stop at an unknown loss date, assumed equally likely to be any time in the window.

| Sightings, last in 1917 | Odds favouring "lost" | PP | EP |
|---|---|---|---|
| None (prior) | 1 : 1 | 0.500 | 0.500 |
| 1 | 1.85 : 1 | 0.351 | **0.649** |
| 2 | 5.35 : 1 | 0.157 | **0.843** |
| 3 | 19.6 : 1 | 0.048 | 0.952 |

(The 1913 sighting alone gives an EP of 0.674.)

## Your question about PP
The formula doesn't claim a single observation is evidence of presence. PP falls with every sighting, so 0.351 is lower than the 0.5 starting point. It's higher than 0.157 only because it has moved less far from that assumed 50%.

The within-model logic is sound: one sighting landing in the first 16% of the window is unremarkable (chance 0.157), but two both landing there is much less likely (chance 0.025).

So the 0.649 is largely an artefact of the prior, because little data leaves the result close to 50%. An old single-sighting cluster can never score very high for this reason: even a 1900 sighting only reaches 0.789.

## Where the comparison breaks down
- **Different questions:** the pooled figure treats both records as one process with one loss date. The cluster figures treat them as two unrelated populations, each starting again from 50%.
- **Incompatible results:** if the two populations are independent, the taxon is gone only if both are, so regional EP would be 0.674 × 0.649 = **0.437**, not 0.843. The split model assumes a 75% prior chance that at least one population survives, against 50% for the pooled model.
- **Weak independence:** these two records may reflect one collector's visits between 1913 and 1917 more than two separate populations with their own histories.

## Changing my recommendation
I previously suggested a floor, `EP_region + (1 − EP_region) × EP_cluster`, but I no longer recommend it. It counts the same sightings twice, once in the regional figure and again in the cluster figure, and would give *Potentilla* about 0.945 and 0.949, a confidence these two records don't support.

**I'd use this instead:** `EP_cluster' = max(EP_region, EP_cluster)`.
- **Why it's defensible:** it applies the one thing we know for certain, that a population can't be less lost than the region. It adds no new modelling assumption.
- ***Potentilla villosa*:** both populations show 0.843, the same as the merged result, so changing the radius no longer changes the picture.
- **What it keeps:** an old cluster of a taxon that's still present regionally keeps its high EP, which is the useful local signal.
- **What it doesn't do:** it's a consistency limit, not a population-level model, and it still leaves those clusters resting on very little data. Single-sighting clusters could also be marked as "1 sighting" in the tooltip.

## Decision for you
Should I apply `max` in `computeClusterPPs` and switch to counting distinct dates? It's a small change, but it needs the published regional EP passed into the map layer. Since it changes what the map reports, you may want to run it past whoever owns the Solow method first.
