# 缠论's contract: the algorithm's records

Version 1.0.0. The records the algorithm of 缠论 gives over a run of bars, of whatever implementation gives them, and
how they cross from one project to another as JSON. Two forms state it: TypeScript (`ts/`, Zod schemas) and Lean
(`lean/`, structures with a JSON codec). The vectors (`vectors/`) are what both must read alike.

The algorithm is a chain, and so are its records: each step's output is the next step's input.

```
the K-line                the bars, as read
  → 包含 →  the merged bar
  → 分型 →  the fractal: a top or a bottom at a merged bar
  → 笔   →  a line of level −2
  → 线段 →  a line of level −1
  → 走势 →  a line of level L, the 线段 of level L + 1; and 中枢 of level L, made of the 线段 at level 0 of the
             走势 of level L − 1 above it
```

Whether an implementation's values are right by the lessons is not the contract's to say: it says what a value is.

## Units

| Kind | What it is |
|---|---|
| time | seconds since 1970-01-01 00:00:00 UTC, a whole number, not negative |
| position | the position of a K-line in the run, from 0: every date but a K-line's own `date` is one |
| bar | the number of a merged bar (its `mno`), from 0 |
| price | a whole number: the price times the data's scale (a power of ten the data gives, not the contract) |
| flag | `stored`: 1 what the algorithm has settled, 0 what it has not yet |
| count | a whole number, not negative |
| text | a string of printable ASCII (U+0020 to U+007E), kept as it is |

Every number is a whole number from −(2⁵³ − 1) to 2⁵³ − 1, the largest every JSON reader holds exactly; a time, a
position, a bar and a count are not negative.

A date that may be not set (`confirm…`) is left out when it is not set; it is never `null`. Every position is a
K-line's of the run, and every bar a merged bar's (The run), so the time of any date is the time of the K-line at its
position (`timeAt` in TypeScript, `Run.timeAt` in Lean): no other time is kept.

## The records

Each record has exactly its fields: none other, none missing but an optional one (marked ?).

### K-line

| Field | Kind | Meaning |
|---|---|---|
| `rno` | count | its number in the run as the algorithm counts it |
| `date` | time | its time |
| `up` | boolean | its direction as the algorithm reads it |
| `open`, `high`, `low`, `close` | price | its prices |
| `volume` | count | its volume |
| `confirmRno` | count | the algorithm's number of the K-line that confirmed it |
| `confirmDate`? | position | the K-line that confirmed it |
| `stored` | flag | |

Rule: `low ≤ min(open, close)` and `max(open, close) ≤ high`.

### Merged bar (包含)

| Field | Kind | Meaning |
|---|---|---|
| `rno` | count | the algorithm's position of it |
| `mno` | bar | its number |
| `up` | boolean | its direction |
| `high`, `low` | price | its high and low |
| `startDate`, `endDate` | position | its first and last K-lines |
| `confirmStartDate`?, `confirmEndDate`? | position | the K-lines that confirmed its start and its end |
| `stored` | flag | |

Rule: `startDate ≤ endDate` and `low ≤ high`.

### Fractal (分型)

| Field | Kind | Meaning |
|---|---|---|
| `rno` | count | the algorithm's position of it |
| `date` | position | its K-line, as the algorithm dates it |
| `mno` | bar | its merged bar |
| `ding` | boolean | a top (true) or a bottom |
| `turningpoint` | boolean | a turning point, as the algorithm reads it |
| `high`, `low` | price | its high and low |
| `confirmStartDate`?, `confirmEndDate`?, `confirmTurningPointDate`? | position | the K-lines that confirmed it |
| `stored` | flag | |

Rule: `low ≤ high`.

### Line (笔, 线段, 走势)

`strokeSchema` and `Stroke` in TypeScript, for every level; `Line` in Lean.


| Field | Kind | Meaning |
|---|---|---|
| `level` | integer, at least −2 | −2 a 笔, −1 a 线段, L ≥ 0 a 走势 of level L |
| `isUp` | boolean | up (from its low to its high) or down (from its high to its low) |
| `startDate`, `endDate` | position | its start and end |
| `confirmStartDate`?, `confirmEndDate`? | position | the K-lines that confirmed its start and its end |
| `high`, `low` | price | its high and low |
| `startRno`, `endRno` | count | the algorithm's numbers of its start and end |
| `stored` | flag | |
| `startBar`, `endBar` | bar | its start and end merged bars |

Rule: `startBar < endBar` and `low < high`.

### 中枢

| Field | Kind | Meaning |
|---|---|---|
| `level` | count | its level L |
| `startRno`, `endRno` | count | the algorithm's numbers of its start and end |
| `startDate`, `endDate` | position | its start and end |
| `entrance`, `exit` | boolean | the way it was entered and left, true upward |
| `zg`, `zd` | price | its band, ZD to ZG |
| `gg`, `dd` | price | its range, DD to GG |
| `ggRno`, `ddRno` | count | the algorithm's numbers of GG and DD |
| `ggDate`, `ddDate` | position | GG and DD |
| `d`, `g` | price | as the algorithm gives them |
| `buy`, `tp0`, `tp0Rno`, `tp1`, `tp1Rno`, `tp2`, `tp2Rno` | text | as the algorithm gives them |
| `confirmStartDate`?, `confirmEndDate`? | position | the K-lines that confirmed its start and its end |
| `stored` | flag | |
| `startBar`, `endBar`, `ggBar`, `ddBar` | bar | its start, end, GG and DD merged bars |

Rule: `startBar ≤ endBar` and `dd ≤ zd ≤ zg ≤ gg`.

### The run

| Part | Holds |
|---|---|
| `klines` | its K-lines: at least one, in the order of their times, no time twice |
| `merged` | its merged bars, each one's `mno` its place among them, from 0 |
| `fractals` | its 分型 |
| `strokes` | its 笔: lines of level −2 |
| `segments` | its 线段: lines of level −1 |
| `trends` | its 走势, by level: the array at L the lines of level L, from 0 |
| `centres` | its 中枢, by level: the array at L the 中枢 of level L, from 0 |

Rules, every one checked: what the table says of each part; every position of every record below the number of
K-lines; every bar (`mno`, `startBar`, `endBar`, `ggBar`, `ddBar`) below the number of merged bars.

## The JSON

A run crosses as one JSON object, its seven parts its names, each record an object of its fields. A number is written
as a whole number, digits only: an optional `-`, then `0` or a digit not `0` and at most 15 more; no fraction, no
exponent, so that both forms read the same number from the same text. Decoding refuses anything the records do not
allow: a number written otherwise or past the bound, a name that is no field or part, a field missing that is not
optional, `null`, a value of another kind (a negative number where a time, a position, a bar or a count is, a
number where a boolean or a text is, a text not printable ASCII), and a broken rule.

The canonical text, which both forms write and the conformance check compares:

- `{` and a line break, then the parts in the order of the table above, each `"part": ` followed by its value,
  separated by `,` and a line break, then a line break, `}` and a line break;
- an array of records: `[]` when empty, else `[`, a record a line separated by `,` and a line break, then `]`; an array
  by level the same, each level's array in place of a record;
- a record: its fields in the order of their names (ASCII), a field not set left out, no spaces; a number in its
  digits, a boolean `true` or `false`, a text in `"` with `"` and `\` escaped by `\`, nothing else escaped.

## Versions

A change to the records is a new version of this contract, in both forms and the vectors together; an
implementation's output changing is not, until the contract does.
