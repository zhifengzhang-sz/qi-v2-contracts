# qi-v2-contracts: what it owns, gives and takes

## Responsibility

It owns the contracts shared by the qi-v2 projects: for each, its records (a `.proto`), its rules (Lean), its examples,
and its Go and TypeScript code. Two products: `market`, the K-lines; and `chanlun`, 缠论's records beyond them. It holds
no data and no implementation of what a contract describes.

## Products

| Product | What | Form | Version | Release | Doc |
|---|---|---|---|---|---|
| `market-proto` | the market data contract's records: `market.proto` | `flake package` | `2.0.0` | tag `market-<version>` | `market/README.md` |
| `market-go` | the market data contract for Go: the module `github.com/zhifengzhang-sz/qi-v2-contracts/market/go`, its records generated and its rules | `flake package` | `2.0.0` | tag `market-<version>` | `market/README.md` |
| `market-ts` | the market data contract for TypeScript: a `node_modules` of `@qi/market` and `@bufbuild/protobuf` | `flake package` | `2.0.0` | tag `market-<version>` | `market/README.md` |
| `market-lean` | the market data contract's rules: the Lake package `market` | `flake package` | `2.0.0` | tag `market-<version>` | `market/README.md` |
| `chanlun-proto` | 缠论's contract's records: `chanlun.proto` | `flake package` | `4.0.0` | tag `chanlun-<version>` | `chanlun/README.md` |
| `chanlun-go` | 缠论's contract for Go: the module `github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go`, its records generated and its rules | `flake package` | `4.0.0` | tag `chanlun-<version>` | `chanlun/README.md` |
| `chanlun-ts` | 缠论's contract for TypeScript: a `node_modules` of `@qi/chanlun` and `@bufbuild/protobuf` | `flake package` | `4.0.0` | tag `chanlun-<version>` | `chanlun/README.md` |
| `chanlun-lean` | 缠论's contract's rules: the Lake package `chanlun` | `flake package` | `4.0.0` | tag `chanlun-<version>` | `chanlun/README.md` |

## Takes

| Product | From | Pinned by |
|---|---|---|
| `qi-v2` | `qi-v2-nix` | `flake.lock` |
| `nixpkgs` | `qi-v2`, which it follows | `flake.lock` |
| `kit` | `qi-v2-nix` | `flake.lock` |
