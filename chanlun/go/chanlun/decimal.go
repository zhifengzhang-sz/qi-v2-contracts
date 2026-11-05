package chanlun

import (
	"errors"
	"strconv"
	"strings"
)

// Decimal: a price or a quantity (SPEC.md, Units), held exactly as its digits say: at most 6 digits after the point
// and at most 15 from the first that is not 0. Never a float64: ParseDecimal reads it from its digits, String writes
// the same digits back, and == and Cmp compare values exactly (one value, one Decimal: -0 is 0). It is held as its
// whole part and its millionths, each a number of its own, since a count of millionths in an int64 does not hold the
// 15 digits before the point that the contract allows. The zero Decimal is 0. A value with no field a holder can
// reach: a copy is a Decimal of its own.
type Decimal struct {
	neg   bool   // below 0; never for 0
	whole uint64 // the digits before the point, below 10^15
	micro uint32 // the digits after the point, in millionths, below 10^6
}

const (
	// at most 15 digits from the first that is not 0
	decimalDigits = 15
	// at most 6 digits after the point
	decimalFraction = 6
)

var errDecimal = errors.New("a decimal of at most 6 digits after the point and 15 from the first that is not 0")

// digits splits a number written as the contract writes it (SPEC.md, The JSON): an optional -, then 0 or a digit not 0
// and more digits, then optionally . and digits, the last not 0. ok is false for anything else: an exponent, a + or a
// leading 0 among them.
func digits(s string) (neg bool, whole, fraction string, ok bool) {
	if strings.HasPrefix(s, "-") {
		neg, s = true, s[1:]
	}
	w := 0
	for w < len(s) && '0' <= s[w] && s[w] <= '9' {
		w++
	}
	if w == 0 || (w > 1 && s[0] == '0') {
		return false, "", "", false
	}
	whole, s = s[:w], s[w:]
	if s == "" {
		return neg, whole, "", true
	}
	if s[0] != '.' || len(s) == 1 || s[len(s)-1] == '0' {
		return false, "", "", false
	}
	for _, c := range []byte(s[1:]) {
		if c < '0' || '9' < c {
			return false, "", "", false
		}
	}
	return neg, whole, s[1:], true
}

// significant: the number of digits of whole and fraction from the first that is not 0
func significant(whole, fraction string) int {
	return len(strings.TrimLeft(whole+fraction, "0"))
}

// ParseDecimal reads a decimal from its digits, as the contract writes it (SPEC.md, Units and The JSON): an optional -,
// then 0 or a digit not 0 and more digits, then optionally . and at most 6 digits, the last not 0; at most 15 digits
// from the first that is not 0. No exponent. -0 is 0.
func ParseDecimal(s string) (Decimal, error) {
	neg, w, f, ok := digits(s)
	if !ok || len(f) > decimalFraction || significant(w, f) > decimalDigits {
		return Decimal{}, errDecimal
	}
	whole, err := strconv.ParseUint(w, 10, 64)
	if err != nil {
		return Decimal{}, errDecimal
	}
	var micro uint32
	for i := range decimalFraction {
		micro *= 10
		if i < len(f) {
			micro += uint32(f[i] - '0')
		}
	}
	return Decimal{neg: neg && (whole != 0 || micro != 0), whole: whole, micro: micro}, nil
}

// String writes the decimal's digits as the contract writes them, the canonical text's: no exponent, no 0 after the
// last digit after the point, no point for a whole number, - for a value below 0.
func (d Decimal) String() string {
	var b strings.Builder
	if d.neg {
		b.WriteByte('-')
	}
	b.WriteString(strconv.FormatUint(d.whole, 10))
	if d.micro != 0 {
		b.WriteByte('.')
		b.WriteString(strings.TrimRight(strconv.FormatUint(uint64(d.micro)+1_000_000, 10)[1:], "0"))
	}
	return b.String()
}

// Cmp compares two decimals exactly: -1 if d is below e, 0 if they are the one value, 1 if d is above e.
func (d Decimal) Cmp(e Decimal) int {
	if d.neg != e.neg {
		if d.neg {
			return -1
		}
		return 1
	}
	c := 0
	switch {
	case d.whole < e.whole || (d.whole == e.whole && d.micro < e.micro):
		c = -1
	case d.whole > e.whole || d.micro > e.micro:
		c = 1
	}
	if d.neg {
		return -c
	}
	return c
}

// Sign: -1 below 0, 0 for 0, 1 above 0.
func (d Decimal) Sign() int {
	switch {
	case d.neg:
		return -1
	case d.whole == 0 && d.micro == 0:
		return 0
	}
	return 1
}

// minDecimal and maxDecimal: the lesser and the greater of two decimals
func minDecimal(a, b Decimal) Decimal {
	if a.Cmp(b) <= 0 {
		return a
	}
	return b
}

func maxDecimal(a, b Decimal) Decimal {
	if a.Cmp(b) >= 0 {
		return a
	}
	return b
}
