// Each example of ../../examples.json, read by the generated code, breaks exactly the rules it names.

import { expect, test } from "bun:test";
import { fromJson, type JsonValue } from "@bufbuild/protobuf";
import { checkKLine, checkOngoingKLine, KLineSchema, OngoingKLineSchema } from "../src/index.ts";

const records: Record<string, (value: JsonValue) => string[]> = {
  KLine: (v) => checkKLine(fromJson(KLineSchema, v)),
  OngoingKLine: (v) => checkOngoingKLine(fromJson(OngoingKLineSchema, v)),
};

type Example = { record: string; breaks: string[]; value: JsonValue };
const examples: Example[] = await Bun.file(new URL("../../examples.json", import.meta.url)).json();

for (const e of examples)
  test(`${e.record} ${JSON.stringify(e.value)}`, () => {
    const check = records[e.record];
    if (check === undefined) throw new Error(`${e.record}: no such record`);
    expect(check(e.value)).toEqual(e.breaks);
  });
