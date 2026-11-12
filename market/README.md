# market: the market data contract

Version 2.0.0. The K-line and the ongoing K-line, of whatever source gives them.

| Part | Where |
|---|---|
| The records | `proto/market.proto` |
| The rules | `lean/Market.lean`: each rule a name, and what holds of a record that keeps it |
| The examples | `examples.json`: records, each with the rules it breaks |
| Go | `go/`, the module `github.com/zhifengzhang-sz/qi-v2-contracts/market/go`, package `market`: the records' code generated from the `.proto` (`market.pb.go`), and the rules (`rules.go`): `k.Check()` gives the names of the rules `k` breaks |
| TypeScript | `ts/`, `@qi/market`: the records' code generated from the `.proto` (`market_pb.ts`), and the rules (`rules.ts`): `checkKLine(k)` and `checkOngoingKLine(k)` give the names of the rules `k` breaks |

## Units

| Kind | What it is |
|---|---|
| time | milliseconds since 1970-01-01 00:00:00 UTC: a K-line's `date`, an ongoing K-line's `asOf` |
| position | a K-line's place in its series, from 0: its `index` |
| price, volume | a number with at most 6 decimal places |

## Reading and writing

A record crosses as Protobuf, in its binary form or in Protobuf's JSON, each read and written by the code generated
from the `.proto`: in Go `proto.Marshal` and `protojson.Marshal`, in TypeScript `toBinary` and `toJson` of
`@bufbuild/protobuf`, with `KLineSchema` or `OngoingKLineSchema`. Protobuf's JSON writes a 64-bit number as a string
and leaves out a field at 0; its readers take a number or a string. TypeScript holds a 64-bit number as a `bigint`.

## Taking it

By the flake, at the tag `market-<version>`:

- `market-proto`: `market.proto`, for a generator of another language.
- `market-go`: the Go module as source, for a `replace` of its path in the taker's `go.mod`. It requires
  `google.golang.org/protobuf` v1.36.11.
- `market-ts`: `node_modules` with `@qi/market` as source and `@bufbuild/protobuf` 2.11.0.
- `market-lean`: the Lake package `market`, the rules, and the program that checks `examples.json` against them.

## Changes

2.0.0: The records are the same on the wire, the same messages with the same field numbers: `buf breaking` against
`market-1.1.0` finds no break. They are read and written by code generated from `proto/market.proto`, as Protobuf or
Protobuf's JSON, in place of the contract's own JSON. The rules are defined in Lean and implemented in Go and
TypeScript by the same names, and checked by all three on the examples. Removed: the Zod schemas, the hand-written JSON
of each form, the Avro schemas, the vectors and the conformance check; the limit of 15 digits on a price, and of 2⁵³
on a whole number; the means for a record of a taker's own (`KLineOf`, `OngoingOf`, `Base`, `decodeAs`,
`encodeRecord`). Earlier versions: their tags.
