package market

import (
	"fmt"
)

// The records' rules (SPEC.md, Units and The records), written by hand, each Check giving the first rule broken, nil if
// none is. Decoding checks every one; EncodeOngoingKLine checks them before it writes, since a holder can make a record
// of its own. A whole number past Bound is refused here as in the JSON, so that a record made in Go is held to the
// contract's bound too.

func bounded(at string, ns ...uint64) error {
	for _, n := range ns {
		if n > Bound {
			return fmt.Errorf("%s: %d: a number past %d", at, n, uint64(Bound))
		}
	}
	return nil
}

// Check: a K-line's rules: low ≤ min(open, close) and max(open, close) ≤ high; its volume a quantity, not negative;
// its index and date within Bound.
func (k KLine) Check() error {
	if err := bounded("a K-line", k.Index, k.Date); err != nil {
		return err
	}
	if k.Volume.Sign() < 0 {
		return fmt.Errorf("volume: %s: a quantity not negative", k.Volume)
	}
	if k.Low.Cmp(minDecimal(k.Open, k.Close)) > 0 || maxDecimal(k.Open, k.Close).Cmp(k.High) > 0 {
		return fmt.Errorf("a K-line's open and close within its low and high")
	}
	return nil
}

// Base: the K-line of the base contract a data source's K-line derives from: the K-line itself (SPEC.md, K-line).
func (k KLine) Base() KLine { return k }

// Base: the K-line of the base contract Massive's K-line derives from, its fields but vw and n (SPEC.md, Massive's
// K-line): what a contract built on this one reads of any source's K-line, its index and its date.
func (k MassiveKLine) Base() KLine {
	return KLine{Index: k.Index, Date: k.Date, Open: k.Open, High: k.High, Low: k.Low, Close: k.Close, Volume: k.Volume}
}

// Check: Massive's K-line's rules: the base's, and n within Bound (vw is a price, any decimal).
func (k MassiveKLine) Check() error {
	if err := k.Base().Check(); err != nil {
		return err
	}
	return bounded("n", k.N)
}

func (k OngoingKLine) kline() KLine {
	return KLine{Index: k.Index, Date: k.Date, Open: k.Open, High: k.High, Low: k.Low, Close: k.Close, Volume: k.Volume}
}

func (k MassiveOngoingKLine) kline() MassiveKLine {
	return MassiveKLine{Index: k.Index, Date: k.Date, Open: k.Open, High: k.High, Low: k.Low, Close: k.Close,
		Volume: k.Volume, Vw: k.Vw, N: k.N}
}

func ongoing(kline error, date, asOf uint64) error {
	if kline != nil {
		return fmt.Errorf("the ongoing K-line: %w", kline)
	}
	if err := bounded("asOf", asOf); err != nil {
		return err
	}
	if asOf < date {
		return fmt.Errorf("the ongoing K-line: its asOf not before its date")
	}
	return nil
}

// Check: the ongoing K-line's rules: its K-line's, and date ≤ asOf.
func (k OngoingKLine) Check() error { return ongoing(k.kline().Check(), k.Date, k.AsOf) }

// Check: Massive's ongoing K-line's rules: Massive's K-line's, and date ≤ asOf.
func (k MassiveOngoingKLine) Check() error { return ongoing(k.kline().Check(), k.Date, k.AsOf) }
