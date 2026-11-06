package market

import (
	"errors"
	"strconv"
)

// Decimal: a price or a quantity (SPEC.md, Units), held exactly as its digits say: at most 6 digits after the point
// and at most 15 from the first that is not 0. Never a float64: ParseDecimal reads it from its digits, DecimalOf from a
// whole number of units, String writes the digits back and AppendTo appends them, and == and Cmp compare values
// exactly (one value, one Decimal: -0 is 0). It is 16 bytes: its whole part in one word, and its millionths in another
// with its sign, since a count of millionths in an int64 does not hold the 15 digits before the point that the
// contract allows. The zero Decimal is 0. A value with no field a holder can reach: a copy is a Decimal of its own.
type Decimal struct {
	whole uint64 // the digits before the point, below 10^15
	micro uint32 // the digits after the point, in millionths, below 10^6; and minus, below 0, never for 0
}

const (
	// at most 15 digits from the first that is not 0
	decimalDigits = 15
	// at most 6 digits after the point
	decimalFraction = 6
	// the bit of the millionths' word that says the decimal is below 0
	minus uint32 = 1 << 31
)

var errDecimal = errors.New("a decimal of at most 6 digits after the point and 15 from the first that is not 0")

// digits splits a number written as the contract writes it (SPEC.md, The JSON): an optional -, then 0 or a digit not 0
// and more digits, then optionally . and digits, the last not 0. ok is false for anything else: an exponent, a + or a
// leading 0 among them. Of a text or of the bytes of one, so that the JSON is read with no copy.
func digits[S string | []byte](s S) (neg bool, whole, fraction S, ok bool) {
	if len(s) > 0 && s[0] == '-' {
		neg, s = true, s[1:]
	}
	w := 0
	for w < len(s) && '0' <= s[w] && s[w] <= '9' {
		w++
	}
	if w == 0 || (w > 1 && s[0] == '0') {
		return false, whole, fraction, false
	}
	whole, s = s[:w], s[w:]
	if len(s) == 0 {
		return neg, whole, s, true
	}
	if s[0] != '.' || len(s) == 1 || s[len(s)-1] == '0' {
		return false, whole, fraction, false
	}
	for i := 1; i < len(s); i++ {
		if s[i] < '0' || '9' < s[i] {
			return false, whole, fraction, false
		}
	}
	return neg, whole, s[1:], true
}

// significant: the number of digits of whole and fraction from the first that is not 0
func significant[S string | []byte](whole, fraction S) int {
	z := 0
	for z < len(whole) && whole[z] == '0' {
		z++
	}
	if z == len(whole) {
		for k := 0; k < len(fraction) && fraction[k] == '0'; k++ {
			z++
		}
	}
	return len(whole) + len(fraction) - z
}

// decimalOf: a decimal from its digits, as ParseDecimal reads it
func decimalOf[S string | []byte](s S) (Decimal, bool) {
	neg, w, f, ok := digits(s)
	if !ok || len(f) > decimalFraction || significant(w, f) > decimalDigits {
		return Decimal{}, false
	}
	// at most 15 digits from the first not 0, and no 0 first but 0 itself: below 10^15
	var whole uint64
	for i := 0; i < len(w); i++ {
		whole = whole*10 + uint64(w[i]-'0')
	}
	var micro uint32
	for i := range decimalFraction {
		micro *= 10
		if i < len(f) {
			micro += uint32(f[i] - '0')
		}
	}
	return Decimal{whole: whole, micro: micro}.signed(neg), true
}

// signed: the decimal, below 0 if neg and it is not 0
func (d Decimal) signed(neg bool) Decimal {
	if neg && (d.whole != 0 || d.micro != 0) {
		d.micro |= minus
	}
	return d
}

func (d Decimal) below0() bool       { return d.micro&minus != 0 }
func (d Decimal) millionths() uint32 { return d.micro &^ minus }

// ParseDecimal reads a decimal from its digits, as the contract writes it (SPEC.md, Units and The JSON): an optional -,
// then 0 or a digit not 0 and more digits, then optionally . and at most 6 digits, the last not 0; at most 15 digits
// from the first that is not 0. No exponent. -0 is 0.
func ParseDecimal(s string) (Decimal, error) {
	d, ok := decimalOf(s)
	if !ok {
		return Decimal{}, errDecimal
	}
	return d, nil
}

// pow10: 10^0 to 10^18, each a uint64
var pow10 = func() (p [19]uint64) {
	p[0] = 1
	for i := 1; i < len(p); i++ {
		p[i] = p[i-1] * 10
	}
	return p
}()

// DecimalOf: the decimal of units × 10^−decimals, exactly, for a producer that holds a price or a quantity as a whole
// number of units: millionths with decimals 6, cents with 2, a whole number with 0. Refused, as ParseDecimal refuses
// its digits, unless decimals is from 0 to 18 and the value is within the contract's bounds: at most 6 digits after the
// point (a digit past the sixth that is not 0 is refused, never rounded) and at most 15 from the first that is not 0.
func DecimalOf(units int64, decimals int) (Decimal, error) {
	if decimals < 0 || decimals >= len(pow10) {
		return Decimal{}, errDecimal
	}
	u := uint64(units)
	if units < 0 {
		u = -u // the magnitude, math.MinInt64's among them
	}
	whole, rest := u/pow10[decimals], u%pow10[decimals]
	var micro uint64
	if decimals <= decimalFraction {
		micro = rest * pow10[decimalFraction-decimals]
	} else {
		q := pow10[decimals-decimalFraction]
		if rest%q != 0 {
			return Decimal{}, errDecimal
		}
		micro = rest / q
	}
	d := Decimal{whole: whole, micro: uint32(micro)}
	if d.significant() > decimalDigits {
		return Decimal{}, errDecimal
	}
	return d.signed(units < 0), nil
}

// significant: the number of digits of the decimal as String writes them, from the first that is not 0
func (d Decimal) significant() int {
	m, f := d.millionths(), decimalFraction
	if m == 0 {
		f = 0
	}
	for m != 0 && m%10 == 0 {
		m, f = m/10, f-1
	}
	if d.whole == 0 {
		return figures(uint64(m))
	}
	return figures(d.whole) + f
}

// figures: the number of digits of n, none for 0
func figures(n uint64) int {
	c := 0
	for ; n != 0; n /= 10 {
		c++
	}
	return c
}

// AppendTo appends the decimal's digits to b, as String writes them, and gives the extended slice: how a writer of a
// text holding many, a contract built on this one among them, writes each with nothing allocated.
func (d Decimal) AppendTo(b []byte) []byte {
	if d.below0() {
		b = append(b, '-')
	}
	b = strconv.AppendUint(b, d.whole, 10)
	if m := d.millionths(); m != 0 {
		var f [1 + decimalFraction]byte
		f[0] = '.'
		for i := decimalFraction; i >= 1; i-- {
			f[i], m = byte('0'+m%10), m/10
		}
		n := len(f)
		for f[n-1] == '0' {
			n--
		}
		b = append(b, f[:n]...)
	}
	return b
}

// String writes the decimal's digits as the contract writes them, the canonical text's: no exponent, no 0 after the
// last digit after the point, no point for a whole number, - for a value below 0.
func (d Decimal) String() string {
	var b [24]byte
	return string(d.AppendTo(b[:0]))
}

// Cmp compares two decimals exactly: -1 if d is below e, 0 if they are the one value, 1 if d is above e.
func (d Decimal) Cmp(e Decimal) int {
	if d.below0() != e.below0() {
		if d.below0() {
			return -1
		}
		return 1
	}
	c := 0
	switch dm, em := d.millionths(), e.millionths(); {
	case d.whole < e.whole || (d.whole == e.whole && dm < em):
		c = -1
	case d.whole > e.whole || dm > em:
		c = 1
	}
	if d.below0() {
		return -c
	}
	return c
}

// Sign: -1 below 0, 0 for 0, 1 above 0.
func (d Decimal) Sign() int {
	switch {
	case d.below0():
		return -1
	case d.whole == 0 && d.micro == 0:
		return 0
	}
	return 1
}

// Neg: the decimal of the other sign, exactly: -d, its digits the same, and 0 for 0. Within the bounds whenever d is,
// since the bounds are the same either way.
func (d Decimal) Neg() Decimal {
	if d.whole == 0 && d.micro == 0 {
		return d
	}
	d.micro ^= minus
	return d
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
