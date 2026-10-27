// A run's records as JSON (../SPEC.md, The JSON): how records cross from one project to another. Decoding is the run's
// schema over the parsed text, every record's rules with it; encoding is the canonical text both forms write, so that
// the conformance check compares them as texts: the run's parts in their order, a record a line, its fields in the
// order of their names, a field not set left out.

import { z } from "zod";
import {
  type Centre,
  centreSchema,
  type Fractal,
  fractalSchema,
  type KLine,
  klinesSchema,
  type MergedBar,
  mergedBarSchema,
  type Stroke,
  strokeSchema,
} from "./contracts.ts";

// The run: its K-lines, merged bars, 分型, 笔 (strokes), 线段 (segments), and by level from 0 its 走势 (trends) and
// 中枢 (centres).
// The run's own rules (SPEC.md, The run): the merged bars numbered by their place; every position a K-line's, every
// bar a merged bar's; each part's lines and 中枢 of its level.
const positionsOf = (r: object): readonly number[] =>
  [
    "confirmDate",
    "startDate",
    "endDate",
    "confirmStartDate",
    "confirmEndDate",
    "confirmTurningPointDate",
    "ggDate",
    "ddDate",
  ].flatMap((k) => {
    const v = (r as { readonly [k: string]: unknown })[k];
    return typeof v === "number" ? [v] : [];
  });
const barsOf = (r: object): readonly number[] =>
  ["mno", "startBar", "endBar", "ggBar", "ddBar"].flatMap((k) => {
    const v = (r as { readonly [k: string]: unknown })[k];
    return typeof v === "number" ? [v] : [];
  });

export const runSchema = z
  .object({
    klines: klinesSchema,
    merged: z.array(mergedBarSchema).readonly(),
    fractals: z.array(fractalSchema).readonly(),
    strokes: z.array(strokeSchema).readonly(),
    segments: z.array(strokeSchema).readonly(),
    trends: z.array(z.array(strokeSchema).readonly()).readonly(),
    centres: z.array(z.array(centreSchema).readonly()).readonly(),
  })
  .strict()
  .readonly()
  .superRefine((run, ctx) => {
    const issue = (path: readonly (string | number)[], message: string) =>
      ctx.addIssue({ code: "custom", path: [...path], message });
    const parts: readonly (readonly [string, readonly object[]])[] = [
      ["klines", run.klines],
      ["merged", run.merged],
      ["fractals", run.fractals],
      ["strokes", run.strokes],
      ["segments", run.segments],
    ];
    const levelled: readonly (readonly [string, number, readonly object[]])[] = [
      ...run.trends.map((l, i) => ["trends", i, l] as const),
      ...run.centres.map((l, i) => ["centres", i, l] as const),
    ];
    run.merged.forEach((m, i) => {
      if (m.mno !== i) issue(["merged", i, "mno"], "a merged bar's number its place among the merged bars");
    });
    const inRun = (path: readonly (string | number)[], r: object) => {
      if (positionsOf(r).some((p) => p >= run.klines.length))
        issue(path, "a position past the run's K-lines");
      if (barsOf(r).some((b) => b >= run.merged.length))
        issue(path, "a merged bar past the run's merged bars");
    };
    parts.forEach(([part, rs]) => {
      rs.forEach((r, i) => {
        inRun([part, i], r);
      });
    });
    levelled.forEach(([part, l, rs]) => {
      rs.forEach((r, i) => {
        inRun([part, l, i], r);
      });
    });
    const level = (
      path: readonly (string | number)[],
      rs: readonly { readonly level: number }[],
      want: number,
    ) => {
      rs.forEach((r, i) => {
        if (r.level !== want) issue([...path, i, "level"], `a line or 中枢 here of level ${want}`);
      });
    };
    level(["strokes"], run.strokes, -2);
    level(["segments"], run.segments, -1);
    run.trends.forEach((l, i) => {
      level(["trends", i], l, i);
    });
    run.centres.forEach((l, i) => {
      level(["centres", i], l, i);
    });
  });

export type Run = {
  readonly klines: readonly KLine[];
  readonly merged: readonly MergedBar[];
  readonly fractals: readonly Fractal[];
  readonly strokes: readonly Stroke[];
  readonly segments: readonly Stroke[];
  readonly trends: readonly (readonly Stroke[])[];
  readonly centres: readonly (readonly Centre[])[];
};

// The time of the K-line at a position: how a date of a record is turned back into a time.
export const timeAt = (run: Run, p: number): number | undefined => run.klines[p]?.date;

export type Decoded =
  | { readonly ok: true; readonly run: Run }
  | { readonly ok: false; readonly error: string };

const parsed = (text: string): { readonly ok: true; readonly value: unknown } | { readonly ok: false } => {
  try {
    return { ok: true, value: JSON.parse(text) };
  } catch {
    return { ok: false };
  }
};

// Every number of the text written as a whole number, digits only (no fraction, no exponent), of at most 16 digits;
// the texts in strings skipped. Checked on the text, before it is parsed, as the Lean form checks it.
const literals = (text: string): string | undefined =>
  [...text.matchAll(/"(?:[^"\\]|\\.)*"|-?[0-9][-+0-9.eE]*/g)]
    .map((m) => m[0])
    .find((t) => !t.startsWith('"') && !/^-?(0|[1-9][0-9]{0,15})$/.test(t));

// A run's JSON as its records; a fault as a value, its path and message.
export const decodeRun = (text: string): Decoded => {
  const bad = literals(text);
  if (bad !== undefined)
    return { ok: false, error: `${bad}: a number is a whole number, digits only, at most 16` };
  const j = parsed(text);
  if (!j.ok) return { ok: false, error: "not JSON" };
  const r = runSchema.safeParse(j.value);
  return r.success
    ? { ok: true, run: r.data }
    : {
        ok: false,
        error: r.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; "),
      };
};

const record = (r: object): string =>
  `{${Object.entries(r)
    .filter(([, v]) => v !== undefined)
    .toSorted(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([k, v]) => `${JSON.stringify(k)}:${JSON.stringify(v)}`)
    .join(",")}}`;
const list = (lines: readonly string[]): string => (lines.length === 0 ? "[]" : `[\n${lines.join(",\n")}\n]`);
const records = (rs: readonly object[]): string => list(rs.map(record));

// A run's canonical JSON, of a run the contract allows (decodeRun's, or one runSchema passes).
export const encodeRun = (run: Run): string =>
  `{\n${[
    `"klines": ${records(run.klines)}`,
    `"merged": ${records(run.merged)}`,
    `"fractals": ${records(run.fractals)}`,
    `"strokes": ${records(run.strokes)}`,
    `"segments": ${records(run.segments)}`,
    `"trends": ${list(run.trends.map(records))}`,
    `"centres": ${list(run.centres.map(records))}`,
  ].join(",\n")}\n}\n`;
