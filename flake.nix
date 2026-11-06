{
  # The contracts shared by the qi-v2 projects, each defined once (README.md): a folder a contract, its spec and its
  # forms. Packages: chanlun-ts (缠论's contract for TypeScript), chanlun-lean (for Lean), chanlun-go (for Go),
  # chanlun-avro and chanlun-proto (its Avro schemas and Protobuf description, made from the TypeScript). The common
  # flake, qi-v2, gives the one nixpkgs of every project and the pure shell.
  description = "qi-v2-contracts: the contracts shared by the qi-v2 projects (chanlun 2.3.0: 缠论's records, for TypeScript, Lean and Go, and as Avro and Protobuf)";

  inputs.qi-v2.url = "github:zhifengzhang-sz/qi-v2-nix?dir=qi-v2";
  inputs.nixpkgs.follows = "qi-v2/nixpkgs";
  inputs.kit.url = "github:zhifengzhang-sz/qi-v2-nix?dir=kit";
  inputs.kit.inputs.qi-v2.follows = "qi-v2";

  outputs = { self, nixpkgs, qi-v2, kit }:
    let
      # the systems qi-v2's Lean is pinned for
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # zod, the TypeScript form's one dependency (npm's, pinned by hash), in its package and its decode
      zodOf = pkgs: pkgs.fetchurl {
        url = "https://registry.npmjs.org/zod/-/zod-4.1.12.tgz";
        hash = "sha256-LvnXp9gisFnJvSH4fKpP3EgiDUNzU2eJhN+UL7Z7Q/o=";
      };
    in {
      devShells = forAll (pkgs: {
        default = qi-v2.lib.mkPureShell pkgs {
          name = "contracts";
          # the Lean forms: Lean and Lake pinned in the store (qi-v2's lean preset); each form's lean-toolchain
          # names the same version, which the check chanlun-lean checks. The Go forms: Go (qi-v2's go preset), its
          # caches under the shell's own, never fetching another toolchain
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
        in {
          # 缠论's contract for TypeScript (chanlun/README.md, how to take it): a node_modules of @qi/chanlun, as
          # source, and zod, its one dependency (npm's, pinned by hash); no tests.
          chanlun-ts = pkgs.runCommand "chanlun-ts-2.3.0" { } ''
            m=$out/node_modules
            mkdir -p $m/@qi/chanlun $m/zod
            cp -r ${./chanlun/ts/src} $m/@qi/chanlun/src
            cp ${./chanlun/ts/package.json} $m/@qi/chanlun/package.json
            tar -xzf ${zod} -C $m/zod --strip-components=1
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract for Lean (chanlun/README.md): the Lake package `chanlun` as source, for a taker's Lake.
          chanlun-lean = pkgs.runCommand "chanlun-lean-2.3.0" { } ''
            mkdir -p $out
            cp -r ${./chanlun/lean}/Chanlun $out/Chanlun
            cp ${./chanlun/lean}/Chanlun.lean ${./chanlun/lean}/Main.lean ${./chanlun/lean}/lakefile.toml ${./chanlun/lean}/lean-toolchain $out/
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract for Go (chanlun/README.md, how to take it): the module of chanlun/go as source, without its
          # tests, for a taker's go.mod to replace its module path with; the standard library only.
          chanlun-go = pkgs.runCommand "chanlun-go-2.3.0" { } ''
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
          chanlun-avro = pkgs.runCommand "chanlun-avro-2.3.0" { } ''
            mkdir -p $out
            cp ${./chanlun/avro}/*.avsc $out/
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
          # 缠论's contract as Protobuf (chanlun/SPEC.md, The Protobuf description): chanlun.proto, the records' fields
          # and types, for a taker's protoc
          chanlun-proto = pkgs.runCommand "chanlun-proto-2.3.0" { } ''
            mkdir -p $out
            cp ${./chanlun/proto/chanlun.proto} $out/chanlun.proto
            cp ${./chanlun/SPEC.md} $out/SPEC.md
            cp ${./chanlun/README.md} $out/README.md
          '';
        });

      # The checks that read only this repository's files and the flake's inputs (make check asks Nix for them at
      # once, nix flake check builds them all): each a derivation of exactly the files it reads, so Nix runs it again
      # only when one of them, or a tool, has changed, and otherwise keeps its result, the report make prints among it.
      # The conformance and the cases are run form by form, each form's part reading its decode and the vectors alone.
      checks = forAll (pkgs:
        let
          inherit (pkgs) lib bun go;
          fs = lib.fileset;
          files = root: fileset: fs.toSource { inherit root fileset; };
          # FULL=1 (Makefile): a salt, read under --impure, making every derivation here new, so each runs again; ""
          # in a pure evaluation
          salt = builtins.getEnv "CHECK_SALT";
          run = name: env: pkgs.runCommandLocal name (env // lib.optionalAttrs (salt != "") { inherit salt; });
          # the vectors: chanlun/vectors' JSON files but rules.json (read by the TypeScript form's tests alone); the
          # valid ones, from which the cases are made
          vectors = fs.difference (fs.fileFilter (f: f.hasExt "json") ./chanlun/vectors) ./chanlun/vectors/rules.json;
          valid = fs.difference vectors
            (fs.unions [ ./chanlun/vectors/reject ./chanlun/vectors/massive/reject ./chanlun/vectors/ongoing/reject ]);
          go-env = "export HOME=$TMPDIR GOCACHE=$TMPDIR/go-build GOPATH=$TMPDIR/go GOPROXY=off GOTOOLCHAIN=local";
          # The scripts run under set -eu -o pipefail, which stops at a failing command but not at one failing before
          # the last of an && list: each step is a line of its own.

          # the Lean form, built by Lake with its decode, by qi-v2's Lean (the shell's) once its version is the one
          # chanlun/lean/lean-toolchain names
          chanlun-lean = run "chanlun-lean" { nativeBuildInputs = [ (qi-v2.lib.lean pkgs).package ]; } ''
            cp -r ${./chanlun/lean} lean
            chmod -R u+w lean
            cd lean
            v=$(lean --version | sed -n 's/^Lean (version \([^,]*\),.*/\1/p')
            t=$(sed 's|^leanprover/lean4:v||' lean-toolchain)
            [ -n "$v" ] && [ "$t" = "$v" ] || { echo "chanlun-lean: qi-v2's Lean is '$v', chanlun/lean/lean-toolchain names '$t'"; exit 1; }
            HOME=$TMPDIR LAKE_CACHE_DIR=$TMPDIR/lake lake build
            mkdir -p $out/bin
            cp .lake/build/bin/decode $out/bin/decode
            echo "chanlun-lean: Chanlun and decode built by Lake, Lean $v as lean-toolchain names: PASS" > $out/report
          '';
          # the Go form: every file as gofmt writes it, go vet, its tests over the vectors; the standard library only,
          # nothing fetched
          chanlun-go = run "chanlun-go" { nativeBuildInputs = [ go ]; } ''
            ${go-env}
            cp -r ${files ./chanlun (fs.union ./chanlun/go vectors)} src
            chmod -R u+w src
            cd src/go
            u=$(gofmt -l .) && [ -z "$u" ] || { echo "chanlun-go: not as gofmt writes it: $u"; exit 1; }
            go vet ./...
            go test ./...
            mkdir $out
            echo "chanlun-go: every file as gofmt writes it, go vet, its tests over the vectors: PASS" > $out/report
          '';

          # each form's decode, which the conformance and the cases run: the TypeScript's, its source and zod, the
          # version its package.json names; the Lean's, built by its check; the Go's, built from the module but its tests
          ts-decode = run "chanlun-ts-decode" { } ''
            cp -r ${files ./chanlun/ts (fs.unions [ ./chanlun/ts/src ./chanlun/ts/bin/decode.ts ./chanlun/ts/package.json ./chanlun/ts/tsconfig.json ])} $out
            chmod u+w $out
            mkdir -p $out/node_modules/zod
            tar -xzf ${zodOf pkgs} -C $out/node_modules/zod --strip-components=1
            v=$(sed -n 's/^  "version": "\(.*\)",$/\1/p' $out/node_modules/zod/package.json)
            grep -q "\"zod\": \"$v\"" $out/package.json || { echo "chanlun-ts-decode: zod $v is not the version chanlun/ts/package.json names"; exit 1; }
          '';
          go-decode = run "chanlun-go-decode" { nativeBuildInputs = [ go ]; } ''
            ${go-env}
            cd ${files ./chanlun/go (fs.difference ./chanlun/go (fs.fileFilter (f: lib.hasSuffix "_test.go" f.name) ./chanlun/go))}
            mkdir -p $out/bin
            go build -o $out/bin/decode ./cmd/decode
          '';
          decode = {
            ts = "${bun}/bin/bun ${ts-decode}/bin/decode.ts";
            lean = "${chanlun-lean}/bin/decode";
            go = "${go-decode}/bin/decode";
          };

          # each form's part of the conformance: each run decoded and written to the same text, every reject case
          # refused as a fault of the contract (exit 1, `decode: ` and its message), not a crash; Massive's by --massive,
          # an ongoing K-line by --ongoing; its counts in its output. Under set +e, so that a decode's exit is read, each
          # failure stopping it by an exit of its own
          conformance = lib.mapAttrs (form: d: run "chanlun-conformance-${form}" { } ''
            set +eu +o pipefail
            export HOME=$TMPDIR
            cd ${files ./chanlun vectors} || exit 1
            s=0; r=0; o=0; n=0
            give() { case "$1" in *--ongoing*) o=$((o+1));; *) r=$((r+1));; esac
              ${d} $1 $2 | cmp -s - $2 || { echo "conformance: ${form} does not give $2 back"; s=1; }; }
            refuse() { n=$((n+1))
              e=$(${lib.optionalString (form != "ts") "timeout 60 "}${d} $1 $2 2>&1 >/dev/null); c=$?
              [ $c = 1 ] && case "$e" in "decode: "*) true;; *) false;; esac || { echo "conformance: ${form} on $2: exit $c, $e"; s=1; }; }
            for v in vectors/run.json vectors/small.json vectors/edge.json; do give "" $v; done
            for v in vectors/massive/small.json vectors/massive/edge.json; do give --massive $v; done
            give --ongoing vectors/ongoing/kline.json; give "--massive --ongoing" vectors/ongoing/massive.json
            for v in vectors/reject/*.json; do refuse "" $v; done
            for v in vectors/massive/reject/*.json; do refuse --massive $v; done
            for v in vectors/ongoing/reject/*.json; do refuse --ongoing $v; done
            [ $s = 0 ] || exit 1
            echo "$r $o $n" > $out
          '') decode;
          chanlun-conformance = run "chanlun-conformance" { } ''
            read -r r o n < ${conformance.ts}
            for c in ${conformance.lean} ${conformance.go}; do
              [ "$(cat $c)" = "$r $o $n" ] || { echo "chanlun conformance: the forms did not read the same vectors"; exit 1; }
            done
            mkdir $out
            echo "chanlun conformance: $r runs and $o ongoing K-lines given back alike by three forms (ts, lean, go), $n reject cases refused by all three: PASS" > $out/report
          '';

          # the generated cases (chanlun/vectors/cases.ts): the copies made from the valid vectors by its fixed seed; each
          # form's answers, its decode reading them in one process (--batch) and writing nothing to stderr; then each
          # copy given the same answer by the three forms, all refusing it or all giving back the same text
          cases = files ./chanlun/vectors (fs.union ./chanlun/vectors/cases.ts valid);
          copies = run "chanlun-cases-copies" { } ''
            HOME=$TMPDIR ${bun}/bin/bun ${cases}/cases.ts make $out > report
            mv report $out/report
          '';
          # under set +e as the conformance, each failure stopping it by an exit of its own
          answers = lib.mapAttrs (form: d: run "chanlun-cases-${form}" { } ''
            set +eu +o pipefail
            export HOME=$TMPDIR
            for g in run massive ongoing massive-ongoing; do
              case $g in run) f="";; massive) f=--massive;; ongoing) f=--ongoing;; *) f="--massive --ongoing";; esac
              mkdir -p $out/$g && ${d} $f --batch ${copies}/$g $out/$g 2>err && [ ! -s err ] ||
                { echo "chanlun cases: ${form}'s decode failed on $g:"; cat err; exit 1; }
            done
          '') decode;
          chanlun-cases = run "chanlun-cases" { } ''
            mkdir d
            ln -s ${copies}/* d/
            ln -s ${answers.ts} d/ts
            ln -s ${answers.lean} d/lean
            ln -s ${answers.go} d/go
            HOME=$TMPDIR ${bun}/bin/bun ${cases}/cases.ts compare d ts lean go > line || { cat line; exit 1; }
            mkdir $out
            cat ${copies}/report line > $out/report
          '';
        in {
          inherit chanlun-lean chanlun-go chanlun-conformance chanlun-cases;
        });
    };
}
