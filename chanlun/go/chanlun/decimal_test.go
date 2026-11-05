package chanlun

import (
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
		"9007199254740993",
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
