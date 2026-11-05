package chanlun

import (
	"math"
	"reflect"
	"strconv"
	"testing"
)

func TestDecimalGivesItsDigitsBack(t *testing.T) {
	for _, s := range []string{
		"0", "1", "-1", "100.05", "0.000001", "-0.000001", "999999999999999", "-999999999999999",
		"999999999.999999", "123456789012345", "12345678901234.5", "0.1", "10", "100.1",
	} {
		d, err := ParseDecimal(s)
		if err != nil {
			t.Fatalf("%s: %v", s, err)
		}
		if d.String() != s {
			t.Fatalf("%s given back as %s", s, d)
		}
	}
	// -0 is 0: one value, one Decimal
	d, err := ParseDecimal("-0")
	if err != nil || d.String() != "0" || d != (Decimal{}) || d.Sign() != 0 {
		t.Fatalf("-0: %v %v", d, err)
	}
}

func TestDecimalRefused(t *testing.T) {
	for _, s := range []string{
		"", "-", "+1", "01", "00", "1.", ".5", "1.0", "1.50", "1e2", "1E2", "1.5e0", "0x10", "1.0000001",
		"1000000000000000", "1234567890123.456", "0.1234567", " 1", "1 ", "NaN", "Infinity", "--1", "1-",
		"9007199254740993", "-0.0", "-",
	} {
		if _, err := ParseDecimal(s); err == nil {
			t.Fatalf("%q not refused", s)
		}
	}
}

func TestDecimalCompared(t *testing.T) {
	ds := []string{"-999999999999999", "-100.05", "-1", "-0.000001", "0", "0.000001", "0.1", "1", "99.999999",
		"100", "100.000001", "100.05", "999999999.999999", "999999999999999"}
	for i, a := range ds {
		for j, b := range ds {
			x, _ := ParseDecimal(a)
			y, _ := ParseDecimal(b)
			want := 0
			if i < j {
				want = -1
			} else if i > j {
				want = 1
			}
			if x.Cmp(y) != want {
				t.Fatalf("%s against %s: %d, not %d", a, b, x.Cmp(y), want)
			}
			if (x == y) != (i == j) {
				t.Fatalf("%s == %s: %v", a, b, x == y)
			}
		}
	}
	// the same value however long its whole part: 15 digits before the point, held exactly
	x, _ := ParseDecimal("999999999999998")
	y, _ := ParseDecimal("999999999999999")
	if x.Cmp(y) != -1 {
		t.Fatal("15 digits before the point not compared exactly")
	}
}

// A Decimal is 16 bytes: its whole part, and its millionths with its sign
func TestDecimalIs16Bytes(t *testing.T) {
	if n := reflect.TypeFor[Decimal]().Size(); n > 16 {
		t.Fatalf("a Decimal of %d bytes", n)
	}
}

func TestDecimalNegated(t *testing.T) {
	for _, s := range []string{"0", "1", "100.05", "0.000001", "999999999999999", "999999999.999999", "12.5"} {
		d, _ := ParseDecimal(s)
		n := d.Neg()
		want := "-" + s
		if s == "0" {
			want = "0"
		}
		m, _ := ParseDecimal(want)
		switch {
		case n.String() != want:
			t.Fatalf("-(%s) is %s", s, n)
		case n != m:
			t.Fatalf("-(%s) is not the Decimal of %s", s, want)
		case n.Neg() != d:
			t.Fatalf("-(-(%s)) is not %s", s, s)
		case d.Sign() != -n.Sign():
			t.Fatalf("-(%s): its sign", s)
		}
	}
	// -0 is 0, the one zero
	if (Decimal{}).Neg() != (Decimal{}) {
		t.Fatal("-0 is not the zero Decimal")
	}
}

func TestDecimalOfUnits(t *testing.T) {
	for _, c := range []struct {
		units    int64
		decimals int
		want     string
	}{
		{100050000, 6, "100.05"}, {-1, 6, "-0.000001"}, {15, 1, "1.5"}, {1500, 3, "1.5"}, {10, 7, "0.000001"},
		{999999999999999, 0, "999999999999999"}, {-999999999999999, 0, "-999999999999999"},
		{999999999999999, 6, "999999999.999999"}, {0, 18, "0"}, {0, 0, "0"}, {12345, 2, "123.45"},
		{1_000_000_000_000_000_000, 18, "1"}, {-150_000_000, 8, "-1.5"},
	} {
		d, err := DecimalOf(c.units, c.decimals)
		if err != nil {
			t.Fatalf("%d × 10^-%d: %v", c.units, c.decimals, err)
		}
		p, _ := ParseDecimal(c.want)
		if d != p || d.String() != c.want {
			t.Fatalf("%d × 10^-%d: %s, not %s", c.units, c.decimals, d, c.want)
		}
	}
	for _, c := range []struct {
		units    int64
		decimals int
	}{
		{1, 7}, {1_000_000_000_000_000, 0}, {1234567890123456, 6}, {1, -1}, {1, 19}, {math.MinInt64, 0},
		{math.MaxInt64, 0}, {math.MaxInt64, 18}, {123, 9},
	} {
		if d, err := DecimalOf(c.units, c.decimals); err == nil {
			t.Fatalf("%d × 10^-%d: not refused, %s", c.units, c.decimals, d)
		}
	}
}

// DecimalOf and ParseDecimal one Decimal for one value: units and decimals written as digits read to the same Decimal,
// or both refused
func FuzzDecimalOf(f *testing.F) {
	f.Add(int64(100050000), uint8(6))
	f.Add(int64(-1), uint8(7))
	f.Add(int64(math.MinInt64), uint8(18))
	f.Fuzz(func(t *testing.T, units int64, decimals uint8) {
		n := int(decimals % 20)
		d, err := DecimalOf(units, n)
		if n > 18 {
			if err == nil {
				t.Fatalf("%d decimals not refused", n)
			}
			return
		}
		// the digits of units × 10^-n, its 0s after the point dropped
		u := strconv.FormatUint(uint64(units), 10)
		if units < 0 {
			u = strconv.FormatUint(-uint64(units), 10)
		}
		for len(u) <= n {
			u = "0" + u
		}
		w, f := u[:len(u)-n], u[len(u)-n:]
		for len(f) > 0 && f[len(f)-1] == '0' {
			f = f[:len(f)-1]
		}
		s := w
		if f != "" {
			s += "." + f
		}
		if units < 0 {
			s = "-" + s
		}
		p, perr := ParseDecimal(s)
		switch {
		case (err == nil) != (perr == nil):
			t.Fatalf("%d × 10^-%d: DecimalOf %v, ParseDecimal(%s) %v", units, n, err, s, perr)
		case err == nil && d != p:
			t.Fatalf("%d × 10^-%d: %s, not %s", units, n, d, p)
		case err == nil && (d.String() != p.String() || d.Neg().Neg() != d):
			t.Fatalf("%d × 10^-%d: %s", units, n, d)
		}
	})
}
