package chanlun

import "math"

// The rules of ../../lean/Chanlun.lean, by the same names. Check gives the names of the rules a record breaks, in
// their order there, nil if it breaks none.

type rule struct {
	name  string
	holds bool
}

func broken(rules ...rule) []string {
	var names []string
	for _, r := range rules {
		if !r.holds {
			names = append(names, r.name)
		}
	}
	return names
}

func finite(xs ...float64) bool {
	for _, x := range xs {
		if math.IsInf(x, 0) || math.IsNaN(x) {
			return false
		}
	}
	return true
}

// Check gives the names of the rules m breaks.
func (m *MergedBar) Check() []string {
	within, ascending, index := true, true, false
	for i, p := range m.Extremes {
		within = within && m.Start <= p && p <= m.End
		ascending = ascending && (i == 0 || m.Extremes[i-1] < p)
		index = index || p == m.Index
	}
	return broken(
		rule{"finite", finite(m.High, m.Low)},
		rule{"range", m.Low <= m.High},
		rule{"extremesWithin", within},
		rule{"extremesAscending", ascending},
		rule{"indexInExtremes", index},
	)
}

// Check gives the names of the rules f breaks: a 分型 has none.
func (f *Fractal) Check() []string { return nil }

// Check gives the names of the rules l breaks.
func (l *Line) Check() []string { return broken(rule{"startBeforeEnd", l.Start < l.End}) }

// Check gives the names of the rules s breaks.
func (s *Segment) Check() []string { return broken(rule{"startBeforeEnd", s.Start < s.End}) }

// Check gives the names of the rules m breaks.
func (m *Move) Check() []string { return broken(rule{"startBeforeEnd", m.Start < m.End}) }

// Check gives the names of the rules c breaks.
func (c *Consolidation) Check() []string {
	return broken(
		rule{"finite", finite(c.Zg, c.Zd, c.Gg, c.Dd)},
		rule{"startBeforeEnd", c.Start < c.End},
		rule{"bands", c.Dd <= c.Zd && c.Zd <= c.Zg && c.Zg <= c.Gg},
	)
}
