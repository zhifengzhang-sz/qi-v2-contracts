package chanlun

// What encoding/json alone does not refuse, refused here as by every form; the rules held for a record made in Go;
// and a fuzzed text never a panic, and, if read, given back as a text that reads to itself.

import (
	"strings"
	"testing"
)

func small(t *testing.T) string { return string(read(t, "small.json")) }

func TestJSONRefused(t *testing.T) {
	s := small(t)
	for name, text := range map[string]string{
		"a name twice":              strings.Replace(s, `"index":0,`, `"index":0,"index":0,`, 1),
		"a name twice, escaped":     strings.Replace(s, `"index":0,`, `"index":0,"\u0069ndex":0,`, 1),
		"a part twice":              strings.Replace(s, `"fractals": [`, `"fractals": [], "fractals": [`, 1),
		"an exponent":               strings.Replace(s, `"open":100,`, `"open":1e2,`, 1),
		"a huge exponent":           strings.Replace(s, `"open":100,`, `"open":1e999999999,`, 1),
		"a field it does not know":  strings.Replace(s, `"open":100,`, `"open":100,"extra":1,`, 1),
		"a part it does not know":   strings.Replace(s, `"klines": [`, `"extra": [], "klines": [`, 1),
		"null for a field not set":  strings.Replace(s, `{"end":5,`, `{"confirmEnd":null,"end":5,`, 1),
		"a text where a number is":  strings.Replace(s, `"open":100,`, `"open":"100",`, 1),
		"a number where a boolean":  strings.Replace(s, `"up":true`, `"up":1`, 1),
		"a fraction where a whole":  strings.Replace(s, `"index":0,`, `"index":0.5,`, 1),
		"a whole number negative":   strings.Replace(s, `"index":0,`, `"index":-1,`, 1),
		"a whole past the bound":    strings.Replace(s, `"date":1767623700000`, `"date":9007199254740992`, 1),
		"17 digits":                 strings.Replace(s, `"date":1767623700000`, `"date":10000000000000000`, 1),
		"a byte order mark":         "\ufeff" + s,
		"text after the value":      s + "{}",
		"a seventh decimal":         strings.Replace(s, `"high":100.1,`, `"high":100.1000001,`, 1),
		"a 0 after the point, last": strings.Replace(s, `"high":100.1,`, `"high":100.10,`, 1),
	} {
		if _, err := DecodeRun([]byte(text)); err == nil {
			t.Errorf("%s: not refused", name)
		}
	}
	if _, err := DecodeRun(append([]byte(s[:30]), append([]byte{0xff}, s[30:]...)...)); err == nil ||
		err.Error() != "text not UTF-8" {
		t.Errorf("text not UTF-8: %v", err)
	}
	// -0 is 0, given back as 0
	r, err := DecodeRun([]byte(strings.Replace(s, `"index":0,`, `"index":-0,`, 1)))
	if err != nil {
		t.Fatal(err)
	}
	if text, _ := EncodeRun(r); text != s {
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
	// a run made in Go is checked before it is written
	run := Run{Klines: ListOf(k, k)}
	if _, err := EncodeRun(run); err == nil {
		t.Error("a run of two K-lines at one place written")
	}
	if _, err := EncodeRun(Run{}); err == nil {
		t.Error("a run of no K-line written")
	}
	if _, err := EncodeOngoingKLine(OngoingKLine{Date: 2, AsOf: 1}); err == nil {
		t.Error("an ongoing K-line whose asOf is before its date written")
	}
	text, err := EncodeRun(Run{Klines: ListOf(k)})
	if err != nil {
		t.Fatal(err)
	}
	want := "{\n\"klines\": [\n{\"close\":10.5,\"date\":1,\"high\":11,\"index\":0,\"low\":9,\"open\":10,\"volume\":1}\n],\n" +
		"\"merged\": [],\n\"fractals\": [],\n\"strokes\": [],\n\"segments\": [],\n\"moves\": [],\n\"consolidations\": []\n}\n"
	if text != want {
		t.Errorf("not the canonical text:\n%s", text)
	}
}

func FuzzDecodeRun(f *testing.F) {
	for _, n := range []string{"small.json", "edge.json", "massive/small.json", "reject/merged-ongoing-twice.json",
		"reject/number-with-exponent.json", "reject/kline-high-twice.json"} {
		data, err := readVector(n)
		if err != nil {
			f.Fatal(err)
		}
		f.Add(data)
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		for _, m := range []mode{{}, {massive: true}, {ongoing: true}, {massive: true, ongoing: true}} {
			text, err := giveBack(m, data)
			if err != nil {
				continue
			}
			again, err := giveBack(m, []byte(text))
			if err != nil || again != text {
				t.Fatalf("read, but its text does not read to itself: %v", err)
			}
		}
	})
}
