package chanlun

import (
	"fmt"
	"strconv"

	"github.com/zhifengzhang-sz/qi-v2-contracts/market/go/market"
)

// The records' rules (SPEC.md, Units, The records and The run), written by hand, each Check giving the first rule
// broken, nil if none is. Decoding checks every one; EncodeRun checks them before it writes, since a holder can make a
// record or a run of its own. A whole number past market's Bound is refused here as in the JSON, so that a record made
// in Go is held to the contract's bound too. A K-line's rules are market's, its Check.

// Stroke: 笔, a line (SPEC.md, Line).
type Stroke = Line

func bounded(at string, ns ...uint64) error {
	for _, n := range ns {
		if n > market.Bound {
			return fmt.Errorf("%s: %d: a number past %d", at, n, uint64(market.Bound))
		}
	}
	return nil
}

func (o Optional[T]) or(none T) T {
	if v, ok := o.Get(); ok {
		return v
	}
	return none
}

// Check: a merged bar's rules: start ≤ end, low ≤ high, extremes at least one K-line, every one from start to end, in
// ascending order with none twice, and index one of them.
func (m MergedBar) Check() error {
	if err := bounded("a merged bar", m.Index, m.MIndex, m.Start, m.End, m.ConfirmEnd.or(0)); err != nil {
		return err
	}
	if err := bounded("extremes", m.Extremes.items...); err != nil {
		return err
	}
	switch {
	case m.Start > m.End || m.Low.Cmp(m.High) > 0:
		return fmt.Errorf("a merged bar's first K-line not after its last, its low at most its high")
	case m.Extremes.Len() == 0:
		return fmt.Errorf("extremes: a merged bar's extremes hold at least one K-line")
	}
	in := false
	for i, p := range m.Extremes.items {
		switch {
		case p < m.Start || m.End < p:
			return fmt.Errorf("extremes.%d: a merged bar's extremes from its start to its end", i)
		case i > 0 && m.Extremes.items[i-1] >= p:
			return fmt.Errorf("extremes.%d: a merged bar's extremes in ascending order, none twice", i)
		}
		in = in || p == m.Index
	}
	if !in {
		return fmt.Errorf("a merged bar's index one of its extremes")
	}
	return nil
}

// Check: a 分型's rule: its mIndex within Bound.
func (f Fractal) Check() error { return bounded("a 分型", f.MIndex) }

func lineRule(start, end uint64, confirmEnd Optional[uint64], level uint64) error {
	if err := bounded("a line", start, end, confirmEnd.or(0), level); err != nil {
		return err
	}
	if start >= end {
		return fmt.Errorf("a line from a merged bar to a later one")
	}
	return nil
}

// Check: a line's rule: start < end.
func (l Line) Check() error { return lineRule(l.Start, l.End, l.ConfirmEnd, 0) }

// Check: a 线段's rule, a line's: start < end.
func (s Segment) Check() error { return lineRule(s.Start, s.End, s.ConfirmEnd, s.Level) }

// Check: a 走势's rule, a line's: start < end.
func (m Move) Check() error { return lineRule(m.Start, m.End, m.ConfirmEnd, m.Level) }

// Check: a 中枢's rules: start < end and dd ≤ zd ≤ zg ≤ gg.
func (c Consolidation) Check() error {
	if err := bounded("a 中枢", c.Level, c.Start, c.End, c.ConfirmEnd.or(0)); err != nil {
		return err
	}
	if c.Start >= c.End || c.Dd.Cmp(c.Zd) > 0 || c.Zd.Cmp(c.Zg) > 0 || c.Zg.Cmp(c.Gg) > 0 {
		return fmt.Errorf("a 中枢 from a merged bar to a later one, its band ZD to ZG within its range DD to GG")
	}
	return nil
}

// What the run's rules need of a record by level: its bars and its level
func (s Segment) span() (uint64, uint64, Optional[uint64], uint64) {
	return s.Start, s.End, s.ConfirmEnd, s.Level
}
func (m Move) span() (uint64, uint64, Optional[uint64], uint64) {
	return m.Start, m.End, m.ConfirmEnd, m.Level
}
func (c Consolidation) span() (uint64, uint64, Optional[uint64], uint64) {
	return c.Start, c.End, c.ConfirmEnd, c.Level
}

type levelled interface {
	Check() error
	span() (start, end uint64, confirmEnd Optional[uint64], level uint64)
}

// klineOf: a run's K-line, market's, of the base or of Massive's: its rules, and its base's index and date
type klineOf interface {
	market.KLine | market.MassiveKLine
	Check() error
	Base() market.KLine
}

// where: a part, or a level of a part by level, made its place's text (segments.2) only for a fault, so that a run of
// many levels is checked with no text made for each
type where struct {
	part  string
	level int // -1 for a part not by level
}

func (w where) String() string {
	if w.level < 0 {
		return w.part
	}
	return w.part + "." + strconv.Itoa(w.level)
}

// lines: the rules of the run over the records of one part or one level: each one's own, its level, its bars below
// the number of merged bars, strictly increasing by start, every one confirmed but the last
func lines[L levelled](at where, name string, rs List[L], level uint64, levelledPart bool, merged uint64) error {
	var previous uint64
	for i, r := range rs.items {
		if err := r.Check(); err != nil {
			return fmt.Errorf("%s.%d: %w", at, i, err)
		}
		start, end, confirmEnd, l := r.span()
		switch {
		case levelledPart && l != level:
			return fmt.Errorf("%s.%d.level: a %s here of level %d", at, i, name, level)
		case start >= merged || end >= merged || confirmEnd.or(0) >= merged:
			return fmt.Errorf("%s.%d: a merged bar past the run's merged bars", at, i)
		case i > 0 && previous >= start:
			return fmt.Errorf("%s.%d.start: a run's %s strictly increasing by start", at, i, name)
		case !confirmEnd.IsSet() && i < rs.Len()-1:
			return fmt.Errorf("%s.%d: a run's %s every one confirmed but the last", at, i, name)
		}
		previous = start
	}
	return nil
}

// lastLevel: a part by level ends with a level that is not empty: its levels 0 to its highest with a record, an
// empty part a List of no level (SPEC.md, The run), so that one run has one text
func lastLevel[T any](part string, levels List[List[T]]) error {
	if last, ok := levels.Last(); ok && last.Len() == 0 {
		return fmt.Errorf("%s.%d: a part by level's last level not empty", part, levels.Len()-1)
	}
	return nil
}

// strokes: a line as a record of no level, for lines
type stroke Line

func (s stroke) Check() error { return Line(s).Check() }
func (s stroke) span() (uint64, uint64, Optional[uint64], uint64) {
	return s.Start, s.End, s.ConfirmEnd, 0
}

func checkRun[K klineOf](klines List[K], merged List[MergedBar], fractals List[Fractal], strokes List[Line],
	segments List[List[Segment]], moves List[List[Move]], consolidations List[List[Consolidation]]) error {
	n, b := uint64(klines.Len()), uint64(merged.Len())
	// klines: at least one, in the order of their times, no time twice, each one's index its place
	if n == 0 {
		return fmt.Errorf("klines: a run has at least one K-line")
	}
	for i, k := range klines.items {
		if err := k.Check(); err != nil {
			return fmt.Errorf("klines.%d: %w", i, err)
		}
		switch base := k.Base(); {
		case base.Index != uint64(i):
			return fmt.Errorf("klines.%d.index: a K-line's index its place in the run", i)
		case i > 0 && klines.items[i-1].Base().Date >= base.Date:
			return fmt.Errorf("klines.%d: a run's K-lines in the order of their times, no time twice", i)
		}
	}
	// merged: each one's mIndex its place, every position below the number of K-lines, every one confirmed but the last
	for i, m := range merged.items {
		if err := m.Check(); err != nil {
			return fmt.Errorf("merged.%d: %w", i, err)
		}
		past := m.Index >= n || m.Start >= n || m.End >= n || m.ConfirmEnd.or(0) >= n
		for _, p := range m.Extremes.items {
			past = past || p >= n
		}
		switch {
		case m.MIndex != uint64(i):
			return fmt.Errorf("merged.%d.mIndex: a merged bar's number its place among the merged bars", i)
		case past:
			return fmt.Errorf("merged.%d: a position past the run's K-lines", i)
		case !m.ConfirmEnd.IsSet() && i < merged.Len()-1:
			return fmt.Errorf("merged.%d: a run's merged bars every one confirmed but the last", i)
		}
	}
	// fractals: strictly increasing by mIndex, every one below the number of merged bars
	for i, f := range fractals.items {
		if err := f.Check(); err != nil {
			return fmt.Errorf("fractals.%d: %w", i, err)
		}
		switch {
		case f.MIndex >= b:
			return fmt.Errorf("fractals.%d: a merged bar past the run's merged bars", i)
		case i > 0 && fractals.items[i-1].MIndex >= f.MIndex:
			return fmt.Errorf("fractals.%d.mIndex: a run's 分型 strictly increasing by mIndex", i)
		}
	}
	ss := make([]stroke, strokes.Len())
	for i, s := range strokes.items {
		ss[i] = stroke(s)
	}
	if err := lines(where{"strokes", -1}, "笔", List[stroke]{items: ss}, 0, false, b); err != nil {
		return err
	}
	// segments, moves and consolidations: by level, the array at L the records of level L, each part ending with a
	// level that is not empty
	if err := lastLevel("segments", segments); err != nil {
		return err
	}
	if err := lastLevel("moves", moves); err != nil {
		return err
	}
	if err := lastLevel("consolidations", consolidations); err != nil {
		return err
	}
	for l, rs := range segments.items {
		if err := lines(where{"segments", l}, "线段", rs, uint64(l), true, b); err != nil {
			return err
		}
	}
	for l, rs := range moves.items {
		if err := lines(where{"moves", l}, "走势", rs, uint64(l), true, b); err != nil {
			return err
		}
	}
	for l, rs := range consolidations.items {
		if err := lines(where{"consolidations", l}, "中枢", rs, uint64(l), true, b); err != nil {
			return err
		}
	}
	return nil
}

// Check: the run's rules (SPEC.md, The run), each record's among them.
func (r Run) Check() error {
	return checkRun(r.Klines, r.Merged, r.Fractals, r.Strokes, r.Segments, r.Moves, r.Consolidations)
}

// Check: Massive's run's rules, the run's (SPEC.md, The run).
func (r MassiveRun) Check() error {
	return checkRun(r.Klines, r.Merged, r.Fractals, r.Strokes, r.Segments, r.Moves, r.Consolidations)
}

// TimeAt: the time of the K-line at the position p, and false past the run's K-lines (SPEC.md, Units): how a position
// is turned back into a time.
func (r Run) TimeAt(p uint64) (uint64, bool) { return timeAt(r.Klines, p) }

// TimeAt: the time of the K-line at the position p, and false past the run's K-lines.
func (r MassiveRun) TimeAt(p uint64) (uint64, bool) { return timeAt(r.Klines, p) }

func timeAt[K klineOf](klines List[K], p uint64) (uint64, bool) {
	if p >= uint64(klines.Len()) {
		return 0, false
	}
	return klines.items[p].Base().Date, true
}
