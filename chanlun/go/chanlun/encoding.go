package chanlun

import (
	"errors"
)

// encoding/json: no type of the package crosses through it, and each says so rather than writing {} for a price. A
// run has one canonical text, which EncodeRun writes and DecodeRun reads with every rule; encoding/json rewrites what a
// MarshalJSON gives (it compacts it, and MarshalIndent indents it again), so a run written through it would be a second
// text of the one run. It knows a record's fields by their Go names (Index, MIndex), not the contract's, and reads a
// record without its rules or the run's. So every record, both runs, and Decimal, List and Optional have MarshalJSON
// and UnmarshalJSON, and both give ErrEncodingJSON: what to use instead.

// ErrEncodingJSON: what MarshalJSON and UnmarshalJSON give, for every type of the package: the contract's JSON is
// written and read by its own functions, not by encoding/json.
var ErrEncodingJSON = errors.New("chanlun: not by encoding/json: a run is written by EncodeRun and read by DecodeRun " +
	"or DecodeMassiveRun, an ongoing K-line by EncodeOngoingKLine and DecodeOngoingKLine or DecodeMassiveOngoingKLine, " +
	"a Decimal by String and ParseDecimal")

// MarshalJSON: refused, ErrEncodingJSON: a Decimal's digits are String's.
func (Decimal) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a Decimal is read from its digits by ParseDecimal.
func (*Decimal) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a List is written in its run by EncodeRun.
func (List[T]) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a List is read in its run by DecodeRun.
func (*List[T]) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: an Optional is written in its record, and left out when it is not set, by
// EncodeRun.
func (Optional[T]) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: an Optional is read in its record by DecodeRun.
func (*Optional[T]) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a run is written by EncodeRun.
func (Run) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a run is read by DecodeRun.
func (*Run) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: Massive's run is written by EncodeRun.
func (MassiveRun) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: Massive's run is read by DecodeMassiveRun.
func (*MassiveRun) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: an ongoing K-line is written by EncodeOngoingKLine.
func (OngoingKLine) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: an ongoing K-line is read by DecodeOngoingKLine.
func (*OngoingKLine) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: Massive's ongoing K-line is written by EncodeOngoingKLine.
func (MassiveOngoingKLine) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: Massive's ongoing K-line is read by DecodeMassiveOngoingKLine.
func (*MassiveOngoingKLine) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a K-line is written in its run by EncodeRun.
func (KLine) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a K-line is read in its run by DecodeRun.
func (*KLine) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: Massive's K-line is written in its run by EncodeRun.
func (MassiveKLine) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: Massive's K-line is read in its run by DecodeMassiveRun.
func (*MassiveKLine) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a merged bar is written in its run by EncodeRun.
func (MergedBar) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a merged bar is read in its run by DecodeRun.
func (*MergedBar) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a 分型 is written in its run by EncodeRun.
func (Fractal) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a 分型 is read in its run by DecodeRun.
func (*Fractal) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a line, a 笔, is written in its run by EncodeRun.
func (Line) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a line, a 笔, is read in its run by DecodeRun.
func (*Line) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a 线段 is written in its run by EncodeRun.
func (Segment) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a 线段 is read in its run by DecodeRun.
func (*Segment) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a 走势 is written in its run by EncodeRun.
func (Move) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a 走势 is read in its run by DecodeRun.
func (*Move) UnmarshalJSON([]byte) error { return ErrEncodingJSON }

// MarshalJSON: refused, ErrEncodingJSON: a 中枢 is written in its run by EncodeRun.
func (Consolidation) MarshalJSON() ([]byte, error) { return nil, ErrEncodingJSON }

// UnmarshalJSON: refused, ErrEncodingJSON: a 中枢 is read in its run by DecodeRun.
func (*Consolidation) UnmarshalJSON([]byte) error { return ErrEncodingJSON }
