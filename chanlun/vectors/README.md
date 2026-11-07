# The vectors

The conformance check's data (`make check`): what every form must read alike, the TypeScript, the Lean and the Go. A
run holds no K-line: the K-lines it is made from, and the ongoing K-line, are market's (`../../market/SPEC.md`), with
its own vectors (`../../market/vectors/`).

| File | What it is | Every form must |
|---|---|---|
| `run.json` | a run's records over 4,000 one-minute bars made up by `bars.ts` (not of any market), which it does not hold: every kind of record, 中枢 of levels 0 and 1, fields not set among them: a 中枢 under construction, and the 笔, 线段 and 走势 still going on at its end (the last of `strokes`, `segments[0]` and `moves[0]`, no `confirmEnd`); each part by level ending with its highest level with a record (to 2.2.0 it also held empty levels above that, which 2.3.0 refuses) | decode it, and encode it to the same text |
| `small.json` | a run over six K-lines, made by hand: every kind of record, every rule kept | decode it, and encode it to the same text |
| `edge.json` | `small.json` with parts empty, and a 中枢 whose band is its whole range | decode it, and encode it to the same text |
| `reject/*.json` | `small.json` with one thing wrong, the file named by it: each rule broken, a field unknown, missing, `null` or of another kind, a record going on that is not the last of its part or level, two going on, a merged bar with 2.0.0's `confirmStart`, a number written with a fraction where a whole number is, not JSON, a run or a record that is not an object, a part by level ending with an empty level, or holding an empty level alone (`[[]]`) | refuse it, as a fault of the contract |
| `rules.json` | the rules of `../SPEC.md`, each with the reject vectors that break it and the TypeScript form's refusal of them (`../ts/test/rules.test.ts`): every rule has a vector, every reject vector names a rule; and, under `market`, the rules of market's contract that a vector here breaks, a position's and its JSON's, each of which market's own vectors break too (`../../market/vectors/rules.json`) | refuse each vector of a rule |
| `cases.ts` | the generated cases: from each valid vector, copies changed by a fixed seed, a value (by one, to 0, negative, a seventh decimal, a sixteenth digit, an exponent, text, `null`, a boolean), a field dropped or added or named twice, a record or an entry dropped, doubled or moved, `confirmEnd` taken away or added, an empty level added at the end of a part by level; made by `make chanlun-cases`, a check of the flake, and kept in the Nix store by what they are made from, not in the repository; the copies of the ongoing K-lines are market's (`../../market/vectors/cases.ts`) | give each copy the same answer: all refuse it, or all read it and give back the same text |

`run.json`'s records were computed from the bars by the implementation of the algorithm at hand when they were made.
The contract does not depend on how they were made.
