// The contract's vectors (../../vectors/), each read as bin/decode.ts reads it: the ongoing K-lines decoded and encoded
// again to the same text, every reject case refused, of the base and of Massive's; the conformance check (make check)
// compares the Lean and Go forms' text with the same files.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { decodeMassiveOngoingKLine, decodeOngoingKLine, encodeOngoingKLine } from "../src/codec.ts";

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

describe("the ongoing K-lines", () => {
  it.each([
    ["ongoing/kline.json", decodeOngoingKLine],
    ["ongoing/massive.json", decodeMassiveOngoingKLine],
  ] as const)("%s decodes, and encodes to the same text", (n, decode) => {
    const r = decode(text(n));
    if (!r.ok) expect.fail(r.error);
    expect(encodeOngoingKLine(r.kline)).toBe(text(n));
  });
  it.each(readdirSync(join(V, "ongoing", "reject")))("ongoing/reject/%s is refused", (n) => {
    expect(fault(join("ongoing", "reject", n), decodeOngoingKLine)).not.toBe("");
  });
  it.each(
    readdirSync(join(V, "ongoing", "massive", "reject")),
  )("ongoing/massive/reject/%s is refused as Massive's", (n) => {
    expect(fault(join("ongoing", "massive", "reject", n), decodeMassiveOngoingKLine)).not.toBe("");
  });
});
