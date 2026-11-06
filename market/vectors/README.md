# The vectors

The conformance check's data (`make check`): what every form must read alike, the TypeScript, the Lean and the Go.

| File | What it is | Every form must |
|---|---|---|
| `ongoing/` | `kline.json`, an ongoing K-line of the base: the bar after chanlun's `small.json`'s last, half a minute in; `massive.json`, the same as Massive's; `reject/*.json`, `kline.json` with one thing wrong, the file named by it | decode `kline.json` and `massive.json` as ongoing K-lines, of the base and of Massive's, and encode each to the same text; refuse each reject case as an ongoing K-line of the base, as a fault of the contract |
| `rules.json` | the rules of `../SPEC.md`, each with the reject vectors here that break it and the TypeScript form's refusal of them (`../ts/test/rules.test.ts`): every reject vector names a rule; a rule no vector here breaks is broken in a run, by chanlun's vectors (`../../chanlun/vectors/rules.json`, under `market`), whose check holds every rule here to a vector | refuse each vector of a rule |
| `cases.ts` | the generated cases: from each valid vector, copies changed by a fixed seed, a value (by one, to 0, negative, a seventh decimal, a sixteenth digit, an exponent, text, `null`, a boolean), a field dropped or added or named twice; made by `make market-cases`, a check of the flake, and kept in the Nix store by what they are made from, not in the repository | give each copy the same answer: all refuse it, or all read it and give back the same text |

A K-line in a run is chanlun's to read (`../../chanlun/vectors/`): its runs hold K-lines of this contract, and its reject
cases break this contract's rules, a K-line's and its JSON's, within a run.
