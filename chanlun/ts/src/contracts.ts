// 缠论's records (../SPEC.md, The records): the algorithm's records, of whatever implementation gives them, each a Zod
// schema. The algorithm is a chain, and so are its records: each step's output is the next step's input.
//
//   the K-line (klineSchema)       the input, the bars as read
//     → 包含 →  the merged bar (mergedBarSchema)
//     → 分型 →  the fractal, a top or a bottom at a merged bar (fractalSchema)
//     → 笔   →  a line of level −2 (strokeSchema)
//     → 线段 →  a line of level −1 (strokeSchema)
//     → 走势 →  a line of level L, the 线段 of level L + 1 (strokeSchema); and 中枢 of level L (centreSchema), made of
//              the 线段 at level 0, of the 走势 of level L − 1 above it
//
// A K-line's date is its time, seconds since 1970, UTC; every other date is the position of its K-line in the run,
// from 0, absent where not set. Every configuration after 包含 is on merged bars, by their number (`mno`): a 分型 its
// merged bar, a line its start and end merged bars, a 中枢 its start, end, GG and DD merged bars. A price is a whole
// number, the price times the data's scale. Whether an implementation's values are right by the lessons is not these
// contracts' to test: they say what a value is, not whether it is the lessons'.

import { z } from "zod";

// a K-line's position in the series
const position = z.number().int().nonnegative();
// a merged bar's number (`mno`)
const bar = z.number().int().nonnegative();
// a price, a whole number: the price times the data's scale
const price = z.number().int();
// `stored`: 1 what the algorithm has settled, 0 what it has not yet
const stored = z.union([z.literal(0), z.literal(1)]);

// a K-line
export const klineSchema = z
  .object({
    rno: z.number().int().nonnegative(),
    // its time, seconds since 1970, UTC
    date: z.number().int().nonnegative(),
    up: z.boolean(),
    open: price,
    high: price,
    low: price,
    close: price,
    volume: z.number().int().nonnegative(),
    confirmRno: z.number().int().nonnegative(),
    confirmDate: position.optional(),
    stored,
  })
  .strict()
  .readonly()
  .refine(
    (k) => k.low <= Math.min(k.open, k.close) && Math.max(k.open, k.close) <= k.high,
    "a K-line's open and close within its low and high",
  );

// 包含's merged bar, number `mno`: from `startDate` to `endDate`, its first and last K-lines, up or down, its high and
// low; `rno` the algorithm's position of it.
export const mergedBarSchema = z
  .object({
    rno: z.number().int().nonnegative(),
    mno: z.number().int().nonnegative(),
    up: z.boolean(),
    high: price,
    low: price,
    startDate: position,
    confirmStartDate: position.optional(),
    endDate: position,
    confirmEndDate: position.optional(),
    stored,
  })
  .strict()
  .readonly()
  .refine(
    (m) => m.startDate <= m.endDate && m.low <= m.high,
    "a merged bar's first K-line not after its last, its low at most its high",
  );

// 分型: a top (`ding`) or a bottom at the merged bar `mno`, dated by the algorithm at `date`.
export const fractalSchema = z
  .object({
    rno: z.number().int().nonnegative(),
    date: position,
    mno: z.number().int().nonnegative(),
    ding: z.boolean(),
    turningpoint: z.boolean(),
    high: price,
    low: price,
    confirmStartDate: position.optional(),
    confirmEndDate: position.optional(),
    confirmTurningPointDate: position.optional(),
    stored,
  })
  .strict()
  .readonly()
  .refine((f) => f.low <= f.high, "a 分型's low at most its high");

// A line of the structure: its level as the algorithm numbers it (−2 a 笔, −1 a 线段, L a 走势 of level L, which is a
// 线段 of level L + 1), up (`isUp`) or down, from the merged bar `startBar` to the merged bar `endBar` (the algorithm's
// dates `startDate` and `endDate` beside), from its low to its high when up, from its high to its low when down.
export const strokeSchema = z
  .object({
    level: z.number().int().min(-2),
    isUp: z.boolean(),
    startDate: position,
    confirmStartDate: position.optional(),
    endDate: position,
    confirmEndDate: position.optional(),
    high: price,
    low: price,
    startRno: z.number().int().nonnegative(),
    endRno: z.number().int().nonnegative(),
    stored,
    startBar: bar,
    endBar: bar,
  })
  .strict()
  .readonly()
  .refine(
    (b) => b.startBar < b.endBar && b.low < b.high,
    "a line from a merged bar to a later one, its low below its high",
  );

// 中枢: of level L (made of the 线段 at level 0, of the 走势 of level L − 1 above it), from the merged bar `startBar` to
// the merged bar `endBar`, its band ZD to ZG within its range DD to GG (at the merged bars `ggBar` and `ddBar`); the
// algorithm's dates beside (`startDate`, `endDate`, `ggDate`, `ddDate`); the way it was entered and left (`entrance`,
// `exit`, true upward); the algorithm's `buy` to `tp2Rno` kept as their text.
// a text: printable ASCII (U+0020 to U+007E), so that both forms read and write it alike
const text = z.string().regex(/^[\x20-\x7e]*$/, "a text of printable ASCII");
export const centreSchema = z
  .object({
    level: z.number().int().nonnegative(),
    startRno: z.number().int().nonnegative(),
    startDate: position,
    endRno: z.number().int().nonnegative(),
    endDate: position,
    entrance: z.boolean(),
    exit: z.boolean(),
    zg: price,
    zd: price,
    gg: price,
    ggRno: z.number().int().nonnegative(),
    ggDate: position,
    dd: price,
    ddRno: z.number().int().nonnegative(),
    ddDate: position,
    d: price,
    g: price,
    buy: text,
    tp0: text,
    tp0Rno: text,
    tp1: text,
    tp1Rno: text,
    tp2: text,
    tp2Rno: text,
    confirmStartDate: position.optional(),
    confirmEndDate: position.optional(),
    stored,
    startBar: bar,
    endBar: bar,
    ggBar: bar,
    ddBar: bar,
  })
  .strict()
  .readonly()
  .refine(
    (c) => c.startBar <= c.endBar && c.dd <= c.zd && c.zd <= c.zg && c.zg <= c.gg,
    "a 中枢 from a merged bar to one not before it, its band ZD to ZG within its range DD to GG",
  );

// a run's K-lines: at least one, their times strictly increasing
export const klinesSchema = z
  .array(klineSchema)
  .min(1)
  .readonly()
  .refine(
    (ks) => ks.every((k, i) => i === 0 || (ks[i - 1]?.date ?? 0) < k.date),
    "a run's K-lines in the order of their times, no time twice",
  );

export type KLine = z.output<typeof klineSchema>;
export type MergedBar = z.output<typeof mergedBarSchema>;
export type Fractal = z.output<typeof fractalSchema>;
export type Stroke = z.output<typeof strokeSchema>;
export type Centre = z.output<typeof centreSchema>;
