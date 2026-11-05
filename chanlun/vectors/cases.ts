// The generated cases (../../Makefile, chanlun-cases): from each valid vector, changed copies made by a fixed seed, so
// that every form is asked the same many questions the vectors do not ask one by one. For each copy every form must
// give the same answer: all refuse it, or all read it and give back the same text.
//   bun chanlun/vectors/cases.ts make DIR             the copies, DIR/<group>/<copy>.json, a group a decode mode
//   bun chanlun/vectors/cases.ts compare DIR FORM...  each form's answers, DIR/<form>/<group>/<copy>.json, compared
// A group is the mode its copies are decoded in: run, massive (--massive), ongoing (--ongoing), massive-ongoing
// (--massive --ongoing). An answer is the canonical text, or a line `decode: <message>` for a fault. A copy's name
// says what was changed: <vector>.<number>.<kind>.<place>.json.
//
// The kinds: a value changed (a number by one up or down, to 0, negative, with a seventh decimal, with a sixteenth
// digit, with an exponent; a value as text, `null`, a boolean); a field dropped, a field added (a name of no record,
// one of another record's, or a name the object already has); an entry of a list dropped, doubled or moved (a record,
// a level, an entry of `extremes`); `confirmEnd` taken away, or added where it is not set.
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// the seed, and how many copies of each vector: run.json is large, so fewer
const seed = 20261105;
const vectors: readonly {
  readonly file: string;
  readonly name: string;
  readonly group: string;
  readonly copies: number;
}[] = [
  { file: "run.json", name: "run", group: "run", copies: 60 },
  { file: "small.json", name: "small", group: "run", copies: 700 },
  { file: "edge.json", name: "edge", group: "run", copies: 400 },
  { file: "massive/small.json", name: "massive-small", group: "massive", copies: 500 },
  { file: "massive/edge.json", name: "massive-edge", group: "massive", copies: 300 },
  { file: "ongoing/kline.json", name: "ongoing-kline", group: "ongoing", copies: 200 },
  { file: "ongoing/massive.json", name: "ongoing-massive", group: "massive-ongoing", copies: 200 },
];
export const groups = ["run", "massive", "ongoing", "massive-ongoing"] as const;

// mulberry32: the same numbers from the same seed
const random = (s: number) => {
  let a = s >>> 0;
  return (): number => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};

// A JSON value as written: a number its text, an object its names in order, a name possibly twice
type J =
  | { readonly t: "num"; readonly raw: string }
  | { readonly t: "str"; readonly s: string }
  | { readonly t: "bool"; readonly b: boolean }
  | { readonly t: "null" }
  | { readonly t: "arr"; readonly xs: readonly J[] }
  | { readonly t: "obj"; readonly kvs: readonly (readonly [string, J])[] };

const parse = (text: string): J => {
  let i = 0;
  const ws = () => {
    while (i < text.length && " \t\n\r".includes(text[i] ?? "")) i++;
  };
  const value = (): J => {
    ws();
    const c = text[i];
    if (c === "{") {
      i++;
      const kvs: (readonly [string, J])[] = [];
      ws();
      if (text[i] === "}") {
        i++;
        return { t: "obj", kvs };
      }
      for (;;) {
        ws();
        const k = value();
        if (k.t !== "str") throw new Error(`a name at ${i}`);
        ws();
        if (text[i++] !== ":") throw new Error(`: at ${i}`);
        kvs.push([k.s, value()]);
        ws();
        const d = text[i++];
        if (d === "}") return { t: "obj", kvs };
        if (d !== ",") throw new Error(`, at ${i}`);
      }
    }
    if (c === "[") {
      i++;
      const xs: J[] = [];
      ws();
      if (text[i] === "]") {
        i++;
        return { t: "arr", xs };
      }
      for (;;) {
        xs.push(value());
        ws();
        const d = text[i++];
        if (d === "]") return { t: "arr", xs };
        if (d !== ",") throw new Error(`, at ${i}`);
      }
    }
    if (c === '"') {
      const m = /^"(?:[^"\\]|\\.)*"/.exec(text.slice(i));
      if (m === null) throw new Error(`a string at ${i}`);
      i += m[0].length;
      return { t: "str", s: JSON.parse(m[0]) as string };
    }
    for (const [w, v] of [
      ["true", { t: "bool", b: true }],
      ["false", { t: "bool", b: false }],
      ["null", { t: "null" }],
    ] as const)
      if (text.startsWith(w, i)) {
        i += w.length;
        return v;
      }
    const m = /^-?[0-9][0-9.eE+-]*/.exec(text.slice(i));
    if (m === null) throw new Error(`a value at ${i}`);
    i += m[0].length;
    return { t: "num", raw: m[0] };
  };
  const v = value();
  ws();
  if (i !== text.length) throw new Error(`text after the value at ${i}`);
  return v;
};

// written as the vectors are: an object of records a record a line, a record on one line
const write = (j: J, top = true): string => {
  switch (j.t) {
    case "num":
      return j.raw;
    case "str":
      return JSON.stringify(j.s);
    case "bool":
      return String(j.b);
    case "null":
      return "null";
    case "arr": {
      const nested = j.xs.some((x) => x.t === "obj" || x.t === "arr");
      if (j.xs.length === 0) return "[]";
      return nested
        ? `[\n${j.xs.map((x) => write(x, false)).join(",\n")}\n]`
        : `[${j.xs.map((x) => write(x)).join(",")}]`;
    }
    case "obj": {
      const parts = j.kvs.map(([k, v]) => `${JSON.stringify(k)}${top ? ": " : ":"}${write(v, false)}`);
      const lists = j.kvs.some(([, v]) => v.t === "arr" && v.xs.some((x) => x.t === "obj" || x.t === "arr"));
      return top && lists ? `{\n${parts.join(",\n")}\n}\n` : `{${parts.join(",")}}${top ? "\n" : ""}`;
    }
  }
};

type Path = readonly (string | number)[];
// j with the value at p replaced by f of it
const update = (j: J, p: Path, f: (x: J) => J): J => {
  if (p.length === 0) return f(j);
  const [k, ...rest] = p;
  if (j.t === "obj")
    return { t: "obj", kvs: j.kvs.map(([n, v]) => [n, n === k ? update(v, rest, f) : v] as const) };
  if (j.t === "arr") return { t: "arr", xs: j.xs.map((v, i) => (i === k ? update(v, rest, f) : v)) };
  return j;
};
// every place in j, with its value
const places = (j: J, p: Path = []): (readonly [Path, J])[] => [
  [p, j],
  ...(j.t === "obj"
    ? j.kvs.flatMap(([k, v]) => places(v, [...p, k]))
    : j.t === "arr"
      ? j.xs.flatMap((v, i) => places(v, [...p, i]))
      : []),
];

// A decimal's text moved by one, exactly: the same number of digits after the point, the last not 0
const byOne = (raw: string, d: 1n | -1n): string => {
  const m = /^(-?)([0-9]+)(?:\.([0-9]+))?$/.exec(raw);
  if (m === null) return raw;
  const [, sign = "", whole = "", fraction = ""] = m;
  const scale = fraction.length;
  const v = BigInt(`${sign}${whole}${fraction}`) + d * 10n ** BigInt(scale);
  const abs = (v < 0n ? -v : v).toString().padStart(scale + 1, "0");
  const w = abs.slice(0, abs.length - scale);
  const f = abs.slice(abs.length - scale).replace(/0+$/, "");
  return `${v < 0n ? "-" : ""}${w}${f === "" ? "" : `.${f}`}`;
};
const seventh = (raw: string): string => {
  const [w, f = ""] = raw.split(".");
  return `${w}.${f.padEnd(6, "0")}1`;
};
// sixteen digits from the first that is not 0: 1s put before the whole part
const sixteenth = (raw: string): string => {
  const neg = raw.startsWith("-");
  const [w = "", f = ""] = (neg ? raw.slice(1) : raw).split(".");
  const whole = w.replace(/^0+/, "");
  const digits = `${whole}${f}`.replace(/^0+/, "").length;
  const more = Math.max(16 - digits, 0);
  const lead = whole === "" && f !== "" ? f.length - f.replace(/^0+/, "").length : 0;
  const ones = "1".repeat(Math.max(more - lead, 1));
  return `${neg ? "-" : ""}${ones}${whole}${f === "" ? "" : `.${f}`}`;
};

type Change = { readonly kind: string; readonly place: Path; readonly copy: J };
const name = (p: Path): string => (p.length === 0 ? "top" : p.join("."));

// The changes of one kind at one place picked at random, or undefined where the kind has no place in j
const change = (j: J, kind: string, pick: <T>(xs: readonly T[]) => T | undefined): Change | undefined => {
  const all = places(j);
  const nums = all.filter(([, v]) => v.t === "num");
  const leaves = all.filter(([, v]) => v.t === "num" || v.t === "bool");
  const objects = all.filter(([, v]) => v.t === "obj");
  const lists = all.filter(([p, v]) => v.t === "arr" && v.xs.length > 0 && p.length > 0);
  const value = (from: readonly (readonly [Path, J])[], f: (x: J) => J | undefined): Change | undefined => {
    const target = pick(from);
    if (target === undefined) return undefined;
    const to = f(target[1]);
    return to === undefined ? undefined : { kind, place: target[0], copy: update(j, target[0], () => to) };
  };
  const num = (f: (raw: string) => string) =>
    value(nums, (x) => (x.t === "num" ? { t: "num", raw: f(x.raw) } : x));
  // records that may have `confirmEnd`: a merged bar, a line, a 中枢
  const confirmable = objects.filter(([p]) => {
    const part = p[0];
    return (
      p.length >= 2 &&
      (part === "merged" ||
        part === "strokes" ||
        part === "segments" ||
        part === "moves" ||
        part === "consolidations") &&
      p.length === (part === "merged" || part === "strokes" ? 2 : 3)
    );
  });
  const has = (x: J, k: string) => x.t === "obj" && x.kvs.some(([n]) => n === k);
  switch (kind) {
    case "plus-one":
      return num((r) => byOne(r, 1n));
    case "minus-one":
      return num((r) => byOne(r, -1n));
    case "zero":
      return value(leaves, () => ({ t: "num", raw: "0" }));
    case "negative":
      return num((r) => (r.startsWith("-") ? r.slice(1) : `-${r}`));
    case "seventh-decimal":
      return num(seventh);
    case "sixteenth-digit":
      return num(sixteenth);
    case "exponent":
      return num((r) => `${r}e0`);
    case "as-text":
      return value(leaves, (x) => ({
        t: "str",
        s: x.t === "num" ? x.raw : x.t === "bool" ? String(x.b) : "",
      }));
    case "null":
      return value(leaves, () => ({ t: "null" }));
    case "boolean":
      return value(leaves, (x) => ({ t: "bool", b: x.t === "bool" ? !x.b : pick([true, false]) === true }));
    case "field-dropped":
      return value(
        objects.filter(([, v]) => v.t === "obj" && v.kvs.length > 0),
        (x) => {
          if (x.t !== "obj") return undefined;
          const k = pick(x.kvs.map(([n]) => n));
          return { t: "obj", kvs: x.kvs.filter(([n]) => n !== k) };
        },
      );
    case "field-added":
      return value(objects, (x) => {
        if (x.t !== "obj") return undefined;
        const names = [
          "extra",
          "confirmStart",
          "level",
          "asOf",
          "vw",
          "n",
          "mIndex",
          "index",
          "up",
          "kind",
        ].filter((n) => !has(x, n));
        const k = pick(names) ?? "extra";
        return { t: "obj", kvs: [...x.kvs, [k, { t: "num", raw: "0" }]] };
      });
    case "name-twice":
      return value(
        objects.filter(([, v]) => v.t === "obj" && v.kvs.length > 0),
        (x) => {
          if (x.t !== "obj") return undefined;
          const kv = pick(x.kvs);
          return kv === undefined ? undefined : { t: "obj", kvs: [...x.kvs, kv] };
        },
      );
    case "entry-dropped":
      return value(lists, (x) => {
        if (x.t !== "arr") return undefined;
        const i = Math.floor(rand() * x.xs.length);
        return { t: "arr", xs: x.xs.filter((_, k) => k !== i) };
      });
    case "entry-doubled":
      return value(lists, (x) => {
        if (x.t !== "arr") return undefined;
        const i = Math.floor(rand() * x.xs.length);
        return { t: "arr", xs: x.xs.flatMap((v, k) => (k === i ? [v, v] : [v])) };
      });
    case "entry-moved":
      return value(
        lists.filter(([, v]) => v.t === "arr" && v.xs.length > 1),
        (x) => {
          if (x.t !== "arr") return undefined;
          const i = Math.floor(rand() * x.xs.length);
          const k = (i + 1 + Math.floor(rand() * (x.xs.length - 1))) % x.xs.length;
          const rest = x.xs.filter((_, n) => n !== i);
          const v = x.xs[i];
          return v === undefined ? undefined : { t: "arr", xs: [...rest.slice(0, k), v, ...rest.slice(k)] };
        },
      );
    case "confirm-end-dropped":
      return value(
        confirmable.filter(([, v]) => has(v, "confirmEnd")),
        (x) => (x.t === "obj" ? { t: "obj", kvs: x.kvs.filter(([n]) => n !== "confirmEnd") } : undefined),
      );
    case "confirm-end-added":
      return value(
        confirmable.filter(([, v]) => !has(v, "confirmEnd")),
        (x) => {
          if (x.t !== "obj") return undefined;
          const end = x.kvs.find(([n]) => n === "end")?.[1] ?? { t: "num", raw: "0" };
          const kvs = [...x.kvs, ["confirmEnd", end] as const].sort(([a], [b]) =>
            a < b ? -1 : a > b ? 1 : 0,
          );
          return { t: "obj", kvs };
        },
      );
    default:
      return undefined;
  }
};

export const kinds = [
  "plus-one",
  "minus-one",
  "zero",
  "negative",
  "seventh-decimal",
  "sixteenth-digit",
  "exponent",
  "as-text",
  "null",
  "boolean",
  "field-dropped",
  "field-added",
  "name-twice",
  "entry-dropped",
  "entry-doubled",
  "entry-moved",
  "confirm-end-dropped",
  "confirm-end-added",
] as const;

const rand = random(seed);
const pick = <T>(xs: readonly T[]): T | undefined => xs[Math.floor(rand() * xs.length)];

const make = (dir: string) => {
  const V = import.meta.dirname;
  const counts = new Map<string, number>();
  for (const g of groups) mkdirSync(join(dir, g), { recursive: true });
  let total = 0;
  for (const v of vectors) {
    const j = parse(readFileSync(join(V, v.file), "utf8"));
    let n = 0;
    let tries = 0;
    while (n < v.copies && tries < v.copies * 20) {
      tries++;
      const kind = pick(kinds) ?? "zero";
      const c = change(j, kind, pick);
      if (c === undefined) continue;
      const file = `${v.name}.${String(n).padStart(4, "0")}.${c.kind}.${name(c.place)}.json`;
      writeFileSync(join(dir, v.group, file), write(c.copy));
      counts.set(kind, (counts.get(kind) ?? 0) + 1);
      n++;
    }
    total += n;
  }
  process.stdout.write(
    `cases: ${total} copies by seed ${seed}: ${kinds.map((k) => `${k} ${counts.get(k) ?? 0}`).join(", ")}\n`,
  );
};

const compare = (dir: string, forms: readonly string[]) => {
  let copies = 0;
  let read = 0;
  let refused = 0;
  const disagree: string[] = [];
  for (const g of groups) {
    for (const file of readdirSync(join(dir, g)).sort()) {
      copies++;
      const answers = forms.map((f) => {
        try {
          return readFileSync(join(dir, f, g, file), "utf8");
        } catch {
          return "(no answer)";
        }
      });
      const fault = answers.map((a) => a.startsWith("decode: "));
      if (fault.every((x) => x)) refused++;
      else if (
        !fault.some((x) => x) &&
        answers.every((a) => a === answers[0]) &&
        answers[0] !== "(no answer)"
      )
        read++;
      else
        disagree.push(
          `cases: ${g}/${file}: ${forms
            .map(
              (f, i) =>
                `${f} ${fault[i] ? (answers[i] ?? "").trimEnd() : answers[i] === "(no answer)" ? "no answer" : `text of ${answers[i]?.length} bytes`}`,
            )
            .join("; ")}`,
        );
    }
  }
  for (const d of disagree) process.stdout.write(`${d}\n`);
  const line = `${copies} generated cases by seed ${seed}, each given the same answer by ${forms.length} forms (${forms.join(", ")}): ${read} read and given back alike, ${refused} refused by all`;
  if (disagree.length > 0) {
    process.stdout.write(`chanlun cases: ${disagree.length} of ${copies} not answered alike: FAIL\n`);
    process.exit(1);
  }
  process.stdout.write(`chanlun cases: ${line}: PASS\n`);
};

const [mode, dir, ...forms] = process.argv.slice(2);
if (mode === "make" && dir !== undefined) make(dir);
else if (mode === "compare" && dir !== undefined && forms.length > 0) compare(dir, forms);
else {
  process.stderr.write("usage: bun cases.ts make DIR | bun cases.ts compare DIR FORM...\n");
  process.exit(1);
}
