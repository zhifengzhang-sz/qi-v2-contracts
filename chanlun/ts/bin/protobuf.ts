// A contract's Protobuf description from its Zod schemas (../../../README.md, How a contract is written): the JSON
// Schema Zod gives for its records, by name (z.toJSONSchema of a registry), and each field's number, kept in a file of
// its own so that a field keeps its number for good, give the .proto text: the records' fields and types, not their
// rules (a refine is a function, which Zod's JSON Schema leaves out). Nothing here is the contract's own: it serves
// every contract.
//
// The mapping: a whole number not below 0 `uint64`, else `int64`; a union of whole constants `uint32`, or `int32` when
// one is below 0; `bool`; `string`; a record its message; an array `repeated`; an array of arrays `repeated` of a
// message `<Item>List` holding `repeated <Item> items = 1`; a field not required `optional`. A field's name in
// snake_case, a letter first, whose JSON name by Protobuf's rule is the record's own. Anything else is refused.

// What Zod's JSON Schema gives for a record, of what the mapping reads
export type Schema = {
  readonly type?: string;
  readonly minimum?: number;
  readonly const?: unknown;
  readonly anyOf?: readonly Schema[];
  readonly items?: Schema;
  readonly $ref?: string;
  readonly properties?: { readonly [name: string]: Schema };
  readonly required?: readonly string[];
};

// Each message's field numbers, and the numbers of the fields it no longer has, by their old names
export type Numbers = {
  readonly package: string;
  readonly messages: {
    readonly [message: string]: {
      readonly fields: { readonly [field: string]: number };
      readonly reserved: { readonly [field: string]: number };
    };
  };
};

export type Generated =
  | { readonly ok: true; readonly text: string }
  | { readonly ok: false; readonly error: string };

type Field = { readonly type: string; readonly list: string | undefined } | { readonly error: string };

const snake = (name: string): string => name.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);
// Protobuf's JSON name of a field: each letter after `_` capitalized, the `_` dropped
const jsonName = (name: string): string => name.replace(/_([a-z0-9])/g, (_, c: string) => c.toUpperCase());

const scalar = (s: Schema): string | undefined => {
  if (s.type === "integer") return (s.minimum ?? -1) >= 0 ? "uint64" : "int64";
  if (s.type === "boolean") return "bool";
  if (s.type === "string") return "string";
  const consts = s.anyOf?.map((a) => a.const);
  if (consts !== undefined && consts.length > 0 && consts.every((c) => Number.isInteger(c)))
    return consts.some((c) => (c as number) < 0) ? "int32" : "uint32";
  return undefined;
};

const element = (s: Schema): string | undefined => s.$ref ?? scalar(s);

const field = (s: Schema): Field => {
  if (s.type !== "array") {
    const t = element(s);
    return t === undefined ? { error: "a type with no Protobuf form" } : { type: t, list: undefined };
  }
  const item = s.items ?? {};
  if (item.type !== "array") {
    const t = element(item);
    return t === undefined
      ? { error: "an array of a type with no Protobuf form" }
      : { type: `repeated ${t}`, list: undefined };
  }
  const inner = item.items === undefined ? undefined : element(item.items);
  return inner === undefined || item.items?.$ref === undefined
    ? { error: "an array of arrays of anything but a record" }
    : { type: `repeated ${inner}List`, list: inner };
};

const message = (
  name: string,
  s: Schema,
  numbers: Numbers["messages"][string] | undefined,
): { readonly text: string; readonly lists: readonly string[] } | { readonly error: string } => {
  if (s.type !== "object" || s.properties === undefined) return { error: `${name}: not a record` };
  if (numbers === undefined) return { error: `${name}: no field numbers` };
  const props = Object.entries(s.properties);
  const required = new Set(s.required ?? []);
  const names = new Set(props.map(([f]) => f));
  const missing = props.filter(([f]) => numbers.fields[f] === undefined).map(([f]) => f);
  const stale = Object.keys(numbers.fields).filter((f) => !names.has(f));
  const all = [...Object.values(numbers.fields), ...Object.values(numbers.reserved)];
  const twice = all.filter((n, i) => all.indexOf(n) !== i);
  const bad = all.filter((n) => !Number.isInteger(n) || n < 1 || (n >= 19000 && n <= 19999) || n > 536870911);
  const unnamed = props
    .map(([f]) => f)
    .filter((f) => !/^[a-z][a-z0-9]*(_[a-z0-9]+)*$/.test(snake(f)) || jsonName(snake(f)) !== f);
  const faults = [
    ...(missing.length > 0 ? [`fields with no number: ${missing.join(", ")}`] : []),
    ...(stale.length > 0
      ? [`numbers of fields it does not have (move them to reserved): ${stale.join(", ")}`]
      : []),
    ...(twice.length > 0 ? [`numbers given twice: ${twice.join(", ")}`] : []),
    ...(bad.length > 0 ? [`numbers Protobuf does not allow: ${bad.join(", ")}`] : []),
    ...(unnamed.length > 0 ? [`names with no snake_case of the same JSON name: ${unnamed.join(", ")}`] : []),
  ];
  if (faults.length > 0) return { error: `${name}: ${faults.join("; ")}` };
  const fields = props.map(([f, fs]) => ({ f, n: numbers.fields[f] ?? 0, t: field(fs) }));
  const untyped = fields.flatMap((x) => ("error" in x.t ? [`${x.f} (${x.t.error})`] : []));
  if (untyped.length > 0) return { error: `${name}: ${untyped.join(", ")}` };
  const lines = [...fields]
    .sort((a, b) => a.n - b.n)
    .map(({ f, n, t }) => {
      const type = "error" in t ? "" : t.type;
      const optional = required.has(f) || type.startsWith("repeated ") ? "" : "optional ";
      return `  ${optional}${type} ${snake(f)} = ${n};`;
    });
  const reserved = Object.entries(numbers.reserved).sort((a, b) => a[1] - b[1]);
  const kept =
    reserved.length === 0
      ? []
      : [
          `  reserved ${reserved.map(([, n]) => n).join(", ")};`,
          `  reserved ${reserved.map(([f]) => `"${snake(f)}"`).join(", ")};`,
        ];
  return {
    text: [`message ${name} {`, ...lines, ...kept, "}"].join("\n"),
    lists: fields.flatMap(({ t }) => ("error" in t || t.list === undefined ? [] : [t.list])),
  };
};

// The .proto text of the records `schemas` (z.toJSONSchema of a registry: its `schemas`, by name, in their order),
// headed by `header`, a comment's lines
export const protobuf = (
  schemas: { readonly [name: string]: Schema },
  numbers: Numbers,
  header: readonly string[],
): Generated => {
  const extra = Object.keys(numbers.messages).filter((m) => schemas[m] === undefined);
  if (extra.length > 0) return { ok: false, error: `field numbers of no record: ${extra.join(", ")}` };
  const made = Object.entries(schemas).map(([name, s]) => message(name, s, numbers.messages[name]));
  const errors = made.flatMap((m) => ("error" in m ? [m.error] : []));
  if (errors.length > 0) return { ok: false, error: errors.join("\n") };
  const ok = made.flatMap((m) => ("error" in m ? [] : [m]));
  const lists = [...new Set(ok.flatMap((m) => m.lists))];
  const clash = lists.filter((l) => schemas[`${l}List`] !== undefined);
  if (clash.length > 0)
    return {
      ok: false,
      error: `a record named as a list's message: ${clash.map((l) => `${l}List`).join(", ")}`,
    };
  const listMessages = lists.map((l) => [`message ${l}List {`, `  repeated ${l} items = 1;`, "}"].join("\n"));
  const text = [
    ...header.map((h) => `// ${h}`.trimEnd()),
    "",
    'syntax = "proto3";',
    "",
    `package ${numbers.package};`,
    "",
    [...ok.map((m) => m.text), ...listMessages].join("\n\n"),
    "",
  ].join("\n");
  return { ok: true, text };
};
