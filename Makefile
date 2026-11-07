# The contracts' checks (README.md), product by product, market's and chanlun's: each form's own, then the conformance
# of each product's forms, each run only when what it reads has changed, its result kept by what it reads: the flake's
# checks (flake.nix) by Nix, each TypeScript form's, whose packages npm gives, by its key in .stamps. FULL=1 runs every
# part. In the shell (nix develop).
.PHONY: help check market chanlun market-ts chanlun-ts market-avro chanlun-avro market-proto chanlun-proto market-go-types chanlun-go-types market-lean chanlun-lean market-go chanlun-go market-conformance chanlun-conformance market-cases chanlun-cases packages products-check
SYSTEM = x86_64-linux
KIT = $(shell bun -e 'const n = JSON.parse(await Bun.file("flake.lock").text()).nodes.kit.locked; console.log(n.type + ":" + n.owner + "/" + n.repo + "/" + n.rev + "?dir=" + n.dir)')

# FULL=1: every part again, the TypeScript forms' stamps passed over and each of the flake's checks made new by a salt,
# read under --impure (flake.nix, checks)
ifneq ($(FULL),)
export CHECK_SALT := $(shell date +%s%N)
impure = --impure
endif

# nix build of $(1), offline when the store holds everything it needs, that is when a dry run offline would build only
# this flake's own derivations (market-… and chanlun-…, made from the files here); online otherwise, as on a fresh
# store (CI's). Each build's log shown, the others built on when one fails, the outputs' paths written.
nix-build = o=; d=$$(nix build $(impure) --offline --dry-run --no-link $(1) 2>&1) && \
	! printf '%s\n' "$$d" | grep '^  /nix/store/.*\.drv$$' | grep -qv -- '-\(market\|chanlun\)-[^/]*\.drv$$' && o=--offline; \
	nix build $(impure) $$o -L -j auto --keep-going --no-link --print-out-paths $(1)

# the flake's checks $(1) named, asked of Nix at once, and each one's report printed, kept with its result; a file
# under the folders they read, $(2), that git does not know, which they would not see, stops them
nix-checks = u=$$(git ls-files --others --exclude-standard $(2)) || exit 1; [ -z "$$u" ] || \
	{ echo "not in git, so not seen by the flake's checks (git add it): $$u"; exit 1; }; \
	p=$$($(call nix-build,$(foreach c,$(1),.\#checks.$(SYSTEM).$(c)))) && for r in $$p; do cat $$r/report; done

market-checks = market-lean market-go market-conformance market-cases
chanlun-checks = chanlun-lean chanlun-go chanlun-conformance chanlun-cases

help: ## the targets
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /: /'

check: market chanlun products-check ## both products: their forms' checks and their conformance, each only when what it reads has changed (FULL=1: every part)

market: market-ts ## the market data contract: the TypeScript form, then the flake's checks at once
	@$(call nix-checks,$(market-checks),market)

chanlun: chanlun-ts ## 缠论's contract, built on market's: the TypeScript form, then the flake's checks at once
	@$(call nix-checks,$(chanlun-checks),chanlun market)

# chanlun's TypeScript form on market's, in chanlun/ts: its packages by its bun.lock, then @qi/market as the flake's
# chanlun-ts has it, a copy of market's source and package.json, in place of the symlinks into market/ts that Bun makes
# of a file: dependency, through which market's source would read market's own node_modules, a second zod
chanlun-ts-install = bun install --frozen-lockfile && rm -rf node_modules/@qi/market && mkdir -p node_modules/@qi/market && \
	cp -r ../../market/ts/src ../../market/ts/package.json node_modules/@qi/market/

# The TypeScript forms' keys, each a product's: its recipe (<product>-ts-run, and <product>-ts-install, as written
# here), every file it reads (its packages by bun.lock; chanlun's, market's TypeScript form it takes, and what of
# market's its tests read), and the store path of each tool it runs. Its stamp, .stamps/<product>-ts.<key>, written
# when it passes, keeps its result: it runs again when no stamp has its key, or with FULL=1. No recipe found, or no key
# made, stops make.
ts-tools = bun biome node protoc
ts-key = $(shell r=$$(sed -n '/^define $(1)-ts-run$$/,/^endef$$/p; /^$(1)-ts-install = /,/[^\\]$$/p' Makefile) && [ -n "$$r" ] && \
	{ printf '%s\n' "$$r"; \
	{ find $(2) -name node_modules -prune -o -type f -print0; find $(3) -name '*.json' -print0; } | LC_ALL=C sort -z | xargs -0 sha256sum; \
	for t in $(ts-tools); do readlink -f "$$(command -v $$t)"; done; } | sha256sum | cut -c1-16)
market-ts-reads = market/ts market/SPEC.md market/avro market/proto market/go/market/records.go
chanlun-ts-reads = chanlun/ts chanlun/SPEC.md chanlun/avro chanlun/proto chanlun/go/chanlun/records.go \
	market/ts/src market/ts/package.json market/ts/bin/avro.ts market/ts/bin/protobuf.ts market/ts/bin/golang.ts \
	market/vectors/rules.json
market-ts-key := $(call ts-key,market,$(market-ts-reads),market/vectors)
chanlun-ts-key := $(call ts-key,chanlun,$(chanlun-ts-reads),chanlun/vectors)
$(if $(and $(market-ts-key),$(chanlun-ts-key)),,$(error the TypeScript forms' keys: no recipe market-ts-run or chanlun-ts-run in the Makefile, or no key made of it))

market-ts: .stamps/market-ts.$(market-ts-key) ## market's TypeScript form: Biome, tsc, its tests over the vectors, each ongoing K-line through Avro among them, and every rule of SPEC.md with its reject vectors (market/vectors/rules.json); its Avro schemas, Protobuf description and Go types what its Zod schemas make, read by an Avro implementation and protoc (a make step, kept by its key)
	@echo "market-ts: PASS, kept by what it reads as .stamps/market-ts.$(market-ts-key)"

chanlun-ts: .stamps/chanlun-ts.$(chanlun-ts-key) ## chanlun's TypeScript form, on market's (@qi/market, a copy of market's source, as chanlun-ts has it): Biome, tsc, its tests over the vectors, every run through Avro among them, its generators market's byte for byte, and every rule of SPEC.md with its reject vectors, and of market's those its vectors break (chanlun/vectors/rules.json); its Avro schemas, Protobuf description and Go types what its Zod schemas make, read by an Avro implementation and protoc (a make step, kept by its key)
	@echo "chanlun-ts: PASS, kept by what it reads as .stamps/chanlun-ts.$(chanlun-ts-key)"

.stamps/market-ts.$(market-ts-key): $(if $(FULL),FORCE)
	$(market-ts-run)
	@mkdir -p .stamps && touch $@

.stamps/chanlun-ts.$(chanlun-ts-key): $(if $(FULL),FORCE)
	$(chanlun-ts-run)
	@mkdir -p .stamps && touch $@

define market-ts-run
cd market/ts && bun install --frozen-lockfile && biome check . && ./node_modules/.bin/tsc --noEmit -p . && ./node_modules/.bin/vitest run
cd market/ts && bun bin/avsc.ts --check
cd market/ts && bun bin/proto.ts --check
cd market/ts && bun bin/go.ts --check
protoc --proto_path=market/proto --descriptor_set_out=/dev/null market.proto
endef

define chanlun-ts-run
cd chanlun/ts && $(chanlun-ts-install) && biome check . && ./node_modules/.bin/tsc --noEmit -p . && ./node_modules/.bin/vitest run
cd chanlun/ts && bun bin/avsc.ts --check
cd chanlun/ts && bun bin/proto.ts --check
cd chanlun/ts && bun bin/go.ts --check
protoc --proto_path=chanlun/proto --descriptor_set_out=/dev/null chanlun.proto
endef

FORCE:

market-avro: ## market's Avro schemas, market/avro/*.avsc, made again from the Zod schemas
	cd market/ts && bun bin/avsc.ts

chanlun-avro: ## chanlun's Avro schemas, chanlun/avro/*.avsc, made again from the Zod schemas
	cd chanlun/ts && $(chanlun-ts-install) && bun bin/avsc.ts

market-proto: ## market's Protobuf description, market/proto/market.proto, made again from the Zod schemas and market/proto/fields.json (a new field: its number added there first)
	cd market/ts && bun bin/proto.ts

chanlun-proto: ## chanlun's Protobuf description, chanlun/proto/chanlun.proto, made again from the Zod schemas and chanlun/proto/fields.json
	cd chanlun/ts && $(chanlun-ts-install) && bun bin/proto.ts

market-go-types: ## market's Go types, market/go/market/records.go, made again from the Zod schemas
	cd market/ts && bun bin/go.ts

chanlun-go-types: ## chanlun's Go types, chanlun/go/chanlun/records.go, made again from the Zod schemas, naming market's
	cd chanlun/ts && $(chanlun-ts-install) && bun bin/go.ts

market-lean: ## market's Lean form, built by Lake with its decode, by qi-v2's Lean (the shell's) once its version is the one market/lean/lean-toolchain names (a check of the flake)
	@$(call nix-checks,$@,market)

chanlun-lean: ## chanlun's Lean form, built by Lake with its decode on market's Lake package as market-lean built it, by qi-v2's Lean once its version is the one chanlun/lean/lean-toolchain names (a check of the flake)
	@$(call nix-checks,$@,chanlun market)

market-go: ## market's Go form, market/go: every file as gofmt writes it, go vet, its tests over the vectors; the standard library only, nothing fetched (a check of the flake)
	@$(call nix-checks,$@,market)

chanlun-go: ## chanlun's Go form, chanlun/go, on market's module by its replace: every file as gofmt writes it, go vet, its tests over the vectors; nothing fetched (a check of the flake)
	@$(call nix-checks,$@,chanlun market)

market-conformance: ## market's three forms on every vector, each form's part reading its decode and the vectors alone: each ongoing K-line decoded and written to the same text by each, every reject case refused by each, as a fault of the contract (exit 1, `decode: ` and its message), not a crash (a check of the flake)
	@$(call nix-checks,$@,market)

chanlun-conformance: ## chanlun's three forms on every vector, each form's part reading its decode and the vectors alone: each run decoded and written to the same text by each, every reject case refused by each, as a fault of the contract (exit 1, `decode: ` and its message), not a crash (a check of the flake)
	@$(call nix-checks,$@,chanlun market)

market-cases: ## market's generated cases: from each valid vector, changed copies by a fixed seed (market/vectors/cases.ts), each answered alike by the three forms, all refusing it or all giving back the same text; each form's decode reads them in one process (--batch) and writes nothing to stderr (a check of the flake)
	@$(call nix-checks,$@,market)

chanlun-cases: ## chanlun's generated cases: the same, of its runs (chanlun/vectors/cases.ts) (a check of the flake)
	@$(call nix-checks,$@,chanlun market)

packages: ## the flake's packages built, and each taken as a taker takes it: the TypeScript ones imported by Bun, the Lean ones built by Lake, chanlun's beside market's where its lakefile names it, the Go ones built by Go in a module of its own by a replace to each one's store path, chanlun's and market's both, nothing fetched; each decoding market's ongoing K-line, or chanlun's small run, to the same text; the Avro ones what the schemas make, read by an Avro implementation; the Protobuf ones read by protoc
	@t=$$(mktemp -d) && trap 'rm -rf $$t' EXIT && \
	k=$$PWD/market/vectors/ongoing/kline.json && \
	v=$$PWD/chanlun/vectors/small.json && mkdir $$t/market $$t/chanlun && \
	ts=$$(nix build .#market-ts --no-link --print-out-paths) && ln -s $$ts/node_modules $$t/market/node_modules && \
	printf '%s\n' 'import { readFileSync } from "node:fs";' \
	  'import { decodeOngoingKLine, encodeOngoingKLine } from "@qi/market";' \
	  'const r = decodeOngoingKLine(readFileSync(process.argv.at(-1) ?? "", "utf8"));' \
	  'if (!r.ok) process.exit(1);' 'process.stdout.write(encodeOngoingKLine(r.kline));' > $$t/market/take.ts && \
	(cd $$t/market && bun take.ts $$k) | cmp -s - $$k && \
	echo "packages: $$ts taken by Bun: PASS" && \
	ts=$$(nix build .#chanlun-ts --no-link --print-out-paths) && ln -s $$ts/node_modules $$t/chanlun/node_modules && \
	printf '%s\n' 'import { readFileSync } from "node:fs";' 'import { decodeRun, encodeRun } from "@qi/chanlun";' \
	  'const r = decodeRun(readFileSync(process.argv.at(-1) ?? "", "utf8"));' 'if (!r.ok) process.exit(1);' \
	  'process.stdout.write(encodeRun(r.run));' > $$t/chanlun/take.ts && \
	(cd $$t/chanlun && bun take.ts $$v) | cmp -s - $$v && \
	echo "packages: $$ts taken by Bun: PASS" && \
	lean=$$(nix build .#market-lean --no-link --print-out-paths) && \
	cp -r $$lean $$t/market/lean && chmod -R u+w $$t/market/lean && (cd $$t/market/lean && lake build -q) && \
	$$t/market/lean/.lake/build/bin/decode --ongoing $$k | cmp -s - $$k && echo "packages: $$lean built by Lake: PASS" && \
	lean=$$(nix build .#chanlun-lean --no-link --print-out-paths) && \
	cp -r $$lean $$t/chanlun/lean && chmod -R u+w $$t/chanlun/lean && (cd $$t/chanlun/lean/chanlun/lean && lake build -q) && \
	$$t/chanlun/lean/chanlun/lean/.lake/build/bin/decode $$v | cmp -s - $$v && echo "packages: $$lean built by Lake: PASS" && \
	mgo=$$(nix build .#market-go --no-link --print-out-paths) && go=$$(nix build .#chanlun-go --no-link --print-out-paths) && \
	mkdir $$t/market/go $$t/chanlun/go && \
	printf '%s\n' 'module take' '' 'go 1.23' '' 'require github.com/zhifengzhang-sz/qi-v2-contracts/market/go v0.0.0' '' \
	  "replace github.com/zhifengzhang-sz/qi-v2-contracts/market/go => $$mgo" > $$t/market/go/go.mod && \
	printf '%s\n' 'package main' 'import (' '"os"' '"github.com/zhifengzhang-sz/qi-v2-contracts/market/go/market"' ')' \
	  'func main() {' 'data, _ := os.ReadFile(os.Args[len(os.Args)-1])' 'text := ""' \
	  'k, err := market.DecodeOngoingKLine(data)' 'if err == nil { text, err = market.EncodeOngoingKLine(k) }' \
	  'if err != nil { os.Exit(1) }' 'os.Stdout.WriteString(text)' '}' > $$t/market/go/take.go && \
	(cd $$t/market/go && GOPROXY=off GOFLAGS=-mod=readonly go build -o take .) && \
	$$t/market/go/take $$k | cmp -s - $$k && echo "packages: $$mgo taken by Go: PASS" && \
	printf '%s\n' 'module take' '' 'go 1.23' '' 'require (' 'github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go v0.0.0' \
	  'github.com/zhifengzhang-sz/qi-v2-contracts/market/go v0.0.0' ')' '' \
	  "replace github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go => $$go" \
	  "replace github.com/zhifengzhang-sz/qi-v2-contracts/market/go => $$mgo" > $$t/chanlun/go/go.mod && \
	printf '%s\n' 'package main' 'import (' '"os"' '"github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go/chanlun"' ')' \
	  'func main() {' 'data, _ := os.ReadFile(os.Args[len(os.Args)-1])' 'text := ""' \
	  'r, err := chanlun.DecodeRun(data)' 'if err == nil { text, err = chanlun.EncodeRun(r) }' \
	  'if err != nil { os.Exit(1) }' 'os.Stdout.WriteString(text)' '}' > $$t/chanlun/go/take.go && \
	(cd $$t/chanlun/go && GOPROXY=off GOFLAGS=-mod=readonly go build -o take .) && \
	$$t/chanlun/go/take $$v | cmp -s - $$v && echo "packages: $$go taken by Go: PASS" && \
	avro=$$(nix build .#market-avro --no-link --print-out-paths) && \
	(cd market/ts && bun install --frozen-lockfile && bun bin/avsc.ts --check $$avro) && echo "packages: $$avro read by avsc: PASS" && \
	avro=$$(nix build .#chanlun-avro --no-link --print-out-paths) && \
	(cd chanlun/ts && $(chanlun-ts-install) && bun bin/avsc.ts --check $$avro) && \
	echo "packages: $$avro read by avsc: PASS" && \
	mproto=$$(nix build .#market-proto --no-link --print-out-paths) && \
	protoc --proto_path=$$mproto --descriptor_set_out=/dev/null market.proto && echo "packages: $$mproto read by protoc: PASS" && \
	proto=$$(nix build .#chanlun-proto --no-link --print-out-paths) && \
	protoc --proto_path=$$proto --descriptor_set_out=/dev/null chanlun.proto && \
	echo "packages: $$proto read by protoc: PASS"

products-check: ## whether PRODUCTS.md states what the project has (the kit's kit products)
	@kit=$$($(call nix-build,"$(KIT)")) && $$kit/bin/kit products --root .
