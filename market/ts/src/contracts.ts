// The market data's records (../SPEC.md, The records): the K-lines, of whatever source gives them, each a Zod schema.
//
//   the K-line (klineSchema; a data source's, massiveKlineSchema)       the bars as read, each complete
//   (a bar still going on: the ongoing K-line, ongoingKlineSchema, massiveOngoingKlineSchema, in no series yet)
//
// A K-line's date is its begin time, milliseconds since 1970, UTC. A price and a quantity are decimals. A contract built
// on this one takes its K-line, and its units (positionSchema, priceSchema) for records of its own.

import { z } from "zod";

// a time: milliseconds since 1970, UTC
const time = z.number().int().nonnegative();
// a K-line's position in the series
const position = z.number().int().nonnegative();
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

// The units a contract built on this one takes for records of its own (../SPEC.md, Units): a position, a K-line's
// place in its series, and a price
export const positionSchema = position;
export const priceSchema = price;

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
    // its place in its series, from 0
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

// The ongoing K-line of a data source, defined once over the source's K-line: its K-line's fields and rule, `index` the
// place it will take when complete, and `asOf`, when its values were last updated, not before its `date`. A bar still
// going on, in no series yet. (Zod's types do not reach a field through the generic shape, hence the casts.)
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

export type KLine = z.output<typeof klineSchema>;
export type MassiveKLine = z.output<typeof massiveKlineSchema>;
export type OngoingKLine = z.output<typeof ongoingKlineSchema>;
export type MassiveOngoingKLine = z.output<typeof massiveOngoingKlineSchema>;
