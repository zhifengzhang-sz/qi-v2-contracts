// The contract's vectors (../../vectors/), each read as bin/decode.ts reads it: the runs decoded and encoded again to
// the same text, every reject case refused; the conformance check (make check) compares the Lean and Go forms' text with
// the same files. The ongoing K-lines are market's (../../../market/vectors/).
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { decodeRun, encodeRun } from "../src/codec.ts";

const V = join(import.meta.dirname, "..", "..", "vectors");
// A vector as bin/decode.ts reads it: its bytes as UTF-8, a byte that is not UTF-8 refused, not replaced
const read = (
  n: string,
): { readonly ok: true; readonly text: string } | { readonly ok: false; readonly error: string } => {
  try {
    return {
      ok: true,
      text: new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(readFileSync(join(V, n))),
    };
  } catch {
    return { ok: false, error: "text not UTF-8" };
  }
};
const text = (n: string): string => {
  const t = read(n);
  if (!t.ok) expect.fail(`${n}: ${t.error}`);
  return t.text;
};
// A reject case's fault, by `decode`, or text not UTF-8 before anything is decoded; "" if it is not refused
const fault = (
  n: string,
  decode: (text: string) => { readonly ok: true } | { readonly ok: false; readonly error: string },
): string => {
  const t = read(n);
  const r = t.ok ? decode(t.text) : t;
  return r.ok ? "" : r.error;
};

describe("the vectors", () => {
  it.each(["run.json", "small.json", "edge.json"])("%s decodes, and encodes to the same text", (n) => {
    const r = decodeRun(text(n));
    if (!r.ok) expect.fail(r.error);
    expect(encodeRun(r.run)).toBe(text(n));
  });
  it("run.json holds every kind of record, 走势 of level 0, a 中枢 of level 1, a 中枢 under construction and a 笔, a 线段 and a 走势 still going on", () => {
    const r = decodeRun(text("run.json"));
    if (!r.ok) expect.fail(r.error);
    const { klines, merged, fractals, strokes, segments, moves, consolidations } = r.run;
    expect([klines, merged, fractals, strokes, segments].every((x) => x.length > 0)).toBe(true);
    expect(moves[0]?.length).toBeGreaterThan(0);
    expect(consolidations[1]?.length).toBeGreaterThan(0);
    expect(consolidations.flat().some((c) => c.confirmEnd === undefined)).toBe(true);
    // the one going on is the last of its part or level, and every other is confirmed
    expect(strokes.at(-1)?.confirmEnd).toBeUndefined();
    expect(segments[0]?.at(-1)?.confirmEnd).toBeUndefined();
    expect(moves[0]?.at(-1)?.confirmEnd).toBeUndefined();
    expect(strokes.slice(0, -1).every((s) => s.confirmEnd !== undefined)).toBe(true);
  });
  it.each(readdirSync(join(V, "reject")))("reject/%s is refused", (n) => {
    expect(fault(join("reject", n), decodeRun)).not.toBe("");
  });
});
