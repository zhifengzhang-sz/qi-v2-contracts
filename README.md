# qi-v2-contracts

The contracts shared by the qi-v2 projects. A contract states records and their rules, and nothing of how they are
used. Each is a folder, released on its own and tagged `<contract>-<version>`.

| Contract | What it states | Version |
|---|---|---|
| [`market/`](market/README.md) | the K-line and the ongoing K-line | 2.0.0 |
| [`chanlun/`](chanlun/README.md) | 缠论's merged bar, 分型, lines and 中枢 | 4.0.0 |

## A contract

| Part | What it is |
|---|---|
| `proto/<contract>.proto` | the records |
| `lean/` | the rules, defined formally: each a name, and what holds of a record that keeps it |
| `examples.json` | records, each with the rules it breaks |
| `go/`, `ts/` | Go and TypeScript: the records' code generated from the `.proto` by `buf generate` (`make generate`), and the rules by the same names |

A language implements the rules when, on every example, it gives the names of exactly the rules the example names.

## Checks and releases

In the shell (`nix develop`), `make check`: `buf lint` and Biome; for each contract, its generated code what its
`.proto` makes, and its examples checked by Lean, Go and TypeScript; `PRODUCTS.md` against the project (`kit`).

A release of a contract: its version in `ts/package.json`, `lean/lakefile.toml` and its README, an entry under
Changes; `make check`; `make breaking`, the `.proto` against the contract's last release, where a break is a new major
version; `make packages`, the flake's packages built; then the tag. A taker pins the tag.
