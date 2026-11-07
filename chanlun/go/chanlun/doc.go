// Package chanlun is 缠论's contract in Go (SPEC.md): the records the algorithm of 缠论 gives over a run of bars, of
// whatever implementation gives them, and how they cross from one project to another as JSON.
//
// The records' types (records.go) are made from the TypeScript form's Zod schemas, not edited by hand; their rules
// (rules.go) and their JSON (json.go, codec.go) are written by hand, every rule of SPEC.md, and held to the vectors
// with the TypeScript and Lean forms (make check). The standard library only, and market's module: a run's K-lines
// are market.KLine, the base's, held to their rules by their Check, and a price is a market.Decimal; this package
// defines no K-line of its own (github.com/zhifengzhang-sz/qi-v2-contracts/market/go/market).
//
// DecodeRun reads a run's JSON, refusing what every form refuses: a number not written in digits or past the bound, a
// name that is no field or part, a name twice in one object, text not UTF-8, a field missing that is not optional,
// null, a value of another kind, and a broken rule; on a fault it gives the zero value. It reads the text straight
// into the records, with no tree of the whole text. EncodeRun writes the canonical text, once the rules are checked. A
// price and a quantity are market's Decimal, exact, never a float64; a whole number is a uint64 up to market's Bound.
// Nothing goes through encoding/json: each type's MarshalJSON and UnmarshalJSON give ErrEncodingJSON (encoding.go),
// market's market.ErrEncodingJSON. A type a taker defines on one of them (type Bars chanlun.List[chanlun.MergedBar])
// has none of its methods, these among them, and encoding/json writes it as {}: hold the packages' own types.
//
// Nothing given out changes what another holder has. A record is a value: its fields are numbers, booleans, Decimals,
// Optionals and Lists, each a value with no exported slice, map or pointer. A List keeps its items behind methods:
// ListOf copies them in, Slice copies them out, and At, All and Values give them as values. A Run holds its parts as
// Lists, so a holder that changes its copy of a run, or of anything it was given from one, changes nothing in anyone
// else's. A run a holder makes is checked by Run.Check, and by EncodeRun before it is written.
package chanlun
