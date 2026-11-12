# chanlun: 缠论's contract

Version 4.0.0. The records the algorithm of 缠论 makes beyond the K-line, of whatever implementation makes them: the
merged bar (包含), the 分型, the line (笔), the 线段, the 走势 and the 中枢. The contract says what a value is, not whether
it is right by the lessons, and not how records are gathered: a run of them, their order, and which is still going on
are their user's.

| Part | Where |
|---|---|
| The records | `proto/chanlun.proto` |
| The rules | `lean/Chanlun.lean`: each rule a name, and what holds of a record that keeps it; each of one record alone |
| The examples | `examples.json`: records, each with the rules it breaks |
| Go | `go/`, the module `github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go`, package `chanlun`: the records' code generated from the `.proto` (`chanlun.pb.go`), and the rules (`rules.go`): `r.Check()` gives the names of the rules `r` breaks |
| TypeScript | `ts/`, `@qi/chanlun`: the records' code generated from the `.proto` (`chanlun_pb.ts`), and the rules (`rules.ts`): `checkMergedBar(r)`, `checkFractal(r)`, `checkLine(r)`, `checkSegment(r)`, `checkMove(r)` and `checkConsolidation(r)` give the names of the rules `r` breaks |

## Units

| Kind | What it is |
|---|---|
| position | a K-line's place in its series, from 0 (market's `KLine.index`): a merged bar's `index`, `start`, `end`, `confirmEnd` and `extremes` |
| bar | a merged bar's number, its `mIndex`, from 0: a 分型's `mIndex`, a line's, a 线段's, a 走势's and a 中枢's `start`, `end` and `confirmEnd` |
| price | a number with at most 6 decimal places: a merged bar's `high` and `low`, a 中枢's `zg`, `zd`, `gg` and `dd` |
| level | from 0: a 线段's, a 走势's and a 中枢's `level` |

A `confirmEnd` not set means the record is still going on: a merged bar still merging, a line not yet ended, a 中枢
under construction.

## Reading and writing

A record crosses as Protobuf, in its binary form or in Protobuf's JSON, each read and written by the code generated
from the `.proto`: in Go `proto.Marshal` and `protojson.Marshal`, in TypeScript `toBinary` and `toJson` of
`@bufbuild/protobuf`, with the record's schema (`MergedBarSchema`, …). Protobuf's JSON writes a 64-bit number as a
string and leaves out a field at 0; its readers take a number or a string. TypeScript holds a 64-bit number as a
`bigint`.

## Taking it

By the flake, at the tag `chanlun-<version>`:

- `chanlun-proto`: `chanlun.proto`, for a generator of another language.
- `chanlun-go`: the Go module as source, for a `replace` of its path in the taker's `go.mod`. It requires
  `google.golang.org/protobuf` v1.36.11.
- `chanlun-ts`: `node_modules` with `@qi/chanlun` as source and `@bufbuild/protobuf` 2.11.0.
- `chanlun-lean`: the Lake package `chanlun`, the rules, and the program that checks `examples.json` against them.

## Changes

4.0.0: The run is removed, `Run` and its lists (`SegmentList`, `MoveList`, `ConsolidationList`), and with it every rule
of a run (each part in order of `start`, at most one record still going on and only the last, every bar below the
number of merged bars, a part by level ending with a level not empty) and Reading the records: how records are gathered
and read together is their user's. The six records are the same on the wire, the same messages with the same field
numbers: `buf breaking` against `chanlun-3.1.0` finds only the four removed messages. They are read and written by code
generated from `proto/chanlun.proto`, as Protobuf or Protobuf's JSON, in place of the contract's own JSON. The rules
are defined in Lean and implemented in Go and TypeScript by the same names, and checked by all three on the examples. A
merged bar's first K-line not after its last is no rule of its own: it follows from `indexInExtremes` and
`extremesWithin` (`MergedBar.startNotAfterEnd`). The contract no longer takes market's: its records hold no record of
market's, and a position and a price are numbers. Removed: the Zod schemas, the hand-written JSON of each form, the
Avro schemas, the vectors and the conformance check. Earlier versions: their tags.
