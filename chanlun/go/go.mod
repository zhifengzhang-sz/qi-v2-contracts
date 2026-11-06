// 缠论's contract in Go (SPEC.md): the records' types, made from the Zod schemas (chanlun/records.go), their rules and
// their JSON written by hand, and the program decode (cmd/decode). The standard library only, and market's module, whose
// K-line a run holds (../../market/go): beside it in the repository, by the replace below; a taker of this module
// requires and replaces both (../README.md, Taking it).
module github.com/zhifengzhang-sz/qi-v2-contracts/chanlun/go

go 1.23

require github.com/zhifengzhang-sz/qi-v2-contracts/market/go v0.0.0

replace github.com/zhifengzhang-sz/qi-v2-contracts/market/go => ../../market/go
