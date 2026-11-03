// The Protobuf description's mapping (bin/protobuf.ts): what it writes for each kind of field, and what it refuses: a
// field with no number, a number of a field gone and not reserved, a number twice, a name whose JSON name would differ,
// a type with no Protobuf form.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { type Numbers, protobuf } from "../bin/protobuf.ts";

const int = { type: "integer", minimum: 0 };
const record = {
  type: "object",
  properties: {
    count: int,
    price: { type: "integer", minimum: -5 },
    on: { type: "boolean" },
    name: { type: "string" },
    flag: { anyOf: [{ const: 0 }, { const: 1 }] },
    lastDate: int,
  },
  required: ["count", "price", "on", "name", "flag"],
};
const run = {
  type: "object",
  properties: {
    rows: { type: "array", items: { $ref: "Row" } },
    levels: { type: "array", items: { type: "array", items: { $ref: "Row" } } },
  },
  required: ["rows", "levels"],
};
const numbers = (
  row: { readonly [f: string]: number },
  reserved: { readonly [f: string]: number } = {},
): Numbers => ({
  package: "t.v1",
  messages: { Row: { fields: row, reserved }, Run: { fields: { rows: 1, levels: 2 }, reserved: {} } },
});
const all = { count: 1, price: 2, on: 3, name: 4, flag: 5, lastDate: 6 };
const made = (n: Numbers, row: object = record) => protobuf({ Row: row, Run: run }, n, []);

describe("the Protobuf description", () => {
  it("maps each kind of field, a list's message for an array of arrays, the reserved kept", () => {
    const r = made(numbers({ ...all, lastDate: 8 }, { old: 6 }));
    if (!r.ok) expect.fail(r.error);
    expect(r.text).toContain(
      "  uint64 count = 1;\n  int64 price = 2;\n  bool on = 3;\n  string name = 4;\n  uint32 flag = 5;",
    );
    expect(r.text).toContain('  optional uint64 last_date = 8;\n  reserved 6;\n  reserved "old";');
    expect(r.text).toContain("  repeated Row rows = 1;\n  repeated RowList levels = 2;");
    expect(r.text).toContain("message RowList {\n  repeated Row items = 1;\n}");
  });
  it("keeps a number reserved without its name, in order with the named ones", () => {
    const r = made({
      package: "t.v1",
      messages: {
        Row: { fields: { ...all, lastDate: 8 }, reserved: { old: 7 }, reservedNumbers: [6] },
        Run: { fields: { rows: 1, levels: 2 }, reserved: {} },
      },
    });
    if (!r.ok) expect.fail(r.error);
    expect(r.text).toContain('  optional uint64 last_date = 8;\n  reserved 6, 7;\n  reserved "old";');
  });
  it("refuses a field with no number", () => {
    const { lastDate: _, ...rest } = all;
    expect(made(numbers(rest))).toMatchObject({
      ok: false,
      error: expect.stringContaining("no number: lastDate"),
    });
  });
  it("refuses a number of a field it does not have", () => {
    expect(made(numbers({ ...all, gone: 7 }))).toMatchObject({
      ok: false,
      error: expect.stringContaining("gone"),
    });
  });
  it("refuses a number given twice, a reserved one among them", () => {
    expect(made(numbers(all, { old: 6 }))).toMatchObject({
      ok: false,
      error: expect.stringContaining("twice: 6"),
    });
  });
  it("refuses a name whose JSON name would differ", () => {
    const row = { ...record, properties: { ...record.properties, URL: int } };
    expect(made(numbers({ ...all, URL: 7 }), row)).toMatchObject({
      ok: false,
      error: expect.stringContaining("URL"),
    });
  });
  it("refuses a type with no Protobuf form", () => {
    const row = { ...record, properties: { ...record.properties, when: { type: "number" } } };
    expect(made(numbers({ ...all, when: 7 }), row)).toMatchObject({
      ok: false,
      error: expect.stringContaining("when"),
    });
  });
});

describe("the field numbers", () => {
  const file = join(import.meta.dirname, "..", "..", "proto", "fields.json");
  const { messages } = JSON.parse(readFileSync(file, "utf8")) as Numbers;
  it.each([
    ["MassiveKLine", "KLine"],
    ["MassiveRun", "Run"],
    ["Segment", "Line"],
    ["Move", "Line"],
  ])("gives %s the numbers of %s, for the fields they share", (derived, base) => {
    expect(messages[derived]?.fields).toMatchObject(messages[base]?.fields ?? { none: 1 });
  });
  it.each(Object.keys(messages))("gives %s the fields of its Avro schema", (message) => {
    const avsc = join(import.meta.dirname, "..", "..", "avro", `${message}.avsc`);
    const fields = (JSON.parse(readFileSync(avsc, "utf8")) as { fields: { name: string }[] }).fields;
    expect(Object.keys(messages[message]?.fields ?? {}).sort()).toEqual(fields.map((f) => f.name).sort());
  });
});
