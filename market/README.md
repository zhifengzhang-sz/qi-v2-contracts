# market: the market data contract

The records of the market data, the K-lines, of whatever source gives them, and how they cross from one project to
another as JSON: `SPEC.md`. Three forms, the same records: TypeScript (`ts/`, `@qi/market`, Zod), Lean (`lean/`, the
Lake package `market`, no Mathlib) and Go (`go/`, the module `github.com/zhifengzhang-sz/qi-v2-contracts/market/go`,
the standard library only, its types made from the Zod schemas, its rules and JSON written by hand). The vectors
(`vectors/`) are what every form reads alike, checked on every change (`make market`): each vector by each form, every
rule of `SPEC.md` with a reject vector here that breaks it and every reject vector with the rule it breaks
(`vectors/rules.json`), and changed copies of the vectors made by a fixed seed (`vectors/cases.ts`).

A contract built on it takes its K-line, and defines none of its own. A K-line of a source with fields of its own is
its taker's, not this contract's, held to its vectors for the base (`SPEC.md`, K-line). The vectors here are its own:
the ongoing K-line of the base, and for every rule of `SPEC.md` at least one ongoing K-line with one thing wrong that
breaks it.

## Taking it

By the flake, pinned in the taker's `flake.lock` (`inputs.contracts.url =
"github:zhifengzhang-sz/qi-v2-contracts?ref=market-2.0.0";`):

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
"https://github.com/zhifengzhang-sz/qi-v2-contracts"`, `rev = "market-2.0.0"`, `subDir = "market/lean"`.

A Go taker takes the Go form from the flake's package alone, pinned by its own `flake.lock`: never by `go get` (the
module proxy's copy, which no `flake.lock` pins), and never by a sibling path (a checkout beside it, which moves on its
own). Its `go.mod` requires the module at `v0.0.0`, and its flake writes the `replace` to the package's store path
before Go builds, in a build's `postPatch` or in its shell's hook:

```
go mod edit -require=github.com/zhifengzhang-sz/qi-v2-contracts/market/go@v0.0.0 \
  -replace=github.com/zhifengzhang-sz/qi-v2-contracts/market/go=${contracts.packages.${system}.market-go}
```

The module needs nothing else, so Go fetches nothing (`GOPROXY=off` holds), and `go.sum` has no line for it. `make
packages` takes it so: a module of its own, the `replace`, `GOPROXY=off`, the ongoing K-line decoded back to the same
text.

## Using it

TypeScript: `decodeOngoingKLine(text)` gives `{ ok: true, kline }` (an `OngoingKLine`) or `{ ok: false, error }`;
`encodeOngoingKLine(kline)` its canonical JSON; each record's schema (`klineSchema`, `ongoingKlineSchema`) for one
record. For a contract built on it, or a taker's record of its own: `positionSchema` and `priceSchema`, the units its
records share with the K-line; `decodeAs(schema, text)`, a JSON text read as a value of a Zod schema under the rules of
The JSON (`{ ok: true, value }` or `{ ok: false, error }`), and `encodeRecord(r)`, a record's canonical text.

Lean: `Market.decodeOngoingKLine text : Except String OngoingKLine`, `Market.encodeOngoingKLine k : String`; the
structures `KLine`, `Price` and `Quantity`, and `OngoingOf K`, the ongoing K-line made over a K-line, of which
`OngoingKLine` is the base's, with `ToJson` and `FromJson`; `KLineOf K`, what a contract built on it needs of a K-line,
the base's or a taker's own; `Market.KLine.rule`. For a contract built on it, or a taker's record of its own:
`Market.parsed text`, a JSON text under the rules of The JSON, `Market.strict`, an object of only its fields and no
`null`, and `Market.record`, a record's canonical text.

Go: `market.DecodeOngoingKLine(data) (OngoingKLine, error)`, of the text's bytes, UTF-8, the zero value with its
fault; `market.EncodeOngoingKLine(k) (string, error)` its canonical JSON, once the rules are checked; each record's
`Check() error`, and a K-line's `Base()`, the base's fields of a K-line, which a taker's own K-line gives by a `Base` of
its own; the types `KLine` and `OngoingKLine`, made from the Zod schemas (`go/market/records.go`, `make
market-go-types`). Decoding reads the text straight into the
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

- **2.0.0**: no vendor's record. Massive's K-line and Massive's ongoing K-line (`vw`, `n`) are gone from every form and
  from everything made from them: in TypeScript `massiveKlineSchema`, `massiveOngoingKlineSchema`, `MassiveKLine`,
  `MassiveOngoingKLine` and `decodeMassiveOngoingKLine`; in Lean `MassiveKLine`, its `KLineOf`, `MassiveOngoingKLine`
  and `decodeMassiveOngoingKLine`; in Go `MassiveKLine`, `MassiveOngoingKLine`, `DecodeMassiveOngoingKLine` and their
  methods, and `EncodeOngoingKLine` is of an `OngoingKLine`, no longer generic; the Avro schemas `MassiveKLine.avsc` and
  `MassiveOngoingKLine.avsc`; the Protobuf messages `MassiveKLine` and `MassiveOngoingKLine`, and their field numbers in
  `proto/fields.json`; each form's `decode --massive`; the vectors `vectors/ongoing/massive.json` and its 8 reject cases
  (`vectors/ongoing/massive/reject/`), and `vectors/ongoing/reject/vw-and-n-of-massive.json`, the base's ongoing K-line
  with Massive's two fields, refused for a name that is no field as `unknown-field.json` is; the generated cases of
  Massive's ongoing K-line; the checks of them (the conformance's `--massive`, the cases' group `massive-ongoing`, the
  Avro tests of Massive's K-line against the base's). Why: a contract is the language of the data, and a vendor's own
  fields are used only by whoever reads that vendor, so they are the reader's; held here, each new vendor would be a new
  version of this contract and of everything that takes it. A K-line of a source with fields of its own is its taker's
  (`SPEC.md`, K-line): the base's fields and rule and its own, written under The JSON's rules, read and written by what
  each form gives for a record of its own, which stays, naming no source (TypeScript `decodeAs`, `encodeRecord`,
  `positionSchema` and `priceSchema`; Lean `Market.parsed`, `Market.strict`, `Market.record`, `KLineOf` and `OngoingOf`;
  Go `Check`, `KLine.Base`, `Decimal`, `DecimalOf` and `AppendTo`), and held to this contract's vectors for the base.
  The count is no longer a unit of this contract: `n` was its one field, so no record here has a count and no vector
  here could break its rules; Units, the bound of 2⁵³ − 1 and The JSON no longer name it, and chanlun 4.0.0, whose
  `level` is a count, states it. Versions no longer makes a new source's records a minor version. The Avro schemas'
  section says that the vectors break each rule and that a form that checks the rules reads the vectors alike, where it
  said that a reader in any language must check them itself. Not backward-compatible for a taker of Massive's records,
  which is why 2.0.0; every base record, rule and canonical text is 1.0.0's: `vectors/ongoing/kline.json` reads and
  writes the same text, and every reject case kept is refused, as before, and `KLine.avsc`, `OngoingKLine.avsc` and the
  messages `KLine` and `OngoingKLine` are 1.0.0's, their field numbers too. The counts, 1.0.0 to 2.0.0: the rules of
  `SPEC.md` 32 to 30, each with a vector here; the conformance 2 ongoing K-lines and 37 reject cases to 1 and 28; the
  generated cases 400 (58 read, 342 refused) to 200 (24 read, 176 refused), 1.0.0's copies of the base's ongoing
  K-line, byte for byte.
- **1.0.0**: the market data contract, a product of its own: the K-line records of chanlun 2.3.0, the base K-line and
  Massive's and the ongoing K-line of each, with their rules, their units, the rules of their JSON and their canonical
  texts, and the ongoing K-line's readers and writers, as chanlun 2.3.0 has them. It is 1.0.0 because those records
  have been released, and stable, through five versions of chanlun (2.0.0 to 2.3.0); a new source's records will be a
  minor version of it. No record, field, rule or text changes: the ongoing K-line vectors, here (`vectors/ongoing/`),
  read and write the same text, byte for byte. In every form, as chanlun 2.3.0's, of the K-line alone: TypeScript
  `@qi/market`, Lean the Lake package `market` (namespace `Market`), Go the module
  `github.com/zhifengzhang-sz/qi-v2-contracts/market/go` (package `market`); the Avro schemas `KLine.avsc`,
  `MassiveKLine.avsc`, `OngoingKLine.avsc`, `MassiveOngoingKLine.avsc`, in the namespace `qi.market.v1` (chanlun's
  were in `qi.chanlun.v1`); the Protobuf description `market.proto`, package `qi.market.v1`, each message's field
  numbers and reserved numbers its own of `qi.chanlun.v1`, its bytes the same. Not the same for a reader that names
  the record: an Avro reader resolves a record by its full name, so a schema of `qi.chanlun.v1` and one of
  `qi.market.v1` do not read each other's data without an alias, and a schema registry sees a new schema; a Protobuf
  message's full name is new where a reader names it (an `Any`'s type URL). Given for a contract built on it, kept
  inside before: in TypeScript `decodeAs`, `encodeRecord`, `positionSchema` and `priceSchema`; in Lean
  `Market.record`, no longer private; in Go `Decimal.AppendTo` and `KLine.Base` and `MassiveKLine.Base`, unexported
  before. Each form's `decode` reads an ongoing K-line, with `--ongoing` as before, Massive's with `--massive`. Its
  vectors are its own: a reject vector here for every rule of `SPEC.md`, an ongoing K-line with one thing wrong, the
  file named by what it breaks, 37 in all, 29 of the base (`vectors/ongoing/reject/`) and 8 of Massive's
  (`vectors/ongoing/massive/reject/`), those of the rules about its `vw` and `n` among them. Its checks, on its own
  files alone: the conformance, 2 ongoing K-lines given back and 37 reject cases refused by the three forms, each as
  the ongoing K-line it is read as; every rule of `SPEC.md`, 32, listed with the reject vectors here that break it, at
  least one each (`vectors/rules.json`), its check failing for a rule with none; the generated cases, 400 copies of the
  two ongoing K-lines, by the kinds of change a record of numbers has, by its own seed (20261105), 58 read and 342
  refused; each ongoing K-line through Avro and back.
