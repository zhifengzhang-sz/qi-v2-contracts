# The contracts' checks (README.md), in the shell (nix develop). `make check`: both contracts; `make market` or
# `make chanlun`: one. `make generate`: the Go and TypeScript code made again from the .proto files.
.PHONY: check lint generate breaking packages products-check market chanlun
CONTRACTS = market chanlun
KIT = $(shell bun -e 'const n = JSON.parse(await Bun.file("flake.lock").text()).nodes.kit.locked; console.log(n.type + ":" + n.owner + "/" + n.repo + "/" + n.rev + "?dir=" + n.dir)')

check: lint $(CONTRACTS) products-check

# the .proto files by buf's standard rules; the TypeScript by Biome
lint:
	buf lint
	biome check

generate:
	for c in $(CONTRACTS); do buf generate --template $$c/buf.gen.yaml || exit 1; done

# A contract: its generated code what its .proto makes; its examples breaking exactly the rules they name, by Lean, by
# Go and by TypeScript (Go's test cache does not see the examples change, hence -count=1)
$(CONTRACTS):
	@t=$$(mktemp -d) && buf generate --template $@/buf.gen.yaml -o $$t && \
	diff -u $$t/$@/go/$@/$@.pb.go $@/go/$@/$@.pb.go && diff -u $$t/$@/ts/src/$@_pb.ts $@/ts/src/$@_pb.ts; \
	s=$$?; rm -rf $$t; [ $$s -eq 0 ] && echo "$@: generated code current"
	cd $@/lean && lake build -q && lake exe examples ../examples.json
	cd $@/go && go vet ./... && test -z "$$(gofmt -l .)" && go test -count=1 ./...
	cd $@/ts && bun install --frozen-lockfile && bun node_modules/typescript/bin/tsc --noEmit -p . && bun test

# Before a release: each .proto against its contract's last release; a break is a new major version
breaking:
	@for c in $(CONTRACTS); do t=$$(git describe --tags --abbrev=0 --match "$$c-*") && \
	buf breaking $$c/proto --against ".git#tag=$$t,subdir=$$c/proto" && echo "$$c: no break since $$t" || exit 1; done

packages:
	nix build --no-link $(foreach c,$(CONTRACTS),.#$(c)-proto .#$(c)-go .#$(c)-ts .#$(c)-lean)

# whether PRODUCTS.md states what the project has (the kit's kit products)
products-check:
	@kit=$$(nix build --no-link --print-out-paths "$(KIT)") && $$kit/bin/kit products --root .
