{
  # The contracts shared by the qi-v2 projects, each defined once (README.md): a folder a contract, its spec and its
  # forms. Two products, each with its packages: market (the market data contract, the K-lines) as market-ts,
  # market-lean, market-go, market-avro and market-proto; chanlun (缠论's contract, built on market's K-line) as
  # chanlun-ts, chanlun-lean, chanlun-go, chanlun-avro and chanlun-proto. Each is for TypeScript, Lean and Go, or its
  # Avro schemas and Protobuf description, made from the TypeScript. The common flake, qi-v2, gives the one nixpkgs of
  # every project and the pure shell.
  description = "qi-v2-contracts: the contracts shared by the qi-v2 projects (market 1.0.0: the K-lines; chanlun 3.0.0: 缠论's records on them; each for TypeScript, Lean and Go, and as Avro and Protobuf)";

  inputs.qi-v2.url = "github:zhifengzhang-sz/qi-v2-nix?dir=qi-v2";
  inputs.nixpkgs.follows = "qi-v2/nixpkgs";
  inputs.kit.url = "github:zhifengzhang-sz/qi-v2-nix?dir=kit";
  inputs.kit.inputs.qi-v2.follows = "qi-v2";

  outputs = { self, nixpkgs, qi-v2, kit }:
    let
      # the systems qi-v2's Lean is pinned for
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # zod, the TypeScript forms' one dependency (npm's, pinned by hash), in their packages and their decodes
      zodOf = pkgs: pkgs.fetchurl {
        url = "https://registry.npmjs.org/zod/-/zod-4.1.12.tgz";
        hash = "sha256-LvnXp9gisFnJvSH4fKpP3EgiDUNzU2eJhN+UL7Z7Q/o=";
      };
    in {
      devShells = forAll (pkgs: {
        default = qi-v2.lib.mkPureShell pkgs {
          name = "contracts";
          # the Lean forms: Lean and Lake pinned in the store (qi-v2's lean preset); each form's lean-toolchain
          # names the same version, which each Lean check checks. The Go forms: Go (qi-v2's go preset), its caches
          # under the shell's own, never fetching another toolchain
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
          zod = zodOf pkgs;
          # a Go module as source, without its tests, for a taker's go.mod to replace its module path with: market-go's
          # and chanlun-go's
          goModule = src: dir: ''
            mkdir -p $out/${dir} $out/cmd/decode
            cp ${src}/go.mod $out/go.mod
            for f in ${src}/${dir}/*.go; do
              case $f in *_test.go) ;; *) cp $f $out/${dir}/ ;; esac
            done
            cp ${src}/cmd/decode/main.go $out/cmd/decode/main.go
          '';
        in {
          # The market data contract for TypeScript (market/README.md, how to take it): a node_modules of @qi/market,
          # as source, and zod, its one dependency (npm's, pinned by hash); no tests.
          market-ts = pkgs.runCommand "market-ts-1.0.0" { } ''
            m=$out/node_modules
            mkdir -p $m/@qi/market $m/zod
            cp -r ${./market/ts/src} $m/@qi/market/src
            cp ${./market/ts/package.json} $m/@qi/market/package.json
            tar -xzf ${zod} -C $m/zod --strip-components=1
            cp ${./market/SPEC.md} $out/SPEC.md
            cp ${./market/README.md} $out/README.md
          '';
          # The market data contract for Lean (market/README.md): the Lake package `market` as source, for a taker's
          # Lake.
          market-lean = pkgs.runCommand "market-lean-1.0.0" { } ''
            mkdir -p $out
            cp -r ${./market/lean}/Market $out/Market
            cp ${./market/lean}/Market.lean ${./market/lean}/Main.lean ${./market/lean}/lakefile.toml ${./market/lean}/lean-toolchain $out/
            cp ${./market/SPEC.md} $out/SPEC.md
            cp ${./market/README.md} $out/README.md
          '';
          # The market data contract for Go (market/README.md, how to take it): the module of market/go as source,
          # without its tests, for a taker's go.mod to replace its module path with; the standard library only.
          market-go = pkgs.runCommand "market-go-1.0.0" { } ''
            ${goModule ./market/go "market"}
            cp ${./market/SPEC.md} $out/SPEC.md
            cp ${./market/README.md} $out/README.md
          '';
          # The market data contract as Avro (market/SPEC.md, The Avro schemas): one .avsc file for each record, for a
          # taker's Avro library or a schema registry
          market-avro = pkgs.runCommand "market-avro-1.0.0" { } ''
            mkdir -p $out
            cp ${./market/avro}/*.avsc $out/
            cp ${./market/SPEC.md} $out/SPEC.md
            cp ${./market/README.md} $out/README.md
          '';
          # The market data contract as Protobuf (market/SPEC.md, The Protobuf description): market.proto, the
          # records' fields and types, for a taker's protoc
          market-proto = pkgs.runCommand "market-proto-1.0.0" { } ''
            mkdir -p $out
            cp ${./market/proto/market.proto} $out/market.proto
            cp ${./market/SPEC.md} $out/SPEC.md
            cp ${./market/README.md} $out/README.md
          '';

          # 缠论's contract for TypeScript (chanlun/README.md, how to take it): a node_modules of @qi/chanlun, as
          # source, @qi/market, whose K-line it takes, as market-ts has it, and zod (npm's, pinned by hash); no tests.
          chanlun-ts = pkgs.runCommand "chanlun-ts-3.0.0" { } ''
            m=$out/node_modules
            mkdir -p $m/@qi/chanlun $m/@qi/market $m/zod
            cp -r ${./chanlun/ts/src} $m/@qi/chanlun/src
            cp ${./chanlun/ts/package.json} $m/@qi/chanlun/package.json
            cp -r ${./market/ts/src} $m/@qi/market/src
            cp ${./market/ts/package.json} $m/@qi/market/package.json
            tar -xzf ${zod} -C $m/zod --strip-components=1
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract for Lean (chanlun/README.md): the Lake package `chanlun` as source, at chanlun/lean, and
          # the Lake package `market` it requires, at market/lean, where its lakefile names it (../../market/lean),
          # for a taker's Lake.
          chanlun-lean = pkgs.runCommand "chanlun-lean-3.0.0" { } ''
            mkdir -p $out/chanlun/lean $out/market/lean
            cp -r ${./chanlun/lean}/Chanlun $out/chanlun/lean/Chanlun
            cp ${./chanlun/lean}/Chanlun.lean ${./chanlun/lean}/Main.lean ${./chanlun/lean}/lakefile.toml ${./chanlun/lean}/lake-manifest.json ${./chanlun/lean}/lean-toolchain $out/chanlun/lean/
            cp -r ${./market/lean}/Market $out/market/lean/Market
            cp ${./market/lean}/Market.lean ${./market/lean}/Main.lean ${./market/lean}/lakefile.toml ${./market/lean}/lean-toolchain $out/market/lean/
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract for Go (chanlun/README.md, how to take it): the module of chanlun/go as source, without its
          # tests, for a taker's go.mod to replace its module path with, and market's with market-go; the standard
          # library only, and market's module.
          chanlun-go = pkgs.runCommand "chanlun-go-3.0.0" { } ''
            ${goModule ./chanlun/go "chanlun"}
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract as Avro (chanlun/SPEC.md, The Avro schemas): one .avsc file for each record, market's K-line
          # written out in a run's, for a taker's Avro library or a schema registry
          chanlun-avro = pkgs.runCommand "chanlun-avro-3.0.0" { } ''
            mkdir -p $out
            cp ${./chanlun/avro}/*.avsc $out/
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract as Protobuf (chanlun/SPEC.md, The Protobuf description): chanlun.proto, the records' fields
          # and types, which imports market-proto's market.proto, for a taker's protoc
          chanlun-proto = pkgs.runCommand "chanlun-proto-3.0.0" { } ''
            mkdir -p $out
            cp ${./chanlun/proto/chanlun.proto} $out/chanlun.proto
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
        });

      # The checks that read only this repository's files and the flake's inputs (make check asks Nix for them at
      # once, nix flake check builds them all): each a derivation of exactly the files it reads, so Nix runs it again
      # only when one of them, or a tool, has changed, and otherwise keeps its result, the report make prints among it.
      # Each product's checks read its own files, and chanlun's those of market's forms it takes. The conformance and
      # the cases are run form by form, each form's part reading its decode and the vectors alone.
      checks = forAll (pkgs:
        let
          inherit (pkgs) lib bun go;
          fs = lib.fileset;
          files = root: fileset: fs.toSource { inherit root fileset; };
          # FULL=1 (Makefile): a salt, read under --impure, making every derivation here new, so each runs again; ""
          # in a pure evaluation
          salt = builtins.getEnv "CHECK_SALT";
          run = name: env: pkgs.runCommandLocal name (env // lib.optionalAttrs (salt != "") { inherit salt; });
          tests = dir: fs.fileFilter (f: lib.hasSuffix "_test.go" f.name) dir;
          # a product's vectors: its vectors' JSON files but rules.json (read by the TypeScript form's tests alone)
          vectorsOf = dir: fs.difference (fs.fileFilter (f: f.hasExt "json") dir) (dir + "/rules.json");
          marketVectors = vectorsOf ./market/vectors;
          chanlunVectors = vectorsOf ./chanlun/vectors;
          # market's Go package as chanlun's module takes it, by the replace of its go.mod: go.mod and the package,
          # without its tests and its decode
          marketGo = fs.union ./market/go/go.mod (fs.difference ./market/go/market (tests ./market/go/market));
          go-env = "export HOME=$TMPDIR GOCACHE=$TMPDIR/go-build GOPATH=$TMPDIR/go GOPROXY=off GOTOOLCHAIN=local";
          lean = (qi-v2.lib.lean pkgs).package;
          # Lean's version, and the one a form's lean-toolchain names, the same
          toolchain = form: ''
            v=$(lean --version | sed -n 's/^Lean (version \([^,]*\),.*/\1/p')
            t=$(sed 's|^leanprover/lean4:v||' lean-toolchain)
            [ -n "$v" ] && [ "$t" = "$v" ] || { echo "${form}: qi-v2's Lean is '$v', ${form}/lean-toolchain names '$t'"; exit 1; }
          '';
          # The scripts run under set -eu -o pipefail, which stops at a failing command but not at one failing before
          # the last of an && list: each step is a line of its own.

          # market's Lean form, built by Lake with its decode, by qi-v2's Lean (the shell's) once its version is the
          # one market/lean/lean-toolchain names; the package as built kept, on which chanlun's builds
          market-lean = run "market-lean" { nativeBuildInputs = [ lean ]; } ''
            cp -r ${./market/lean} lean
            chmod -R u+w lean
            cd lean
            ${toolchain "market/lean"}
            HOME=$TMPDIR LAKE_CACHE_DIR=$TMPDIR/lake lake build
            mkdir -p $out/bin
            cp .lake/build/bin/decode $out/bin/decode
            cp -r . $out/lean
            echo "market-lean: Market and decode built by Lake, Lean $v as lean-toolchain names: PASS" > $out/report
          '';
          # chanlun's Lean form, built by Lake with its decode on market's Lake package as market-lean built it, at
          # the place its lakefile names, ../../market/lean, by qi-v2's Lean once its version is the one
          # chanlun/lean/lean-toolchain names
          chanlun-lean = run "chanlun-lean" { nativeBuildInputs = [ lean ]; } ''
            mkdir -p src/market src/chanlun
            cp -r ${market-lean}/lean src/market/lean
            cp -r ${./chanlun/lean} src/chanlun/lean
            chmod -R u+w src
            cd src/chanlun/lean
            ${toolchain "chanlun/lean"}
            HOME=$TMPDIR LAKE_CACHE_DIR=$TMPDIR/lake lake build
            mkdir -p $out/bin
            cp .lake/build/bin/decode $out/bin/decode
            echo "chanlun-lean: Chanlun and decode built by Lake on market's Lake package, Lean $v as lean-toolchain names: PASS" > $out/report
          '';
          # each Go form: every file as gofmt writes it, go vet, its tests over the vectors; the standard library only,
          # and chanlun's market's module, nothing fetched
          market-go = run "market-go" { nativeBuildInputs = [ go ]; } ''
            ${go-env}
            cp -r ${files ./market (fs.union ./market/go marketVectors)} src
            chmod -R u+w src
            cd src/go
            u=$(gofmt -l .) && [ -z "$u" ] || { echo "market-go: not as gofmt writes it: $u"; exit 1; }
            go vet ./...
            go test ./...
            mkdir $out
            echo "market-go: every file as gofmt writes it, go vet, its tests over the vectors: PASS" > $out/report
          '';
          chanlun-go = run "chanlun-go" { nativeBuildInputs = [ go ]; } ''
            ${go-env}
            cp -r ${files ./. (fs.unions [ ./chanlun/go chanlunVectors marketGo ])} src
            chmod -R u+w src
            cd src/chanlun/go
            u=$(gofmt -l .) && [ -z "$u" ] || { echo "chanlun-go: not as gofmt writes it: $u"; exit 1; }
            go vet ./...
            go test ./...
            mkdir $out
            echo "chanlun-go: every file as gofmt writes it, go vet, its tests over the vectors, on market's module: PASS" > $out/report
          '';

          # each form's decode of a product, which its conformance and its cases run: the TypeScript's, its source and
          # zod, the version its package.json names, and chanlun's @qi/market; the Lean's, built by its check; the
          # Go's, built from the module but its tests
          ts-decode = product: market: run "${product}-ts-decode" { } ''
            cp -r ${files (./. + "/${product}/ts") (fs.unions (map (f: ./. + "/${product}/ts/${f}") [ "src" "bin/decode.ts" "package.json" "tsconfig.json" ]))} $out
            chmod u+w $out
            mkdir -p $out/node_modules/zod
            tar -xzf ${zodOf pkgs} -C $out/node_modules/zod --strip-components=1
            v=$(sed -n 's/^  "version": "\(.*\)",$/\1/p' $out/node_modules/zod/package.json)
            grep -q "\"zod\": \"$v\"" $out/package.json || { echo "${product}-ts-decode: zod $v is not the version ${product}/ts/package.json names"; exit 1; }
            ${lib.optionalString market ''
              mkdir -p $out/node_modules/@qi/market
              cp -r ${./market/ts/src} $out/node_modules/@qi/market/src
              cp ${./market/ts/package.json} $out/node_modules/@qi/market/package.json
            ''}
          '';
          go-decode = product: fileset: run "${product}-go-decode" { nativeBuildInputs = [ go ]; } ''
            ${go-env}
            cd ${files ./. fileset}/${product}/go
            mkdir -p $out/bin
            go build -o $out/bin/decode ./cmd/decode
          '';
          decodes = {
            market = {
              ts = "${bun}/bin/bun ${ts-decode "market" false}/bin/decode.ts";
              lean = "${market-lean}/bin/decode";
              go = "${go-decode "market" (fs.difference ./market/go (tests ./market/go))}/bin/decode";
            };
            chanlun = {
              ts = "${bun}/bin/bun ${ts-decode "chanlun" true}/bin/decode.ts";
              lean = "${chanlun-lean}/bin/decode";
              go = "${go-decode "chanlun" (fs.union (fs.difference ./chanlun/go (tests ./chanlun/go)) marketGo)}/bin/decode";
            };
          };

          # A product's conformance, each form's part: each valid vector decoded and written to the same text, every
          # reject case refused as a fault of the contract (exit 1, `decode: ` and its message), not a crash, by the
          # steps given (give MODE FILE, refuse MODE FILE): Massive's by --massive, an ongoing K-line by --ongoing; its
          # counts in its output. Under set +e, so that a decode's exit is read, each failure stopping it by an exit of
          # its own. Then the three forms' counts the same, and the report.
          conformanceOf = product: root: vectors: steps:
            let
              part = lib.mapAttrs (form: d: run "${product}-conformance-${form}" { } ''
                set +eu +o pipefail
                export HOME=$TMPDIR
                cd ${files root vectors} || exit 1
                s=0; r=0; o=0; n=0
                give() { case "$1" in *--ongoing*) o=$((o+1));; *) r=$((r+1));; esac
                  ${d} $1 $2 | cmp -s - $2 || { echo "conformance: ${form} does not give $2 back"; s=1; }; }
                refuse() { n=$((n+1))
                  e=$(${lib.optionalString (form != "ts") "timeout 60 "}${d} $1 $2 2>&1 >/dev/null); c=$?
                  [ $c = 1 ] && case "$e" in "decode: "*) true;; *) false;; esac || { echo "conformance: ${form} on $2: exit $c, $e"; s=1; }; }
                ${steps}
                [ $s = 0 ] || exit 1
                echo "$r $o $n" > $out
              '') decodes.${product};
            in run "${product}-conformance" { } ''
              read -r r o n < ${part.ts}
              for c in ${part.lean} ${part.go}; do
                [ "$(cat $c)" = "$r $o $n" ] || { echo "${product} conformance: the forms did not read the same vectors"; exit 1; }
              done
              g=""; [ $r = 0 ] || g="$r runs"; [ $o = 0 ] || g="''${g:+$g and }$o ongoing K-lines"
              mkdir $out
              echo "${product} conformance: $g given back alike by three forms (ts, lean, go), $n reject cases refused by all three: PASS" > $out/report
            '';
          market-conformance = conformanceOf "market" ./market marketVectors ''
            give --ongoing vectors/ongoing/kline.json; give "--massive --ongoing" vectors/ongoing/massive.json
            for v in vectors/ongoing/reject/*.json; do refuse --ongoing $v; done
          '';
          chanlun-conformance = conformanceOf "chanlun" ./chanlun chanlunVectors ''
            for v in vectors/run.json vectors/small.json vectors/edge.json; do give "" $v; done
            for v in vectors/massive/small.json vectors/massive/edge.json; do give --massive $v; done
            for v in vectors/reject/*.json; do refuse "" $v; done
            for v in vectors/massive/reject/*.json; do refuse --massive $v; done
          '';

          # A product's generated cases (<product>/vectors/cases.ts): the copies made from its valid vectors by its
          # fixed seed, by group, a group a decode mode (`groups`, its flags by its name); each form's answers, its
          # decode reading them in one process (--batch) and writing nothing to stderr; then each copy given the same
          # answer by the three forms, all refusing it or all giving back the same text
          casesOf = product: dir: valid: groups:
            let
              cases = files dir (fs.union (dir + "/cases.ts") valid);
              copies = run "${product}-cases-copies" { } ''
                HOME=$TMPDIR ${bun}/bin/bun ${cases}/cases.ts make $out > report
                mv report $out/report
              '';
              # under set +e as the conformance, each failure stopping it by an exit of its own
              answers = lib.mapAttrs (form: d: run "${product}-cases-${form}" { } ''
                set +eu +o pipefail
                export HOME=$TMPDIR
                ${lib.concatStrings (lib.mapAttrsToList (g: f: ''
                  mkdir -p $out/${g} && ${d} ${f} --batch ${copies}/${g} $out/${g} 2>err && [ ! -s err ] ||
                    { echo "${product} cases: ${form}'s decode failed on ${g}:"; cat err; exit 1; }
                '') groups)}
              '') decodes.${product};
            in run "${product}-cases" { } ''
              mkdir d
              ln -s ${copies}/* d/
              ln -s ${answers.ts} d/ts
              ln -s ${answers.lean} d/lean
              ln -s ${answers.go} d/go
              HOME=$TMPDIR ${bun}/bin/bun ${cases}/cases.ts compare d ts lean go > line || { cat line; exit 1; }
              mkdir $out
              cat ${copies}/report line > $out/report
            '';
          market-cases = casesOf "market" ./market/vectors
            (fs.difference marketVectors ./market/vectors/ongoing/reject)
            { ongoing = "--ongoing"; massive-ongoing = "--massive --ongoing"; };
          chanlun-cases = casesOf "chanlun" ./chanlun/vectors
            (fs.difference chanlunVectors (fs.union ./chanlun/vectors/reject ./chanlun/vectors/massive/reject))
            { run = ""; massive = "--massive"; };
        in {
          inherit market-lean market-go market-conformance market-cases;
          inherit chanlun-lean chanlun-go chanlun-conformance chanlun-cases;
        });
    };
}
