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
		"a name twice":              strings.Replace(s, `"index":1,`, `"index":1,"index":1,`, 1),
		"a name twice, escaped":     strings.Replace(s, `"index":1,`, `"index":1,"\u0069ndex":1,`, 1),
		"a part twice":              strings.Replace(s, `"fractals": [`, `"fractals": [], "fractals": [`, 1),
		"an exponent":               strings.Replace(s, `"high":100.3,`, `"high":1e2,`, 1),
		"a huge exponent":           strings.Replace(s, `"high":100.3,`, `"high":1e999999999,`, 1),
		"a field it does not know":  strings.Replace(s, `"high":100.3,`, `"high":100.3,"extra":1,`, 1),
		"a part it does not know":   strings.Replace(s, `"merged": [`, `"extra": [], "merged": [`, 1),
		"null for a field not set":  strings.Replace(s, `{"end":5,`, `{"confirmEnd":null,"end":5,`, 1),
		"a text where a number is":  strings.Replace(s, `"high":100.3,`, `"high":"100.3",`, 1),
		"a number where a boolean":  strings.Replace(s, `"up":true`, `"up":1`, 1),
		"a fraction where a whole":  strings.Replace(s, `"index":1,`, `"index":1.5,`, 1),
		"a whole number negative":   strings.Replace(s, `"index":1,`, `"index":-1,`, 1),
		"a whole past the bound":    strings.Replace(s, `"confirmEnd":4,`, `"confirmEnd":9007199254740992,`, 1),
		"17 digits":                 strings.Replace(s, `"confirmEnd":4,`, `"confirmEnd":10000000000000000,`, 1),
		"a leading 0":               strings.Replace(s, `"confirmEnd":4,`, `"confirmEnd":04,`, 1),
		"a price of 16 digits":      strings.Replace(s, `"high":100.3,`, `"high":1000000000000000,`, 1),
		"a byte order mark":         "\ufeff" + s,
		"text after the value":      s + "{}",
		"a seventh decimal":         strings.Replace(s, `"high":100.3,`, `"high":100.3000001,`, 1),
		"a 0 after the point, last": strings.Replace(s, `"high":100.3,`, `"high":100.30,`, 1),
	} {
		if text == s {
			t.Errorf("%s: small.json not changed", name)
		}
		if _, err := DecodeRun([]byte(text)); err == nil {
			t.Errorf("%s: not refused", name)
		}
	}
	if _, err := DecodeRun(append([]byte(s[:30]), append([]byte{0xff}, s[30:]...)...)); err == nil ||
		err.Error() != "text not UTF-8" {
		t.Errorf("text not UTF-8: %v", err)
	}
	// -0 is 0, given back as 0
	if !strings.Contains(s, `"start":0,`) {
		t.Fatal("small.json: no start 0")
	}
	r, err := DecodeRun([]byte(strings.Replace(s, `"start":0,`, `"start":-0,`, 1)))
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
	m := MergedBar{Up: true, High: d("11"), Low: d("9"), Extremes: ListOf[uint64](0)}
	if err := m.Check(); err != nil {
		t.Fatal(err)
	}
	// a run's merged bar held to its rules
	if _, err := EncodeRun(Run{Merged: ListOf(MergedBar{High: d("9"), Low: d("11"), Extremes: ListOf[uint64](0)})}); err == nil {
		t.Error("a run of a merged bar whose low is above its high written")
	}
	// a run made in Go is checked before it is written
	run := Run{Merged: ListOf(m, m)}
	if _, err := EncodeRun(run); err == nil {
		t.Error("a run of two merged bars numbered 0 written")
	}
	// a run need hold no record: each of its six parts []
	none := "{\n\"merged\": [],\n\"fractals\": [],\n\"strokes\": [],\n\"segments\": [],\n\"moves\": [],\n\"consolidations\": []\n}\n"
	if text, err := EncodeRun(Run{}); err != nil || text != none {
		t.Errorf("a run of no record: %v\n%s", err, text)
	}
	text, err := EncodeRun(Run{Merged: ListOf(m)})
	if err != nil {
		t.Fatal(err)
	}
	want := "{\n\"merged\": [\n{\"end\":0,\"extremes\":[0],\"high\":11,\"index\":0,\"low\":9,\"mIndex\":0,\"start\":0,\"up\":true}\n],\n" +
		"\"fractals\": [],\n\"strokes\": [],\n\"segments\": [],\n\"moves\": [],\n\"consolidations\": []\n}\n"
	if text != want {
		t.Errorf("not the canonical text:\n%s", text)
	}
}

// A decode that fails gives the zero value: never a record half read, nor a run that breaks a rule
func TestRefusedIsZero(t *testing.T) {
	names, err := filepath.Glob(filepath.Join(vectors, "reject", "*.json"))
	if err != nil || len(names) == 0 {
		t.Fatal("reject: no reject case")
	}
	for _, n := range names {
		data, err := os.ReadFile(n)
		if err != nil {
			t.Fatal(err)
		}
		got, err := DecodeRun(data)
		if err == nil || !reflect.ValueOf(got).IsZero() {
			t.Errorf("%s: %v, and not the zero value", n, err)
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
	for _, n := range []string{"small.json", "edge.json", "bounds.json", "reject/merged-ongoing-twice.json",
		"reject/consolidation-zg-as-text.json", "reject/merged-extremes-not-a-list.json"} {
		data, err := readVector(n)
		if err != nil {
			f.Fatal(err)
		}
		f.Add(data)
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		text, err := giveBack(data)
		if err != nil {
			return
		}
		again, err := giveBack([]byte(text))
		if err != nil || again != text {
			t.Fatalf("read, but its text does not read to itself: %v", err)
		}
	})
}
