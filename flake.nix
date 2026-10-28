{
  # The contracts shared by the qi-v2 projects, each defined once (README.md): a folder a contract, its spec and its
  # forms. Packages: chanlun-ts (缠论's contract for TypeScript), chanlun-lean (for Lean) and chanlun-proto (its
  # Protobuf description, made from the TypeScript). The common flake, qi-v2,
  # gives the one nixpkgs of every project and the pure shell.
  description = "qi-v2-contracts: the contracts shared by the qi-v2 projects (chanlun: 缠论's records)";

  inputs.qi-v2.url = "github:zhifengzhang-sz/qi-v2-nix?dir=qi-v2";
  inputs.nixpkgs.follows = "qi-v2/nixpkgs";

  outputs = { self, nixpkgs, qi-v2 }:
    let
      # the systems qi-v2's Lean is pinned for
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAll (pkgs: {
        default = qi-v2.lib.mkPureShell pkgs {
          name = "contracts";
          # the Lean forms: Lean and Lake pinned in the store (qi-v2's lean preset); each form's lean-toolchain
          # names the same version, which make checks
          uses = [ (qi-v2.lib.lean pkgs) ];
          packages = with pkgs; [
            gnumake git gh openssh
            # the TypeScript forms: Bun runs them, Biome lints and formats them, vitest's runtime is Node; their
            # packages are pinned by each form's bun.lock
            bun biome nodejs
            # the Protobuf descriptions, made from the Zod schemas, checked by protoc
            protobuf
          ];
          # of the host, Nix itself: make packages builds the flake's packages
          hostTools = [ "nix" "nix-store" ];
          greeting = ''echo "contracts: make check runs every form, and the conformance of the forms of each contract"'';
        };
      });

      packages = forAll (pkgs:
        let
          zod = pkgs.fetchurl {
            url = "https://registry.npmjs.org/zod/-/zod-4.1.12.tgz";
            hash = "sha256-LvnXp9gisFnJvSH4fKpP3EgiDUNzU2eJhN+UL7Z7Q/o=";
          };
        in {
          # 缠论's contract for TypeScript (chanlun/README.md, how to take it): a node_modules of @qi/chanlun, as
          # source, and zod, its one dependency (npm's, pinned by hash); no tests.
          chanlun-ts = pkgs.runCommand "chanlun-ts-1.1.0" { } ''
            m=$out/node_modules
            mkdir -p $m/@qi/chanlun $m/zod
            cp -r ${./chanlun/ts/src} $m/@qi/chanlun/src
            cp ${./chanlun/ts/package.json} $m/@qi/chanlun/package.json
            tar -xzf ${zod} -C $m/zod --strip-components=1
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract for Lean (chanlun/README.md): the Lake package `chanlun` as source, for a taker's Lake.
          chanlun-lean = pkgs.runCommand "chanlun-lean-1.1.0" { } ''
            mkdir -p $out
            cp -r ${./chanlun/lean}/Chanlun $out/Chanlun
            cp ${./chanlun/lean}/Chanlun.lean ${./chanlun/lean}/Main.lean ${./chanlun/lean}/lakefile.toml ${./chanlun/lean}/lean-toolchain $out/
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract as Protobuf (chanlun/SPEC.md, The Protobuf description): chanlun.proto, the records' fields
          # and types, for a taker's protoc
          chanlun-proto = pkgs.runCommand "chanlun-proto-1.1.0" { } ''
            mkdir -p $out
            cp ${./chanlun/proto/chanlun.proto} $out/chanlun.proto
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
        });
    };
}
