// The records as JSON (../SPEC.md, The JSON): how records cross from one project to another. Decoding is a record's
// schema over the parsed text, its rules with it; encoding is the canonical text every form writes, so that the
// conformance check compares them as texts: a record's fields in the order of their names, a field not set left out.
// A contract built on this one, or a taker of a record of its own, reads and writes its records by the same two
// (decodeAs, encodeRecord).

import type { z } from "zod";
import { decimal, type OngoingKLine, ongoingKlineSchema } from "./contracts.ts";

export type DecodedOngoing<K = OngoingKLine> =
  | { readonly ok: true; readonly kline: K }
  | { readonly ok: false; readonly error: string };

const parsed = (text: string): { readonly ok: true; readonly value: unknown } | { readonly ok: false } => {
  try {
    return { ok: true, value: JSON.parse(text) };
  } catch {
    return { ok: false };
  }
};

// Every number of the text written in digits, no exponent: a whole number of at most 16 digits, or a decimal of at most
// 6 digits after the point and 15 from the first that is not 0, the last not 0 (a fraction is a price's or a
// quantity's only, and they have no more); strings skipped. Checked on the text, before it is parsed, as the Lean form
// checks it.
const literals = (text: string): string | undefined =>
  [...text.matchAll(/"(?:[^"\\]|\\.)*"|-?[0-9][-+0-9.eE]*/g)]
    .map((m) => m[0])
    .find(
      (t) => !t.startsWith('"') && !/^-?(0|[1-9][0-9]{0,15})$/.test(t) && !(t.includes(".") && decimal(t)),
    );

// The first name given twice in one object of the text, if any; the text JSON. JSON.parse keeps the last of the two.
const twice = (text: string): string | undefined => {
  const names: (Set<string> | undefined)[] = [];
  const tokens = [...text.matchAll(/"(?:[^"\\]|\\.)*"|[{}[\]:]/g)].map((m) => m[0]);
  for (const [i, t] of tokens.entries()) {
    if (t === "{") names.push(new Set());
    else if (t === "[") names.push(undefined);
    else if (t === "}" || t === "]") names.pop();
    else if (t.startsWith('"') && tokens[i + 1] === ":") {
      const name = JSON.parse(t) as string;
      const here = names.at(-1);
      if (here?.has(name)) return name;
      here?.add(name);
    }
  }
  return undefined;
};

// A JSON text as a value of `schema`; a fault as a value, its path and message.
export const decodeAs = <R>(
  schema: z.ZodType<R>,
  text: string,
): { readonly ok: true; readonly value: R } | { readonly ok: false; readonly error: string } => {
  const bad = literals(text);
  if (bad !== undefined)
    return {
      ok: false,
      error: `${bad}: a number in digits, a whole number of at most 16, a decimal of at most 6 after the point and 15 in all`,
    };
  const j = parsed(text);
  if (!j.ok) return { ok: false, error: "not JSON" };
  const name = twice(text);
  if (name !== undefined) return { ok: false, error: `${name}: a name twice in one object` };
  const r = schema.safeParse(j.value);
  return r.success
    ? { ok: true, value: r.data }
    : {
        ok: false,
        error: r.error.issues
          .map((i) => (i.path.length > 0 ? `${i.path.join(".")}: ${i.message}` : i.message))
          .join("; "),
      };
};

// An ongoing K-line's JSON as its record
const ongoingDecoder =
  <K>(schema: z.ZodType<K>) =>
  (text: string): DecodedOngoing<K> => {
    const r = decodeAs(schema, text);
    return r.ok ? { ok: true, kline: r.value } : r;
  };
export const decodeOngoingKLine = ongoingDecoder<OngoingKLine>(ongoingKlineSchema);

// A record's canonical JSON, of a record the contract allows: its fields in the order of their names, a field not set
// left out, no spaces.
export const encodeRecord = (r: object): string =>
  `{${Object.entries(r)
    .filter(([, v]) => v !== undefined)
    .toSorted(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([k, v]) => `${JSON.stringify(k)}:${JSON.stringify(v)}`)
    .join(",")}}`;

// An ongoing K-line's canonical JSON, of one the contract allows: its record, and a line break.
export const encodeOngoingKLine = (kline: object): string => `${encodeRecord(kline)}\n`;
