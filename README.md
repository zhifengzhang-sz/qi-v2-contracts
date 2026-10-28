# qi-v2-contracts

The contracts shared by the qi-v2 projects, each defined once: a folder a contract, each with its spec (`SPEC.md`),
its forms, its vectors, and its own version, tagged `<contract>-<version>`.

| Contract | What it states | Forms | Version |
|---|---|---|---|
| [`chanlun/`](chanlun/README.md) | 缠论's records: the K-line, the merged bar, 分型, the lines of every level, 中枢 | TypeScript (Zod), Lean; Protobuf, made from the TypeScript | 1.1.0 |

## How a contract is written

In TypeScript, as Zod schemas: the records, their fields and their rules. Its Protobuf description is made from them
(z.toJSONSchema of the records by name, mapped by `<contract>/ts/bin/protobuf.ts`, which serves every contract), with
each field's number kept in a file of its own, and checked against them on every change: the records' fields and
types for every other language. The rules a refine states do not cross into it; the spec states them, and the vectors
are what every reader of every language must read alike.

## Checks and releases

Each contract's forms decode its vectors to the same values: the conformance check, `make check`, run on every
change (`nix develop`, then `make check`). A contract is published as the flake's packages, one a contract and form
(`chanlun-ts`, `chanlun-lean`); a release is its version in its spec, its forms and its packages, an entry under
Changes in its README, the checks passed, then its tag. The repository holds no data and no implementation of what
a contract describes.
