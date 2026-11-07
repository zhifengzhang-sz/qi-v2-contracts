package market

// The contract's vectors (../../vectors/), each read as the program decode reads it: the ongoing K-line decoded and
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

// giveBack: the text an ongoing K-line is decoded and encoded to
func giveBack(data []byte) (string, error) {
	k, err := DecodeOngoingKLine(data)
	if err != nil {
		return "", err
	}
	return EncodeOngoingKLine(k)
}

func TestVectorsGivenBack(t *testing.T) {
	for _, file := range []string{"ongoing/kline.json"} {
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

// rejectCases: every reject case's file (ongoing/reject)
func rejectCases(t *testing.T) []string {
	t.Helper()
	dir := filepath.Join("ongoing", "reject")
	names, err := filepath.Glob(filepath.Join(vectors, dir, "*.json"))
	if err != nil || len(names) == 0 {
		t.Fatalf("%s: no reject case", dir)
	}
	return names
}

func TestVectorsRefused(t *testing.T) {
	for _, file := range rejectCases(t) {
		t.Run(file, func(t *testing.T) {
			data, err := os.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := giveBack(data); err == nil {
				t.Fatal("not refused")
			}
		})
	}
}
