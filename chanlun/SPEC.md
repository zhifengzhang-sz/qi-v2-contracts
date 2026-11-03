# 缠论's contract: the algorithm's records

Version 2.0.0. The records the algorithm of 缠论 gives over a run of bars, of whatever implementation gives them, and
how they cross from one project to another as JSON. It is written in TypeScript (`ts/`, Zod schemas); Lean (`lean/`,
structures with a JSON codec) is a second form of it; its Avro schemas (`avro/`) and Protobuf description
(`proto/chanlun.proto`) are made from the TypeScript, for every other language and for a schema registry. The vectors (`vectors/`) are what every form must read alike.

The algorithm is a chain, and so are its records: each step's output is the next step's input.

```
the K-line                the bars, as read
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
| time | milliseconds since 1970-01-01 00:00:00 UTC, a whole number, not negative |
| position | the position of a K-line in the run, from 0: a K-line's `index` and a merged bar's `index`, `start`, `end`, `confirmStart`, `confirmEnd` and each of its `extremes` |
| bar | the number of a merged bar (its `mIndex`, a 分型's `mIndex`, a line's `start`, `end` and `confirmEnd`, a consolidation's `start`, `end` and `confirmEnd`), from 0 |
| price | a decimal: at most 6 digits after the point, and at most 15 digits from the first that is not 0 |
| quantity | a decimal as a price is, not negative |
| count | a whole number, not negative |

A time, a position, a bar and a count are whole numbers from 0 to 2⁵³ − 1, which every JSON reader holds
exactly; a price and a quantity are decimals as above, which every JSON reader gives back as the same digits.

A field that may be not set (marked ?) is left out when it is not set; it is never `null`. Every position is a
K-line's of the run, and every bar a merged bar's (The run), so the time of any position is the time of the K-line at
it (`timeAt` in TypeScript, `RunOf.timeAt` in Lean): no other time is kept.

## The records

Each record has exactly its fields: none other, none missing but an optional one (marked ?).

### K-line

| Field | Kind | Meaning |
|---|---|---|
| `index` | position | its place in the run, from 0 |
| `date` | time | its begin time |
| `open`, `high`, `low`, `close` | price | its prices |
| `volume` | quantity | its volume |

Rule: `low ≤ min(open, close)` and `max(open, close) ≤ high`.

A K-line is a complete bar. A bar still going on is an ongoing K-line, a record of its own, in no run.

This is the base contract, 7 fields. Each data source has a contract of its own, derived from the base: the base's
fields and its rule, and the source's own fields, in every form, with a run that takes it (Massive's run, under The
run).

#### Massive's K-line

`massiveKlineSchema` and `MassiveKLine` in TypeScript, `MassiveKLine` in Lean, 9 fields: the base's, and from Massive's
row:

| Field | Kind | Meaning |
|---|---|---|
| `vw` | price | its volume-weighted average price |
| `n` | count | its number of trades |

Its `date` is the row's `t`.

#### The ongoing K-line

The ongoing K-line of a data source has its K-line's fields and rule, `index` the place it will take when complete,
and:

| Field | Kind | Meaning |
|---|---|---|
| `asOf` | time | when its values were last updated |

Rule: `date ≤ asOf`.

It is defined once over any source's K-line, as the run is, so that a source's own fields are defined only in its
K-line: `OngoingKLine` of the base and `MassiveOngoingKLine` of Massive's. In TypeScript they are `ongoingKlineSchema`
and `massiveOngoingKlineSchema`; in Lean, `OngoingOf K`. It crosses as one JSON object of its fields, under the rules
of The JSON, and its canonical text is its record, as there, then a line break. Each form decodes it with
`decodeOngoingKLine` and `decodeMassiveOngoingKLine`, and writes it with `encodeOngoingKLine`.

### Merged bar (包含)

| Field | Kind | Meaning |
|---|---|---|
| `index` | position | one of `extremes`: the K-line that represents the merged bar. The contract does not say which one is chosen |
| `mIndex` | bar | its number |
| `up` | boolean | its direction |
| `high`, `low` | price | its high and low |
| `start`, `end` | position | its first and last K-lines |
| `confirmStart`?, `confirmEnd`? | position | the K-lines that confirmed its start and its end |
| `extremes` | array of position | the K-lines of its extreme, at least one: of its high when it goes up, of its low when it goes down |

Rule: `start ≤ end`, `low ≤ high`, `extremes` holds at least one K-line, every entry of `extremes` is from `start` to
`end`, in ascending order, with none twice, and `index` is in `extremes`.

### Fractal (分型)

| Field | Kind | Meaning |
|---|---|---|
| `mIndex` | bar | its index in the merged-bar sequence |

### Line (笔, 线段, 走势)

`lineSchema` and `Line` in TypeScript, `Line` in Lean.

| Field | Kind | Meaning |
|---|---|---|
| `start`, `end` | bar | its start and end merged bars |
| `confirmEnd` | bar | the merged bar at which it was confirmed |

Rule: `start < end`.

A 笔 is a line: `strokeSchema` and `Stroke` in TypeScript, `Stroke` in Lean.

A 线段 is a line of level L: `segmentSchema` and `Segment` in TypeScript, `Segment` in Lean. It has the line's fields
and rule, and:

| Field | Kind | Meaning |
|---|---|---|
| `level` | count | its level L |

A 走势 is a line of level L: `moveSchema` and `Move` in TypeScript, `Move` in Lean, with the same fields and rule as a
线段.

A run holds every level.

### Consolidation (中枢)

`consolidationSchema` and `Consolidation` in TypeScript, `Consolidation` in Lean.

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
| `klines` | its K-lines: at least one, in the order of their times, no time twice, each one's `index` its place among them, from 0 |
| `merged` | its merged bars, each one's `mIndex` its place among them, from 0 |
| `fractals` | its 分型, strictly increasing by `mIndex` |
| `strokes` | its 笔, strictly increasing by `start` |
| `segments` | its 线段, by level: the array at L the 线段 of level L, from 0, every record's `level` L, each level strictly increasing by `start` |
| `moves` | its 走势, by level: the array at L the 走势 of level L, from 0, every record's `level` L, each level strictly increasing by `start` |
| `consolidations` | its 中枢, by level: the array at L the 中枢 of level L, from 0, every record's `level` L, each level strictly increasing by `start` |

Rules, every one checked: what the table says of each part; every position of every record below the number of
K-lines; every bar (a merged bar's and a 分型's `mIndex`, a line's `start`, `end` and `confirmEnd`, a consolidation's `start`, `end` and `confirmEnd`) below the number of merged bars.

Massive's run is a run whose `klines` are Massive's K-lines, under the same rules: `massiveRunSchema` and
`decodeMassiveRun` in TypeScript, `MassiveRun` and `decodeMassiveRun` in Lean.

## The JSON

A run crosses as one JSON object, its seven parts its names, each record an object of its fields. A number is written
in digits: an optional `-`, then `0` or a digit not `0` and more digits, then, for a price or a quantity,
optionally `.` and digits, the last not `0`; no exponent, so that both forms read the same number from the same text.
Decoding refuses anything the records do not allow: a number written otherwise or past the bound, a name that is no
field or part, a name twice in one object, text not UTF-8, a field missing that is not optional, `null`, a value of
another kind (a negative number where a time, a position, a bar, a count or a quantity is, a fraction where a time, a
position, a bar or a count is, a number where a boolean is), and a broken rule.

The canonical text, which both forms write and the conformance check compares:

- `{` and a line break, then the parts in the order of the table above, each `"part": ` followed by its value,
  separated by `,` and a line break, then a line break, `}` and a line break;
- an array of records: `[]` when empty, else `[`, a record a line separated by `,` and a line break, then `]`; an array
  by level the same, each level's array in place of a record;
- a record: its fields in the order of their names (ASCII), a field not set left out, no spaces; a number in its
  digits, a boolean `true` or `false`, an array of numbers `[`, its numbers separated by `,`, `]`.

## The Avro schemas

The records are also published as Avro schemas, for other languages and for messages on Kafka and Redpanda topics.
`avro/` has one file for each record: `KLine.avsc`, `MassiveKLine.avsc`, `OngoingKLine.avsc`, `MassiveOngoingKLine.avsc`, `MergedBar.avsc`, `Fractal.avsc`, `Line.avsc`,
`Segment.avsc`, `Move.avsc`, `Consolidation.avsc`, `Run.avsc` and `MassiveRun.avsc`, all in the namespace `qi.chanlun.v1`. 笔 is `Line`. Each file
is complete, with every record it uses written out inside it.

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

The schemas give the records' fields and types, not their rules. The rules are on this page: a reader in any language
must check them itself, and must read the vectors alike. Avro's own JSON encoding also differs from the JSON above: it
writes a number in a union as `{"long": 3}`, and a field that is not set as `null`. A reader can use the schemas for its
types alone, and read and write the JSON above.

## The Protobuf description

`proto/chanlun.proto` (package `qi.chanlun.v1`) describes the same records as Protobuf messages: `KLine`, `MassiveKLine`,
`OngoingKLine`, `MassiveOngoingKLine`, `MergedBar`, `Fractal`, `Line`, `Segment`, `Move`, `Consolidation`, `Run` and `MassiveRun`, with `SegmentList`, `MoveList` and `ConsolidationList` for a part by level. It is
generated from the Zod schemas and the field numbers in `proto/fields.json` by `make chanlun-proto`. `make check` fails if
it no longer matches them or `protoc` cannot read it.

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

The records are published in both formats because each has what the other lacks: Avro needs no field numbers, and a
Protobuf reader does not need the schema the data was written with. Both are generated from the same Zod schemas, and
`ts/test/protobuf.test.ts` checks that they hold the same fields.

| | Avro | Protobuf |
|---|---|---|
| A field is identified by | its name, when read | a number |
| Numbers to keep by hand | none | one for each field, for good |
| Read data without the schema it was written with | no | yes |
| Rename a field after a release | a reader refuses old data for a required field and reads an optional one as not set, unless its schema lists an alias | the binary bytes do not change |
| Add a required field after a release | a new reader refuses old data | old data still parses, the field reading as 0 |
| Accepted by [Redpanda's Schema Registry](https://docs.redpanda.com/current/manage/schema-reg/schema-reg-overview/) | yes | yes |

An Avro reader needs the schema because the bytes hold neither names nor numbers. Without it, data can come back wrong with
no error: if a writer's schema has `open` and `high` in the other order, a reader using only its own schema gets them
swapped. With Redpanda's Schema Registry, the producer's serializer puts the schema's ID at the front of each message, and
a reader fetches the schema by that ID. The broker does not add the ID and, by default, does not check it, so a producer
that skips the serializer leaves Avro readers without the schema.

## Versions

A change to the records is a new version of this contract, in its forms, its Avro schemas, its Protobuf description and the vectors
together; an implementation's output changing is not, until the contract does.
