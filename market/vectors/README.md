# The vectors

The conformance check's data (`make check`): what every form must read alike, the TypeScript, the Lean and the Go.

| File | What it is | Every form must |
|---|---|---|
| `ongoing/` | `kline.json`, an ongoing K-line of the base: the bar at `index` 6, begun 2026-01-05 14:36 UTC (`date`), half a minute in (`asOf`), open 100.45, high 100.6, low 100.4, close 100.55, volume 0.25; `reject/*.json`, `kline.json` with one thing wrong, the file named by it | decode `kline.json` as an ongoing K-line, and encode it to the same text; refuse each reject case as an ongoing K-line, as a fault of the contract |
| `rules.json` | the rules of `../SPEC.md`, each with the reject vectors here that break it and the TypeScript form's refusal of them (`../ts/test/rules.test.ts`): every rule has a vector, every reject vector names a rule | refuse each vector of a rule |
| `cases.ts` | the generated cases: from each valid vector, copies changed by a fixed seed, a value (by one, to 0, negative, a seventh decimal, a sixteenth digit, an exponent, text, `null`, a boolean), a field dropped or added or named twice; made by `make market-cases`, a check of the flake, and kept in the Nix store by what they are made from, not in the repository | give each copy the same answer: all refuse it, or all read it and give back the same text |
