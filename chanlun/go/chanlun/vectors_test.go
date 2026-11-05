package chanlun

// The contract's vectors (../../vectors/), each read as the program decode reads it: the runs and the ongoing K-lines
// decoded and encoded again to the same text, every reject case refused; the conformance check (make check) compares
// the TypeScript and Lean forms' text with the same files.

import (
	"os"
	"path/filepath"
	"testing"
)

var vectors = filepath.Join("..", "..", "vectors")

func readVector(name string) ([]byte, error) { return os.ReadFile(filepath.Join(vectors, name)) }

func read(t *testing.T, name string) []byte {
	t.Helper()
	data, err := readVector(name)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

type mode struct {
	massive, ongoing bool
}

// giveBack: the text a vector is decoded and encoded to, in its mode
func giveBack(m mode, data []byte) (string, error) {
	switch {
	case m.ongoing && m.massive:
		k, err := DecodeMassiveOngoingKLine(data)
		if err != nil {
			return "", err
		}
		return EncodeOngoingKLine(k)
	case m.ongoing:
		k, err := DecodeOngoingKLine(data)
		if err != nil {
			return "", err
		}
		return EncodeOngoingKLine(k)
	case m.massive:
		r, err := DecodeMassiveRun(data)
		if err != nil {
			return "", err
		}
		return EncodeRun(r)
	}
	r, err := DecodeRun(data)
	if err != nil {
		return "", err
	}
	return EncodeRun(r)
}

func TestVectorsGivenBack(t *testing.T) {
	for _, c := range []struct {
		file string
		mode mode
	}{
		{"run.json", mode{}},
		{"small.json", mode{}},
		{"edge.json", mode{}},
		{"massive/small.json", mode{massive: true}},
		{"massive/edge.json", mode{massive: true}},
		{"ongoing/kline.json", mode{ongoing: true}},
		{"ongoing/massive.json", mode{massive: true, ongoing: true}},
	} {
		t.Run(c.file, func(t *testing.T) {
			data := read(t, c.file)
			text, err := giveBack(c.mode, data)
			if err != nil {
				t.Fatal(err)
			}
			if text != string(data) {
				t.Fatal("not given back as the same text")
			}
		})
	}
}

func TestVectorsRefused(t *testing.T) {
	for _, c := range []struct {
		dir  string
		mode mode
	}{
		{"reject", mode{}},
		{"massive/reject", mode{massive: true}},
		{"ongoing/reject", mode{ongoing: true}},
	} {
		names, err := filepath.Glob(filepath.Join(vectors, c.dir, "*.json"))
		if err != nil || len(names) == 0 {
			t.Fatalf("%s: no reject case", c.dir)
		}
		for _, n := range names {
			t.Run(filepath.Join(c.dir, filepath.Base(n)), func(t *testing.T) {
				data, err := os.ReadFile(n)
				if err != nil {
					t.Fatal(err)
				}
				if _, err := giveBack(c.mode, data); err == nil {
					t.Fatal("not refused")
				}
			})
		}
	}
}

func TestRunHoldsEveryKind(t *testing.T) {
	r, err := DecodeRun(read(t, "run.json"))
	if err != nil {
		t.Fatal(err)
	}
	if r.Klines.Len() != 4000 || r.Merged.Len() == 0 || r.Fractals.Len() == 0 || r.Strokes.Len() == 0 ||
		r.Segments.Len() == 0 || r.Moves.Len() == 0 || r.Consolidations.Len() < 2 {
		t.Fatal("run.json lacks a kind of record")
	}
	last, _ := r.Strokes.Last()
	if last.ConfirmEnd.IsSet() {
		t.Fatal("run.json's last 笔 is confirmed")
	}
	k := r.Klines.At(3)
	if at, ok := r.TimeAt(3); !ok || at != k.Date {
		t.Fatal("TimeAt is not the K-line's date")
	}
	if _, ok := r.TimeAt(4000); ok {
		t.Fatal("TimeAt past the K-lines")
	}
}
