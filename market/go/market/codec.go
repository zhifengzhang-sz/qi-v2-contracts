package market

import (
	"reflect"
)

// An ongoing K-line's records as JSON (SPEC.md, The JSON): decoding reads the text (json.go) into the record's type
// (records.go), then checks every rule (rules.go); encoding checks the rules, then writes the canonical text every form
// writes, which the conformance check compares: its fields in the order of their names, then a line break.

// decodeAs: data as a T, every rule checked; on a fault the zero T, never a T half read or one that breaks a rule
func decodeAs[T interface{ Check() error }](data []byte) (T, error) {
	var r, zero T
	if err := parse(data, reflect.ValueOf(&r).Elem()); err != nil {
		return zero, err
	}
	if err := r.Check(); err != nil {
		return zero, err
	}
	return r, nil
}

// DecodeOngoingKLine: an ongoing K-line's JSON as its record; a fault as an error, and the zero OngoingKLine.
func DecodeOngoingKLine(data []byte) (OngoingKLine, error) {
	return decodeAs[OngoingKLine](data)
}

// DecodeMassiveOngoingKLine: Massive's ongoing K-line's JSON as its record; a fault as an error, and the zero
// MassiveOngoingKLine.
func DecodeMassiveOngoingKLine(data []byte) (MassiveOngoingKLine, error) {
	return decodeAs[MassiveOngoingKLine](data)
}

// EncodeOngoingKLine: an ongoing K-line's canonical JSON, of the base's or of Massive's, once its rules are checked: its
// record, and a line break.
func EncodeOngoingKLine[K OngoingKLine | MassiveOngoingKLine](kline K) (string, error) {
	if err := any(kline).(interface{ Check() error }).Check(); err != nil {
		return "", err
	}
	e := &encoder{}
	e.write(reflect.ValueOf(&kline).Elem(), shapeOf(reflect.TypeFor[K]()))
	e.str("\n")
	return e.text(), nil
}
