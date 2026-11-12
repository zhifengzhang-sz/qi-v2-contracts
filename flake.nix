{
  # The contracts shared by the qi-v2 projects (README.md): market and chanlun, each its .proto, its rules (Lean), and
  # its Go and TypeScript code. The common flake, qi-v2, gives the one nixpkgs of every project and the pure shell.
  description = "qi-v2-contracts: the contracts shared by the qi-v2 projects (market: the K-lines; chanlun: 缠论's records)";

  inputs.qi-v2.url = "github:zhifengzhang-sz/qi-v2-nix?dir=qi-v2";
  inputs.nixpkgs.follows = "qi-v2/nixpkgs";
  inputs.kit.url = "github:zhifengzhang-sz/qi-v2-nix?dir=kit";
  inputs.kit.inputs.qi-v2.follows = "qi-v2";

  outputs = { self, nixpkgs, qi-v2, kit }:
    let
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAll (pkgs: {
        default = qi-v2.lib.mkPureShell pkgs {
          name = "contracts";
          # Lean and Go by qi-v2's presets; each lean-toolchain names the shell's Lean
          uses = [ (qi-v2.lib.lean pkgs) (qi-v2.lib.go pkgs) ];
          packages = with pkgs; [ gnumake git gh openssh bun biome buf protoc-gen-go protoc-gen-es ];
          hostTools = [ "nix" "nix-store" ];
          greeting = ''echo "contracts: make check"'';
        };
      });

      # Each contract's products: its .proto, its Go module, its TypeScript package, its Lean package. The version is
      # its package.json's.
      packages = forAll (pkgs:
        let
          # the TypeScript code's one dependency, at the version of the shell's protoc-gen-es
          protobufEs = pkgs.fetchurl {
            url = "https://registry.npmjs.org/@bufbuild/protobuf/-/protobuf-2.11.0.tgz";
            hash = "sha256-JaaVnK4Dleoizwq5zcl70tuEAqE8Q212BBowAj1jbC0=";
          };
          contract = c:
            let
              dir = ./. + "/${c}";
              v = (builtins.fromJSON (builtins.readFile (dir + "/ts/package.json"))).version;
            in {
              # the .proto, for a taker's own generator
              "${c}-proto" = pkgs.runCommand "${c}-proto-${v}" { } ''
                mkdir -p $out
                cp ${dir}/proto/${c}.proto ${dir}/README.md $out/
              '';
              # the Go module as source, without its tests, for a taker's go.mod to replace its path with
              "${c}-go" = pkgs.runCommand "${c}-go-${v}" { } ''
                mkdir -p $out/${c}
                cp ${dir}/go/go.mod ${dir}/go/go.sum $out/
                for f in ${dir}/go/${c}/*.go; do case $f in *_test.go) ;; *) cp $f $out/${c}/ ;; esac; done
              '';
              # a node_modules of @qi/<contract> as source, and @bufbuild/protobuf
              "${c}-ts" = pkgs.runCommand "${c}-ts-${v}" { } ''
                m=$out/node_modules
                mkdir -p $m/@qi/${c} $m/@bufbuild/protobuf
                cp -r ${dir}/ts/src $m/@qi/${c}/src
                cp ${dir}/ts/package.json $m/@qi/${c}/
                tar -xzf ${protobufEs} -C $m/@bufbuild/protobuf --strip-components=1
              '';
              # the Lake package: the rules, and the program that checks the examples against them
              "${c}-lean" = pkgs.runCommand "${c}-lean-${v}" { } ''
                mkdir -p $out
                cp ${dir}/lean/*.lean ${dir}/lean/lakefile.toml ${dir}/lean/lake-manifest.json ${dir}/lean/lean-toolchain ${dir}/examples.json $out/
              '';
            };
        in contract "market" // contract "chanlun");
    };
}
