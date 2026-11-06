package chanlun

// What encoding/json alone does not refuse, refused here as by every form; the rules held for a record made in Go;
// and a fuzzed text never a panic, and, if read, given back as a text that reads to itself.

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/zhifengzhang-sz/qi-v2-contracts/market/go/market"
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
	d := func(s string) market.Decimal {
		x, err := market.ParseDecimal(s)
		if err != nil {
			t.Fatal(err)
		}
		return x
	}
	k := market.KLine{Index: 0, Date: 1, Open: d("10"), High: d("11"), Low: d("9"), Close: d("10.5"), Volume: d("1")}
	if err := k.Check(); err != nil {
		t.Fatal(err)
	}
	// a run's K-line held to market's rules
	if _, err := EncodeRun(Run{Klines: ListOf(market.KLine{Open: k.Open, High: k.High, Low: k.Low, Close: d("11.5")})}); err == nil {
		t.Error("a run of a K-line whose close is above its high written")
	}
	// a run made in Go is checked before it is written
	run := Run{Klines: ListOf(k, k)}
	if _, err := EncodeRun(run); err == nil {
		t.Error("a run of two K-lines at one place written")
	}
	if _, err := EncodeRun(Run{}); err == nil {
		t.Error("a run of no K-line written")
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

// A decode that fails gives the zero value: never a record half read, nor a run that breaks a rule
func TestRefusedIsZero(t *testing.T) {
	for _, c := range []struct {
		dir  string
		mode mode
	}{{"reject", mode{}}, {"massive/reject", mode{massive: true}}} {
		names, err := filepath.Glob(filepath.Join(vectors, c.dir, "*.json"))
		if err != nil || len(names) == 0 {
			t.Fatalf("%s: no reject case", c.dir)
		}
		for _, n := range names {
			data, err := os.ReadFile(n)
			if err != nil {
				t.Fatal(err)
			}
			var got any
			switch {
			case c.mode.massive:
				got, err = DecodeMassiveRun(data)
			default:
				got, err = DecodeRun(data)
			}
			if err == nil || !reflect.ValueOf(got).IsZero() {
				t.Errorf("%s: %v, and not the zero value", n, err)
			}
		}
	}
}

// A part by level ends with a level that is not empty, in a run made in Go as in a run read: Check refuses it, and
// EncodeRun does not write it; an empty level below the last stays
func TestLastLevelNotEmpty(t *testing.T) {
	r, err := DecodeRun(read(t, "small.json"))
	if err != nil {
		t.Fatal(err)
	}
	with := func(f func(*Run)) Run { c := r; f(&c); return c }
	segments, consolidations := r.Segments.Slice(), r.Consolidations.Slice()
	for name, broken := range map[string]Run{
		"segments [[a], []]": with(func(c *Run) { c.Segments = ListOf(append(segments, List[Segment]{})...) }),
		"segments [[]]":      with(func(c *Run) { c.Segments = ListOf(List[Segment]{}) }),
		"moves [[a], []]":    with(func(c *Run) { c.Moves = ListOf(r.Moves.At(0), List[Move]{}) }),
		"consolidations [[a], [b], []]": with(func(c *Run) {
			c.Consolidations = ListOf(append(consolidations, List[Consolidation]{})...)
		}),
	} {
		if err := broken.Check(); err == nil || !strings.Contains(err.Error(), "a part by level's last level not empty") {
			t.Errorf("%s: Check gave %v", name, err)
		}
		if text, err := EncodeRun(broken); err == nil {
			t.Errorf("%s: written:\n%s", name, text)
		}
	}
	// the 中枢 of level 1 alone: level 0 empty below it, allowed, and given back
	below := with(func(c *Run) { c.Consolidations = ListOf(List[Consolidation]{}, consolidations[1]) })
	text, err := EncodeRun(below)
	if err != nil {
		t.Fatal(err)
	}
	if again, err := DecodeRun([]byte(text)); err != nil || again.Consolidations.At(0).Len() != 0 {
		t.Fatalf("an empty level below the last: %v", err)
	}
	if !strings.Contains(text, "\"consolidations\": [\n[],\n[\n{") {
		t.Fatalf("an empty level below the last not written as []:\n%s", text)
	}
	// a part with no record is []
	none := with(func(c *Run) { c.Segments, c.Moves = List[List[Segment]]{}, List[List[Move]]{} })
	if text, err := EncodeRun(none); err != nil || !strings.Contains(text, "\"segments\": [],\n\"moves\": [],\n") {
		t.Fatalf("an empty part: %v\n%s", err, text)
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
		for _, m := range []mode{{}, {massive: true}} {
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
