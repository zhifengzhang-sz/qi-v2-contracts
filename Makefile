# The contracts' checks (README.md): each form's own, then the conformance of each contract's forms, run on every
# change. In the shell (nix develop).
.PHONY: help check chanlun chanlun-ts chanlun-avro chanlun-proto chanlun-go-types chanlun-lean chanlun-go chanlun-conformance chanlun-cases packages products-check
KIT = $(shell bun -e 'const n = JSON.parse(await Bun.file("flake.lock").text()).nodes.kit.locked; console.log(n.type + ":" + n.owner + "/" + n.repo + "/" + n.rev + "?dir=" + n.dir)')

help: ## the targets
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /: /'

check: chanlun products-check ## every contract: its forms' checks and their conformance

chanlun: chanlun-ts chanlun-lean chanlun-go chanlun-conformance chanlun-cases ## 缠论's contract

chanlun-ts: ## the TypeScript form: Biome, tsc, its tests over the vectors, every run through Avro among them, and every rule of SPEC.md with its reject vectors (chanlun/vectors/rules.json); its Avro schemas, Protobuf description and Go types what its Zod schemas make, read by an Avro implementation and protoc
	cd chanlun/ts && bun install --frozen-lockfile && biome check . && ./node_modules/.bin/tsc --noEmit -p . && ./node_modules/.bin/vitest run
	cd chanlun/ts && bun bin/avsc.ts --check
	cd chanlun/ts && bun bin/proto.ts --check
	cd chanlun/ts && bun bin/go.ts --check
	protoc --proto_path=chanlun/proto --descriptor_set_out=/dev/null chanlun.proto

chanlun-avro: ## the Avro schemas, chanlun/avro/*.avsc, made again from the Zod schemas
	cd chanlun/ts && bun bin/avsc.ts

chanlun-proto: ## the Protobuf description, chanlun/proto/chanlun.proto, made again from the Zod schemas and chanlun/proto/fields.json (a new field: its number added there first)
	cd chanlun/ts && bun bin/proto.ts

chanlun-go-types: ## the Go form's types, chanlun/go/chanlun/records.go, made again from the Zod schemas
	cd chanlun/ts && bun bin/go.ts

chanlun-lean: ## the Lean form, built with its decode, by the shell's Lean once its version is the one chanlun/lean/lean-toolchain names
	@v=$$(lean --version | sed -n 's/^Lean (version \([^,]*\),.*/\1/p'); t=$$(sed 's|^leanprover/lean4:v||' chanlun/lean/lean-toolchain); \
	[ -n "$$v" ] && [ "$$t" = "$$v" ] || { echo "chanlun-lean: the shell's Lean is '$$v', chanlun/lean/lean-toolchain names '$$t'"; exit 1; }
	cd chanlun/lean && lake build

chanlun-go: ## the Go form, chanlun/go: every file as gofmt writes it, go vet, its tests over the vectors, and its decode built (chanlun/go/.bin/decode); the standard library only, nothing fetched
	@cd chanlun/go && u=$$(gofmt -l .) && [ -z "$$u" ] || { echo "chanlun-go: not as gofmt writes it: $$u"; exit 1; }
	cd chanlun/go && GOPROXY=off go vet ./... && GOPROXY=off go test ./... && GOPROXY=off go build -o .bin/decode ./cmd/decode

chanlun-conformance: chanlun-lean chanlun-go ## the three forms on every vector: each run decoded and written to the same text by each, every reject case refused by each, as a fault of the contract (exit 1, `decode: ` and its message), not a crash; Massive's by each form's --massive, an ongoing K-line by --ongoing
	@cd chanlun && s=0; r=0; o=0; n=0; \
	give() { case "$$1" in *--ongoing*) o=$$((o+1));; *) r=$$((r+1));; esac; \
	  (cd ts && bun bin/decode.ts $$1 ../$$2) | cmp -s - $$2 || { echo "conformance: ts does not give $$2 back"; s=1; }; \
	  lean/.lake/build/bin/decode $$1 $$2 | cmp -s - $$2 || { echo "conformance: lean does not give $$2 back"; s=1; }; \
	  go/.bin/decode $$1 $$2 | cmp -s - $$2 || { echo "conformance: go does not give $$2 back"; s=1; }; }; \
	refuse() { n=$$((n+1)); \
	  e=$$(cd ts && bun bin/decode.ts $$1 ../$$2 2>&1 >/dev/null); c=$$?; \
	  [ $$c = 1 ] && case "$$e" in "decode: "*) true;; *) false;; esac || { echo "conformance: ts on $$2: exit $$c, $$e"; s=1; }; \
	  e=$$(timeout 60 lean/.lake/build/bin/decode $$1 $$2 2>&1 >/dev/null); c=$$?; \
	  [ $$c = 1 ] && case "$$e" in "decode: "*) true;; *) false;; esac || { echo "conformance: lean on $$2: exit $$c, $$e"; s=1; }; \
	  e=$$(timeout 60 go/.bin/decode $$1 $$2 2>&1 >/dev/null); c=$$?; \
	  [ $$c = 1 ] && case "$$e" in "decode: "*) true;; *) false;; esac || { echo "conformance: go on $$2: exit $$c, $$e"; s=1; }; }; \
	for v in vectors/run.json vectors/small.json vectors/edge.json; do give "" $$v; done; \
	for v in vectors/massive/small.json vectors/massive/edge.json; do give --massive $$v; done; \
	give --ongoing vectors/ongoing/kline.json; give "--massive --ongoing" vectors/ongoing/massive.json; \
	for v in vectors/reject/*.json; do refuse "" $$v; done; \
	for v in vectors/massive/reject/*.json; do refuse --massive $$v; done; \
	for v in vectors/ongoing/reject/*.json; do refuse --ongoing $$v; done; \
	[ $$s = 0 ] && echo "chanlun conformance: $$r runs and $$o ongoing K-lines given back alike by three forms (ts, lean, go), $$n reject cases refused by all three: PASS" || { echo "chanlun conformance: FAIL"; exit 1; }

chanlun-cases: chanlun-lean chanlun-go ## the generated cases: from each valid vector, changed copies by a fixed seed (chanlun/vectors/cases.ts), each answered alike by the three forms, all refusing it or all giving back the same text; each form's decode reads them in one process (--batch) and writes nothing to stderr
	@cd chanlun && t=$$(mktemp -d) && trap 'rm -rf $$t' EXIT && s=$$(date +%s) && bun vectors/cases.ts make $$t && \
	for g in run massive ongoing massive-ongoing; do \
	  case $$g in run) f="";; massive) f=--massive;; ongoing) f=--ongoing;; *) f="--massive --ongoing";; esac; \
	  mkdir -p $$t/ts/$$g $$t/lean/$$g $$t/go/$$g && \
	  (cd ts && bun bin/decode.ts $$f --batch $$t/$$g $$t/ts/$$g) 2>$$t/ts.err && \
	  lean/.lake/build/bin/decode $$f --batch $$t/$$g $$t/lean/$$g 2>$$t/lean.err && \
	  go/.bin/decode $$f --batch $$t/$$g $$t/go/$$g 2>$$t/go.err && \
	  [ ! -s $$t/ts.err ] && [ ! -s $$t/lean.err ] && [ ! -s $$t/go.err ] || { echo "chanlun cases: a form's decode failed on $$g:"; cat $$t/*.err; exit 1; }; \
	done && bun vectors/cases.ts compare $$t ts lean go && echo "chanlun cases: made, read and compared in $$(( $$(date +%s) - s )) s"

packages: ## the flake's packages built, and each taken as a taker takes it: the TypeScript one imported by Bun, the Lean one built by Lake, the Go one built by Go in a module of its own by a replace to its store path, nothing fetched, each decoding the small run, and Massive's, to the same text; the Avro one what the schemas make, read by an Avro implementation; the Protobuf one read by protoc
	@ts=$$(nix build .#chanlun-ts --no-link --print-out-paths) && lean=$$(nix build .#chanlun-lean --no-link --print-out-paths) && \
	t=$$(mktemp -d) && trap 'rm -rf $$t' EXIT && v=$$PWD/chanlun/vectors/small.json && m=$$PWD/chanlun/vectors/massive/small.json && \
	ln -s $$ts/node_modules $$t/node_modules && \
	printf '%s\n' 'import { readFileSync } from "node:fs";' 'import { decodeMassiveRun, decodeRun, encodeRun } from "@qi/chanlun";' \
	  'const text = readFileSync(process.argv.at(-1) ?? "", "utf8");' 'const r = process.argv[2] === "--massive" ? decodeMassiveRun(text) : decodeRun(text);' 'if (!r.ok) process.exit(1);' \
	  'process.stdout.write(encodeRun(r.run));' > $$t/take.ts && \
	(cd $$t && bun take.ts $$v) | cmp -s - $$v && (cd $$t && bun take.ts --massive $$m) | cmp -s - $$m && echo "packages: $$ts taken by Bun: PASS" && \
	cp -r $$lean $$t/lean && chmod -R u+w $$t/lean && (cd $$t/lean && lake build -q) && \
	$$t/lean/.lake/build/bin/decode $$v | cmp -s - $$v && $$t/lean/.lake/build/bin/decode --massive $$m | cmp -s - $$m && echo "packages: $$lean built by Lake: PASS" && \
	go=$$(nix build .#chanlun-go --no-link --print-out-paths) && mkdir $$t/go && \
	printf '%s\n' 'module take' '' 'go 1.23' '' 'require github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go v0.0.0' '' \
	  "replace github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go => $$go" > $$t/go/go.mod && \
	printf '%s\n' 'package main' 'import (' '"os"' '"github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go/chanlun"' ')' \
	  'func main() {' 'data, _ := os.ReadFile(os.Args[len(os.Args)-1])' 'text, err := "", error(nil)' \
	  'if os.Args[1] == "--massive" {' 'r, e := chanlun.DecodeMassiveRun(data)' 'if err = e; e == nil { text, err = chanlun.EncodeRun(r) }' \
	  '} else {' 'r, e := chanlun.DecodeRun(data)' 'if err = e; e == nil { text, err = chanlun.EncodeRun(r) }' '}' \
	  'if err != nil { os.Exit(1) }' 'os.Stdout.WriteString(text)' '}' > $$t/go/take.go && \
	(cd $$t/go && GOPROXY=off GOFLAGS=-mod=readonly go build -o take .) && \
	$$t/go/take $$v | cmp -s - $$v && $$t/go/take --massive $$m | cmp -s - $$m && echo "packages: $$go taken by Go: PASS" && \
	avro=$$(nix build .#chanlun-avro --no-link --print-out-paths) && \
	(cd chanlun/ts && bun install --frozen-lockfile && bun bin/avsc.ts --check $$avro) && echo "packages: $$avro read by avsc: PASS" && \
	proto=$$(nix build .#chanlun-proto --no-link --print-out-paths) && \
	protoc --proto_path=$$proto --descriptor_set_out=/dev/null chanlun.proto && echo "packages: $$proto read by protoc: PASS"

products-check: ## whether PRODUCTS.md states what the project has (the kit's kit products)
	@kit=$$(nix build "$(KIT)" --no-link --print-out-paths) && $$kit/bin/kit products --root .
