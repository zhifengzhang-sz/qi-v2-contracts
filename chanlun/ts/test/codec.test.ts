// The contract's vectors (../../vectors/): the runs decoded and encoded again to the same text, every reject case
// refused; the conformance check (make check) compares the Lean form's text with the same files.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { decodeMassiveRun, decodeRun, encodeRun } from "../src/codec.ts";

const V = join(import.meta.dirname, "..", "..", "vectors");
const text = (n: string) => readFileSync(join(V, n), "utf8");

describe("the vectors", () => {
  it.each(["run.json", "small.json", "edge.json"])("%s decodes, and encodes to the same text", (n) => {
    const r = decodeRun(text(n));
    if (!r.ok) expect.fail(r.error);
    expect(encodeRun(r.run)).toBe(text(n));
  });
  it("run.json holds every kind of record, 走势 of level 0, a 中枢 of level 1 and a 中枢 under construction among them", () => {
    const r = decodeRun(text("run.json"));
    if (!r.ok) expect.fail(r.error);
    const { klines, merged, fractals, strokes, segments, moves, consolidations } = r.run;
    expect([klines, merged, fractals, strokes, segments].every((x) => x.length > 0)).toBe(true);
    expect(moves[0]?.length).toBeGreaterThan(0);
    expect(consolidations[1]?.length).toBeGreaterThan(0);
    expect(consolidations.flat().some((c) => c.confirmEnd === undefined)).toBe(true);
  });
  it.each(readdirSync(join(V, "reject")))("reject/%s is refused", (n) => {
    const r = decodeRun(text(join("reject", n)));
    expect(r.ok ? "" : r.error).not.toBe("");
  });
});

describe("Massive's vectors", () => {
  it.each(["massive/small.json", "massive/edge.json"])("%s decodes, and encodes to the same text", (n) => {
    const r = decodeMassiveRun(text(n));
    if (!r.ok) expect.fail(r.error);
    expect(encodeRun(r.run)).toBe(text(n));
  });
  it.each(readdirSync(join(V, "massive", "reject")))("massive/reject/%s is refused", (n) => {
    const r = decodeMassiveRun(text(join("massive", "reject", n)));
    expect(r.ok ? "" : r.error).not.toBe("");
  });
});
