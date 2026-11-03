# The vectors

The conformance check's data (`make check`): what both forms must read alike.

| File | What it is | Both forms must |
|---|---|---|
| `run.json` | a run's records over 4,000 one-minute bars made up by `bars.ts` (not of any market): every kind of record, 中枢 of levels 0 and 1, fields not set among them, 中枢 under construction included | decode it, and encode it to the same text |
| `small.json` | a run of six K-lines made by hand: every kind of record, every rule kept | decode it, and encode it to the same text |
| `edge.json` | `small.json` with the largest volume and the smallest above 0, parts empty, a 中枢 whose band is its whole range | decode it, and encode it to the same text |
| `reject/*.json` | `small.json` with one thing wrong, the file named by it: each rule broken, a field unknown, missing, `null` or of another kind, a number written with a fraction where a whole number is, or with an exponent, or past the bound, not JSON, a K-line of a data source's contract | refuse it, as a fault of the contract |
| `massive/small.json` | `small.json` as Massive's run: `vw` and `n` on each K-line, made up by hand | decode it as Massive's run, and encode it to the same text |
| `massive/edge.json` | `edge.json` as Massive's run, the largest `n` and the lowest `vw` among them | decode it as Massive's run, and encode it to the same text |
| `massive/reject/*.json` | `massive/small.json` with one thing wrong, the file named by it, a K-line of the base among them | refuse it as Massive's run, as a fault of the contract |
| `ongoing/` | `kline.json`, an ongoing K-line of the base: the bar after `small.json`'s last, half a minute in; `massive.json`, the same as Massive's; `reject/*.json`, `kline.json` with one thing wrong, the file named by it | decode `kline.json` and `massive.json` as ongoing K-lines, of the base and of Massive's, and encode each to the same text; refuse each reject case as an ongoing K-line of the base, as a fault of the contract |

`run.json`'s records were computed from the bars by the implementation of the algorithm at hand when they were made.
The contract does not depend on how they were made.
