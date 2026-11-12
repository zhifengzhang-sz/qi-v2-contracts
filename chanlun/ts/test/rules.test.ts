// Each example of ../../examples.json, read by the generated code, breaks exactly the rules it names.

import { expect, test } from "bun:test";
import { fromJson, type JsonValue } from "@bufbuild/protobuf";
import * as chanlun from "../src/index.ts";

const records: Record<string, (value: JsonValue) => string[]> = {
  MergedBar: (v) => chanlun.checkMergedBar(fromJson(chanlun.MergedBarSchema, v)),
  Fractal: (v) => chanlun.checkFractal(fromJson(chanlun.FractalSchema, v)),
  Line: (v) => chanlun.checkLine(fromJson(chanlun.LineSchema, v)),
  Segment: (v) => chanlun.checkSegment(fromJson(chanlun.SegmentSchema, v)),
  Move: (v) => chanlun.checkMove(fromJson(chanlun.MoveSchema, v)),
  Consolidation: (v) => chanlun.checkConsolidation(fromJson(chanlun.ConsolidationSchema, v)),
};

type Example = { record: string; breaks: string[]; value: JsonValue };
const examples: Example[] = await Bun.file(new URL("../../examples.json", import.meta.url)).json();

for (const e of examples)
  test(`${e.record} ${JSON.stringify(e.value)}`, () => {
    const check = records[e.record];
    if (check === undefined) throw new Error(`${e.record}: no such record`);
    expect(check(e.value)).toEqual(e.breaks);
  });
