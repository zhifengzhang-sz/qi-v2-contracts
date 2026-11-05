package chanlun

// Nothing given out changes what another holder has: a taker writing over everything it is given, and over
// everything it can reach from it, changes nothing in the run another holder has.

import (
	"reflect"
	"testing"
)

// overwrite: a taker writing over everything it is given: its copy of the run, each part, each record and list taken
// out of it by every method, and, by reflection, every value reachable from its copy that can be set
func overwrite(r Run) {
	d, _ := ParseDecimal("-1")
	ks := r.Klines.Slice()
	for i := range ks {
		ks[i].Open, ks[i].Index = d, 99
	}
	for _, k := range r.Klines.All() {
		k.Close = d
	}
	for k := range r.Klines.Values() {
		k.High = d
	}
	k := r.Klines.At(0)
	k.Low = d
	ms := r.Merged.Slice()
	for i := range ms {
		es := ms[i].Extremes.Slice()
		for j := range es {
			es[j] = 99
		}
		ms[i].Extremes = ListOf[uint64]()
		ms[i].ConfirmEnd = Some[uint64](99)
	}
	m, _ := r.Merged.Last()
	m.ConfirmEnd, m.Up = None[uint64](), !m.Up
	ls := r.Segments.Slice()
	for i := range ls {
		ss := ls[i].Slice()
		for j := range ss {
			ss[j].Start, ss[j].Level = 99, 99
		}
		ls[i] = ListOf[Segment]()
	}
	cs := r.Consolidations.At(0).Slice()
	cs[0].Zg = d
	// by reflection, every value reachable from the copy that can be set: a List's items cannot be
	var walk func(v reflect.Value)
	walk = func(v reflect.Value) {
		switch v.Kind() {
		case reflect.Struct:
			for i := range v.NumField() {
				walk(v.Field(i))
			}
		case reflect.Slice:
			for i := range v.Len() {
				walk(v.Index(i))
			}
		}
		if v.CanSet() && v.Kind() != reflect.Struct {
			v.Set(reflect.Zero(v.Type()))
		}
	}
	walk(reflect.ValueOf(&r).Elem())
	r.Klines, r.Merged, r.Fractals, r.Strokes = List[KLine]{}, List[MergedBar]{}, List[Fractal]{}, List[Line]{}
	r.Segments, r.Moves, r.Consolidations = List[List[Segment]]{}, List[List[Move]]{}, List[List[Consolidation]]{}
}

func TestNothingGivenOutChangesTheRun(t *testing.T) {
	for _, file := range []string{"run.json", "small.json"} {
		r, err := DecodeRun(read(t, file))
		if err != nil {
			t.Fatal(err)
		}
		before, err := EncodeRun(r)
		if err != nil {
			t.Fatal(err)
		}
		// two takers given the run
		overwrite(r)
		taker := r
		overwrite(taker)
		after, err := EncodeRun(r)
		if err != nil {
			t.Fatal(err)
		}
		if after != before {
			t.Fatalf("%s: a taker writing over what it was given changed the run", file)
		}
	}
}

// No type given out has an exported field, or a method whose result is, a slice, a map, a pointer or a channel: what
// a holder is given can only be a value, but for List.Slice, a copy (TestNothingGivenOutChangesTheRun)
func TestNothingGivenOutIsShared(t *testing.T) {
	shared := func(k reflect.Kind) bool {
		return k == reflect.Slice || k == reflect.Map || k == reflect.Pointer || k == reflect.Chan || k == reflect.UnsafePointer
	}
	for _, typ := range []reflect.Type{
		reflect.TypeFor[KLine](), reflect.TypeFor[MassiveKLine](), reflect.TypeFor[OngoingKLine](),
		reflect.TypeFor[MassiveOngoingKLine](), reflect.TypeFor[MergedBar](), reflect.TypeFor[Fractal](),
		reflect.TypeFor[Line](), reflect.TypeFor[Segment](), reflect.TypeFor[Move](), reflect.TypeFor[Consolidation](),
		reflect.TypeFor[Run](), reflect.TypeFor[MassiveRun](), reflect.TypeFor[Decimal](),
		reflect.TypeFor[List[MergedBar]](), reflect.TypeFor[List[List[Segment]]](), reflect.TypeFor[Optional[uint64]](),
	} {
		for i := range typ.NumField() {
			if f := typ.Field(i); f.IsExported() && shared(f.Type.Kind()) {
				t.Errorf("%s.%s: a field a holder shares", typ, f.Name)
			}
		}
		for _, m := range []reflect.Type{typ, reflect.PointerTo(typ)} {
			for i := range m.NumMethod() {
				method := m.Method(i)
				for o := range method.Type.NumOut() {
					if shared(method.Type.Out(o).Kind()) && method.Name != "Slice" {
						t.Errorf("%s.%s: a result a holder shares", m, method.Name)
					}
				}
			}
		}
	}
}

func TestListCopiesIn(t *testing.T) {
	r, err := DecodeRun(read(t, "small.json"))
	if err != nil {
		t.Fatal(err)
	}
	before, _ := EncodeRun(r)
	ks := r.Klines.Slice()
	ms := r.Merged.Slice()
	es := ms[0].Extremes.Slice()
	ms[0].Extremes = ListOf(es...)
	made := Run{Klines: ListOf(ks...), Merged: ListOf(ms...), Fractals: r.Fractals, Strokes: r.Strokes,
		Segments: r.Segments, Moves: r.Moves, Consolidations: r.Consolidations}
	// the slices it was made of written over after
	d, _ := ParseDecimal("1")
	ks[0].Open, ms[1].Up, es[0] = d, !ms[1].Up, 0
	text, err := EncodeRun(made)
	if err != nil {
		t.Fatal(err)
	}
	if text != before {
		t.Fatal("a run made of slices changed with them")
	}
}
