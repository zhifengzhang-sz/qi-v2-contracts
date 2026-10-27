# qi-v2-contracts

The contracts shared by the qi-v2 projects, each defined once: a folder a contract, each with its spec (`SPEC.md`),
its forms, its vectors, and its own version, tagged `<contract>-<version>`.

| Contract | What it states | Forms | Version |
|---|---|---|---|
| [`chanlun/`](chanlun/README.md) | 缠论's records: the K-line, the merged bar, 分型, the lines of every level, 中枢 | TypeScript (Zod), Lean | 1.0.0 |

Each contract's forms decode its vectors to the same values: the conformance check, `make check`, run on every
change (`nix develop`, then `make check`). A contract is published as the flake's packages, one a contract and form
(`chanlun-ts`, `chanlun-lean`); a release is its version in its spec, its forms and its packages, an entry under
Changes in its README, the checks passed, then its tag. The repository holds no data and no implementation of what
a contract describes.
