# The vectors

The conformance check's data (`make check`): what every form must read alike, the TypeScript, the Lean and the Go.

| File | What it is | Every form must |
|---|---|---|
| `run.json` | a run's records over 4,000 one-minute bars made up by `bars.ts` (not of any market): every kind of record, 中枢 of levels 0 and 1, fields not set among them: a 中枢 under construction, and the 笔, 线段 and 走势 still going on at its end (the last of `strokes`, `segments[0]` and `moves[0]`, no `confirmEnd`); each part by level ending with its highest level with a record (to 2.2.0 it also held empty levels above that, which 2.3.0 refuses) | decode it, and encode it to the same text |
| `small.json` | a run of six K-lines made by hand: every kind of record, every rule kept | decode it, and encode it to the same text |
| `edge.json` | `small.json` with the largest volume and the smallest above 0, parts empty, a 中枢 whose band is its whole range | decode it, and encode it to the same text |
| `reject/*.json` | `small.json` with one thing wrong, the file named by it: each rule broken, a field unknown, missing, `null` or of another kind, a record going on that is not the last of its part or level, two going on, a merged bar with 2.0.0's `confirmStart`, a number written with a fraction where a whole number is, or with an exponent, or with a leading 0, or past the bound, a quantity with a seventh decimal or of 16 digits, not JSON, a run or a record that is not an object, a K-line of a data source's contract, a part by level ending with an empty level, or holding an empty level alone (`[[]]`) | refuse it, as a fault of the contract |
| `massive/small.json` | `small.json` as Massive's run: `vw` and `n` on each K-line, made up by hand | decode it as Massive's run, and encode it to the same text |
| `massive/edge.json` | `edge.json` as Massive's run, the largest `n` and the lowest `vw` among them | decode it as Massive's run, and encode it to the same text |
| `massive/reject/*.json` | `massive/small.json` with one thing wrong, the file named by it, a K-line of the base and a part ending with an empty level among them | refuse it as Massive's run, as a fault of the contract |
| `ongoing/` | `kline.json`, an ongoing K-line of the base: the bar after `small.json`'s last, half a minute in; `massive.json`, the same as Massive's; `reject/*.json`, `kline.json` with one thing wrong, the file named by it | decode `kline.json` and `massive.json` as ongoing K-lines, of the base and of Massive's, and encode each to the same text; refuse each reject case as an ongoing K-line of the base, as a fault of the contract |
| `rules.json` | the rules of `../SPEC.md`, each with the reject vectors that break it and the TypeScript form's refusal of them (`../ts/test/rules.test.ts`): every rule has a vector, every reject vector names a rule | refuse each vector of a rule |
| `cases.ts` | the generated cases: from each valid vector, copies changed by a fixed seed, a value (by one, to 0, negative, a seventh decimal, a sixteenth digit, an exponent, text, `null`, a boolean), a field dropped or added or named twice, a record or an entry dropped, doubled or moved, `confirmEnd` taken away or added, an empty level added at the end of a part by level; made by `make chanlun-cases`, a check of the flake, and kept in the Nix store by what they are made from, not in the repository | give each copy the same answer: all refuse it, or all read it and give back the same text |

`run.json`'s records were computed from the bars by the implementation of the algorithm at hand when they were made.
The contract does not depend on how they were made.
