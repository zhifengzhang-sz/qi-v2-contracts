package market

import (
	"errors"
)

// encoding/json: no type of the package crosses through it, and each says so rather than writing {} for a price. An
// ongoing K-line has one canonical text, which EncodeOngoingKLine writes and DecodeOngoingKLine reads with every rule;
// encoding/json rewrites what a MarshalJSON gives (it compacts it, and MarshalIndent indents it again), so a record
// written through it would be a second text of the one record. It knows a record's fields by their Go names (Index,
// AsOf), not the contract's, and reads a record without its rules. So every record and Decimal have MarshalJSON and
// UnmarshalJSON, and both give ErrEncodingJSON: what to use instead.

// ErrEncodingJSON: what MarshalJSON and UnmarshalJSON give, for every type of the package: the contract's JSON is
// written and read by its own functions, not by encoding/json.
var ErrEncodingJSON = errors.New("market: not by encoding/json: an ongoing K-line is written by EncodeOngoingKLine " +
	"and read by DecodeOngoingKLine, a K-line by its taker, in a text of its own (a contract derived from market " +
	"takes its units and its JSON, refers to its K-lines by their positions, and holds none), a Decimal by String " +
	"and ParseDecimal")

// MarshalJSON: refused, ErrEncodingJSON: a Decimal's digits are String's.
func (Decimal) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a Decimal is read from its digits by ParseDecimal.
func (*Decimal) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: an ongoing K-line is written by EncodeOngoingKLine.
func (OngoingKLine) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: an ongoing K-line is read by DecodeOngoingKLine.
func (*OngoingKLine) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a K-line is written by its taker, in a text of its own; a contract derived
// from this one takes its units and its JSON, refers to its K-lines by their positions, and holds none.
func (KLine) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a K-line is read by its taker, from a text of its own; a contract derived
// from this one takes its units and its JSON, refers to its K-lines by their positions, and holds none.
func (*KLine) UnmarshalJSON([]byte) error { return ErrEncodingJSON }
