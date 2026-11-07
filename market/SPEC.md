# The market data contract: the K-lines

Version 1.1.0. The records of the market data, the K-lines, of whatever source gives them, and how they cross from one
project to another as JSON. It is written in TypeScript (`ts/`, Zod schemas); Lean (`lean/`, structures with a JSON
codec) is a second form of it, and Go (`go/`, one module of the standard library only, its types made from the Zod
schemas, its rules and its JSON written by hand) a third, whose types and functions have the TypeScript's names,
capitalized (`KLine`, `DecodeOngoingKLine`, `EncodeOngoingKLine`); its Avro schemas (`avro/`) and Protobuf description
(`proto/market.proto`) are made from the TypeScript, for every other language and for a schema registry. The vectors
(`vectors/`) are what every form must read alike.

A K-line is one bar of a series of them, at its place in the series, its `index`. A contract derived from this one
takes its units and its JSON, refers to its K-lines by their positions, and holds none: this contract says what a
K-line is; that one what is made from them.

## Units

| Kind | What it is |
|---|---|
| time | milliseconds since 1970-01-01 00:00:00 UTC, a whole number, not negative |
| position | the position of a K-line in its series, from 0: a K-line's `index` |
| price | a decimal: at most 6 digits after the point, and at most 15 digits from the first that is not 0 |
| quantity | a decimal as a price is, not negative |

A time and a position are whole numbers from 0 to 2⁵³ − 1, which every JSON reader holds exactly; a price and a
quantity are decimals as above, which every JSON reader gives back as the same digits.

The six digits after the point bound a quantity as they bound a price. Some venues give a volume with more digits;
such a volume is refused, and the producer must bring it within the bound before it crosses.

## The records

Each record has exactly its fields: none other, none missing.

### K-line

| Field | Kind | Meaning |
|---|---|---|
| `index` | position | its place in its series, from 0 |
| `date` | time | its begin time |
| `open`, `high`, `low`, `close` | price | its prices |
| `volume` | quantity | its volume |

Rule: `low ≤ min(open, close)` and `max(open, close) ≤ high`.

A K-line is a complete bar. A bar still going on is an ongoing K-line, a record of its own, in no series yet.

This is the base contract, 7 fields. A K-line of a source with fields of its own is not this contract's: such a
record is its taker's, the base's fields and rule and its own, written under the rules of The JSON, read and written
by the means each form gives for a record of a taker's own (The JSON), and held to this contract's vectors for the
base.

#### The ongoing K-line

The ongoing K-line has its K-line's fields and rule, `index` the place it will take when complete, and:

| Field | Kind | Meaning |
|---|---|---|
| `asOf` | time | when its values were last updated |

Rule: `date ≤ asOf`.

It is the base's: `OngoingKLine`, in TypeScript `ongoingKlineSchema`, in Lean `OngoingOf KLine`, the ongoing K-line
made over a K-line (`OngoingOf K`, which a taker's own K-line takes too), in Go `OngoingKLine`. It crosses as one JSON
object of its fields, under the rules of The JSON, and its canonical text is its record, as there, then a line break.
Each form decodes it with `decodeOngoingKLine`, and writes it with `encodeOngoingKLine` (in Go, `DecodeOngoingKLine`
and `EncodeOngoingKLine`).

## The JSON

A record crosses as one JSON object of its fields. A number is written in digits: an optional `-`, then `0` or a digit
not `0` and more digits, then, for a price or a quantity, optionally `.` and digits, the last not `0`; no exponent, so
that every form reads the same number from the same text. Decoding refuses anything the records do not allow: a number
written otherwise or past the bound, a name that is no field, a name twice in one object, text not UTF-8, a field
missing, `null`, a value of another kind (a negative number where a time, a position or a quantity is, a fraction where
a time or a position is), and a broken rule.

The canonical text, which every form writes and the conformance check compares:

- a record: its fields in the order of their names (ASCII), no spaces; a number in its digits.

A contract built on this one writes its own records under these rules, and its own text around them, and so does a
taker of a record of its own, a source's K-line with fields of its own among them (K-line); each form gives it the
reading and the writing of a record for that: in TypeScript `decodeAs(schema, text)` and `encodeRecord(r)`, with the
schemas of the units (`positionSchema`, `priceSchema`), in Lean `Market.parsed`, `Market.strict` and `Market.record`,
with `KLineOf` and `OngoingOf` for a K-line of its own and its ongoing K-line. The Go form gives its records' types,
their rules (`Check`) and a K-line's base (`Base`), and `Decimal` with `DecimalOf` and `AppendTo`, by which such a
contract or taker reads and writes its own text of them.

## The Avro schemas

The records are also published as Avro schemas, for other languages and for messages on Kafka and Redpanda topics.
`avro/` has one file for each record: `KLine.avsc` and `OngoingKLine.avsc`, both in the namespace `qi.market.v1`. Each
file is complete, with every record it uses written out inside it.

The files are generated from the Zod schemas by `make market-avro`. `make check` fails if they no longer match the Zod
schemas or an Avro implementation cannot read them, and it runs each ongoing K-line vector through Avro's binary format
and back.

| In the contract | In Avro |
|---|---|
| a whole number | `long` |
| a price, a quantity | `double` |
| a record | `record` |

Fields keep the names they have in the records. Chanlun 2.0.0 to 2.3.0 published the same records, field for field, in
the namespace `qi.chanlun.v1`. An Avro reader resolves a record by its full name, so a schema of one namespace does not
read data written with the other unless the reader's schema lists the other full name as an alias, and a schema
registry sees each as a schema of its own.

Avro's `long` holds every whole number in the contract, but a library's default may not. In JavaScript, `avsc`'s default long
refuses the contract's largest number, so a reader there
needs a long type of its own, as `ts/test/avro.test.ts` shows.

The schemas give the records' fields and types, not their rules. The rules are on this page, and the vectors break each
of them; a form that checks the rules reads the vectors alike. Avro's own JSON encoding also differs from the JSON above: it
writes a number in a union as `{"long": 3}`, and a field that is not set as `null`. A reader can use the schemas for its
types alone, and read and write the JSON above.

## The Protobuf description

`proto/market.proto` (package `qi.market.v1`) describes the same records as Protobuf messages: `KLine` and
`OngoingKLine`. It is generated from the Zod schemas and the field numbers in `proto/fields.json` by
`make market-proto`. `make check` fails if it no longer matches them or `protoc` cannot read it.

| In the contract | In Protobuf |
|---|---|
| a whole number | `uint64`, or `int64` where it may be below 0 |
| a price, a quantity | `double` |
| a record | its `message` |

A field's name is in snake_case, `as_of` for `asOf`, and its JSON name is the record's own.

A field's number stays the same for good. A new field takes a number not used before, a field whose meaning changes takes
a new number and has its old number reserved, and a removed field has its number and name reserved in
`proto/fields.json`. A derived record uses its base's
numbers for the fields they share, which `ts/test/protobuf.test.ts` checks. The numbers each message has and reserves
are those it had in the package `qi.chanlun.v1`, from chanlun 2.0.0 to 2.3.0, so that its bytes are the same; its full
name is new (`qi.market.v1.KLine`, where it was `qi.chanlun.v1.KLine`), which a reader sees where it names the type,
in an `Any`'s type URL or by reflection.

Like the Avro schemas, this gives fields and types, not rules. Protobuf's own JSON also differs from the JSON above: it
writes a 64-bit number as a text, and leaves out a field at 0.

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
together; a source's output changing is not, until the contract does. A change to the base's records is a major one;
it changes a contract derived from this one only where what that one takes, a unit or the JSON, changes.
