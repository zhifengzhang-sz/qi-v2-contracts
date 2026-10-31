# The vectors

The conformance check's data (`make check`): what both forms must read alike.

| File | What it is | Both forms must |
|---|---|---|
| `run.json` | a run's records over 4,000 one-minute bars made up by `bars.ts` (not of any market): every kind of record, 走势 of level 0, 中枢 of levels 0 and 1, dates not set among them | decode it, and encode it to the same text |
| `small.json` | a run of six K-lines made by hand: every kind of record, every rule kept | decode it, and encode it to the same text |
| `edge.json` | `small.json` with a text of every kind of printable ASCII (`"` and `\` among them), a K-line without `confirmDate`, the largest number, parts empty | decode it, and encode it to the same text |
| `reject/*.json` | `small.json` with one thing wrong, the file named by it: each rule broken, a field unknown, missing, `null` or of another kind, a number written with a fraction or an exponent or past the bound, a text not printable ASCII, not JSON | refuse it, as a fault of the contract |

`run.json`'s records were computed from the bars by the implementation of the algorithm at hand when they were made.
The contract does not depend on how they were made.
