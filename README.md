# qi-v2-contracts

The contracts shared by the qi-v2 projects, each defined once: a folder a contract, each with its spec (`SPEC.md`),
its forms, its vectors, and its own version, released on its own and tagged `<contract>-<version>`. A contract may be
built on another, and take its records: each of its forms takes the other's form of the same language, and defines
none of those records of its own.

| Contract | What it states | Built on | Forms | Version | Tags |
|---|---|---|---|---|---|
| [`market/`](market/README.md) | the market data: the base K-line and its ongoing K-line | | TypeScript (Zod), Lean, Go; Avro and Protobuf, made from the TypeScript | 2.0.0 | `market-<version>` |
| [`chanlun/`](chanlun/README.md) | 缠论's records: the merged bar, 分型, the lines, 中枢, and the run that holds them with its K-lines | `market` | TypeScript (Zod), Lean, Go; Avro and Protobuf, made from the TypeScript | 4.0.0 | `chanlun-<version>` |

A narrower contract changes less often, and so does whatever takes it: the K-lines, released alone, stay put while 缠论's
structure moves. A new version of `chanlun` that takes the same K-lines leaves `market` as it is.

## How a contract is written

A contract is written in TypeScript as Zod schemas, which state its records, their fields and their rules. Its Avro schemas,
its Protobuf description and the types of its Go form are generated from them, and `make check` compares them. They give other languages,
and schema registries, the records' fields and types. `<contract>/ts/bin/avro.ts`, `<contract>/ts/bin/protobuf.ts` and
`<contract>/ts/bin/golang.ts` map the output of `z.toJSONSchema`, and hold nothing specific to one contract: each
contract has the same copy, which also maps a record of the contract it is built on (a namespace, a message imported, a
Go type of the other package). Protobuf's field numbers are kept in a file of their own. The rules reach none of them:
the contract's spec states them, a form writes them by hand (the Lean, and the Go beside its types), and the vectors
are what every reader in every language must read alike.

We publish both formats because each has what the other lacks. Avro needs no field numbers, but a reader must have the
schema the data was written with. A Protobuf reader needs no such schema, but its field numbers are kept by hand.
[`market/SPEC.md`](market/SPEC.md#why-both) has the comparison.

## Checks and releases

Each contract's forms decode its vectors to the same values: the conformance check, `make check`, run on every
change (`nix develop`, then `make check`; `make market` or `make chanlun` for one). A change runs again each check that
reads what it changed; every other check keeps its result, kept by what it reads: by Nix for those that read only the
repository's files and the flake's inputs, the flake's checks (`nix flake check` runs them all), and by its key in
`.stamps` for each TypeScript form's, whose packages npm gives. Each contract's checks read its own files; one built on
another reads too the other's forms it takes, so a change to `chanlun` runs no check of `market`'s. `make check FULL=1`
runs every part.

A contract is published as the flake's packages, one a contract and form (`market-ts`, `market-lean`, `market-go`,
`market-avro`, `market-proto`; `chanlun-ts`, `chanlun-lean`, `chanlun-go`, `chanlun-avro`, `chanlun-proto`); a release
of one is its version in its spec, its forms and its packages, an entry under Changes in its README, the checks passed,
then its tag, `market-<version>` or `chanlun-<version>`. A taker pins the tag of the contract it takes. The repository
holds no data and no implementation of what a contract describes.
