// Makes a contract's Avro schemas from its Zod schemas (../../../README.md, How a contract is written). The input is
// the JSON Schema Zod gives for the records by name (z.toJSONSchema of a registry). The output is one schema for each
// record, complete in itself, so that a single file can be registered in a schema registry. The schemas hold the
// records' fields and types, not their rules: a refine is a function, which Zod's JSON Schema leaves out. Nothing here
// is specific to one contract.
//
// The mapping:
// - a whole number is a `long`, a number that may have a fraction a `double`, and a union of whole constants an `int`;
// - `boolean` and `string` stay as they are;
// - a record is a `record`, written out where it first appears in a schema and named after that;
// - an array is an `array`;
// - a field that is not required is a union of `null` and its type, `null` by default.
// Names stay the records' own, and must be names Avro allows. A record of another contract, the one this contract is
// built on (`external`, its namespace by its name), is written out as any record is, in its own namespace, and has no
// file here: its contract publishes it. Anything else is refused.

// What Zod's JSON Schema gives for a record, of what the mapping reads
export type Schema = {
  readonly type?: string;
  readonly const?: unknown;
  readonly anyOf?: readonly Schema[];
  readonly items?: Schema;
  readonly $ref?: string;
  readonly properties?: { readonly [name: string]: Schema };
  readonly required?: readonly string[];
};

export type Generated =
  | { readonly ok: true; readonly files: { readonly [file: string]: string } }
  | { readonly ok: false; readonly error: string };

type Avro = string | readonly Avro[] | { readonly [key: string]: unknown };

const allowed = /^[A-Za-z_][A-Za-z0-9_]*$/;
const largestInt = 2147483647;

// The schema of the record `id`, with every record it uses written out once, each in its namespace: `namespace`, or
// its contract's for a record of `external`; written with it where it differs from the record around it, and named by
// its full name where it differs so. Faults are added to `faults`.
const schemaOf = (
  schemas: { readonly [name: string]: Schema },
  id: string,
  namespace: string,
  external: { readonly [name: string]: string },
  faults: string[],
): Avro => {
  const written = new Set<string>();
  const space = (name: string): string => external[name] ?? namespace;
  const type = (at: string, s: Schema, around: string): Avro => {
    if (s.$ref !== undefined) {
      if (written.has(s.$ref)) return space(s.$ref) === around ? s.$ref : `${space(s.$ref)}.${s.$ref}`;
      const held = schemas[s.$ref];
      if (held !== undefined) return record(s.$ref, held, around);
      faults.push(`${at}: no record ${s.$ref}`);
      return "null";
    }
    if (s.type === "integer") return "long";
    if (s.type === "number") return "double";
    if (s.type === "boolean" || s.type === "string") return s.type;
    if (s.type === "array" && s.items !== undefined)
      return { type: "array", items: type(at, s.items, around) };
    const consts = s.anyOf?.map((a) => a.const);
    if (
      consts !== undefined &&
      consts.length > 0 &&
      consts.every((c) => Number.isInteger(c) && Math.abs(c as number) <= largestInt)
    )
      return "int";
    faults.push(`${at}: a type with no Avro form`);
    return "null";
  };
  const record = (name: string, s: Schema, around: string | undefined): Avro => {
    written.add(name);
    if (!allowed.test(name)) faults.push(`${name}: a name Avro does not allow`);
    if (s.type !== "object" || s.properties === undefined) {
      faults.push(`${name}: not a record`);
      return "null";
    }
    const here = space(name);
    const required = new Set(s.required ?? []);
    const fields = Object.entries(s.properties).map(([f, fs]) => {
      if (!allowed.test(f)) faults.push(`${name}.${f}: a name Avro does not allow`);
      const t = type(`${name}.${f}`, fs, here);
      return required.has(f) ? { name: f, type: t } : { name: f, type: ["null", t], default: null };
    });
    return { type: "record", name, ...(here === around ? {} : { namespace: here }), fields };
  };
  return record(id, schemas[id] ?? {}, undefined);
};

// The schemas of `schemas` (the `schemas` of z.toJSONSchema of a registry, by name), as one file for each record but
// those of `external`, records of the contract this one is built on, by name with their namespace
export const avro = (
  schemas: { readonly [name: string]: Schema },
  namespace: string,
  external: { readonly [name: string]: string } = {},
): Generated => {
  const faults: string[] = [];
  const files = Object.keys(schemas)
    .filter((id) => external[id] === undefined)
    .map(
      (id) =>
        [
          `${id}.avsc`,
          `${JSON.stringify(schemaOf(schemas, id, namespace, external, faults), null, 2)}\n`,
        ] as const,
    );
  return faults.length > 0
    ? { ok: false, error: [...new Set(faults)].join("\n") }
    : { ok: true, files: Object.fromEntries(files) };
};
