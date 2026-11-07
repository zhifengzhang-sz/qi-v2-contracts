# 缠论's contract: the algorithm's records

Version 4.0.0. The records the algorithm of 缠论 gives over a run of bars, of whatever implementation gives them, and
how they cross from one project to another as JSON. It is written in TypeScript (`ts/`, Zod schemas); Lean (`lean/`,
structures with a JSON codec) is a second form of it, and Go (`go/`, one module of the standard library and market's
module only, its types made from the Zod schemas, its rules and its JSON written by hand) a third, whose types and
functions have the TypeScript's names, capitalized (`MergedBar`, `DecodeRun`, `EncodeRun`, `Run.TimeAt`); its Avro
schemas (`avro/`) and Protobuf description (`proto/chanlun.proto`) are made from the TypeScript, for every other
language and for a schema registry. The vectors (`vectors/`) are what every form must read alike.

It is built on the market data contract, market's (`../market/SPEC.md`): the bars, the K-lines, are its, with their
units, their rules and their JSON, and this contract defines no K-line of its own. Each form of this one takes
market's form of the same language for the K-line: in TypeScript `@qi/market`, in Lean the Lake package `market`, in
Go the module `github.com/zhifengzhang-sz/qi-v2-contracts/market/go`; the Avro schemas write market's K-line out in a
run's, and the Protobuf description imports `market.proto`.

The algorithm is a chain, and so are its records: each step's output is the next step's input.

```
the K-line (market's)      the bars, as read
  → 包含 →  the merged bar
  → 分型 →  the fractal: a top or a bottom at a merged bar
  → 笔   →  the lowest level line of level 0
  → 线段 →  a line of level 0
  → 中枢 →  a consolidation of level 0
  → 走势 →  the highest level line of level 0
the 走势 of level L          the input of level L + 1
  → 线段 →  a line of level L + 1
  → 中枢 →  a consolidation of level L + 1
  → 走势 →  the highest level line of level L + 1
```

Whether an implementation's values are right by the lessons is not the contract's to say: it says what a value is.

## Units

| Kind | What it is |
|---|---|
| position | the position of a K-line in the run, market's (`../market/SPEC.md`, Units): a K-line's `index` and a merged bar's `index`, `start`, `end`, `confirmEnd` and each of its `extremes` |
| bar | the number of a merged bar (its `mIndex`, a 分型's `mIndex`, a line's `start`, `end` and `confirmEnd`, a consolidation's `start`, `end` and `confirmEnd`), from 0 |
| price | a decimal, market's: a merged bar's `high` and `low`, and a consolidation's `zg`, `zd`, `gg` and `dd` |
| count | a 线段's, a 走势's and a consolidation's `level`, from 0 |

A time and a quantity are market's units too, and the rules of a position and a price are market's. A bar and a count
are whole numbers from 0 to 2⁵³ − 1, as a time and a position are, which every JSON reader holds exactly.

A field that may be not set (marked ?) is left out when it is not set; it is never `null`. The three records with
`confirmEnd`, the merged bar, the line and the 中枢, leave it out under one rule: a configuration still going on, a merged
bar still merging, a line not yet ended, a 中枢 under construction, has none; in a run at most one record of a part, or
of a level, is going on, the last (The run). Every position is a
K-line's of the run, and every bar a merged bar's (The run), so the time of any position is the time of the K-line at
it (`timeAt` in TypeScript, `RunOf.timeAt` in Lean, `Run.TimeAt` in Go): no other time is kept.

## The records

Each record has exactly its fields: none other, none missing but an optional one (marked ?).

### K-line

The K-line is market's (`../market/SPEC.md`, K-line): the base's, 7 fields, with its rule. A run holds base K-lines
(The run): a K-line of a source with fields of its own is its taker's, and a run holds its base; a bar still going on
is an ongoing K-line, market's too, in no run. This contract defines no K-line of its own.

### Merged bar (包含)

| Field | Kind | Meaning |
|---|---|---|
| `index` | position | one of `extremes`: the K-line that represents the merged bar. The contract does not say which one is chosen |
| `mIndex` | bar | its number |
| `up` | boolean | its direction |
| `high`, `low` | price | its high and low |
| `start`, `end` | position | its first and last K-lines |
| `confirmEnd`? | position | the K-line that confirmed its end. Not set while it is still merging |
| `extremes` | array of position | the K-lines of its extreme, at least one: of its high when it goes up, of its low when it goes down |

Rule: `start ≤ end`, `low ≤ high`, `extremes` holds at least one K-line, every entry of `extremes` is from `start` to
`end`, in ascending order, with none twice, and `index` is in `extremes`.

`index ∈ extremes` is all the contract fixes of `index`: which of `extremes` it is is the implementation's choice, and
may be one of its parameters. The contract says what a value is, not how it is filled, so it does not say which one is
chosen. A merged bar has no `confirmStart`: its first K-line both begins it and confirms its start, so that K-line is
`start`; its end alone is confirmed later, by `confirmEnd`.

### Fractal (分型)

| Field | Kind | Meaning |
|---|---|---|
| `mIndex` | bar | its index in the merged-bar sequence |

### Line (笔, 线段, 走势)

`lineSchema` and `Line` in TypeScript, `Line` in Lean, `Line` in Go.

| Field | Kind | Meaning |
|---|---|---|
| `start`, `end` | bar | its start and end merged bars |
| `confirmEnd`? | bar | the merged bar at which it was confirmed. Not set while it is still going on |

Rule: `start < end`.

A 笔 is a line: `strokeSchema` and `Stroke` in TypeScript, `Stroke` in Lean, `Stroke` in Go.

A 线段 is a line of level L: `segmentSchema` and `Segment` in TypeScript, `Segment` in Lean, `Segment` in Go. It has the
line's fields and rule, and:

| Field | Kind | Meaning |
|---|---|---|
| `level` | count | its level L |

A 走势 is a line of level L: `moveSchema` and `Move` in TypeScript, `Move` in Lean, `Move` in Go, with the same fields
and rule as a 线段.

A part by level holds the levels 0 to its highest level with a record (The run), and a level a run does not hold,
above them, is empty.

### Consolidation (中枢)

`consolidationSchema` and `Consolidation` in TypeScript, `Consolidation` in Lean, `Consolidation` in Go.

| Field | Kind | Meaning |
|---|---|---|
| `level` | count | its level L |
| `start`, `end` | bar | its start and end merged bars |
| `confirmEnd`? | bar | the merged bar at which it was confirmed. Not set while it is under construction |
| `zg`, `zd` | price | its band, ZD to ZG |
| `gg`, `dd` | price | its range, DD to GG |

Rule: `start < end` and `dd ≤ zd ≤ zg ≤ gg`.

### The run

| Part | Holds |
|---|---|
| `klines` | its K-lines, market's: at least one, in the order of their times, no time twice, each one's `index` its place among them, from 0 |
| `merged` | its merged bars, each one's `mIndex` its place among them, from 0 |
| `fractals` | its 分型, strictly increasing by `mIndex` |
| `strokes` | its 笔, strictly increasing by `start` |
| `segments` | its 线段, by level: the array at L the 线段 of level L, from 0, every record's `level` L, each level strictly increasing by `start` |
| `moves` | its 走势, by level: the array at L the 走势 of level L, from 0, every record's `level` L, each level strictly increasing by `start` |
| `consolidations` | its 中枢, by level: the array at L the 中枢 of level L, from 0, every record's `level` L, each level strictly increasing by `start` |

Rules, every one checked: what the table says of each part; every position of every record below the number of
K-lines; every bar (a merged bar's and a 分型's `mIndex`, a line's `start`, `end` and `confirmEnd`, a consolidation's `start`, `end` and `confirmEnd`) below the number of merged bars; in `merged`, in `strokes` and in each level of `segments`, `moves` and
`consolidations`, at most one record with no `confirmEnd`, and if one, the last: the configuration still going on. A run
of confirmed records alone conforms; the one going on is allowed, not required.

A part by level, `segments`, `moves` or `consolidations`, ends with a level that is not empty: the levels it holds are 0
to its highest level with a record, a level below its highest may be empty, and a part with no record is `[]`. So one
run has one canonical text: `"moves": [[a]]` and `"moves": [[a], []]` would be one run, and the second is refused.

## Reading the records

A 分型 carries only `mIndex`, and a line only `start`, `end` and `confirmEnd`. Their kind, direction, extent and prices
are not fields: they are read from the merged bars, so that a consumer, a chart among them, needs the records and not the
algorithm. From the records alone:

- A merged bar's extreme is its `high` when `up` is true and its `low` when `up` is false: the price its `extremes` are
  the K-lines of.
- A 分型 at `mIndex` m is a top where merged bar m goes up and merged bar m + 1 goes down, and a bottom where merged bar
  m goes down and merged bar m + 1 goes up. Its price is merged bar m's extreme, at the K-line merged bar m's `index`.
- A line from the merged bar `start` to the merged bar `end` goes up when `end`'s extreme is above `start`'s, and down
  when it is below. Its high and low are the extremes of its two ends, the greater its high and the lesser its low, taken
  from those merged bars' `high`, `low` and `up`; it runs from the K-line merged bar `start`'s `index` to the K-line
  merged bar `end`'s `index`, whose times are its times (`timeAt`).
- A record with no `confirmEnd` is the one still going on: its `end` is where it stands at the run's last K-line.

## The JSON

A run crosses as one JSON object, its seven parts its names, each record an object of its fields, under the rules of
market's JSON (`../market/SPEC.md`, The JSON), how a number is written among them. Decoding refuses anything the
records do not allow: what market's JSON refuses, a name that is no field or part, a field missing that is not
optional, `null`, a value of another kind (a negative number or a fraction where a bar or a count is, a number where
a boolean is), and a broken rule.

The canonical text, which every form writes and the conformance check compares:

- `{` and a line break, then the parts in the order of the table above, each `"part": ` followed by its value,
  separated by `,` and a line break, then a line break, `}` and a line break;
- an array of records: `[]` when empty, else `[`, a record a line separated by `,` and a line break, then `]`; an array
  by level the same, each level's array in place of a record;
- a record: as market's (`../market/SPEC.md`, The JSON), its fields in the order of their names (ASCII), a field not
  set left out, no spaces; a number in its digits, a boolean `true` or `false`, an array of numbers `[`, its numbers
  separated by `,`, `]`.

## The Avro schemas

The records are also published as Avro schemas, for other languages and for messages on Kafka and Redpanda topics.
`avro/` has one file for each record: `MergedBar.avsc`, `Fractal.avsc`, `Line.avsc`, `Segment.avsc`, `Move.avsc`,
`Consolidation.avsc` and `Run.avsc`, all in the namespace `qi.chanlun.v1`. 笔 is `Line`. Each file is complete, with
every record it uses written out inside it: a run's K-line is market's (`../market/avro/`), written out as it is there,
in its namespace, `qi.market.v1`, which `ts/test/avro.test.ts` checks.

The files are generated from the Zod schemas by `make chanlun-avro`. `make check` fails if they no longer match the Zod
schemas or an Avro implementation cannot read them, and it runs every run vector through Avro's binary format and back.

| In the contract | In Avro |
|---|---|
| a whole number | `long` |
| a price, a quantity | `double` |
| a boolean | `boolean` |
| a record | `record` |
| an array | `array` |
| a part by level | an `array` of `array`s |
| a field that may be left out | a union of `null` and its type, `null` by default |

Fields keep the names they have in the records.

Avro's `long` holds every whole number in the contract, but a library's default may not. In JavaScript, `avsc`'s default long
refuses the contract's largest number, so a reader there
needs a long type of its own, as `ts/test/avro.test.ts` shows.

The schemas give the records' fields and types, not their rules. The rules are on this page, and the vectors break each
of them; a form that checks the rules reads the vectors alike. Avro's own JSON encoding also differs from the JSON above: it
writes a number in a union as `{"long": 3}`, and a field that is not set as `null`. A reader can use the schemas for its
types alone, and read and write the JSON above.

## The Protobuf description

`proto/chanlun.proto` (package `qi.chanlun.v1`) describes the same records as Protobuf messages: `MergedBar`,
`Fractal`, `Line`, `Segment`, `Move`, `Consolidation` and `Run`, with `SegmentList`, `MoveList` and
`ConsolidationList` for a part by level. A run's K-line is market's message, `qi.market.v1.KLine`, of `market.proto`
(`../market/proto/`), which it imports: `protoc` reads it with both folders on its path. It is generated from the Zod
schemas and the field numbers in `proto/fields.json` by `make chanlun-proto`. `make check` fails if it no longer
matches them or `protoc` cannot read it.

| In the contract | In Protobuf |
|---|---|
| a whole number | `uint64`, or `int64` where it may be below 0 |
| a price, a quantity | `double` |
| a boolean | `bool` |
| a record | its `message` |
| an array | `repeated` |
| a part by level | `repeated` of a message holding one level |
| a field that may be left out | `optional` |

A field's name is in snake_case, `m_index` for `mIndex`, and its JSON name is the record's own.

A field's number stays the same for good. A new field takes a number not used before, a field whose meaning changes takes
a new number and has its old number reserved, and a removed field has its number and name reserved in
`proto/fields.json`. A derived record uses its base's
numbers for the fields they share, which `ts/test/protobuf.test.ts` checks.

Like the Avro schemas, this gives fields and types, not rules. Protobuf's own JSON also differs from the JSON above: it
writes a 64-bit number as a text, leaves out a field at 0, false or an empty list unless the field is `optional`, and
writes a part by level as a list of `{"items": [...]}`.

## Why both

The records are published in both formats for the reasons market's are (`../market/SPEC.md`, Why both): Avro needs
no field numbers, and a Protobuf reader does not need the schema the data was written with. Both are generated from the
same Zod schemas, and `ts/test/protobuf.test.ts` checks that they hold the same fields.

## Versions

A change to the records is a new version of this contract, in its forms, its Avro schemas, its Protobuf description and the vectors
together; an implementation's output changing is not, until the contract does. Market's contract has versions of its
own (`../market/SPEC.md`, Versions): one that changes what a run holds is a version of this one too, a change to the
base's K-line a major one.
