// A run's JSON decoded and written again as its canonical JSON (the conformance check's TypeScript side):
//   bun bin/decode.ts FILE
// A fault to stderr, exit 1.
import { readFile } from "node:fs/promises";
import { decodeRun, encodeRun } from "../src/codec.ts";

const file = process.argv[2];
const text = file === undefined ? undefined : await readFile(file, "utf8").catch(() => undefined);
const r =
  text === undefined ? { ok: false as const, error: `cannot read ${file ?? "(no FILE)"}` } : decodeRun(text);
if (r.ok) process.stdout.write(encodeRun(r.run));
else {
  process.stderr.write(`decode: ${r.error}\n`);
  process.exit(1);
}
