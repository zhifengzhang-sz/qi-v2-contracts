# qi-v2-contracts

The contracts shared by the qi-v2 projects, each defined once: a folder a contract, each with its spec (`SPEC.md`),
its forms, its vectors, and its own version, tagged `<contract>-<version>`.

| Contract | What it states | Forms | Version |
|---|---|---|---|
| [`chanlun/`](chanlun/README.md) | 缠论's records: the K-line, the merged bar, 分型, the lines, 中枢 | TypeScript (Zod), Lean; Avro and Protobuf, made from the TypeScript | 2.1.0 |

## How a contract is written

A contract is written in TypeScript as Zod schemas, which state its records, their fields and their rules. Its Avro schemas
and its Protobuf description are generated from them, and `make check` compares them. They give other languages,
and schema registries, the records' fields and types. `<contract>/ts/bin/avro.ts` and `<contract>/ts/bin/protobuf.ts` map
the output of `z.toJSONSchema`, and hold nothing specific to one contract; Protobuf's field numbers are kept in a file of their own.
The rules reach neither: the contract's spec states them, and the vectors are what every reader in every language must read
alike.

We publish both formats because each has what the other lacks. Avro needs no field numbers, but a reader must have the
schema the data was written with. A Protobuf reader needs no such schema, but its field numbers are kept by hand.
[`chanlun/SPEC.md`](chanlun/SPEC.md#why-both) has the comparison.

## Checks and releases

Each contract's forms decode its vectors to the same values: the conformance check, `make check`, run on every
change (`nix develop`, then `make check`). A contract is published as the flake's packages, one a contract and form
(`chanlun-ts`, `chanlun-lean`, `chanlun-avro`, `chanlun-proto`); a release is its version in its spec, its forms and its packages, an entry under
Changes in its README, the checks passed, then its tag. The repository holds no data and no implementation of what
a contract describes.
