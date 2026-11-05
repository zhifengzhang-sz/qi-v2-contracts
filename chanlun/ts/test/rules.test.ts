// Every rule of SPEC.md has a reject vector that breaks it, and every reject vector names a rule
// (../../vectors/rules.json, whose `about` says how): SPEC.md's passages that state rules are read from its headings,
// tables and paragraphs; each is the rules listed for it and the text listed as no rule, and nothing else; each rule
// has its vectors, and the TypeScript form refuses each of them with one of the rule's refusals.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { decodeMassiveRun, decodeOngoingKLine, decodeRun } from "../src/codec.ts";

const V = join(import.meta.dirname, "..", "..", "vectors");
type Rule = {
  readonly rule: string;
  readonly refused: readonly string[];
  readonly vectors: readonly string[];
};
type Passage = { readonly rules: readonly Rule[]; readonly "no rule": readonly string[] };
const { passages: listed } = JSON.parse(readFileSync(join(V, "rules.json"), "utf8")) as {
  readonly passages: { readonly [name: string]: Passage };
};

// SPEC.md's passages that state rules, by name: each row and paragraph of Units, The records (before its first record)
// and The run, each `Rule:` paragraph of a record, and The JSON's first paragraph
const passagesOf = (md: string): Map<string, string> => {
  const found = new Map<string, string>();
  const all = new Set(["Units", "The records", "The run"]);
  let heading = "";
  let paragraphs = 0;
  let table = 0;
  let lines: string[] = [];
  let code = false;
  const end = () => {
    if (lines.length === 0) return;
    const text = lines.join(" ");
    lines = [];
    paragraphs++;
    if (text.startsWith("Rule: ")) found.set(`${heading}, Rule`, text.slice("Rule: ".length));
    else if (all.has(heading) || (heading === "The JSON" && paragraphs === 1))
      found.set(`${heading}, paragraph ${paragraphs}`, text);
  };
  for (const line of md.split("\n")) {
    if (line.startsWith("```")) code = !code;
    if (code || line.startsWith("```")) continue;
    if (line.startsWith("#")) {
      end();
      heading = line.replace(/^#+ /, "");
      paragraphs = 0;
      table = 0;
    } else if (line.startsWith("|")) {
      end();
      table++;
      const cells = line
        .split("|")
        .slice(1, -1)
        .map((c) => c.trim());
      if (table > 2 && all.has(heading)) found.set(`${heading}, ${cells[0]}`, cells.slice(1).join(" | "));
    } else if (line.trim() === "") {
      end();
      table = 0;
    } else lines.push(line);
  }
  end();
  return found;
};
const spec = passagesOf(readFileSync(join(V, "..", "SPEC.md"), "utf8"));

// A reject vector's fault in the TypeScript form, by its folder's mode, as bin/decode.ts reads it
const fault = (vector: string): string => {
  const bytes = readFileSync(join(V, vector));
  let text: string;
  try {
    text = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);
  } catch {
    return "text not UTF-8";
  }
  const r = vector.startsWith("massive/")
    ? decodeMassiveRun(text)
    : vector.startsWith("ongoing/")
      ? decodeOngoingKLine(text)
      : decodeRun(text);
  return r.ok ? "" : r.error;
};

const rejects = ["reject", "massive/reject", "ongoing/reject"].flatMap((d) =>
  readdirSync(join(V, d))
    .filter((f) => f.endsWith(".json"))
    .map((f) => `${d}/${f}`),
);

describe("every rule of SPEC.md has a reject vector", () => {
  it("SPEC.md's passages are found", () => {
    expect(spec.size).toBeGreaterThan(20);
  });
  it.each([...spec.keys()])("SPEC.md, %s: its rules listed, nothing else in it", (name) => {
    const passage = listed[name];
    if (passage === undefined) expect.fail(`SPEC.md, ${name}: no rule of it listed in vectors/rules.json`);
    let rest = spec.get(name) ?? "";
    for (const text of [...passage.rules.map((r) => r.rule), ...passage["no rule"]]) {
      if (!rest.includes(text))
        expect.fail(`vectors/rules.json, ${name}: "${text}" is not in SPEC.md's passage`);
      rest = rest.replace(text, " ");
    }
    const left = rest
      .replace(/[\s,;:.()]+/g, " ")
      .replace(/\band\b/g, " ")
      .trim();
    if (left !== "")
      expect.fail(
        `SPEC.md, ${name}: "${left}" is neither a rule listed in vectors/rules.json with its vectors, nor listed there as no rule`,
      );
    for (const r of passage.rules)
      if (r.vectors.length === 0) expect.fail(`vectors/rules.json, ${name}: "${r.rule}" has no vector`);
  });
  it("every passage of vectors/rules.json is SPEC.md's", () => {
    expect(Object.keys(listed).filter((n) => !spec.has(n))).toEqual([]);
  });
  it("every reject vector names a rule, and every vector named is a reject vector", () => {
    const named = new Set(Object.values(listed).flatMap((p) => p.rules.flatMap((r) => r.vectors)));
    expect(rejects.filter((v) => !named.has(v))).toEqual([]);
    expect([...named].filter((v) => !rejects.includes(v))).toEqual([]);
  });
  const cases = Object.entries(listed).flatMap(([name, p]) =>
    p.rules.flatMap((r) => r.vectors.map((v) => [v, `${name}: ${r.rule}`, r.refused] as const)),
  );
  it.each(cases)("%s is refused by the TypeScript form for %s", (vector, _, refused) => {
    const e = fault(vector);
    expect(e).not.toBe("");
    if (!refused.some((r) => e.includes(r)))
      expect.fail(`${vector}: refused for "${e}", not for the rule named`);
  });
});
