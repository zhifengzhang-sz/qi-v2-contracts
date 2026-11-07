# chanlun: 缠论's contract

The records the algorithm of 缠论 gives over a run of bars, of whatever implementation gives them, and how they cross
from one project to another as JSON: `SPEC.md`. It is built on the market data contract (`../market/`): a run's bars
are market's base K-lines, and this contract defines no K-line of its own. Three forms, the same records, each on
market's form of the same language: TypeScript (`ts/`, `@qi/chanlun`, Zod, on `@qi/market`), Lean (`lean/`, the Lake
package `chanlun`, no Mathlib, on the Lake package `market`) and Go (`go/`, the module
`github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go`, the standard library and market's module only, its types made
from the Zod schemas, its rules and JSON written by hand). The vectors (`vectors/`) are what every form reads alike,
checked on every change (`make chanlun`): each vector by each form, every rule of `SPEC.md` with its reject vectors, and
every rule of market's that a run's K-line breaks (`vectors/rules.json`), and changed copies of the vectors made by a
fixed seed (`vectors/cases.ts`).

## Taking it

By the flake, pinned in the taker's `flake.lock` (`inputs.contracts.url =
"github:zhifengzhang-sz/qi-v2-contracts?ref=chanlun-4.0.0";`), whose packages hold or name market's of the same
revision:

- `contracts.packages.${system}.chanlun-ts`: `node_modules/@qi/chanlun`, `@qi/market` and `zod`, as source; `import {
  decodeRun, mergedBarSchema } from "@qi/chanlun"`, and the K-line from `@qi/market` (`import { klineSchema } from
  "@qi/market"`).
- `contracts.packages.${system}.chanlun-lean`: the Lake package as source at `chanlun/lean`, and market's at
  `market/lean`, where its lakefile requires it (`path = "../../market/lean"`); a taker's Lake requires
  `chanlun/lean` of a copy of it; `import Chanlun`, and `import Market` for the K-line.
- `contracts.packages.${system}.chanlun-go`: the Go module as source, without its tests; `import
  "github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go/chanlun"`, with market's module (`market-go`) beside it.
- `contracts.packages.${system}.chanlun-avro`: the Avro schemas, one `.avsc` file for each record, each complete,
  market's K-line written out in a run's, for other languages and for schema registries.
- `contracts.packages.${system}.chanlun-proto`: `chanlun.proto`, the same records for Protobuf, which imports
  `market.proto` (`market-proto`): `protoc` reads it with both on its path. `SPEC.md` describes both formats, and says
  why there are two.

Or by the language's own lock: Lake, `[[require]]` with `name = "chanlun"`, `git =
"https://github.com/zhifengzhang-sz/qi-v2-contracts"`, `rev = "chanlun-4.0.0"`, `subDir = "chanlun/lean"`: its `market`,
required by path, is in the same checkout.

A Go taker takes the Go forms from the flake's packages alone, pinned by its own `flake.lock`: never by `go get` (the
module proxy's copy, which no `flake.lock` pins), and never by a sibling path (a checkout beside it, which moves on its
own). Its `go.mod` requires both modules at `v0.0.0`, chanlun's and market's, since chanlun's requires market's and a
`replace` of a module taken is not the taker's; its flake writes both `replace`s to the packages' store paths before Go
builds, in a build's `postPatch` or in its shell's hook:

```
go mod edit -require=github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go@v0.0.0 \
  -require=github.com/zhifengzhang-sz/qi-v2-contracts/market/go@v0.0.0 \
  -replace=github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go=${contracts.packages.${system}.chanlun-go} \
  -replace=github.com/zhifengzhang-sz/qi-v2-contracts/market/go=${contracts.packages.${system}.market-go}
```

The modules need nothing else, so Go fetches nothing (`GOPROXY=off` holds), and `go.sum` has no line for them. `make
packages` takes them so: a module of its own, the two `replace`s, `GOPROXY=off`, the small run decoded back to the same
text.

## Using it

TypeScript: `decodeRun(text)` gives `{ ok: true, run }` or `{ ok: false, error }`; `encodeRun(run)` its canonical JSON;
`timeAt(run, p)` the time of the K-line at position `p`; each record's schema (`mergedBarSchema`, `lineSchema`,
`consolidationSchema`, …) for one record, and `klinesSchema` for a run's K-lines. A K-line, its schema and its type are
`@qi/market`'s, as is the ongoing K-line (`decodeOngoingKLine`).

Lean: `Chanlun.decodeRun text : Except String Run`, `Chanlun.encodeRun run : String`, `run.timeAt p : Option Nat`; the
structures `MergedBar`, `Fractal`, `Line`, `Stroke`, `Segment`, `Move`, `Consolidation`, `RunOf K`, of which `Run` is
the run, of the base's K-lines, with `ToJson` and `FromJson`. A K-line is `Market.KLine`, a price `Market.Price`, the
ongoing K-line `Market.OngoingOf K`.

Go: `chanlun.DecodeRun(data) (Run, error)`, of the text's bytes, UTF-8, the zero value with its fault;
`chanlun.EncodeRun(run) (string, error)` its canonical JSON, once the rules are checked; `run.TimeAt(p) (uint64, bool)`;
each record's and the run's `Check() error`; the types `MergedBar`, `Fractal`, `Line`, `Segment`, `Move`,
`Consolidation` and `Run`, made from the Zod schemas (`go/chanlun/records.go`, `make chanlun-go-types`), and `Stroke`, a
`Line`, written by hand beside them. A run's K-lines are `market.KLine`, held to their rules by their `Check`, and a
price is a `market.Decimal` (`../market/README.md`, Using it); the ongoing K-line is `market.OngoingKLine`. Decoding
reads the text straight into the records, with no tree of the whole text: a run as producers write it holds its records
and its text, little more (a `List` is 24 bytes, so a text of many empty levels, each `[]`, costs some 8 times its
size). Not by `encoding/json`: every record, the run, `List` and `Optional` give `ErrEncodingJSON` from `MarshalJSON`
and `UnmarshalJSON`, which says to use `EncodeRun` and `DecodeRun`, since `encoding/json` would write a second text of
the one run, by Go's names, and read it without its rules; a K-line and a `Decimal` give market's. Nothing given out
changes what another holder has: a record is a value, its fields numbers, booleans, `Decimal`s, `Optional`s (`Some`,
`None`, `Get`) and `List`s, none an exported slice, map or pointer; a `List` keeps its items behind methods, `ListOf`
copying them in, `Slice` copying them out, `Len`, `At`, `Last`, `All` and `Values` giving them as values.

A producer's output is mapped to the records by the producer or by its user, not by the contract.

## Changes

- **4.0.0**: on market 2.0.0, no vendor's record. Massive's run is gone from every form and from everything made from
  it: in TypeScript `massiveRunSchema`, `MassiveRun`, `decodeMassiveRun` and `massiveKlinesSchema`; in Lean `MassiveRun`
  and `decodeMassiveRun`; in Go `MassiveRun`, `DecodeMassiveRun` and their methods, and `EncodeRun` is of a `Run`, no
  longer generic; the Avro schema `MassiveRun.avsc`; the Protobuf message `MassiveRun` and its field numbers in
  `proto/fields.json`; each form's `decode --massive`; the vectors of Massive's runs, `vectors/massive/` (2 runs and 19
  reject cases), and `vectors/reject/klines-of-massive.json`; the generated cases of Massive's runs; the checks of them.
  A run holds base K-lines (`SPEC.md`, K-line): a K-line of a source with fields of its own is its taker's, and a run
  holds its base. Why: as market 2.0.0's (`../market/README.md`, Changes). No run of Massive's is made a run of the base
  K-lines: without `vw` and `n`, each is byte for byte a vector here already (`small.json`, `edge.json`, and for 13 of
  the reject cases the one of the same name in `vectors/reject/`), and the other 6 broke a rule of Massive's alone (its
  `vw` missing or text, its `n` missing, negative or a fraction, and a run of the base read as Massive's), gone with it,
  as is `klines-of-massive.json`, the base's run with Massive's K-lines, refused for a name that is no field as
  `kline-unknown-field.json` is. Every rule here keeps a vector of its own. The count, market's in 3.0.0, is this
  contract's (Units): a 线段's, a 走势's and a consolidation's `level`, from 0, a whole number to 2⁵³ − 1 as a bar is,
  refused negative or a fraction (The JSON), the same rules as before; `consolidation-level-negative.json` breaks its
  `from 0`, and `consolidation-level-with-a-fraction.json`, new, a level of 0.5, breaks its whole number, as Massive's
  `n` with a fraction did in 3.0.0. Versions no longer makes a new source's K-line a minor version; the Avro schemas'
  section and the Protobuf description's header as market 2.0.0's. Not backward-compatible for a taker of Massive's
  run, which is why 4.0.0; every other record, rule and canonical text is 3.0.0's: every vector kept reads and writes
  the same text, or is refused, as before, and the Avro schemas and Protobuf messages kept are 3.0.0's, their field
  numbers too. The counts, 3.0.0 to 4.0.0: the rules of `SPEC.md` 48 to 47 (Massive's run's 2 gone, the count's
  `from 0` stated here), each with a vector here; market's rules held to a vector here 31 to 28; the conformance 5 runs
  and 142 reject cases to 3 and 123; the generated cases 1,960 (384 read, 1,576 refused) to 1,160 (222 read, 938
  refused), 3.0.0's copies of the base's runs, byte for byte.
- **3.0.0**: built on the market data contract, market 1.0.0 (`../market/`): the K-line records, the base's and
  Massive's and the ongoing K-line of each, with their units, their rules, the rules of their JSON and their canonical
  texts, are market's, a product of its own released on its own, and this contract defines no K-line of its own; each
  form takes market's form of the same language for the K-line (TypeScript `@qi/market`, Lean the Lake package `market`,
  Go market's module), the Avro schemas write market's K-line out in a run's, in its namespace `qi.market.v1`, and the
  Protobuf description imports `market.proto` for it, its bytes the same. No record of this contract and no text
  changes: every vector of 2.3.0 reads and writes the same text, byte for byte, and the ongoing K-lines are market's
  vectors now (`../market/vectors/ongoing/`). Not backward-compatible for a taker's code where it names a K-line, which
  is why 3.0.0: in TypeScript `klineSchema`, `massiveKlineSchema`, `ongoingKlineSchema`, `massiveOngoingKlineSchema`,
  `KLine`, `MassiveKLine`, `OngoingKLine`, `MassiveOngoingKLine`, `DecodedOngoing`, `decodeOngoingKLine`,
  `decodeMassiveOngoingKLine` and `encodeOngoingKLine` are `@qi/market`'s; in Lean `KLine`, `MassiveKLine`, `KLineOf`,
  `OngoingOf`, `OngoingKLine`, `MassiveOngoingKLine`, `Price`, `Quantity`, `decimal`, `decimalLE`, `decimalEq`,
  `KLine.rule`, `OngoingOf.check`, `decodeOngoingOf`, `decodeOngoingKLine`, `decodeMassiveOngoingKLine`,
  `encodeOngoingKLine`, and the JSON's `namesOf`, `strict`, `literals`, `twice`, `bound`, `bounded` and `parsed`
  are `Market.`'s, not `Chanlun.`'s; in Go `KLine`, `MassiveKLine`, `OngoingKLine`, `MassiveOngoingKLine`,
  `Decimal`, `ParseDecimal`, `DecimalOf`, `Bound`, `DecodeOngoingKLine`, `DecodeMassiveOngoingKLine` and
  `EncodeOngoingKLine` are `market.`'s, a merged bar's and a 中枢's prices are `market.Decimal`, and a K-line and a
  `Decimal` give `market.ErrEncodingJSON` to `encoding/json`, not `chanlun.ErrEncodingJSON`, whose text no longer
  names the ongoing K-line or `Decimal`. The Avro files of the K-lines and the Protobuf messages of the K-lines are
  market's, in `qi.market.v1`: their fields and their bytes the same, their full names new, so an Avro reader of
  2.3.0's `Run.avsc` and one of 3.0.0's do not read each other's data without an alias for the K-line, a schema
  registry sees a new `Run`, and a Protobuf reader that names the K-line's type (an `Any`'s type URL) sees a new name.
  Each form's `decode` reads runs alone (no `--ongoing`: market's reads the ongoing K-line). The packages: `chanlun-ts` holds `@qi/market`; `chanlun-lean` holds market's Lake package where its lakefile requires it;
  a taker of `chanlun-go` requires and replaces market's module too (`market-go`); `chanlun-proto` needs `market-proto`
  beside it. `SPEC.md`: Units names a position, a price and a count market's, and states the bar's bound, which 2.3.0
  stated with theirs; the K-line is market's; The JSON is under
  market's; the Avro, Protobuf and Why both sections name market's. The rules map lists, under `market`, market's rules
  that a run here breaks, a K-line's and its JSON's, and its check holds every rule of market's to a vector, there or
  here; the conformance reads 5 runs and 142 reject cases with the three forms; the generated cases are the 1,960 copies
  of 2.3.0 of the runs, byte for byte, the ongoing K-lines' copies market's.
- **2.3.0**: one canonical text for one run. A part by level (`segments`, `moves`, `consolidations`) ends with a level
  that is not empty: the levels it holds are 0 to its highest level with a record, an empty level below that stays
  allowed, and a part with no record is `[]`, never `[[]]`. 2.0.0 to 2.2.0 read `"moves": [[a]]` and
  `"moves": [[a], []]`, one run, and wrote each back as it was given, so one run had two texts; the canonical text is how
  runs are compared and pinned, so 2.3.0 refuses the second, in all three forms (`decode: `, exit 1) and in the Go's
  `Check`, by which its `EncodeRun` never writes it. Not backward-compatible one way: a run written under 2.0.0 to
  2.2.0 with a trailing empty level is read by 2.2.0, not by 2.3.0, and its producer must drop the empty levels above
  its highest with a record; every run 2.3.0 reads 2.2.0 reads, to the same text. `run.json` was such a run: its
  `moves` held five empty levels after level 0, and its `consolidations` four after level 1, now dropped, its records
  unchanged. Five reject cases for the rule (`segments`, `moves` and `consolidations` ending with an empty level,
  `segments` as `[[]]`, and Massive's `moves` ending with one), in `vectors/rules.json` under it, and the generated
  cases add an empty level at a part's end. The Go form made lighter, no text it reads or writes changed: its
  `Decimal` 16 bytes (24 before), its sign in the word of its millionths, exact as before; `Neg`, its negation;
  `DecimalOf(units, decimals)`, a producer's whole number of units as a `Decimal`, refused past the bounds; its reader
  without the tree of the whole text, reading straight into the records (a run of 200,000 K-lines, 43.6 MB, read in
  about a sixth of the time, with 39 MB of heap above the text where 2.2.0 took some 750 MB). `encoding/json` no longer
  writes `{}` for a price: every record, both runs, `Decimal`, `List` and `Optional` refuse it in `MarshalJSON` and
  `UnmarshalJSON` with `ErrEncodingJSON`, which says to use `EncodeRun` and `DecodeRun`. A decode that fails gives the
  zero value, never a record half read. The Lean form's usage error starts with `decode: `, as the others do.
  `SPEC.md` names the Go's types beside the TypeScript's and the Lean's.
- **2.2.0**: a Go form, `go/`, and its package `chanlun-go`: one module of the standard library only; its types made
  from the Zod schemas by `ts/bin/go.ts` (`make chanlun-go-types`, and `make check` compares them); its rules and its
  JSON written by hand, refusing what the other forms refuse, encoding/json's leniencies among them (a name twice, bytes
  not UTF-8, an exponent, a field it does not know); a price and a quantity an exact `Decimal`; its records values
  through which no holder changes another's; its `decode`. The conformance check reads every vector with the three
  forms. Every rule of `SPEC.md` has its reject vectors, listed in `vectors/rules.json` and checked by `make check`,
  which fails on a rule with no vector, a vector that names no rule, or a vector the TypeScript form refuses for another
  rule; seven reject cases are added for rules that had none: a quantity with a seventh decimal, and of 16 digits, a
  number with a leading 0, a fraction where a position is, and where a bar is, a run that is not an object, and a record
  that is not one. The generated cases, `vectors/cases.ts`: from each valid vector, changed copies by a fixed seed,
  2,360 in all, each answered alike by the three forms, each form's `decode` reading them in one process (`--batch`).
  `SPEC.md`'s paragraph on the forms names the Go, and its "both forms" is every form. No record, field, rule or
  canonical text changes: every run 2.1.1 reads 2.2.0 reads, and the other way.

- **2.1.1**: the identity of the 线段 of level L + 1 with the 走势 of level L is no longer stated: it said how the
  level above is made, not a rule of the records, and in 2.1.0 it asked that a 走势 still going on be copied into the
  level above. A run need not copy it: the run's rule allows, in each level, one record going on, the last, and does
  not require it. `run.json`'s `segments[1]` no longer holds one: its last record, going on, is gone. No record, field
  or schema changes, so every run 2.1.0 reads 2.1.1 reads, and the other way.
- **2.1.0**: a configuration still going on can be in a run, under one rule for the three records with `confirmEnd`: a
  line's (笔, 线段, 走势) is optional, as the merged bar's and the 中枢's already were, and in `merged`, in `strokes` and in
  each level of `segments`, `moves` and `consolidations` at most one record has none, the last. A run of confirmed
  records alone still conforms. The merged bar's `confirmStart` is gone: it equalled `start` in every run, the first
  K-line both beginning a merged bar and confirming its start. In Avro a line's `confirmEnd` is a union with `null`; in
  Protobuf it is `optional`, its number 14 kept, and `confirm_start`'s 7 reserved. SPEC gains Reading the records (a
  分型's kind and a line's direction, extent and prices from the merged bars), the identity of the 线段 of level L + 1
  with the 走势 of level L, and notes on `index` and on a quantity's six digits. The vectors: `confirmStart` gone from
  every merged bar; `run.json` holds again the 笔, 线段 and 走势 still going on at its end, which 2.0.0 left out; reject
  cases for a record going on that is not the last, two going on, in each of the five parts, and a merged bar still
  carrying `confirmStart`. Not backward-compatible both ways: 2.0.0 refuses a run that leaves out a line's
  `confirmEnd`, and 2.1.0 refuses a run that still carries `confirmStart`.
- **2.0.0**: the records reworked one at a time. The K-line has 7 fields, its `index`, its begin time and its prices
  and volume. A data source's K-line is derived from it, with a run that takes it: Massive's adds `vw` and `n`. The
  ongoing K-line, a bar still going on, is a record of its own, in no run, with `asOf`. The merged bar's number is
  `mIndex` and its K-lines `start` and `end`, and it gains `index` and `extremes`; 分型 is its `mIndex` alone. A line is `start`, `end` and `confirmEnd`, merged bars; 线段
  (`Segment`) and 走势 (`Move`, the part `moves` in place of `trends`) are lines with `level`, by level. 中枢 is
  `Consolidation` (the part `consolidations` in place of `centres`), 8 fields, from a merged bar to a later one. A
  price and a quantity (a K-line's volume) are decimals, and a time is in milliseconds; the kinds flag and text are
  gone. The JSON also refuses a name twice in one object and text not UTF-8. The Avro schemas, `avro/`, made from the
  Zod schemas, and the package `chanlun-avro`. The Protobuf description's field numbers follow SPEC's rule, a changed
  field's old number reserved. The vectors are in the new records and units, with Massive's runs, the ongoing
  K-lines and 125 reject cases.
- **1.1.0**: the Protobuf description, `proto/chanlun.proto`, made from the Zod schemas with the field numbers of
  `proto/fields.json` and checked against them; the package `chanlun-proto`. The records, the JSON and the vectors
  unchanged.
- **1.0.0**: the records (K-line, merged bar, 分型, the lines of every level, 中枢 with every date) and the run's rules;
  the JSON, its numbers and texts, and its canonical text; the TypeScript and Lean forms; the vectors (a run over
  4,000 bars made up, a small run, an edge run, 38 reject cases).
