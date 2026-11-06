// 缠论's records (../SPEC.md, The records): the algorithm's records, of whatever implementation gives them, each a Zod
// schema. The algorithm is a chain, and so are its records: each step's output is the next step's input.
//
//   the K-line (market's klineSchema; a data source's, massiveKlineSchema)  the input, the bars as read, each complete
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
// The K-line is market's (@qi/market, ../../market/SPEC.md), and so are the units it shares with these records: a
// position is a K-line's place in the run, and a price is a decimal. Every configuration after 包含 is on merged bars,
// by their number (a merged bar's `mIndex`): a 分型 its merged bar, a line its start and end merged bars, a 中枢 its
// start and end merged bars. A configuration still going on, a merged bar still merging, a line not yet ended, a 中枢
// under construction, has no `confirmEnd`: one rule for the three, and in a run at most one record of a part, or of a
// level, is going on, the last (codec.ts). Whether an implementation's values are right by the lessons is not these
// contracts' to test: they say what a value is, not whether it is the lessons'.

import {
  klineSchema,
  massiveKlineSchema,
  positionSchema as position,
  priceSchema as price,
} from "@qi/market";
import { z } from "zod";

// a merged bar's number (its `mIndex`)
const bar = z.number().int().nonnegative();

// 包含's merged bar, number `mIndex`: from `start` to `end`, its first and last K-lines, up or down, its high and low;
// `extremes` the K-lines of its extreme, of its high when it goes up, of its low when it goes down, each from `start`
// to `end`, in ascending order, none twice; `index` one of `extremes`: the K-line that represents the merged bar. The
// contract does not say which one is chosen. `confirmEnd` the K-line that confirmed its end, not set while it is still
// merging.
export const mergedBarSchema = z
  .object({
    index: position,
    mIndex: z.number().int().nonnegative(),
    up: z.boolean(),
    high: price,
    low: price,
    start: position,
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

// A line: from the merged bar `start` to the merged bar `end`, `confirmEnd` the merged bar at which it was confirmed,
// not set while it is still going on. A plain object, so that 线段 and 走势 derive from it by `.extend()`, with the
// line's rule.
const lineBase = z
  .object({
    start: bar,
    end: bar,
    confirmEnd: bar.optional(),
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

// a run's K-lines, market's: at least one, their times strictly increasing
const inOrder = (ks: readonly { readonly date: number }[]): boolean =>
  ks.every((k, i) => i === 0 || (ks[i - 1]?.date ?? 0) < k.date);
const inOrderMessage = "a run's K-lines in the order of their times, no time twice";
export const klinesSchema = z.array(klineSchema).min(1).readonly().refine(inOrder, inOrderMessage);
export const massiveKlinesSchema = z
  .array(massiveKlineSchema)
  .min(1)
  .readonly()
  .refine(inOrder, inOrderMessage);

export type MergedBar = z.output<typeof mergedBarSchema>;
export type Fractal = z.output<typeof fractalSchema>;
export type Line = z.output<typeof lineSchema>;
export type Stroke = Line;
export type Segment = z.output<typeof segmentSchema>;
export type Move = z.output<typeof moveSchema>;
export type Consolidation = z.output<typeof consolidationSchema>;
