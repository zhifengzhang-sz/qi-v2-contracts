# qi-v2-contracts: what it owns, gives and takes

## Responsibility

It owns the contracts shared by the qi-v2 projects, each defined once: the records, their forms and their vectors. A
contract is a folder with its spec, its forms, its vectors and its own version, released on its own, tagged
`<contract>-<version>`. Two products: `market`, the market data contract, the K-lines; and `chanlun`, 缠论's contract,
built on market's K-line. It holds no data and no implementation of what a contract describes.

## Products

| Product | What | Form | Version | Release | Doc |
|---|---|---|---|---|---|
| `market-ts` | the market data contract for TypeScript: a `node_modules` of `@qi/market` and zod | `flake package` | `1.1.0` | tag `market-<version>` | `market/SPEC.md` |
| `market-lean` | the market data contract for Lean: the Lake package `market` | `flake package` | `1.1.0` | tag `market-<version>` | `market/SPEC.md` |
| `market-go` | the market data contract for Go: the module `github.com/zhifengzhang-sz/qi-v2-contracts/market/go`, the standard library only | `flake package` | `1.1.0` | tag `market-<version>` | `market/SPEC.md` |
| `market-avro` | the market data contract as Avro: one `.avsc` file for each record, with its fields and types | `flake package` | `1.1.0` | tag `market-<version>` | `market/SPEC.md` |
| `market-proto` | the market data contract as Protobuf: `market.proto`, with the records' fields and types | `flake package` | `1.1.0` | tag `market-<version>` | `market/SPEC.md` |
| `chanlun-ts` | 缠论's contract for TypeScript: a `node_modules` of `@qi/chanlun`, `@qi/market` and zod | `flake package` | `3.1.0` | tag `chanlun-<version>` | `chanlun/SPEC.md` |
| `chanlun-lean` | 缠论's contract for Lean: the Lake package `chanlun`, and the Lake package `market` it requires, where it requires it | `flake package` | `3.1.0` | tag `chanlun-<version>` | `chanlun/SPEC.md` |
| `chanlun-go` | 缠论's contract for Go: the module `github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go`, the standard library and market's module only (`market-go`) | `flake package` | `3.1.0` | tag `chanlun-<version>` | `chanlun/SPEC.md` |
| `chanlun-avro` | 缠论's contract as Avro: one `.avsc` file for each record, with its fields and types | `flake package` | `3.1.0` | tag `chanlun-<version>` | `chanlun/SPEC.md` |
| `chanlun-proto` | 缠论's contract as Protobuf: `chanlun.proto`, with the records' fields and types | `flake package` | `3.1.0` | tag `chanlun-<version>` | `chanlun/SPEC.md` |

## Takes

| Product | From | Pinned by |
|---|---|---|
| `qi-v2` | `qi-v2-nix` | `flake.lock` |
| `nixpkgs` | `qi-v2`, which it follows | `flake.lock` |
| `kit` | `qi-v2-nix` | `flake.lock` |
