package chanlun

import (
	"reflect"
	"strings"
)

// A run's records as JSON, and an ongoing K-line's (SPEC.md, The JSON): decoding reads the text (json.go) into the
// records' types (records.go), then checks every rule (rules.go); encoding checks the rules, then writes the
// canonical text every form writes, which the conformance check compares: the run's parts in their order, a record a
// line, its fields in the order of their names, a field not set left out.

func decodeAs[T interface{ Check() error }](data []byte) (T, error) {
	var r T
	j, err := parse(data)
	if err != nil {
		return r, err
	}
	if err := decodeRecord(reflect.ValueOf(&r).Elem(), &j, ""); err != nil {
		return r, err
	}
	if err := r.Check(); err != nil {
		return r, err
	}
	return r, nil
}

// DecodeRun: a run's JSON, its bytes UTF-8, as its records; a fault, with its place, as an error.
func DecodeRun(data []byte) (Run, error) { return decodeAs[Run](data) }

// DecodeMassiveRun: a run of Massive's K-lines, its JSON, as its records; a fault as an error.
func DecodeMassiveRun(data []byte) (MassiveRun, error) { return decodeAs[MassiveRun](data) }

// DecodeOngoingKLine: an ongoing K-line's JSON as its record; a fault as an error.
func DecodeOngoingKLine(data []byte) (OngoingKLine, error) {
	return decodeAs[OngoingKLine](data)
}

// DecodeMassiveOngoingKLine: Massive's ongoing K-line's JSON as its record; a fault as an error.
func DecodeMassiveOngoingKLine(data []byte) (MassiveOngoingKLine, error) {
	return decodeAs[MassiveOngoingKLine](data)
}

func records[T any](b *strings.Builder, l List[T]) {
	if l.Len() == 0 {
		b.WriteString("[]")
		return
	}
	b.WriteString("[\n")
	for i, r := range l.items {
		if i > 0 {
			b.WriteString(",\n")
		}
		writeRecord(b, reflect.ValueOf(r))
	}
	b.WriteString("\n]")
}

func levels[T any](b *strings.Builder, l List[List[T]]) {
	if l.Len() == 0 {
		b.WriteString("[]")
		return
	}
	b.WriteString("[\n")
	for i, rs := range l.items {
		if i > 0 {
			b.WriteString(",\n")
		}
		records(b, rs)
	}
	b.WriteString("\n]")
}

// EncodeRun: a run's canonical JSON, of a run or of Massive's run, once its rules are checked: a run that breaks one is
// not written, and its fault is the error.
func EncodeRun[R Run | MassiveRun](run R) (string, error) {
	var b strings.Builder
	part := func(name string, write func()) {
		if b.Len() > 2 {
			b.WriteString(",\n")
		}
		b.WriteString(`"` + name + `": `)
		write()
	}
	b.WriteString("{\n")
	switch r := any(run).(type) {
	case Run:
		if err := r.Check(); err != nil {
			return "", err
		}
		part("klines", func() { records(&b, r.Klines) })
		writeParts(part, &b, r.Merged, r.Fractals, r.Strokes, r.Segments, r.Moves, r.Consolidations)
	case MassiveRun:
		if err := r.Check(); err != nil {
			return "", err
		}
		part("klines", func() { records(&b, r.Klines) })
		writeParts(part, &b, r.Merged, r.Fractals, r.Strokes, r.Segments, r.Moves, r.Consolidations)
	}
	b.WriteString("\n}\n")
	return b.String(), nil
}

func writeParts(part func(string, func()), b *strings.Builder, merged List[MergedBar], fractals List[Fractal],
	strokes List[Line], segments List[List[Segment]], moves List[List[Move]], consolidations List[List[Consolidation]]) {
	part("merged", func() { records(b, merged) })
	part("fractals", func() { records(b, fractals) })
	part("strokes", func() { records(b, strokes) })
	part("segments", func() { levels(b, segments) })
	part("moves", func() { levels(b, moves) })
	part("consolidations", func() { levels(b, consolidations) })
}

// EncodeOngoingKLine: an ongoing K-line's canonical JSON, of the base's or of Massive's, once its rules are checked: its
// record, and a line break.
func EncodeOngoingKLine[K OngoingKLine | MassiveOngoingKLine](kline K) (string, error) {
	if err := any(kline).(interface{ Check() error }).Check(); err != nil {
		return "", err
	}
	var b strings.Builder
	writeRecord(&b, reflect.ValueOf(kline))
	b.WriteString("\n")
	return b.String(), nil
}
