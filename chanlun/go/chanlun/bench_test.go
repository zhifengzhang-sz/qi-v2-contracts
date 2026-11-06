package chanlun

// What reading and writing a large run costs: run.json's records 50 times over, each copy moved past the one before, a
// run of 200,000 K-lines and 43.6 MB of text. Its time, the memory it allocates, and the most heap it holds at once
// above what was held before (peak-MB, sampled), against the size of the text (peak/text). Reported, not a gate:
//
//	go test -run '^$' -bench . -benchmem ./chanlun

import (
	"runtime"
	"runtime/metrics"
	"sync/atomic"
	"testing"
	"time"

	"github.com/zhifengzhang-sz/qi-v2-contracts/market/go/market"
)

// large: run.json's records copies times over, each copy's positions, bars and times moved past the one before; every
// record going on in a copy but the last confirmed at its end, so that only the last of a part or a level is going on
func large(tb testing.TB, copies int) Run {
	data, err := readVector("run.json")
	if err != nil {
		tb.Fatal(err)
	}
	r, err := DecodeRun(data)
	if err != nil {
		tb.Fatal(err)
	}
	n, b := uint64(r.Klines.Len()), uint64(r.Merged.Len())
	first, _ := r.TimeAt(0)
	last, _ := r.TimeAt(n - 1)
	span := last - first + 60_000
	ended := func(o Optional[uint64], by, end uint64, lastCopy bool) Optional[uint64] {
		if e, ok := o.Get(); ok {
			return Some(e + by)
		}
		if lastCopy {
			return o
		}
		return Some(end)
	}
	var ks []market.KLine
	var ms []MergedBar
	var fs []Fractal
	var ss []Line
	segments := make([][]Segment, r.Segments.Len())
	moves := make([][]Move, r.Moves.Len())
	consolidations := make([][]Consolidation, r.Consolidations.Len())
	for c := range copies {
		lastCopy := c == copies-1
		dk, dm, dt := uint64(c)*n, uint64(c)*b, uint64(c)*span
		for k := range r.Klines.Values() {
			k.Index, k.Date = k.Index+dk, k.Date+dt
			ks = append(ks, k)
		}
		for m := range r.Merged.Values() {
			m.Index, m.MIndex, m.Start, m.End = m.Index+dk, m.MIndex+dm, m.Start+dk, m.End+dk
			m.ConfirmEnd = ended(m.ConfirmEnd, dk, m.End, lastCopy)
			es := m.Extremes.Slice()
			for i := range es {
				es[i] += dk
			}
			m.Extremes = ListOf(es...)
			ms = append(ms, m)
		}
		for f := range r.Fractals.Values() {
			f.MIndex += dm
			fs = append(fs, f)
		}
		for s := range r.Strokes.Values() {
			s.Start, s.End = s.Start+dm, s.End+dm
			s.ConfirmEnd = ended(s.ConfirmEnd, dm, s.End, lastCopy)
			ss = append(ss, s)
		}
		for l, level := range r.Segments.All() {
			for s := range level.Values() {
				s.Start, s.End = s.Start+dm, s.End+dm
				s.ConfirmEnd = ended(s.ConfirmEnd, dm, s.End, lastCopy)
				segments[l] = append(segments[l], s)
			}
		}
		for l, level := range r.Moves.All() {
			for s := range level.Values() {
				s.Start, s.End = s.Start+dm, s.End+dm
				s.ConfirmEnd = ended(s.ConfirmEnd, dm, s.End, lastCopy)
				moves[l] = append(moves[l], s)
			}
		}
		for l, level := range r.Consolidations.All() {
			for s := range level.Values() {
				s.Start, s.End = s.Start+dm, s.End+dm
				s.ConfirmEnd = ended(s.ConfirmEnd, dm, s.End, lastCopy)
				consolidations[l] = append(consolidations[l], s)
			}
		}
	}
	ls := func(xs [][]Segment) (l []List[Segment]) {
		for _, x := range xs {
			l = append(l, ListOf(x...))
		}
		return l
	}
	lm := func(xs [][]Move) (l []List[Move]) {
		for _, x := range xs {
			l = append(l, ListOf(x...))
		}
		return l
	}
	lc := func(xs [][]Consolidation) (l []List[Consolidation]) {
		for _, x := range xs {
			l = append(l, ListOf(x...))
		}
		return l
	}
	return Run{Klines: ListOf(ks...), Merged: ListOf(ms...), Fractals: ListOf(fs...), Strokes: ListOf(ss...),
		Segments: ListOf(ls(segments)...), Moves: ListOf(lm(moves)...), Consolidations: ListOf(lc(consolidations)...)}
}

// heap: the bytes of the heap's objects, live and not yet swept
func heap(s []metrics.Sample) uint64 {
	metrics.Read(s)
	return s[0].Value.Uint64()
}

// peak: the most heap held at once while op runs, above what was held before it, sampled
func peak(b *testing.B, op func()) uint64 {
	b.StopTimer()
	runtime.GC()
	s := []metrics.Sample{{Name: "/memory/classes/heap/objects:bytes"}}
	before := heap(s)
	var most atomic.Uint64
	done, stopped := make(chan struct{}), make(chan struct{})
	go func() {
		s := []metrics.Sample{{Name: "/memory/classes/heap/objects:bytes"}}
		for {
			if h := heap(s); h > most.Load() {
				most.Store(h)
			}
			select {
			case <-done:
				close(stopped)
				return
			default:
				time.Sleep(20 * time.Microsecond)
			}
		}
	}()
	b.StartTimer()
	op()
	b.StopTimer()
	if h := heap(s); h > most.Load() {
		most.Store(h)
	}
	close(done)
	<-stopped
	b.StartTimer()
	if m := most.Load(); m > before {
		return m - before
	}
	return 0
}

func report(b *testing.B, most, text uint64) {
	b.ReportMetric(float64(text)/1e6, "text-MB")
	b.ReportMetric(float64(most)/1e6, "peak-MB")
	b.ReportMetric(float64(most)/float64(text), "peak/text")
}

func BenchmarkDecodeRun(b *testing.B) {
	text, err := EncodeRun(large(b, 50))
	if err != nil {
		b.Fatal(err)
	}
	data := []byte(text)
	text = ""
	b.SetBytes(int64(len(data)))
	b.ReportAllocs()
	b.ResetTimer()
	var most uint64
	for range b.N {
		most = max(most, peak(b, func() {
			r, err := DecodeRun(data)
			if err != nil {
				b.Fatal(err)
			}
			runtime.KeepAlive(r)
		}))
	}
	report(b, most, uint64(len(data)))
}

func BenchmarkEncodeRun(b *testing.B) {
	r := large(b, 50)
	text, err := EncodeRun(r)
	if err != nil {
		b.Fatal(err)
	}
	b.SetBytes(int64(len(text)))
	size := uint64(len(text))
	text = ""
	b.ReportAllocs()
	b.ResetTimer()
	var most uint64
	for range b.N {
		most = max(most, peak(b, func() {
			t, err := EncodeRun(r)
			if err != nil {
				b.Fatal(err)
			}
			runtime.KeepAlive(t)
		}))
	}
	report(b, most, size)
}
