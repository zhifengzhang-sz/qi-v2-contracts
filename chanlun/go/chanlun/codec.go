package chanlun

import (
	"reflect"
)

// A run's records as JSON (SPEC.md, The JSON): decoding reads the text (json.go) into the records' types
// (records.go), then checks every rule (rules.go); encoding checks the rules, then writes the canonical text every form
// writes, which the conformance check compares: the run's parts in their order, a record a line, its fields in the
// order of their names, a field not set left out. An ongoing K-line is market's (market.DecodeOngoingKLine).

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

// DecodeRun: a run's JSON, its bytes UTF-8, as its records; a fault, with its place, as an error, and the zero Run.
func DecodeRun(data []byte) (Run, error) { return decodeAs[Run](data) }

// records: a part's records, a record a line
func records[T any](e *encoder, l *List[T]) {
	if l.Len() == 0 {
		e.str("[]")
		return
	}
	s := shapeOf(reflect.TypeFor[T]())
	e.str("[\n")
	for i := range l.items {
		if i > 0 {
			e.str(",\n")
		}
		e.write(reflect.ValueOf(&l.items[i]).Elem(), s)
		e.cut()
	}
	e.str("\n]")
}

// levels: a part by level, a level's records in place of a record
func levels[T any](e *encoder, l *List[List[T]]) {
	if l.Len() == 0 {
		e.str("[]")
		return
	}
	e.str("[\n")
	for i := range l.items {
		if i > 0 {
			e.str(",\n")
		}
		records(e, &l.items[i])
	}
	e.str("\n]")
}

// EncodeRun: a run's canonical JSON, once its rules are checked: a run that breaks one is not written, and its fault is
// the error.
func EncodeRun(run Run) (string, error) {
	if err := run.Check(); err != nil {
		return "", err
	}
	// the parts in their order, each its name and its value, separated by , and a line break
	e := &encoder{}
	e.str("{\n\"merged\": ")
	records(e, &run.Merged)
	e.str(",\n\"fractals\": ")
	records(e, &run.Fractals)
	e.str(",\n\"strokes\": ")
	records(e, &run.Strokes)
	e.str(",\n\"segments\": ")
	levels(e, &run.Segments)
	e.str(",\n\"moves\": ")
	levels(e, &run.Moves)
	e.str(",\n\"consolidations\": ")
	levels(e, &run.Consolidations)
	e.str("\n}\n")
	return e.text(), nil
}
