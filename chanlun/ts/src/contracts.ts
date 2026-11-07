// 缠论's records (../SPEC.md, The records): what the algorithm of 缠论 makes beyond the K-line, of whatever
// implementation makes it, each a Zod schema: the merged bar (mergedBarSchema), the fractal (fractalSchema), the line
// (lineSchema), the 笔 (strokeSchema, a line), the 线段 and the 走势 (segmentSchema and moveSchema, lines with a level),
// and the consolidation (consolidationSchema); the run that holds them for a series is codec.ts's (runSchema).
//
// They are derived from market's K-line (@qi/market, ../../market/SPEC.md), whose units they take: a position is a
// K-line's place in its series, and a price is a decimal. A K-line is defined there, once, and none is here: what the
// algorithm makes that market defines is market's. Every record but the merged bar is on merged bars, by their number
// (a merged bar's `mIndex`): a 分型 its merged bar, a line its start and end merged bars, a 中枢 its start and end merged
// bars. A configuration still going on, a merged bar still merging, a line not yet ended, a 中枢 under construction, has
// no `confirmEnd`: one rule for the three, and in a run at most one record of a part, or of a level, is going on, the
// last (codec.ts). Whether an implementation's values are right by the lessons is not these contracts' to test: they
// say what a value is, not whether it is the lessons'.

import { positionSchema as position, priceSchema as price } from "@qi/market";
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

export type MergedBar = z.output<typeof mergedBarSchema>;
export type Fractal = z.output<typeof fractalSchema>;
export type Line = z.output<typeof lineSchema>;
export type Stroke = Line;
export type Segment = z.output<typeof segmentSchema>;
export type Move = z.output<typeof moveSchema>;
export type Consolidation = z.output<typeof consolidationSchema>;
