// The Protobuf description's mapping (bin/protobuf.ts): what it writes for each kind of field, and what it refuses: a
// field with no number, a number of a field gone and not reserved, a number twice, a name whose JSON name would differ,
// a type with no Protobuf form.
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
