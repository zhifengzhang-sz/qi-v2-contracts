// A run's records as JSON (../SPEC.md, The JSON): how records cross from one project to another, under market's
// JSON (../../market/SPEC.md, The JSON), read and written by market's decodeAs and encodeRecord. Decoding is the
// run's schema over the parsed text, every record's rules with it; encoding is the canonical text every form writes, so
// that the conformance check compares them as texts: the run's parts in their order, a record a line, its fields in
// the order of their names, a field not set left out.

import { decodeAs, encodeRecord } from "@qi/market";
import { z } from "zod";
import {
  consolidationSchema,
  fractalSchema,
  type Line,
  mergedBarSchema,
  moveSchema,
  segmentSchema,
  strokeSchema,
} from "./contracts.ts";

// The run: the records of a series, its merged bars, 分型, 笔 (strokes), and by level from 0 its 线段 (segments), 走势
// (moves) and 中枢 (consolidations); the series' K-lines are market's, and the run holds none.
// The run's own rules (SPEC.md, The run): the merged bars numbered by their place; the 分型 strictly increasing by
// `mIndex`; the 笔 and each level's 线段, 走势 and 中枢 strictly increasing by `start`; every bar a merged bar's; each
// level's 线段, 走势 and 中枢 of that level; in `merged`, in `strokes` and in each level of `segments`, `moves` and
// `consolidations` at most one record going on (its `confirmEnd` not set), the last; `segments`, `moves` and
// `consolidations` each ending with a level that is not empty, so that one run has one text.
export const runSchema = z
  .object({
    merged: z.array(mergedBarSchema).readonly(),
    fractals: z.array(fractalSchema).readonly(),
    strokes: z.array(strokeSchema).readonly(),
    segments: z.array(z.array(segmentSchema).readonly()).readonly(),
    moves: z.array(z.array(moveSchema).readonly()).readonly(),
    consolidations: z.array(z.array(consolidationSchema).readonly()).readonly(),
  })
  .strict()
  .readonly()
  .superRefine((run, ctx) => {
    const issue = (path: readonly (string | number)[], message: string) =>
      ctx.addIssue({ code: "custom", path: [...path], message });
    const parts: readonly (readonly [string, readonly { readonly mIndex: number }[]])[] = [
      ["merged", run.merged],
      ["fractals", run.fractals],
    ];
    run.merged.forEach((m, i) => {
      if (m.mIndex !== i)
        issue(["merged", i, "mIndex"], "a merged bar's number its place among the merged bars");
    });
    run.fractals.forEach((f, i) => {
      if (i > 0 && (run.fractals[i - 1]?.mIndex ?? 0) >= f.mIndex)
        issue(["fractals", i, "mIndex"], "a run's 分型 strictly increasing by mIndex");
    });
    const inRun = (path: readonly (string | number)[], r: { readonly mIndex: number }) => {
      if (r.mIndex >= run.merged.length) issue(path, "a merged bar past the run's merged bars");
    };
    // records strictly increasing by `start`
    const rising = (
      path: readonly (string | number)[],
      name: string,
      rs: readonly { readonly start: number }[],
    ) => {
      rs.forEach((r, i) => {
        if (i > 0 && (rs[i - 1]?.start ?? 0) >= r.start)
          issue([...path, i, "start"], `a run's ${name} strictly increasing by start`);
      });
    };
    // at most one record of a part, or of a level, going on (its `confirmEnd` not set), and it the last
    const ongoingLast = (
      path: readonly (string | number)[],
      name: string,
      rs: readonly { readonly confirmEnd?: number | undefined }[],
    ) => {
      rs.forEach((r, i) => {
        if (r.confirmEnd === undefined && i < rs.length - 1)
          issue([...path, i], `a run's ${name} every one confirmed but the last`);
      });
    };
    // A line's `start`, `end` and `confirmEnd` are merged bars, a merged bar's of the same names K-lines
    const linesIn = (path: readonly (string | number)[], ls: readonly Line[]) => {
      ls.forEach((l, i) => {
        if ([l.start, l.end, l.confirmEnd].some((b) => b !== undefined && b >= run.merged.length))
          issue([...path, i], "a merged bar past the run's merged bars");
      });
    };
    // a part by level ends with a level that is not empty: its levels 0 to its highest with a record, `[]` if none
    const lastLevel = (part: string, ls: readonly (readonly unknown[])[]) => {
      if (ls.length > 0 && ls.at(-1)?.length === 0)
        issue([part, ls.length - 1], "a part by level's last level not empty");
    };
    lastLevel("segments", run.segments);
    lastLevel("moves", run.moves);
    lastLevel("consolidations", run.consolidations);
    ongoingLast(["merged"], "merged bars", run.merged);
    linesIn(["strokes"], run.strokes);
    rising(["strokes"], "笔", run.strokes);
    ongoingLast(["strokes"], "笔", run.strokes);
    run.segments.forEach((l, i) => {
      linesIn(["segments", i], l);
      rising(["segments", i], "线段", l);
      ongoingLast(["segments", i], "线段", l);
      l.forEach((s, k) => {
        if (s.level !== i) issue(["segments", i, k, "level"], `a 线段 here of level ${i}`);
      });
    });
    run.moves.forEach((l, i) => {
      linesIn(["moves", i], l);
      rising(["moves", i], "走势", l);
      ongoingLast(["moves", i], "走势", l);
      l.forEach((m, k) => {
        if (m.level !== i) issue(["moves", i, k, "level"], `a 走势 here of level ${i}`);
      });
    });
    parts.forEach(([part, rs]) => {
      rs.forEach((r, i) => {
        inRun([part, i], r);
      });
    });
    // A 中枢's `start`, `end` and `confirmEnd` are merged bars, a merged bar's of the same names K-lines
    run.consolidations.forEach((cs, l) => {
      rising(["consolidations", l], "中枢", cs);
      ongoingLast(["consolidations", l], "中枢", cs);
      cs.forEach((c, i) => {
        if ([c.start, c.end, c.confirmEnd].some((b) => b !== undefined && b >= run.merged.length))
          issue(["consolidations", l, i], "a merged bar past the run's merged bars");
        if (c.level !== l) issue(["consolidations", l, i, "level"], `a 中枢 here of level ${l}`);
      });
    });
  });

export type Run = z.output<typeof runSchema>;

export type Decoded<R = Run> =
  | { readonly ok: true; readonly run: R }
  | { readonly ok: false; readonly error: string };

// A run's JSON as its records
const decoder =
  <R>(schema: z.ZodType<R>) =>
  (text: string): Decoded<R> => {
    const r = decodeAs(schema, text);
    return r.ok ? { ok: true, run: r.value } : r;
  };
export const decodeRun = decoder<Run>(runSchema);

const list = (lines: readonly string[]): string => (lines.length === 0 ? "[]" : `[\n${lines.join(",\n")}\n]`);
const records = (rs: readonly object[]): string => list(rs.map(encodeRecord));

// A run's canonical JSON, of a run the contract allows (a decoder's, or one its run schema passes).
export const encodeRun = (run: Run): string =>
  `{\n${[
    `"merged": ${records(run.merged)}`,
    `"fractals": ${records(run.fractals)}`,
    `"strokes": ${records(run.strokes)}`,
    `"segments": ${list(run.segments.map(records))}`,
    `"moves": ${list(run.moves.map(records))}`,
    `"consolidations": ${list(run.consolidations.map(records))}`,
  ].join(",\n")}\n}\n`;
