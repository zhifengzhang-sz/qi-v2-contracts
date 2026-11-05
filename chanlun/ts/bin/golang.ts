// A contract's Go types from its Zod schemas (../../../README.md, How a contract is written): the JSON Schema Zod gives
// for its records, by name (z.toJSONSchema of a registry), as one Go file of struct types, gofmt's layout. The types
// hold the records' fields and types, not their rules (a refine is a function, which Zod's JSON Schema leaves out):
// the Go form's own code, written by hand, checks the rules and reads and writes the JSON. Nothing here is the
// contract's own: it serves every contract.
//
// The mapping: a record a struct of its name; a field exported, its name the record's with its first letter
// capitalized, and tagged `<tag>:"<the record's name>"`, the tag the package's name, by which the hand-written JSON
// finds it; a whole number not below 0 `uint64`; a number that may have a fraction `Decimal`; `bool`; an array
// `List[T]` and an array of arrays `List[List[T]]`; a field not required `Optional[T]`. `Decimal`, `List` and
// `Optional` are the Go form's own, written by hand: values that hold no exported slice, map or pointer. Anything else
// is refused: a record not named, a union, a name with no Go form, and a text or a whole number that may be below 0,
// which the hand-written JSON does not read (a contract that has one adds it there and here together).

// What Zod's JSON Schema gives for a record, of what the mapping reads
export type Schema = {
  readonly type?: string;
  readonly minimum?: number;
  readonly items?: Schema;
  readonly $ref?: string;
  readonly properties?: { readonly [name: string]: Schema };
  readonly required?: readonly string[];
};

export type Generated =
  | { readonly ok: true; readonly text: string }
  | { readonly ok: false; readonly error: string };

const allowed = /^[A-Za-z][A-Za-z0-9]*$/;
const exported = (name: string): string => `${name.charAt(0).toUpperCase()}${name.slice(1)}`;

const type = (schemas: { readonly [name: string]: Schema }, s: Schema): string | undefined => {
  if (s.$ref !== undefined) return schemas[s.$ref] === undefined ? undefined : s.$ref;
  if (s.type === "integer") return (s.minimum ?? -1) >= 0 ? "uint64" : undefined;
  if (s.type === "number") return "Decimal";
  if (s.type === "boolean") return "bool";
  if (s.type === "array" && s.items !== undefined) {
    const item = type(schemas, s.items);
    return item === undefined ? undefined : `List[${item}]`;
  }
  return undefined;
};

// A struct's lines in gofmt's layout: a field a line, its name, type and tag each in a column as wide as its widest,
// and a space
const struct = (name: string, fields: readonly (readonly [string, string, string])[]): string => {
  const w0 = Math.max(...fields.map(([n]) => n.length));
  const w1 = Math.max(...fields.map(([, t]) => t.length));
  return [
    `type ${name} struct {`,
    ...fields.map(([n, t, tag]) => `\t${n.padEnd(w0)} ${t.padEnd(w1)} ${tag}`),
    "}",
  ].join("\n");
};

// The Go file of the records `schemas` (z.toJSONSchema of a registry: its `schemas`, by name, in their order), in the
// package `pkg`, its fields tagged by its name, headed by `header`, a comment's lines, each record with its line of
// `docs`
export const golang = (
  schemas: { readonly [name: string]: Schema },
  docs: { readonly [name: string]: string },
  pkg: string,
  header: readonly string[],
  constants: readonly (readonly [string, string, string])[],
): Generated => {
  const faults: string[] = [];
  const records = Object.entries(schemas).map(([name, s]) => {
    if (!allowed.test(name)) faults.push(`${name}: a name with no Go form`);
    if (s.type !== "object" || s.properties === undefined) {
      faults.push(`${name}: not a record`);
      return "";
    }
    const doc = docs[name];
    if (doc === undefined) faults.push(`${name}: no line of docs`);
    const required = new Set(s.required ?? []);
    const fields = Object.entries(s.properties).map(([f, fs]) => {
      if (!allowed.test(f)) faults.push(`${name}.${f}: a name with no Go form`);
      const t = type(schemas, fs);
      if (t === undefined) faults.push(`${name}.${f}: a type with no Go form`);
      const go = t === undefined ? "" : required.has(f) ? t : `Optional[${t}]`;
      return [exported(f), go, `\`${pkg}:"${f}"\``] as const;
    });
    if (fields.length === 0) faults.push(`${name}: a record of no field`);
    return `// ${name}: ${doc ?? ""}\n${struct(name, fields)}`;
  });
  if (faults.length > 0) return { ok: false, error: [...new Set(faults)].join("\n") };
  const consts = constants.map(([n, doc, v]) => `// ${n}: ${doc}\nconst ${n} = ${JSON.stringify(v)}`);
  const text = [
    ...header.map((h) => `// ${h}`.trimEnd()),
    "",
    `package ${pkg}`,
    "",
    [...consts, ...records].join("\n\n"),
    "",
  ].join("\n");
  return { ok: true, text };
};
