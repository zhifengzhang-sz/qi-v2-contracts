package chanlun

import (
	"encoding/json"
	"os"
	"slices"
	"testing"

	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

// Each example of ../../examples.json, read by the generated code, breaks exactly the rules it names.
func TestExamples(t *testing.T) {
	data, err := os.ReadFile("../../examples.json")
	if err != nil {
		t.Fatal(err)
	}
	var examples []struct {
		Record string
		Breaks []string
		Value  json.RawMessage
	}
	if err := json.Unmarshal(data, &examples); err != nil {
		t.Fatal(err)
	}
	for _, e := range examples {
		var r interface {
			proto.Message
			Check() []string
		}
		switch e.Record {
		case "MergedBar":
			r = &MergedBar{}
		case "Fractal":
			r = &Fractal{}
		case "Line":
			r = &Line{}
		case "Segment":
			r = &Segment{}
		case "Move":
			r = &Move{}
		case "Consolidation":
			r = &Consolidation{}
		default:
			t.Errorf("%s: no such record", e.Record)
			continue
		}
		if err := protojson.Unmarshal(e.Value, r); err != nil {
			t.Errorf("%s %s: %v", e.Record, e.Value, err)
		} else if got := r.Check(); !slices.Equal(got, e.Breaks) {
			t.Errorf("%s %s: breaks %v", e.Record, e.Value, got)
		}
	}
}
