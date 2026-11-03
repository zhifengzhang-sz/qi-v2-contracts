// 缠论's records (../SPEC.md, The records): the algorithm's records, of whatever implementation gives them, each a Zod
// schema. The algorithm is a chain, and so are its records: each step's output is the next step's input.
//
//   the K-line (klineSchema; a data source's, massiveKlineSchema)       the input, the bars as read, each complete
//   (a bar still going on: the ongoing K-line, ongoingKlineSchema, massiveOngoingKlineSchema, in no run)
//     → 包含 →  the merged bar (mergedBarSchema)
//     → 分型 →  the fractal, a top or a bottom at a merged bar (fractalSchema)
//     → 笔   →  the lowest level line of level 0 (strokeSchema, which is lineSchema)
//     → 线段 →  a line of level 0 (segmentSchema)
//     → 中枢 →  a consolidation of level 0 (consolidationSchema)
//     → 走势 →  the highest level line of level 0 (moveSchema)
//   the 走势 of level L (moveSchema)                                    the input of level L + 1
//     → 线段 →  a line of level L + 1 (segmentSchema)
//     → 中枢 →  a consolidation of level L + 1 (consolidationSchema)
//     → 走势 →  the highest level line of level L + 1 (moveSchema)
//
// A K-line's date is its begin time, milliseconds since 1970, UTC. Every configuration after 包含 is on merged bars, by
// their number (a merged bar's `mIndex`): a 分型 its merged bar, a line its start and end merged bars, a 中枢 its start
// and end merged bars. A price and a quantity are decimals. Whether an implementation's values are right by the lessons
// is not these contracts' to test: they say what a value is, not whether it is the lessons'.

import { z } from "zod";

// a time: milliseconds since 1970, UTC
const time = z.number().int().nonnegative();
// a K-line's position in the series
const position = z.number().int().nonnegative();
// a merged bar's number (its `mIndex`)
const bar = z.number().int().nonnegative();
// a decimal as the contract writes it: at most 6 digits after the point, at most 15 from the first that is not 0. A
// number with no more digits than that is given back as the same digits, which is how it is checked here.
export const decimal = (digits: string): boolean => {
  const m = /^-?(0|[1-9][0-9]*)(?:\.([0-9]*[1-9]))?$/.exec(digits);
  const [, whole = "", fraction = ""] = m ?? [];
  return m !== null && fraction.length <= 6 && `${whole}${fraction}`.replace(/^0+/, "").length <= 15;
};
const decimalMessage = "a decimal of at most 6 digits after the point and 15 from the first that is not 0";
// a price, a decimal
const price = z.number().refine((x) => decimal(String(x)), `a price ${decimalMessage}`);
// a quantity, a decimal as a price is, not negative
const quantity = z
  .number()
  .nonnegative()
  .refine((x) => decimal(String(x)), `a quantity ${decimalMessage}`);

// A K-line's rule, of the base and of every K-line derived from it
const withinRange = (k: {
  readonly open: number;
  readonly high: number;
  readonly low: number;
  readonly close: number;
}): boolean => k.low <= Math.min(k.open, k.close) && Math.max(k.open, k.close) <= k.high;
const withinRangeMessage = "a K-line's open and close within its low and high";

// The base contract of a K-line, 7 fields: each data source's contract derives from it by `.extend()` here, with the
// base's rule; a plain object for that (a schema ending in `.readonly().refine(...)` has no `.extend`).
const klineBase = z
  .object({
    // its place in the run, from 0
    index: position,
    // its begin time
    date: time,
    open: price,
    high: price,
    low: price,
    close: price,
    volume: quantity,
  })
  .strict();

// a K-line
export const klineSchema = klineBase.readonly().refine(withinRange, withinRangeMessage);

// Massive's K-line, 9 fields: the base, and `vw` and `n` of Massive's row; its `date` the row's `t`
const massiveKlineBase = klineBase.extend({
  vw: price,
  n: z.number().int().nonnegative(),
});
export const massiveKlineSchema = massiveKlineBase.readonly().refine(withinRange, withinRangeMessage);

// The ongoing K-line of a data source, defined once over the source's K-line, as the run is: its K-line's fields and
// rule, `index` the place it will take when complete, and `asOf`, when its values were last updated, not before its
// `date`. A bar still going on, in no run. (Zod's types do not reach a field through the generic shape, hence the casts.)
type Ongoing = KLine & { readonly asOf: number };
const ongoingOf = <S extends typeof klineBase.shape>(kline: z.ZodObject<S, z.core.$strict>) =>
  kline
    .extend({ asOf: time })
    .readonly()
    .refine((k) => withinRange(k as Ongoing), withinRangeMessage)
    .refine(
      (k) => (k as Ongoing).date <= (k as Ongoing).asOf,
      "an ongoing K-line's asOf not before its date",
    );
export const ongoingKlineSchema = ongoingOf(klineBase);
export const massiveOngoingKlineSchema = ongoingOf(massiveKlineBase);

// 包含's merged bar, number `mIndex`: from `start` to `end`, its first and last K-lines, up or down, its high and low;
// `extremes` the K-lines of its extreme, of its high when it goes up, of its low when it goes down, each from `start`
// to `end`, in ascending order, none twice; `index` one of `extremes`: the K-line that represents the merged bar. The
// contract does not say which one is chosen.
export const mergedBarSchema = z
  .object({
    index: position,
    mIndex: z.number().int().nonnegative(),
    up: z.boolean(),
    high: price,
    low: price,
    start: position,
    confirmStart: position.optional(),
    end: position,
    confirmEnd: position.optional(),
    extremes: z.array(position).min(1).readonly(),
  })
  .strict()
  .readonly()
  .refine(
    (m) => m.start <= m.end && m.low <= m.high,
    "a merged bar's first K-line not after its last, its low at most its high",
  )
  .refine((m) => m.extremes.includes(m.index), "a merged bar's index one of its extremes")
  .refine(
    (m) => m.extremes.every((p) => m.start <= p && p <= m.end),
    "a merged bar's extremes from its start to its end",
  )
  .refine(
    (m) => m.extremes.every((p, i) => i === 0 || (m.extremes[i - 1] ?? 0) < p),
    "a merged bar's extremes in ascending order, none twice",
  );

// 分型: its merged bar, `mIndex`.
export const fractalSchema = z
  .object({
    mIndex: bar,
  })
  .strict()
  .readonly();

// A line: from the merged bar `start` to the merged bar `end`, `confirmEnd` the merged bar at which it was confirmed.
// A plain object, so that 线段 and 走势 derive from it by `.extend()`, with the line's rule.
const lineBase = z
  .object({
    start: bar,
    end: bar,
    confirmEnd: bar,
  })
  .strict();
const lineRule = (l: { readonly start: number; readonly end: number }): boolean => l.start < l.end;
const lineMessage = "a line from a merged bar to a later one";
export const lineSchema = lineBase.readonly().refine(lineRule, lineMessage);

// 笔: a line
export const strokeSchema = lineSchema;

// 线段 of level L
export const segmentSchema = lineBase
  .extend({ level: z.number().int().nonnegative() })
  .readonly()
  .refine(lineRule, lineMessage);

// 走势 of level L
export const moveSchema = lineBase
  .extend({ level: z.number().int().nonnegative() })
  .readonly()
  .refine(lineRule, lineMessage);

// 中枢: of level L, from the merged bar `start` to the merged bar `end`, `confirmEnd` the merged bar at which it was
// confirmed, not set while it is under construction; its band ZD to ZG within its range DD to GG.
export const consolidationSchema = z
  .object({
    level: z.number().int().nonnegative(),
    start: bar,
    end: bar,
    confirmEnd: bar.optional(),
    zg: price,
    zd: price,
    gg: price,
    dd: price,
  })
  .strict()
  .readonly()
  .refine(
    (c) => c.start < c.end && c.dd <= c.zd && c.zd <= c.zg && c.zg <= c.gg,
    "a 中枢 from a merged bar to a later one, its band ZD to ZG within its range DD to GG",
  );

// a run's K-lines: at least one, their times strictly increasing
const inOrder = (ks: readonly { readonly date: number }[]): boolean =>
  ks.every((k, i) => i === 0 || (ks[i - 1]?.date ?? 0) < k.date);
const inOrderMessage = "a run's K-lines in the order of their times, no time twice";
export const klinesSchema = z.array(klineSchema).min(1).readonly().refine(inOrder, inOrderMessage);
export const massiveKlinesSchema = z
  .array(massiveKlineSchema)
  .min(1)
  .readonly()
  .refine(inOrder, inOrderMessage);

export type KLine = z.output<typeof klineSchema>;
export type MassiveKLine = z.output<typeof massiveKlineSchema>;
export type OngoingKLine = z.output<typeof ongoingKlineSchema>;
export type MassiveOngoingKLine = z.output<typeof massiveOngoingKlineSchema>;
export type MergedBar = z.output<typeof mergedBarSchema>;
export type Fractal = z.output<typeof fractalSchema>;
export type Line = z.output<typeof lineSchema>;
export type Stroke = Line;
export type Segment = z.output<typeof segmentSchema>;
export type Move = z.output<typeof moveSchema>;
export type Consolidation = z.output<typeof consolidationSchema>;
