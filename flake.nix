{
  # The contracts shared by the qi-v2 projects, each defined once (README.md): a folder a contract, its spec and its
  # forms. Packages: chanlun-ts (缠论's contract for TypeScript), chanlun-lean (for Lean), chanlun-go (for Go),
  # chanlun-avro and chanlun-proto (its Avro schemas and Protobuf description, made from the TypeScript). The common
  # flake, qi-v2, gives the one nixpkgs of every project and the pure shell.
  description = "qi-v2-contracts: the contracts shared by the qi-v2 projects (chanlun 2.2.0: 缠论's records, for TypeScript, Lean and Go, and as Avro and Protobuf)";

  inputs.qi-v2.url = "github:zhifengzhang-sz/qi-v2-nix?dir=qi-v2";
  inputs.nixpkgs.follows = "qi-v2/nixpkgs";
  inputs.kit.url = "github:zhifengzhang-sz/qi-v2-nix?dir=kit";
  inputs.kit.inputs.qi-v2.follows = "qi-v2";

  outputs = { self, nixpkgs, qi-v2, kit }:
    let
      # the systems qi-v2's Lean is pinned for
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAll (pkgs: {
        default = qi-v2.lib.mkPureShell pkgs {
          name = "contracts";
          # the Lean forms: Lean and Lake pinned in the store (qi-v2's lean preset); each form's lean-toolchain
          # names the same version, which make checks. The Go forms: Go (qi-v2's go preset), its caches under the
          # shell's own, never fetching another toolchain
          uses = [ (qi-v2.lib.lean pkgs) (qi-v2.lib.go pkgs) ];
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
          chanlun-ts = pkgs.runCommand "chanlun-ts-2.2.0" { } ''
            m=$out/node_modules
            mkdir -p $m/@qi/chanlun $m/zod
            cp -r ${./chanlun/ts/src} $m/@qi/chanlun/src
            cp ${./chanlun/ts/package.json} $m/@qi/chanlun/package.json
            tar -xzf ${zod} -C $m/zod --strip-components=1
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract for Lean (chanlun/README.md): the Lake package `chanlun` as source, for a taker's Lake.
          chanlun-lean = pkgs.runCommand "chanlun-lean-2.2.0" { } ''
            mkdir -p $out
            cp -r ${./chanlun/lean}/Chanlun $out/Chanlun
            cp ${./chanlun/lean}/Chanlun.lean ${./chanlun/lean}/Main.lean ${./chanlun/lean}/lakefile.toml ${./chanlun/lean}/lean-toolchain $out/
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract for Go (chanlun/README.md, how to take it): the module of chanlun/go as source, without its
          # tests, for a taker's go.mod to replace its module path with; the standard library only.
          chanlun-go = pkgs.runCommand "chanlun-go-2.2.0" { } ''
            mkdir -p $out/chanlun $out/cmd/decode
            cp ${./chanlun/go/go.mod} $out/go.mod
            for f in ${./chanlun/go/chanlun}/*.go; do
              case $f in *_test.go) ;; *) cp $f $out/chanlun/ ;; esac
            done
            cp ${./chanlun/go/cmd/decode/main.go} $out/cmd/decode/main.go
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract as Avro (chanlun/SPEC.md, The Avro schemas): one .avsc file for each record, for a taker's
          # Avro library or a schema registry
          chanlun-avro = pkgs.runCommand "chanlun-avro-2.2.0" { } ''
            mkdir -p $out
            cp ${./chanlun/avro}/*.avsc $out/
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract as Protobuf (chanlun/SPEC.md, The Protobuf description): chanlun.proto, the records' fields
          # and types, for a taker's protoc
          chanlun-proto = pkgs.runCommand "chanlun-proto-2.2.0" { } ''
            mkdir -p $out
            cp ${./chanlun/proto/chanlun.proto} $out/chanlun.proto
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
        });
    };
}
