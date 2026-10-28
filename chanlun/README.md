# chanlun: 缠论's contract

The records the algorithm of 缠论 gives over a run of bars, of whatever implementation gives them, and how they cross
from one project to another as JSON: `SPEC.md`. Two forms, the same records: TypeScript (`ts/`, `@qi/chanlun`, Zod)
and Lean (`lean/`, the Lake package `chanlun`, no Mathlib). The vectors (`vectors/`) are what both read alike,
checked on every change (`make chanlun`).

## Taking it

By the flake, pinned in the taker's `flake.lock` (`inputs.contracts.url =
"github:zhifengzhang-sz/qi-v2-contracts?ref=chanlun-1.1.0";`):

- `contracts.packages.${system}.chanlun-ts`: `node_modules/@qi/chanlun` and `zod`, as source; `import { decodeRun,
  klineSchema } from "@qi/chanlun"`.
- `contracts.packages.${system}.chanlun-lean`: the Lake package as source; `import Chanlun`.
- `contracts.packages.${system}.chanlun-proto`: `chanlun.proto`, the records' fields and types for any other
  language (`SPEC.md`, The Protobuf description).

Or by the language's own lock: Lake, `[[require]]` with `name = "chanlun"`, `git =
"https://github.com/zhifengzhang-sz/qi-v2-contracts"`, `rev = "chanlun-1.1.0"`, `subDir = "chanlun/lean"`.

## Using it

TypeScript: `decodeRun(text)` gives `{ ok: true, run }` or `{ ok: false, error }`; `encodeRun(run)` the canonical
JSON; `timeAt(run, p)` the time of the K-line at position `p`; each record's schema (`klineSchema`, …) for one record.

Lean: `Chanlun.decodeRun text : Except String Run`, `Chanlun.encodeRun run : String`, `run.timeAt p : Option Nat`;
the structures `KLine`, `MergedBar`, `Fractal`, `Line`, `Centre`, `Run`, with `ToJson` and `FromJson`.

A producer's output is mapped to the records by the producer or by its user, not by the contract.

## Changes

- **1.1.0**: the Protobuf description, `proto/chanlun.proto`, made from the Zod schemas with the field numbers of
  `proto/fields.json` and checked against them; the package `chanlun-proto`. The records, the JSON and the vectors
  unchanged.
- **1.0.0**: the records (K-line, merged bar, 分型, the lines of every level, 中枢 with every date) and the run's rules;
  the JSON, its numbers and texts, and its canonical text; the TypeScript and Lean forms; the vectors (a run over
  4,000 bars made up, a small run, an edge run, 38 reject cases).
