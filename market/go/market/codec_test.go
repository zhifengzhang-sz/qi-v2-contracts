package market

// What encoding/json alone does not refuse, refused here as by every form; the rules held for a record made in Go;
// and a fuzzed text never a panic, and, if read, given back as a text that reads to itself.

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func kline(t *testing.T) string { return string(read(t, "ongoing/kline.json")) }

func TestJSONRefused(t *testing.T) {
	s := kline(t)
	for _, want := range []string{`"index":6,`, `"open":100.45,`, `"high":100.6,`, `"asOf":1767623790000,`} {
		if !strings.Contains(s, want) {
			t.Fatalf("ongoing/kline.json no longer holds %s", want)
		}
	}
	for name, text := range map[string]string{
		"a name twice":              strings.Replace(s, `"index":6,`, `"index":6,"index":6,`, 1),
		"a name twice, escaped":     strings.Replace(s, `"index":6,`, `"index":6,"\u0069ndex":6,`, 1),
		"an exponent":               strings.Replace(s, `"open":100.45,`, `"open":1e2,`, 1),
		"a huge exponent":           strings.Replace(s, `"open":100.45,`, `"open":1e999999999,`, 1),
		"a field it does not know":  strings.Replace(s, `"open":100.45,`, `"open":100.45,"extra":1,`, 1),
		"null":                      strings.Replace(s, `"open":100.45,`, `"open":null,`, 1),
		"a text where a number is":  strings.Replace(s, `"open":100.45,`, `"open":"100.45",`, 1),
		"a boolean where a number":  strings.Replace(s, `"open":100.45,`, `"open":true,`, 1),
		"a fraction where a whole":  strings.Replace(s, `"index":6,`, `"index":6.5,`, 1),
		"a whole number negative":   strings.Replace(s, `"index":6,`, `"index":-1,`, 1),
		"a whole past the bound":    strings.Replace(s, `"asOf":1767623790000`, `"asOf":9007199254740992`, 1),
		"17 digits":                 strings.Replace(s, `"asOf":1767623790000`, `"asOf":10000000000000000`, 1),
		"a field missing":           strings.Replace(s, `"open":100.45,`, ``, 1),
		"a byte order mark":         "\ufeff" + s,
		"text after the value":      s + "{}",
		"not an object":             "[" + s + "]",
		"a seventh decimal":         strings.Replace(s, `"high":100.6,`, `"high":100.6000001,`, 1),
		"a 0 after the point, last": strings.Replace(s, `"high":100.6,`, `"high":100.60,`, 1),
	} {
		if _, err := DecodeOngoingKLine([]byte(text)); err == nil {
			t.Errorf("%s: not refused", name)
		}
	}
	if _, err := DecodeOngoingKLine(append([]byte(s[:10]), append([]byte{0xff}, s[10:]...)...)); err == nil ||
		err.Error() != "text not UTF-8" {
		t.Errorf("text not UTF-8: %v", err)
	}
	// -0 is 0, given back as 0
	zero := strings.Replace(s, `"index":6,`, `"index":0,`, 1)
	k, err := DecodeOngoingKLine([]byte(strings.Replace(s, `"index":6,`, `"index":-0,`, 1)))
	if err != nil {
		t.Fatal(err)
	}
	if text, _ := EncodeOngoingKLine(k); text != zero {
		t.Error("-0 not given back as 0")
	}
}

func TestRulesOfARecordMadeInGo(t *testing.T) {
	d := func(s string) Decimal {
		x, err := ParseDecimal(s)
		if err != nil {
			t.Fatal(err)
		}
		return x
	}
	k := KLine{Index: 0, Date: 1, Open: d("10"), High: d("11"), Low: d("9"), Close: d("10.5"), Volume: d("1")}
	if err := k.Check(); err != nil {
		t.Fatal(err)
	}
	for name, broken := range map[string]KLine{
		"a date past the bound": {Date: Bound + 1, Open: k.Open, High: k.High, Low: k.Low, Close: k.Close},
		"a volume negative":     {Open: k.Open, High: k.High, Low: k.Low, Close: k.Close, Volume: d("-1")},
		"close above high":      {Open: k.Open, High: k.High, Low: k.Low, Close: d("11.5")},
		"open below low":        {Open: d("8"), High: k.High, Low: k.Low, Close: k.Close},
	} {
		if broken.Check() == nil {
			t.Errorf("%s: not refused", name)
		}
	}
	m := MassiveKLine{Index: 0, Date: 1, Open: d("10"), High: d("11"), Low: d("9"), Close: d("10.5"), Volume: d("1"),
		Vw: d("10.2"), N: Bound + 1}
	if m.Check() == nil {
		t.Error("Massive's K-line of an n past the bound: not refused")
	}
	if m.Base() != k || k.Base() != k {
		t.Error("a K-line's base is not its fields but vw and n")
	}
	// an ongoing K-line made in Go is checked before it is written
	if _, err := EncodeOngoingKLine(OngoingKLine{Date: 2, AsOf: 1}); err == nil {
		t.Error("an ongoing K-line whose asOf is before its date written")
	}
	text, err := EncodeOngoingKLine(OngoingKLine{Index: 0, Date: 1, Open: k.Open, High: k.High, Low: k.Low,
		Close: k.Close, Volume: k.Volume, AsOf: 2})
	if err != nil {
		t.Fatal(err)
	}
	if want := "{\"asOf\":2,\"close\":10.5,\"date\":1,\"high\":11,\"index\":0,\"low\":9,\"open\":10,\"volume\":1}\n"; text != want {
		t.Errorf("not the canonical text:\n%s", text)
	}
}

// A decode that fails gives the zero value: never a record half read, nor one that breaks a rule
func TestRefusedIsZero(t *testing.T) {
	names, err := filepath.Glob(filepath.Join(vectors, "ongoing", "reject", "*.json"))
	if err != nil || len(names) == 0 {
		t.Fatal("ongoing/reject: no reject case")
	}
	for _, n := range names {
		data, err := os.ReadFile(n)
		if err != nil {
			t.Fatal(err)
		}
		got, err := DecodeOngoingKLine(data)
		if err == nil || !reflect.ValueOf(got).IsZero() {
			t.Errorf("%s: %v, and not the zero value", n, err)
		}
		m, err := DecodeMassiveOngoingKLine(data)
		if err == nil || !reflect.ValueOf(m).IsZero() {
			t.Errorf("%s as Massive's: %v, and not the zero value", n, err)
		}
	}
}

func FuzzDecodeOngoingKLine(f *testing.F) {
	for _, n := range []string{"ongoing/kline.json", "ongoing/massive.json", "ongoing/reject/as-of-before-date.json",
		"ongoing/reject/as-of-missing.json"} {
		data, err := readVector(n)
		if err != nil {
			f.Fatal(err)
		}
		f.Add(data)
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		for _, massive := range []bool{false, true} {
			text, err := giveBack(massive, data)
			if err != nil {
				continue
			}
			again, err := giveBack(massive, []byte(text))
			if err != nil || again != text {
				t.Fatalf("read, but its text does not read to itself: %v", err)
			}
		}
	})
}
