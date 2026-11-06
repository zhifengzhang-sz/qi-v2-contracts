# The contracts' checks (README.md): each form's own, then the conformance of each contract's forms, each run only when
# what it reads has changed, its result kept by what it reads: the flake's checks (flake.nix) by Nix, the TypeScript
# form's, whose packages npm gives, by its key in .stamps. FULL=1 runs every part. In the shell (nix develop).
.PHONY: help check chanlun chanlun-ts chanlun-avro chanlun-proto chanlun-go-types chanlun-lean chanlun-go chanlun-conformance chanlun-cases packages products-check
SYSTEM = x86_64-linux
KIT = $(shell bun -e 'const n = JSON.parse(await Bun.file("flake.lock").text()).nodes.kit.locked; console.log(n.type + ":" + n.owner + "/" + n.repo + "/" + n.rev + "?dir=" + n.dir)')

# FULL=1: every part again, the TypeScript form's stamp passed over and each of the flake's checks made new by a salt,
# read under --impure (flake.nix, checks)
ifneq ($(FULL),)
export CHECK_SALT := $(shell date +%s%N)
impure = --impure
endif

# nix build of $(1), offline when the store holds everything it needs, that is when a dry run offline would build only
# this flake's own derivations (chanlun-…, made from the files here); online otherwise, as on a fresh store (CI's).
# Each build's log shown, the others built on when one fails, the outputs' paths written.
nix-build = o=; d=$$(nix build $(impure) --offline --dry-run --no-link $(1) 2>&1) && \
	! printf '%s\n' "$$d" | grep '^  /nix/store/.*\.drv$$' | grep -qv -- '-chanlun-[^/]*\.drv$$' && o=--offline; \
	nix build $(impure) $$o -L -j auto --keep-going --no-link --print-out-paths $(1)

# the flake's checks named, asked of Nix at once, and each one's report printed, kept with its result; a file under
# chanlun that git does not know, which they would not see, stops them
nix-checks = u=$$(git ls-files --others --exclude-standard chanlun) || exit 1; [ -z "$$u" ] || \
	{ echo "not in git, so not seen by the flake's checks (git add it): $$u"; exit 1; }; \
	p=$$($(call nix-build,$(foreach c,$(1),.\#checks.$(SYSTEM).$(c)))) && for r in $$p; do cat $$r/report; done

help: ## the targets
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /: /'

check: chanlun products-check ## every contract: its forms' checks and their conformance, each only when what it reads has changed (FULL=1: every part)

chanlun: chanlun-ts ## 缠论's contract: the TypeScript form, then the flake's checks at once
	@$(call nix-checks,chanlun-lean chanlun-go chanlun-conformance chanlun-cases)

# The TypeScript form's key: its recipe (chanlun-ts-run, as written here), every file it reads (its packages by
# bun.lock), and the store path of each tool it runs. Its stamp, .stamps/chanlun-ts.<key>, written when it passes, keeps
# its result: it runs again when no stamp has its key, or with FULL=1. No recipe found, or no key made, stops make.
ts-reads = chanlun/ts chanlun/SPEC.md chanlun/avro chanlun/proto chanlun/go/chanlun/records.go
ts-tools = bun biome node protoc
ts-key := $(shell r=$$(sed -n '/^define chanlun-ts-run$$/,/^endef$$/p' Makefile) && [ -n "$$r" ] && { printf '%s\n' "$$r"; \
	{ find $(ts-reads) -name node_modules -prune -o -type f -print0; find chanlun/vectors -name '*.json' -print0; } | LC_ALL=C sort -z | xargs -0 sha256sum; \
	for t in $(ts-tools); do readlink -f "$$(command -v $$t)"; done; } | sha256sum | cut -c1-16)
$(if $(ts-key),,$(error the TypeScript form's key: no recipe chanlun-ts-run in the Makefile, or no key made of it))

chanlun-ts: .stamps/chanlun-ts.$(ts-key) ## the TypeScript form: Biome, tsc, its tests over the vectors, every run through Avro among them, and every rule of SPEC.md with its reject vectors (chanlun/vectors/rules.json); its Avro schemas, Protobuf description and Go types what its Zod schemas make, read by an Avro implementation and protoc (a make step, kept by its key)
	@echo "chanlun-ts: PASS, kept by what it reads as .stamps/chanlun-ts.$(ts-key)"

.stamps/chanlun-ts.$(ts-key): $(if $(FULL),FORCE)
	$(chanlun-ts-run)
	@mkdir -p .stamps && touch $@

define chanlun-ts-run
cd chanlun/ts && bun install --frozen-lockfile && biome check . && ./node_modules/.bin/tsc --noEmit -p . && ./node_modules/.bin/vitest run
cd chanlun/ts && bun bin/avsc.ts --check
cd chanlun/ts && bun bin/proto.ts --check
cd chanlun/ts && bun bin/go.ts --check
protoc --proto_path=chanlun/proto --descriptor_set_out=/dev/null chanlun.proto
endef

FORCE:

chanlun-avro: ## the Avro schemas, chanlun/avro/*.avsc, made again from the Zod schemas
	cd chanlun/ts && bun bin/avsc.ts

chanlun-proto: ## the Protobuf description, chanlun/proto/chanlun.proto, made again from the Zod schemas and chanlun/proto/fields.json (a new field: its number added there first)
	cd chanlun/ts && bun bin/proto.ts

chanlun-go-types: ## the Go form's types, chanlun/go/chanlun/records.go, made again from the Zod schemas
	cd chanlun/ts && bun bin/go.ts

chanlun-lean: ## the Lean form, built by Lake with its decode, by qi-v2's Lean (the shell's) once its version is the one chanlun/lean/lean-toolchain names (a check of the flake)
	@$(call nix-checks,$@)

chanlun-go: ## the Go form, chanlun/go: every file as gofmt writes it, go vet, its tests over the vectors; the standard library only, nothing fetched (a check of the flake)
	@$(call nix-checks,$@)

chanlun-conformance: ## the three forms on every vector, each form's part reading its decode and the vectors alone: each run decoded and written to the same text by each, every reject case refused by each, as a fault of the contract (exit 1, `decode: ` and its message), not a crash; Massive's by each form's --massive, an ongoing K-line by --ongoing (a check of the flake)
	@$(call nix-checks,$@)

chanlun-cases: ## the generated cases: from each valid vector, changed copies by a fixed seed (chanlun/vectors/cases.ts), each answered alike by the three forms, all refusing it or all giving back the same text; each form's decode reads them in one process (--batch) and writes nothing to stderr (a check of the flake)
	@$(call nix-checks,$@)

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
	@kit=$$($(call nix-build,"$(KIT)")) && $$kit/bin/kit products --root .
