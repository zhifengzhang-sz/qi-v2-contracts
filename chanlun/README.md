# chanlun: 缠论's contract

The records the algorithm of 缠论 gives over a run of bars, of whatever implementation gives them, and how they cross
from one project to another as JSON: `SPEC.md`. Three forms, the same records: TypeScript (`ts/`, `@qi/chanlun`,
Zod), Lean (`lean/`, the Lake package `chanlun`, no Mathlib) and Go (`go/`, the module
`github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go`, the standard library only, its types made from the Zod
schemas, its rules and JSON written by hand). The vectors (`vectors/`) are what every form reads alike, checked on
every change (`make chanlun`): each vector by each form, every rule of `SPEC.md` with its reject vectors
(`vectors/rules.json`), and changed copies of the vectors made by a fixed seed (`vectors/cases.ts`).

## Taking it

By the flake, pinned in the taker's `flake.lock` (`inputs.contracts.url =
"github:zhifengzhang-sz/qi-v2-contracts?ref=chanlun-2.2.0";`):

- `contracts.packages.${system}.chanlun-ts`: `node_modules/@qi/chanlun` and `zod`, as source; `import { decodeRun,
  klineSchema } from "@qi/chanlun"`.
- `contracts.packages.${system}.chanlun-lean`: the Lake package as source; `import Chanlun`.
- `contracts.packages.${system}.chanlun-go`: the Go module as source, without its tests; `import
  "github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go/chanlun"`.
- `contracts.packages.${system}.chanlun-avro`: the Avro schemas, one `.avsc` file for each record, for other languages
  and for schema registries.
- `contracts.packages.${system}.chanlun-proto`: `chanlun.proto`, the same records for Protobuf. `SPEC.md` describes both
  formats, and says why there are two.

Or by the language's own lock: Lake, `[[require]]` with `name = "chanlun"`, `git =
"https://github.com/zhifengzhang-sz/qi-v2-contracts"`, `rev = "chanlun-2.2.0"`, `subDir = "chanlun/lean"`.

A Go taker takes the Go form from the flake's package alone, pinned by its own `flake.lock`: never by `go get` (the
module proxy's copy, which no `flake.lock` pins), and never by a sibling path (a checkout beside it, which moves on its
own). Its `go.mod` requires the module at `v0.0.0`, and its flake writes the `replace` to the package's store path
before Go builds, in a build's `postPatch` or in its shell's hook:

```
go mod edit -require=github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go@v0.0.0 \
  -replace=github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go=${contracts.packages.${system}.chanlun-go}
```

The module needs nothing else, so Go fetches nothing (`GOPROXY=off` holds), and `go.sum` has no line for it. `make
packages` takes it so: a module of its own, the `replace`, `GOPROXY=off`, the small runs decoded back to the same text.

## Using it

TypeScript: `decodeRun(text)` gives `{ ok: true, run }` or `{ ok: false, error }`, `decodeMassiveRun(text)` the same of
a run of Massive's K-lines; `encodeRun(run)` the canonical JSON of either; `timeAt(run, p)` the time of the K-line at
position `p`; `decodeOngoingKLine(text)` gives `{ ok: true, kline }` (an `OngoingKLine`) or `{ ok: false, error }`,
`decodeMassiveOngoingKLine(text)` the same of Massive's ongoing K-line (a `MassiveOngoingKLine`);
`encodeOngoingKLine(kline)` the canonical JSON of either; each record's schema (`klineSchema`, `massiveKlineSchema`,
`ongoingKlineSchema`, `massiveOngoingKlineSchema`, …) for one record.

Lean: `Chanlun.decodeRun text : Except String Run`, `Chanlun.decodeMassiveRun text : Except String MassiveRun`,
`Chanlun.encodeRun run : String`, `run.timeAt p : Option Nat`; `Chanlun.decodeOngoingKLine text : Except String
OngoingKLine`, `Chanlun.decodeMassiveOngoingKLine text : Except String MassiveOngoingKLine`,
`Chanlun.encodeOngoingKLine k : String`; the structures `KLine`, `MassiveKLine`, `MergedBar`,
`Fractal`, `Line`, `Stroke`, `Segment`, `Move`, `Consolidation`, `RunOf K`, of which `Run` and `MassiveRun` are the two runs,
and `OngoingOf K`, of which `OngoingKLine` and `MassiveOngoingKLine` are the two ongoing K-lines, with `ToJson` and
`FromJson`.

Go: `chanlun.DecodeRun(data) (Run, error)`, `chanlun.DecodeMassiveRun(data) (MassiveRun, error)`,
`chanlun.DecodeOngoingKLine(data)` and `chanlun.DecodeMassiveOngoingKLine(data)`, of the text's bytes, UTF-8;
`chanlun.EncodeRun(run) (string, error)` the canonical JSON of either run, and `chanlun.EncodeOngoingKLine(k)` of either
ongoing K-line, each once the rules are checked; `run.TimeAt(p) (uint64, bool)`; each record's and each run's
`Check() error`; the types `KLine`, `MassiveKLine`, `OngoingKLine`, `MassiveOngoingKLine`, `MergedBar`, `Fractal`,
`Line`, `Segment`, `Move`, `Consolidation`, `Run` and `MassiveRun`, made from the Zod schemas
(`go/chanlun/records.go`, `make chanlun-go-types`), and `Stroke`, a `Line`, written by hand beside them. A price and
a quantity are a `Decimal`, never a `float64`: `ParseDecimal` reads it from its digits, `String` writes the same
digits, `Cmp` and `==` compare values exactly; it holds the 15 digits before the point the contract allows, which a
count of millionths in an `int64` does not. A whole number is a `uint64` from 0 to `Bound`. Nothing given out changes what another holder has: a record is a value, its fields
numbers, booleans, `Decimal`s, `Optional`s (`Some`, `None`, `Get`) and `List`s, none an exported slice, map or pointer;
a `List` keeps its items behind methods, `ListOf` copying them in, `Slice` copying them out, `Len`, `At`, `Last`, `All`
and `Values` giving them as values.

A producer's output is mapped to the records by the producer or by its user, not by the contract.

## Changes

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
