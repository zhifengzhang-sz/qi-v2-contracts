package chanlun

// The contract's vectors (../../vectors/), each read as the program decode reads it: the runs decoded and encoded again
// to the same text, every reject case refused; the conformance check (make check) compares the TypeScript and Lean
// forms' text with the same files. The ongoing K-lines are market's (../../../market/vectors/).

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

// giveBack: the text a vector is decoded and encoded to
func giveBack(data []byte) (string, error) {
	r, err := DecodeRun(data)
	if err != nil {
		return "", err
	}
	return EncodeRun(r)
}

func TestVectorsGivenBack(t *testing.T) {
	for _, file := range []string{"run.json", "small.json", "edge.json", "bounds.json"} {
		t.Run(file, func(t *testing.T) {
			data := read(t, file)
			text, err := giveBack(data)
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
	names, err := filepath.Glob(filepath.Join(vectors, "reject", "*.json"))
	if err != nil || len(names) == 0 {
		t.Fatal("reject: no reject case")
	}
	for _, n := range names {
		t.Run(filepath.Join("reject", filepath.Base(n)), func(t *testing.T) {
			data, err := os.ReadFile(n)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := giveBack(data); err == nil {
				t.Fatal("not refused")
			}
		})
	}
}

func TestRunHoldsEveryKind(t *testing.T) {
	r, err := DecodeRun(read(t, "run.json"))
	if err != nil {
		t.Fatal(err)
	}
	if r.Merged.Len() == 0 || r.Fractals.Len() == 0 || r.Strokes.Len() == 0 ||
		r.Segments.Len() == 0 || r.Moves.Len() == 0 || r.Consolidations.Len() < 2 {
		t.Fatal("run.json lacks a kind of record")
	}
	last, _ := r.Strokes.Last()
	if last.ConfirmEnd.IsSet() {
		t.Fatal("run.json's last 笔 is confirmed")
	}
}
