// 缠论's contract as Protobuf (../../SPEC.md, The Protobuf description): ../proto/chanlun.proto made from the Zod
// schemas of ../src and the field numbers of ../proto/fields.json, or, with --check, compared with the file:
//   bun bin/proto.ts [--check]
// A fault to stderr, exit 1.
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import {
  centreSchema,
  fractalSchema,
  klineSchema,
  mergedBarSchema,
  runSchema,
  strokeSchema,
} from "../src/index.ts";
import { type Numbers, protobuf, type Schema } from "./protobuf.ts";

const dir = join(import.meta.dirname, "..", "..", "proto");
const out = join(dir, "chanlun.proto");
const records = z
  .registry<{ id: string }>()
  .add(klineSchema, { id: "KLine" })
  .add(mergedBarSchema, { id: "MergedBar" })
  .add(fractalSchema, { id: "Fractal" })
  .add(strokeSchema, { id: "Line" })
  .add(centreSchema, { id: "Centre" })
  .add(runSchema, { id: "Run" });
const fail = (error: string): never => {
  process.stderr.write(`proto: ${error}\n`);
  return process.exit(1);
};
const json = (file: string): Promise<unknown> =>
  readFile(file, "utf8")
    .then((t) => JSON.parse(t) as unknown)
    .catch(() => fail(`cannot read ${file}`));
const { version } = (await json(join(import.meta.dirname, "..", "package.json"))) as {
  readonly version: string;
};
const header = [
  `缠论's contract, chanlun ${version} (../SPEC.md): the records' fields and types, made from the Zod schemas of`,
  "../ts/src by ../ts/bin/proto.ts with the field numbers of fields.json; not edited by hand. The records' rules are",
  "not here (SPEC.md, The records and The run): every reader checks them, and reads the vectors (../vectors/) alike.",
];

const numbers = (await json(join(dir, "fields.json"))) as Numbers;
// Zod's JSON Schema, of which the mapping reads its part (Schema)
const schemas = z.toJSONSchema(records, { unrepresentable: "throw" }).schemas as {
  readonly [name: string]: Schema;
};
const made = protobuf(schemas, numbers, header);
if (!made.ok) fail(made.error);
else if (process.argv[2] === "--check") {
  const now = await readFile(out, "utf8").catch(() => "");
  if (now !== made.text) fail(`${out} is not what the schemas make: bun bin/proto.ts`);
  process.stdout.write(`proto: ${out} is what the schemas make\n`);
} else {
  await writeFile(out, made.text);
  process.stdout.write(`proto: ${out} written\n`);
}
