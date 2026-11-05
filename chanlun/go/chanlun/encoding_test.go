package chanlun

// encoding/json never writes a record, a run, a Decimal, a List or an Optional, nor reads one: each refuses it with
// ErrEncodingJSON, which says what to use. Every type of records.go among them.

import (
	"encoding/json"
	"errors"
	"go/ast"
	"go/parser"
	"go/token"
	"reflect"
	"slices"
	"strings"
	"testing"
)

func TestNotByEncodingJSON(t *testing.T) {
	r, err := DecodeRun(read(t, "small.json"))
	if err != nil {
		t.Fatal(err)
	}
	k, err := DecodeOngoingKLine(read(t, "ongoing/kline.json"))
	if err != nil {
		t.Fatal(err)
	}
	m, err := DecodeMassiveRun(read(t, "massive/small.json"))
	if err != nil {
		t.Fatal(err)
	}
	mk, err := DecodeMassiveOngoingKLine(read(t, "ongoing/massive.json"))
	if err != nil {
		t.Fatal(err)
	}
	given := []any{
		r, m, k, mk, r.Klines.At(0), m.Klines.At(0), r.Merged.At(0), r.Fractals.At(0), r.Strokes.At(0),
		r.Segments.At(0).At(0), r.Moves.At(0).At(0), r.Consolidations.At(0).At(0), r.Klines.At(0).High, r.Klines,
		r.Merged.At(0).Extremes, r.Segments, r.Merged.At(0).ConfirmEnd, None[uint64](), Optional[Decimal]{},
	}
	// every type records.go makes is one of them
	file, err := parser.ParseFile(token.NewFileSet(), "records.go", nil, 0)
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	for _, v := range given {
		names = append(names, reflect.TypeOf(v).Name())
	}
	ast.Inspect(file, func(n ast.Node) bool {
		if s, ok := n.(*ast.TypeSpec); ok && !slices.Contains(names, s.Name.Name) {
			t.Errorf("%s, a type of records.go: not tried", s.Name.Name)
		}
		return true
	})
	for _, v := range given {
		name := reflect.TypeOf(v).String()
		for _, x := range []any{v, reflect.New(reflect.TypeOf(v)).Interface()} {
			b, err := json.Marshal(x)
			if !errors.Is(err, ErrEncodingJSON) || b != nil {
				t.Errorf("%s: json.Marshal gave %q, %v", name, b, err)
			}
			if _, err := json.MarshalIndent(x, "", " "); !errors.Is(err, ErrEncodingJSON) {
				t.Errorf("%s: json.MarshalIndent gave %v", name, err)
			}
		}
		if b, _ := reflect.ValueOf(v).Interface().(json.Marshaler).MarshalJSON(); b != nil {
			t.Errorf("%s: MarshalJSON gave bytes", name)
		}
		p := reflect.New(reflect.TypeOf(v))
		for _, text := range []string{"{}", "[]", "1", "null", `{"klines": []}`} {
			if err := json.Unmarshal([]byte(text), p.Interface()); !errors.Is(err, ErrEncodingJSON) {
				t.Errorf("%s: json.Unmarshal of %s gave %v", name, text, err)
			}
		}
		if !p.Elem().IsZero() {
			t.Errorf("%s: json.Unmarshal changed it", name)
		}
	}
	// a taker's own record holding a Decimal: refused, never {}
	type mine struct{ Price Decimal }
	if b, err := json.Marshal(mine{r.Klines.At(0).Open}); err == nil || !strings.Contains(err.Error(), "EncodeRun") {
		t.Errorf("a Decimal in a record of a taker's: %q, %v", b, err)
	}
}
