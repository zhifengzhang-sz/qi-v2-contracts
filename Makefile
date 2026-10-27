# The contracts' checks (README.md): each form's own, then the conformance of each contract's forms, run on every
# change. In the shell (nix develop).
.PHONY: help check chanlun chanlun-ts chanlun-lean chanlun-conformance packages
help: ## the targets
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /: /'

check: chanlun ## every contract: its forms' checks and their conformance

chanlun: chanlun-ts chanlun-lean chanlun-conformance ## 缠论's contract

chanlun-ts: ## the TypeScript form: Biome, tsc, its tests over the vectors
	cd chanlun/ts && bun install --frozen-lockfile && biome check . && ./node_modules/.bin/tsc --noEmit -p . && ./node_modules/.bin/vitest run

chanlun-lean: ## the Lean form, built with its decode, by the shell's Lean once its version is the one chanlun/lean/lean-toolchain names
	@v=$$(lean --version | sed -n 's/^Lean (version \([^,]*\),.*/\1/p'); t=$$(sed 's|^leanprover/lean4:v||' chanlun/lean/lean-toolchain); \
	[ -n "$$v" ] && [ "$$t" = "$$v" ] || { echo "chanlun-lean: the shell's Lean is '$$v', chanlun/lean/lean-toolchain names '$$t'"; exit 1; }
	cd chanlun/lean && lake build

chanlun-conformance: chanlun-lean ## both forms on every vector: each run decoded and written to the same text by both, every reject case refused by both, as a fault of the contract (exit 1, `decode: ` and its message), not a crash
	@cd chanlun && s=0; r=0; n=0; \
	for v in vectors/run.json vectors/small.json vectors/edge.json; do r=$$((r+1)); \
	  (cd ts && bun bin/decode.ts ../$$v) | cmp -s - $$v || { echo "conformance: ts does not give $$v back"; s=1; }; \
	  lean/.lake/build/bin/decode $$v | cmp -s - $$v || { echo "conformance: lean does not give $$v back"; s=1; }; \
	done; \
	for v in vectors/reject/*.json; do n=$$((n+1)); \
	  e=$$(cd ts && bun bin/decode.ts ../$$v 2>&1 >/dev/null); c=$$?; \
	  [ $$c = 1 ] && case "$$e" in "decode: "*) true;; *) false;; esac || { echo "conformance: ts on $$v: exit $$c, $$e"; s=1; }; \
	  e=$$(timeout 60 lean/.lake/build/bin/decode $$v 2>&1 >/dev/null); c=$$?; \
	  [ $$c = 1 ] && case "$$e" in "decode: "*) true;; *) false;; esac || { echo "conformance: lean on $$v: exit $$c, $$e"; s=1; }; \
	done; \
	[ $$s = 0 ] && echo "chanlun conformance: $$r runs given back alike by both forms, $$n reject cases refused by both: PASS" || { echo "chanlun conformance: FAIL"; exit 1; }

packages: ## the flake's packages built, and each taken as a taker takes it: the TypeScript one imported by Bun, the Lean one built by Lake, each decoding the small run to the same text
	@ts=$$(nix build .#chanlun-ts --no-link --print-out-paths) && lean=$$(nix build .#chanlun-lean --no-link --print-out-paths) && \
	t=$$(mktemp -d) && trap 'rm -rf $$t' EXIT && v=$$PWD/chanlun/vectors/small.json && \
	ln -s $$ts/node_modules $$t/node_modules && \
	printf '%s\n' 'import { readFileSync } from "node:fs";' 'import { decodeRun, encodeRun } from "@qi/chanlun";' \
	  'const r = decodeRun(readFileSync(process.argv[2] ?? "", "utf8"));' 'if (!r.ok) process.exit(1);' \
	  'process.stdout.write(encodeRun(r.run));' > $$t/take.ts && \
	(cd $$t && bun take.ts $$v) | cmp -s - $$v && echo "packages: $$ts taken by Bun: PASS" && \
	cp -r $$lean $$t/lean && chmod -R u+w $$t/lean && (cd $$t/lean && lake build -q) && \
	$$t/lean/.lake/build/bin/decode $$v | cmp -s - $$v && echo "packages: $$lean built by Lake: PASS"
