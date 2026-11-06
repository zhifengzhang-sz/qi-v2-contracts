// Package market is the market data contract in Go (SPEC.md): the K-lines, of whatever source gives them, and how they
// cross from one project to another as JSON.
//
// The records' types (records.go) are made from the TypeScript form's Zod schemas, not edited by hand; their rules
// (rules.go) and their JSON (json.go, codec.go) are written by hand, every rule of SPEC.md, and held to the vectors
// with the TypeScript and Lean forms (make check). The standard library only.
//
// DecodeOngoingKLine and DecodeMassiveOngoingKLine read an ongoing K-line's JSON, refusing what every form refuses: a
// number not written in digits or past the bound, a name that is no field, a name twice in one object, text not UTF-8,
// a field missing, null, a value of another kind, and a broken rule; on a fault they give the zero value. They read
// the text straight into the record. EncodeOngoingKLine writes the canonical text, once the rules are checked. A price
// and a quantity are a Decimal, exact, never a float64 (ParseDecimal from its digits, DecimalOf from a whole number of
// units, Neg its negation, String and AppendTo its digits); a whole number is a uint64 up to Bound. Nothing goes through
// encoding/json: each type's MarshalJSON and UnmarshalJSON give ErrEncodingJSON (encoding.go). A type a taker defines
// on one of them (type Price market.Decimal) has none of its methods, these among them, and encoding/json writes it as
// {}: hold the package's own types.
//
// A K-line is a value: its fields are numbers and Decimals, each a value with no exported slice, map or pointer, so a
// holder that changes its copy changes nothing in anyone else's. A contract built on this one takes its K-lines, their
// rules (Check) and their base (Base), and Decimal for its own prices.
package market
