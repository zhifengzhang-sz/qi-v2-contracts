// A run's JSON decoded and written again as its canonical JSON (the conformance check's TypeScript side), with
// --massive a run of Massive's K-lines, with --ongoing an ongoing K-line, of the base or with --massive Massive's:
//   bun bin/decode.ts [--massive] [--ongoing] FILE
// The file's bytes are read as UTF-8, a byte that is not UTF-8 refused, not replaced. A fault to stderr, exit 1.
import { readFile } from "node:fs/promises";
import {
  decodeMassiveOngoingKLine,
  decodeMassiveRun,
  decodeOngoingKLine,
  decodeRun,
  encodeOngoingKLine,
  encodeRun,
} from "../src/codec.ts";

const fail = (error: string): never => {
  process.stderr.write(`decode: ${error}\n`);
  return process.exit(1);
};
const args = process.argv.slice(2);
const massive = args.includes("--massive");
const ongoing = args.includes("--ongoing");
const files = args.filter((a) => a !== "--massive" && a !== "--ongoing");
const file = files.length === 1 ? files[0] : undefined;
if (file === undefined || file.startsWith("--"))
  fail("usage: bun bin/decode.ts [--massive] [--ongoing] FILE");
const bytes = await readFile(file ?? "").catch(() => fail(`cannot read ${file}`));
const text = (() => {
  try {
    return new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);
  } catch {
    return fail("text not UTF-8");
  }
})();
const r = ongoing
  ? (massive ? decodeMassiveOngoingKLine : decodeOngoingKLine)(text)
  : (massive ? decodeMassiveRun : decodeRun)(text);
if (!r.ok) fail(r.error);
else process.stdout.write("run" in r ? encodeRun(r.run) : encodeOngoingKLine(r.kline));
