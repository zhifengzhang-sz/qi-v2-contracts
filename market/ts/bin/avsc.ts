// The market data contract as Avro (../../SPEC.md, The Avro schemas). Makes ../avro/<record>.avsc from the Zod schemas
// of ../src. With --check, it instead compares what it would make with the files of a folder, ../avro if none is named,
// and has an Avro implementation read each of them:
//   bun bin/avsc.ts [--check [DIR]]
// A fault goes to stderr, with exit 1.
import { readdir, readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import avsc from "avsc";
import { z } from "zod";
import { klineSchema, ongoingKlineSchema } from "../src/index.ts";
import { avro, type Schema } from "./avro.ts";

const home = join(import.meta.dirname, "..", "..", "avro");
const namespace = "qi.market.v1";
const records = z
  .registry<{ id: string }>()
  .add(klineSchema, { id: "KLine" })
  .add(ongoingKlineSchema, { id: "OngoingKLine" });
const fail = (error: string): never => {
  process.stderr.write(`avsc: ${error}\n`);
  return process.exit(1);
};

// Zod's JSON Schema, of which the mapping reads its part (Schema)
const schemas = z.toJSONSchema(records, { unrepresentable: "throw" }).schemas as {
  readonly [name: string]: Schema;
};
const made = avro(schemas, namespace);
if (!made.ok) fail(made.error);
else if (process.argv[2] === "--check") {
  const dir = resolve(process.argv[3] ?? home);
  const there = (await readdir(dir).catch(() => [] as string[])).filter((f) => f.endsWith(".avsc"));
  const extra = there.filter((f) => made.files[f] === undefined);
  if (extra.length > 0) fail(`${dir}: not what the schemas make: ${extra.join(", ")}`);
  for (const [file, text] of Object.entries(made.files)) {
    const now = await readFile(join(dir, file), "utf8").catch(() => "");
    if (now !== text) fail(`${join(dir, file)} is not what the schemas make: bun bin/avsc.ts`);
    try {
      avsc.Type.forSchema(JSON.parse(now));
    } catch (e) {
      fail(`${join(dir, file)}: not read by an Avro implementation: ${(e as Error).message}`);
    }
  }
  process.stdout.write(`avsc: ${dir} is what the schemas make, and an Avro implementation reads it\n`);
} else {
  await Promise.all(Object.entries(made.files).map(([file, text]) => writeFile(join(home, file), text)));
  process.stdout.write(`avsc: ${home} written\n`);
}
