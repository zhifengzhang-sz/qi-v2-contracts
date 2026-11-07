package market

// Nothing given out changes what another holder has: a record is a value, its fields numbers and Decimals, so a holder
// writing over its copy changes nothing in another's.

import (
	"reflect"
	"testing"
)

func TestNothingGivenOutChangesTheRecord(t *testing.T) {
	k, err := DecodeOngoingKLine(read(t, "ongoing/kline.json"))
	if err != nil {
		t.Fatal(err)
	}
	before, err := EncodeOngoingKLine(k)
	if err != nil {
		t.Fatal(err)
	}
	d, _ := ParseDecimal("-1")
	taker := k
	taker.Open, taker.Index, taker.AsOf = d, 99, 99
	base := k.kline().Base()
	base.High = d
	after, err := EncodeOngoingKLine(k)
	if err != nil {
		t.Fatal(err)
	}
	if after != before {
		t.Fatal("a taker writing over what it was given changed the record")
	}
}

// No type given out has an exported field, or a method whose result is, a slice, a map, a pointer or a channel: what
// a holder is given can only be a value, but for MarshalJSON, which gives no bytes at all (TestNotByEncodingJSON)
func TestNothingGivenOutIsShared(t *testing.T) {
	shared := func(k reflect.Kind) bool {
		return k == reflect.Slice || k == reflect.Map || k == reflect.Pointer || k == reflect.Chan || k == reflect.UnsafePointer
	}
	for _, typ := range []reflect.Type{
		reflect.TypeFor[KLine](), reflect.TypeFor[OngoingKLine](), reflect.TypeFor[Decimal](),
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
					if shared(method.Type.Out(o).Kind()) && method.Name != "MarshalJSON" && method.Name != "AppendTo" {
						t.Errorf("%s.%s: a result a holder shares", m, method.Name)
					}
				}
			}
		}
	}
}
