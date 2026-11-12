package market

import "math"

// The rules of ../../lean/Market.lean, by the same names. Check gives the names of the rules a record breaks, in
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

func klineRules(open, high, low, close, volume float64) []rule {
	return []rule{
		{"finite", finite(open, high, low, close, volume)},
		{"range", low <= open && low <= close && open <= high && close <= high},
		{"volumeNotNegative", 0 <= volume},
	}
}

// Check gives the names of the rules k breaks.
func (k *KLine) Check() []string {
	return broken(klineRules(k.Open, k.High, k.Low, k.Close, k.Volume)...)
}

// Check gives the names of the rules k breaks: its K-line's, and asOfNotBeforeDate.
func (k *OngoingKLine) Check() []string {
	return broken(append(klineRules(k.Open, k.High, k.Low, k.Close, k.Volume),
		rule{"asOfNotBeforeDate", k.Date <= k.AsOf})...)
}
