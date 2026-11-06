package market

// The contract's vectors (../../vectors/), each read as the program decode reads it: the ongoing K-lines decoded and
// encoded again to the same text, every reject case refused; the conformance check (make check) compares the
// TypeScript and Lean forms' text with the same files.

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

// giveBack: the text an ongoing K-line is decoded and encoded to, of the base or of Massive's
func giveBack(massive bool, data []byte) (string, error) {
	if massive {
		k, err := DecodeMassiveOngoingKLine(data)
		if err != nil {
			return "", err
		}
		return EncodeOngoingKLine(k)
	}
	k, err := DecodeOngoingKLine(data)
	if err != nil {
		return "", err
	}
	return EncodeOngoingKLine(k)
}

func TestVectorsGivenBack(t *testing.T) {
	for _, c := range []struct {
		file    string
		massive bool
	}{
		{"ongoing/kline.json", false},
		{"ongoing/massive.json", true},
	} {
		t.Run(c.file, func(t *testing.T) {
			data := read(t, c.file)
			text, err := giveBack(c.massive, data)
			if err != nil {
				t.Fatal(err)
			}
			if text != string(data) {
				t.Fatal("not given back as the same text")
			}
		})
	}
}

// rejectCase: a reject case's file, and whether it is read as Massive's ongoing K-line (ongoing/massive/reject) or as
// the base's (ongoing/reject)
type rejectCase struct {
	file    string
	massive bool
}

// rejectCases: every reject case, of the base and of Massive's
func rejectCases(t *testing.T) []rejectCase {
	t.Helper()
	var cases []rejectCase
	for _, d := range []struct {
		dir     string
		massive bool
	}{
		{filepath.Join("ongoing", "reject"), false},
		{filepath.Join("ongoing", "massive", "reject"), true},
	} {
		names, err := filepath.Glob(filepath.Join(vectors, d.dir, "*.json"))
		if err != nil || len(names) == 0 {
			t.Fatalf("%s: no reject case", d.dir)
		}
		for _, n := range names {
			cases = append(cases, rejectCase{n, d.massive})
		}
	}
	return cases
}

func TestVectorsRefused(t *testing.T) {
	for _, c := range rejectCases(t) {
		t.Run(c.file, func(t *testing.T) {
			data, err := os.ReadFile(c.file)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := giveBack(c.massive, data); err == nil {
				t.Fatal("not refused")
			}
		})
	}
}
