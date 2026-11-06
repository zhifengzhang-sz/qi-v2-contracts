// Command decode: an ongoing K-line's JSON decoded and written again as its canonical JSON (the conformance check's Go
// side), of the base or with --massive Massive's:
//
//	decode [--massive] --ongoing FILE
//
// The canonical text to stdout; a fault to stderr as `decode: ` and its message, exit 1. With --batch, every .json
// file of the folder IN, in the order of their names, decoded so in one process (the generated cases,
// ../../../vectors/cases.ts), each one's answer written to OUT under its name: its canonical text, or the line
// `decode: ` and its fault:
//
//	decode [--massive] --ongoing --batch IN OUT
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/zhifengzhang-sz/qi-v2-contracts/market/go/market"
)

const usage = "usage: decode [--massive] --ongoing FILE | [--massive] --ongoing --batch IN OUT"

// answer: a file's bytes as its canonical text, or its fault
func answer(massive bool, data []byte) (string, error) {
	if massive {
		k, err := market.DecodeMassiveOngoingKLine(data)
		if err != nil {
			return "", err
		}
		return market.EncodeOngoingKLine(k)
	}
	k, err := market.DecodeOngoingKLine(data)
	if err != nil {
		return "", err
	}
	return market.EncodeOngoingKLine(k)
}

func fail(message string) {
	fmt.Fprintf(os.Stderr, "decode: %s\n", message)
	os.Exit(1)
}

func main() {
	var massive, ongoing, batch bool
	var files []string
	for _, a := range os.Args[1:] {
		switch a {
		case "--massive":
			massive = true
		case "--ongoing":
			ongoing = true
		case "--batch":
			batch = true
		default:
			files = append(files, a)
		}
	}
	switch {
	case ongoing && batch && len(files) == 2:
		entries, err := os.ReadDir(files[0])
		if err != nil {
			fail("cannot read " + files[0])
		}
		var names []string
		for _, e := range entries {
			if strings.HasSuffix(e.Name(), ".json") {
				names = append(names, e.Name())
			}
		}
		slices.Sort(names)
		for _, n := range names {
			data, err := os.ReadFile(filepath.Join(files[0], n))
			if err != nil {
				fail("cannot read " + n)
			}
			out, err := answer(massive, data)
			if err != nil {
				out = "decode: " + err.Error() + "\n"
			}
			if err := os.WriteFile(filepath.Join(files[1], n), []byte(out), 0o644); err != nil {
				fail("cannot write " + filepath.Join(files[1], n))
			}
		}
	case ongoing && !batch && len(files) == 1 && !strings.HasPrefix(files[0], "--"):
		data, err := os.ReadFile(files[0])
		if err != nil {
			fail("cannot read " + files[0])
		}
		out, err := answer(massive, data)
		if err != nil {
			fail(err.Error())
		}
		os.Stdout.WriteString(out)
	default:
		fmt.Fprintf(os.Stderr, "decode: %s\n", usage)
		os.Exit(1)
	}
}
