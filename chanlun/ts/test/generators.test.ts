// The generators hold nothing specific to one contract (../../../README.md, How a contract is written): each contract
// has the same copy, so this one's bin/avro.ts, bin/protobuf.ts and bin/golang.ts are market's, byte for byte.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const here = join(import.meta.dirname, "..", "bin");
const market = join(import.meta.dirname, "..", "..", "..", "market", "ts", "bin");

describe("the generators", () => {
  it.each(["avro.ts", "protobuf.ts", "golang.ts"])("bin/%s is market's, byte for byte", (file) => {
    expect(readFileSync(join(here, file), "utf8")).toBe(readFileSync(join(market, file), "utf8"));
  });
});
