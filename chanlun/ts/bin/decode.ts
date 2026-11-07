// A run's JSON decoded and written again as its canonical JSON (the conformance check's TypeScript side; an ongoing
// K-line is market's, ../../../market/ts/bin/decode.ts):
//   bun bin/decode.ts FILE
// The file's bytes are read as UTF-8, a byte that is not UTF-8 refused, not replaced. A fault to stderr, exit 1.
// With --batch, every .json file of the folder IN, in the order of their names, decoded so in one process (the
// generated cases, ../../vectors/cases.ts), each one's answer written to OUT under its name: its canonical text, or
// the line `decode: ` and its fault:
//   bun bin/decode.ts --batch IN OUT
import { readdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { decodeRun, encodeRun } from "../src/codec.ts";

const usage = "usage: bun bin/decode.ts FILE | --batch IN OUT";
const fail = (error: string): never => {
  process.stderr.write(`decode: ${error}\n`);
  return process.exit(1);
};
const args = process.argv.slice(2);
const batch = args.includes("--batch");
const files = args.filter((a) => a !== "--batch");

// A file's bytes as its answer: the canonical text, or its fault
const answer = (
  bytes: Uint8Array,
): { readonly ok: true; readonly text: string } | { readonly ok: false; readonly error: string } => {
  const text = (() => {
    try {
      return new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);
    } catch {
      return undefined;
    }
  })();
  if (text === undefined) return { ok: false, error: "text not UTF-8" };
  const r = decodeRun(text);
  return !r.ok ? r : { ok: true, text: encodeRun(r.run) };
};

if (batch) {
  const [inDir, outDir] = files;
  if (files.length !== 2 || inDir === undefined || outDir === undefined) fail(usage);
  const names = (await readdir(inDir ?? "").catch(() => fail(`cannot read ${inDir}`)))
    .filter((n) => n.endsWith(".json"))
    .sort();
  for (const n of names) {
    const bytes = await readFile(join(inDir ?? "", n)).catch(() => fail(`cannot read ${n}`));
    const r = answer(bytes);
    await writeFile(join(outDir ?? "", n), r.ok ? r.text : `decode: ${r.error}\n`).catch(() =>
      fail(`cannot write ${join(outDir ?? "", n)}`),
    );
  }
} else {
  const file = files.length === 1 ? files[0] : undefined;
  if (file === undefined || file.startsWith("--")) fail(usage);
  const bytes = await readFile(file ?? "").catch(() => fail(`cannot read ${file}`));
  const r = answer(bytes);
  if (!r.ok) fail(r.error);
  else process.stdout.write(r.text);
}
