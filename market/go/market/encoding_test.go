package market

// encoding/json never writes a record or a Decimal, nor reads one: each refuses it with ErrEncodingJSON, which says
// what to use. Every type of records.go among them.

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
	k, err := DecodeOngoingKLine(read(t, "ongoing/kline.json"))
	if err != nil {
		t.Fatal(err)
	}
	mk, err := DecodeMassiveOngoingKLine(read(t, "ongoing/massive.json"))
	if err != nil {
		t.Fatal(err)
	}
	given := []any{k, mk, k.kline(), mk.kline(), k.High}
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
		for _, text := range []string{"{}", "[]", "1", "null", `{"asOf": 1}`} {
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
	if b, err := json.Marshal(mine{k.Open}); err == nil || !strings.Contains(err.Error(), "ParseDecimal") {
		t.Errorf("a Decimal in a record of a taker's: %q, %v", b, err)
	}
}
