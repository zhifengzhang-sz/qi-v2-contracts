# qi-v2-contracts: what it owns, gives and takes

## Responsibility

It owns the contracts shared by the qi-v2 projects, each defined once: the records, their forms and their vectors. A
contract is a folder with its spec, its forms, its vectors and its own version. It holds no data and no implementation
of what a contract describes.

## Products

| Product | What | Form | Version | Release | Doc |
|---|---|---|---|---|---|
| `chanlun-ts` | 缠论's contract for TypeScript: a `node_modules` of `@qi/chanlun` and zod | `flake package` | `1.1.0` | tag `chanlun-<version>` | `chanlun/SPEC.md` |
| `chanlun-lean` | 缠论's contract for Lean: the Lake package `chanlun` | `flake package` | `1.1.0` | tag `chanlun-<version>` | `chanlun/SPEC.md` |
| `chanlun-proto` | 缠论's contract as Protobuf: `chanlun.proto`, the records' fields and types | `flake package` | `1.1.0` | tag `chanlun-<version>` | `chanlun/SPEC.md` |

## Takes

| Product | From | Pinned by |
|---|---|---|
| `qi-v2` | `qi-v2-nix` | `flake.lock` |
| `nixpkgs` | `qi-v2`, which it follows | `flake.lock` |
| `kit` | `qi-v2-nix` | `flake.lock` |
