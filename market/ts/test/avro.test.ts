// The Avro schemas. First the mapping (bin/avro.ts): what it writes for each kind of field, a record of another
// contract among them, and what it refuses. Then the schemas of ../avro themselves, read by an Avro implementation:
// every ongoing K-line vector goes through Avro's binary format and comes back as the same text.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import avsc from "avsc";
import { describe, expect, it } from "vitest";
import { avro } from "../bin/avro.ts";
import { decodeOngoingKLine, encodeOngoingKLine } from "../src/index.ts";

const record = {
  type: "object",
  properties: {
    count: { type: "integer", minimum: 0 },
    price: { type: "integer", minimum: -5 },
    on: { type: "boolean" },
    name: { type: "string" },
    flag: { anyOf: [{ const: 0 }, { const: 1 }] },
    lastDate: { type: "integer", minimum: 0 },
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
const made = (row: object = record) => avro({ Row: row, Run: run }, "t.v1");
const parsed = (file: string): unknown => {
  const r = made();
  if (!r.ok) expect.fail(r.error);
  return JSON.parse(r.files[file] ?? "null");
};
const withField = (type: object) => ({ ...record, properties: { ...record.properties, when: type } });

describe("the Avro mapping", () => {
  it("maps each kind of field, a field not required to a union with null, null by default", () => {
    expect(parsed("Row.avsc")).toEqual({
      type: "record",
      name: "Row",
      namespace: "t.v1",
      fields: [
        { name: "count", type: "long" },
        { name: "price", type: "long" },
        { name: "on", type: "boolean" },
        { name: "name", type: "string" },
        { name: "flag", type: "int" },
        { name: "lastDate", type: ["null", "long"], default: null },
      ],
    });
  });
  it("writes a record out where it first appears and names it after that, an array of arrays as it is", () => {
    const r = parsed("Run.avsc") as { readonly fields: readonly { readonly type: unknown }[] };
    expect(r.fields[0]?.type).toMatchObject({ type: "array", items: { type: "record", name: "Row" } });
    expect(r.fields[1]?.type).toEqual({ type: "array", items: { type: "array", items: "Row" } });
  });
  it("writes a record of another contract out in its namespace, names it by its full name after, and gives it no file", () => {
    const pair = {
      type: "object",
      properties: { a: { $ref: "Row" }, b: { $ref: "Row" } },
      required: ["a", "b"],
    };
    const r = avro({ Row: record, Run: pair }, "t.v1", { Row: "o.v1" });
    if (!r.ok) expect.fail(r.error);
    expect(Object.keys(r.files)).toEqual(["Run.avsc"]);
    const s = JSON.parse(r.files["Run.avsc"] ?? "null") as {
      readonly fields: readonly { readonly type: unknown }[];
    };
    expect(s.fields[0]?.type).toMatchObject({ type: "record", name: "Row", namespace: "o.v1" });
    expect(s.fields[1]?.type).toBe("o.v1.Row");
    expect(() => avsc.Type.forSchema(s as avsc.Schema)).not.toThrow();
  });
  it("refuses a name Avro does not allow", () => {
    const row = { ...record, properties: { ...record.properties, "a-b": { type: "string" } } };
    expect(made(row)).toMatchObject({ ok: false, error: expect.stringContaining("Row.a-b") });
  });
  it("refuses a type with no Avro form", () => {
    expect(made(withField({ type: "null" }))).toMatchObject({
      ok: false,
      error: expect.stringContaining("Row.when: a type with no Avro form"),
    });
  });
  it("refuses a union of constants too large for an int", () => {
    expect(made(withField({ anyOf: [{ const: 2147483648 }] }))).toMatchObject({
      ok: false,
      error: expect.stringContaining("Row.when"),
    });
  });
  it("refuses something that is not a record, and a record that is not there", () => {
    expect(made({ type: "string" })).toMatchObject({
      ok: false,
      error: expect.stringContaining("not a record"),
    });
    expect(avro({ Run: run }, "t.v1")).toMatchObject({
      ok: false,
      error: expect.stringContaining("no record Row"),
    });
  });
});

const dir = join(import.meta.dirname, "..", "..", "avro");
const vectors = join(import.meta.dirname, "..", "..", "vectors");
const files = readdirSync(dir).filter((f) => f.endsWith(".avsc"));
const schema = (file: string) => JSON.parse(readFileSync(join(dir, file), "utf8"));
// avsc's default long refuses the contract's largest number, though Avro's
// long is 64 bits. This is avsc's documented way to replace it: a JavaScript number, over the contract's whole range.
const long = avsc.types.LongType.__with({
  fromBuffer: (b: Buffer) => {
    const n = Number(b.readBigInt64LE());
    if (!Number.isSafeInteger(n)) throw new Error("a long past the contract's bound");
    return n;
  },
  toBuffer: (n: number) => {
    const b = Buffer.alloc(8);
    b.writeBigInt64LE(BigInt(n));
    return b;
  },
  fromJSON: Number,
  toJSON: Number,
  isValid: Number.isSafeInteger,
  compare: (a: number, b: number) => a - b,
});
const typeOf = (s: object) => avsc.Type.forSchema(s as avsc.Schema, { registry: { long } });
const type = (file: string) => typeOf(schema(file));

describe("the Avro schemas, read by an Avro implementation", () => {
  it("are one for each record", () => {
    expect([...files].sort()).toEqual(["KLine", "OngoingKLine"].map((r) => `${r}.avsc`));
  });
  it.each(files)("reads %s", (file) => {
    expect(() => type(file)).not.toThrow();
  });
  it.each([
    ["ongoing/kline.json", "OngoingKLine.avsc", decodeOngoingKLine],
  ] as const)("gives %s back as the same text through Avro's binary format", (vector, file, decode) => {
    const text = readFileSync(join(vectors, vector), "utf8");
    const r = decode(text);
    if (!r.ok) expect.fail(r.error);
    const t = type(file);
    const back = t.fromBuffer(t.toBuffer(r.kline));
    expect(encodeOngoingKLine({ ...back })).toBe(text);
  });
});
