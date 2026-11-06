# market: the market data contract

The records of the market data, the K-lines, of whatever source gives them, and how they cross from one project to
another as JSON: `SPEC.md`. Three forms, the same records: TypeScript (`ts/`, `@qi/market`, Zod), Lean (`lean/`, the
Lake package `market`, no Mathlib) and Go (`go/`, the module `github.com/zhifengzhang-sz/qi-v2-contracts/market/go`,
the standard library only, its types made from the Zod schemas, its rules and JSON written by hand). The vectors
(`vectors/`) are what every form reads alike, checked on every change (`make market`): each vector by each form, every
reject vector here with the rule of `SPEC.md` it breaks (`vectors/rules.json`), and changed copies of the vectors made
by a fixed seed (`vectors/cases.ts`).

A contract built on it takes its K-line, and defines none of its own: 缠论's (`../chanlun/`), whose run holds K-lines of
this contract. Its runs are where a K-line's rules are broken one by one (`../chanlun/vectors/rules.json`, under
`market`); market's own vectors are the ongoing K-lines.

## Taking it

By the flake, pinned in the taker's `flake.lock` (`inputs.contracts.url =
"github:zhifengzhang-sz/qi-v2-contracts?ref=market-1.0.0";`):

- `contracts.packages.${system}.market-ts`: `node_modules/@qi/market` and `zod`, as source; `import {
  decodeOngoingKLine, klineSchema } from "@qi/market"`.
- `contracts.packages.${system}.market-lean`: the Lake package as source; `import Market`.
- `contracts.packages.${system}.market-go`: the Go module as source, without its tests; `import
  "github.com/zhifengzhang-sz/qi-v2-contracts/market/go/market"`.
- `contracts.packages.${system}.market-avro`: the Avro schemas, one `.avsc` file for each record, for other languages
  and for schema registries.
- `contracts.packages.${system}.market-proto`: `market.proto`, the same records for Protobuf. `SPEC.md` describes both
  formats, and says why there are two.

Or by the language's own lock: Lake, `[[require]]` with `name = "market"`, `git =
"https://github.com/zhifengzhang-sz/qi-v2-contracts"`, `rev = "market-1.0.0"`, `subDir = "market/lean"`.

A Go taker takes the Go form from the flake's package alone, pinned by its own `flake.lock`: never by `go get` (the
module proxy's copy, which no `flake.lock` pins), and never by a sibling path (a checkout beside it, which moves on its
own). Its `go.mod` requires the module at `v0.0.0`, and its flake writes the `replace` to the package's store path
before Go builds, in a build's `postPatch` or in its shell's hook:

```
go mod edit -require=github.com/zhifengzhang-sz/qi-v2-contracts/market/go@v0.0.0 \
  -replace=github.com/zhifengzhang-sz/qi-v2-contracts/market/go=${contracts.packages.${system}.market-go}
```

The module needs nothing else, so Go fetches nothing (`GOPROXY=off` holds), and `go.sum` has no line for it. `make
packages` takes it so: a module of its own, the `replace`, `GOPROXY=off`, the ongoing K-lines decoded back to the same
text.

## Using it

TypeScript: `decodeOngoingKLine(text)` gives `{ ok: true, kline }` (an `OngoingKLine`) or `{ ok: false, error }`,
`decodeMassiveOngoingKLine(text)` the same of Massive's ongoing K-line (a `MassiveOngoingKLine`);
`encodeOngoingKLine(kline)` the canonical JSON of either; each record's schema (`klineSchema`, `massiveKlineSchema`,
`ongoingKlineSchema`, `massiveOngoingKlineSchema`) for one record. For a contract built on it: `positionSchema` and
`priceSchema`, the units its records share with the K-line; `decodeAs(schema, text)`, a JSON text read as a value of a
Zod schema under the rules of The JSON (`{ ok: true, value }` or `{ ok: false, error }`), and `encodeRecord(r)`, a
record's canonical text.

Lean: `Market.decodeOngoingKLine text : Except String OngoingKLine`, `Market.decodeMassiveOngoingKLine text : Except
String MassiveOngoingKLine`, `Market.encodeOngoingKLine k : String`; the structures `KLine`, `MassiveKLine`, `Price` and
`Quantity`, and `OngoingOf K`, of which `OngoingKLine` and `MassiveOngoingKLine` are the two ongoing K-lines, with
`ToJson` and `FromJson`; `KLineOf K`, what a run needs of a source's K-line; `Market.KLine.rule`. For a contract built
on it: `Market.parsed text`, a JSON text under the rules of The JSON, `Market.strict`, an object of only its fields and
no `null`, and `Market.record`, a record's canonical text.

Go: `market.DecodeOngoingKLine(data) (OngoingKLine, error)` and `market.DecodeMassiveOngoingKLine(data)`, of the
text's bytes, UTF-8, each the zero value with its fault; `market.EncodeOngoingKLine(k) (string, error)` the canonical
JSON of either ongoing K-line, once the rules are checked; each record's `Check() error`, and a K-line's `Base()`, the
base's fields of any source's K-line; the types `KLine`, `MassiveKLine`, `OngoingKLine` and `MassiveOngoingKLine`, made
from the Zod schemas (`go/market/records.go`, `make market-go-types`). Decoding reads the text straight into the
record. A price and a quantity are a `Decimal`, 16 bytes, never a `float64`: `ParseDecimal` reads it from its digits,
`DecimalOf(units, decimals)` from a whole number of units (millionths with 6, cents with 2), refusing a value past the
bounds, never rounding it; `String` writes its digits and `AppendTo` appends them to a slice, `Neg` gives its negation,
`Cmp` and `==` compare values exactly; it holds the 15 digits before the point the contract allows, which a count of
millionths in an `int64` does not. A whole number is a `uint64` from 0 to `Bound`. Not by `encoding/json`: every record
and `Decimal` give `ErrEncodingJSON` from `MarshalJSON` and `UnmarshalJSON`, which says what to use, since
`encoding/json` would write a second text of the one record, by Go's names, and read it without its rules. A record is a
value, its fields numbers and `Decimal`s, none an exported slice, map or pointer: nothing given out changes what another
holder has.

A source's output is mapped to the records by the source's reader or by its user, not by the contract.

## Changes

- **1.0.0**: the market data contract, a product of its own: the K-line records of chanlun 2.3.0 (`../chanlun/`), the
  base K-line and Massive's and the ongoing K-line of each, with their rules, their units, the rules of their JSON and
  their canonical texts, and the ongoing K-line's readers and writers, as chanlun 2.3.0 has them. It is 1.0.0 because
  those records have been released, and stable, through five versions of chanlun (2.0.0 to 2.3.0); a new source's
  records will be a minor version of it. No record, field, rule or text changes: the ongoing K-line vectors, here
  (`vectors/ongoing/`), read and write the same text, byte for byte, and every run of chanlun's holds its K-lines as it
  did. In every form, as chanlun 2.3.0's, of the K-line alone: TypeScript `@qi/market`, Lean the Lake package `market`
  (namespace `Market`), Go the module `github.com/zhifengzhang-sz/qi-v2-contracts/market/go` (package `market`); the
  Avro schemas `KLine.avsc`, `MassiveKLine.avsc`, `OngoingKLine.avsc`, `MassiveOngoingKLine.avsc`, in the namespace
  `qi.market.v1` (chanlun's were in `qi.chanlun.v1`); the Protobuf description `market.proto`, package `qi.market.v1`,
  each message's field numbers and reserved numbers its own of `qi.chanlun.v1`, its bytes the same. Not the same
  for a reader that names the record: an Avro reader resolves a record by its full name, so a schema of
  `qi.chanlun.v1` and one of `qi.market.v1` do not read each other's data without an alias, and a schema registry
  sees a new schema; a Protobuf message's full name is new where a reader names it (an `Any`'s type URL). Given for a
  contract built on it, which chanlun 2.3.0 kept inside: in TypeScript `decodeAs`, `encodeRecord`, `positionSchema`
  and `priceSchema`; in Lean `Market.record`, no longer private; in Go `Decimal.AppendTo` and `KLine.Base` and
  `MassiveKLine.Base`, unexported before. Each form's `decode` reads an ongoing K-line, with `--ongoing` as before. Its
  checks: the conformance, 2 ongoing K-lines given back and 2 reject cases refused by the three forms; every rule of
  `SPEC.md` listed with the reject vectors here that break it (`vectors/rules.json`), those of a K-line in a run
  chanlun's (its check holds every rule here to a vector, here or in a run); the generated cases, 400 copies of the
  two ongoing K-lines, by the kinds of change a record of numbers has, by the seed of chanlun's: new copies, not
  chanlun 2.3.0's copies of them, which were drawn among the kinds of a run too (58 read and 342 refused here, 62 and
  338 there); each ongoing K-line through Avro and back.
