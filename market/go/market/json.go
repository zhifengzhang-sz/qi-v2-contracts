package market

import (
	"fmt"
	"math/bits"
	"reflect"
	"slices"
	"strconv"
	"strings"
	"sync"
	"unicode/utf16"
	"unicode/utf8"
)

// The contract's JSON (SPEC.md, The JSON), read and written by hand: encoding/json alone takes a name twice (the last
// wins), replaces bytes that are not UTF-8 and reads a number with an exponent and a field it does not know, each of
// which the contract refuses. Here the text is read from its first byte to its last straight into the record's type
// (records.go) by its fields' tags, with no tree of the text built. It refuses what is not JSON and what the contract
// does not allow of any JSON (text not UTF-8, a name twice in one object, a number not written in digits), a name that
// is no field, a field missing, null, and a value of another kind. The rules come after (rules.go). The records here
// are of numbers alone, whole numbers and decimals: a contract built on this one, whose records hold more (chanlun's,
// with booleans, lists and fields that may be not set), reads its text by a reader of its own, under the same rules.

// A record's fields, by their tags, and how each is read and written; a type's, how a value of it is read and written
type op uint8

const (
	opUint    op = iota // a whole number, a uint64
	opDecimal           // a price or a quantity, a Decimal
	opRecord            // a record, by its fields
	opNone              // a type the JSON does not read
)

type field struct {
	name   string
	quoted string // "name":
	index  int
	shape  *shape // its type's
}

type shape struct {
	op       op
	fields   []field // a record's, in the order of the type
	sorted   []field // a record's, in the order of their names (ASCII), the canonical text's
	required uint64  // a record's fields, a bit each by their place in fields: every one, none may be left out
}

var shapes sync.Map // reflect.Type → *shape

var decimalType = reflect.TypeFor[Decimal]()

func opOf(t reflect.Type) op {
	switch {
	case t == decimalType:
		return opDecimal
	case t.Kind() == reflect.Uint64:
		return opUint
	case t.Kind() == reflect.Struct:
		return opRecord
	}
	return opNone
}

func shapeOf(t reflect.Type) *shape {
	if s, ok := shapes.Load(t); ok {
		return s.(*shape)
	}
	s := &shape{op: opOf(t)}
	if s.op == opRecord {
		for i := range t.NumField() {
			sf := t.Field(i)
			name, ok := sf.Tag.Lookup("market")
			if !ok {
				continue
			}
			if len(s.fields) == 64 {
				panic("market: a record of more than 64 fields")
			}
			s.required |= 1 << len(s.fields)
			s.fields = append(s.fields, field{name: name, quoted: strconv.Quote(name) + ":", index: i, shape: shapeOf(sf.Type)})
		}
		s.sorted = slices.Clone(s.fields)
		slices.SortFunc(s.sorted, func(a, b field) int { return strings.Compare(a.name, b.name) })
	}
	v, _ := shapes.LoadOrStore(t, s)
	return v.(*shape)
}

// A place in the JSON as the TypeScript form names it: the names from the top, joined by ., the top itself "the
// JSON". Kept as steps while reading, and made a text only for a fault.
type step struct {
	name string // a field's name
}

// The reader: the text, where it is, and the place it is reading
type decoder struct {
	s    []byte
	i    int
	at   []step
	name []byte // a name read with escapes in it
}

func (d *decoder) place(more ...string) string {
	var b strings.Builder
	for _, s := range d.at {
		if b.Len() > 0 {
			b.WriteByte('.')
		}
		b.WriteString(s.name)
	}
	for _, m := range more {
		if b.Len() > 0 {
			b.WriteByte('.')
		}
		b.WriteString(m)
	}
	if b.Len() == 0 {
		return "the JSON"
	}
	return b.String()
}

// fault: a value refused at the place being read
func (d *decoder) fault(format string, a ...any) error {
	return fmt.Errorf("%s: %s", d.place(), fmt.Sprintf(format, a...))
}

// syntax: a text that is not JSON
func (d *decoder) syntax(what string) error {
	return fmt.Errorf("not JSON: %s at byte %d", what, d.i)
}

// parse: data read into dst, a record's type: the text one JSON value, its numbers well written, and nothing after it
func parse(data []byte, dst reflect.Value) error {
	if !utf8.Valid(data) {
		return fmt.Errorf("text not UTF-8")
	}
	d := decoder{s: data, at: make([]step, 0, 2)}
	if err := d.read(dst, shapeOf(dst.Type())); err != nil {
		return err
	}
	d.space()
	if d.i != len(d.s) {
		return d.syntax("text after the value")
	}
	return nil
}

func (d *decoder) space() {
	for d.i < len(d.s) {
		switch d.s[d.i] {
		case ' ', '\t', '\n', '\r':
			d.i++
		default:
			return
		}
	}
}

func hasWord(s []byte, w string) bool { return len(s) >= len(w) && string(s[:len(w)]) == w }

// begin: the first byte of the value that begins at the place, after any space: {, [, ", - or a digit, t or f; a
// fault if none begins there, or null, which the contract never writes
func (d *decoder) begin() (byte, error) {
	d.space()
	if d.i >= len(d.s) {
		return 0, d.syntax("the text ends where a value is")
	}
	switch c := d.s[d.i]; {
	case c == '{' || c == '[' || c == '"' || c == '-' || ('0' <= c && c <= '9'):
		return c, nil
	case hasWord(d.s[d.i:], "true"), hasWord(d.s[d.i:], "false"):
		return c, nil
	case hasWord(d.s[d.i:], "null"):
		return 0, d.fault("null, where a value is")
	}
	return 0, d.syntax("no value")
}

// kindOf: what a value that begins with c is, for a fault
func kindOf(c byte) string {
	switch c {
	case '{':
		return "an object"
	case '[':
		return "an array"
	case '"':
		return "a text"
	case 't', 'f':
		return "a boolean"
	}
	return "a number"
}

func isNumber(c byte) bool { return c == '-' || ('0' <= c && c <= '9') }

// read: the value at the place read into dst, by its type's shape
func (d *decoder) read(dst reflect.Value, s *shape) error {
	switch s.op {
	case opUint:
		n, err := d.whole()
		dst.SetUint(n)
		return err
	case opDecimal:
		x, err := d.decimal()
		*dst.Addr().Interface().(*Decimal) = x
		return err
	case opRecord:
		return d.record(dst, s)
	}
	return d.fault("a field of a type the JSON does not read (%s)", dst.Type())
}

// number: a JSON number, refused unless written as the contract writes a number (SPEC.md, The JSON): in digits, no
// exponent; a whole number of at most 16 digits, or a decimal of at most 6 digits after the point and 15 from the
// first that is not 0, the last not 0. Its kind and bound are its field's (whole, decimal). The bytes of the text.
func (d *decoder) number() ([]byte, error) {
	start := d.i
	for d.i < len(d.s) {
		c := d.s[d.i]
		if !isNumber(c) && c != '+' && c != '.' && c != 'e' && c != 'E' {
			break
		}
		d.i++
	}
	t := d.s[start:d.i]
	_, w, f, ok := digits(t)
	if !ok || (len(f) == 0 && len(w) > 16) ||
		(len(f) > 0 && (len(f) > decimalFraction || significant(w, f) > decimalDigits)) {
		return nil, fmt.Errorf("%s: a number in digits, a whole number of at most 16, a decimal of at most 6 after the point and 15 in all", t)
	}
	return t, nil
}

// Bound: the largest whole number of the contract, either way (SPEC.md, Units): 2⁵³ − 1, which every JSON reader holds
// exactly. A time, a position and a count are whole numbers from 0 to Bound.
const Bound = 1<<53 - 1

// whole: a whole number from 0 to Bound, as a time, a position and a count are (-0 is 0)
func (d *decoder) whole() (uint64, error) {
	c, err := d.begin()
	if err != nil {
		return 0, err
	}
	if !isNumber(c) {
		return 0, d.fault("a whole number, not %s", kindOf(c))
	}
	t, err := d.number()
	if err != nil {
		return 0, err
	}
	neg, w, f, _ := digits(t)
	if len(f) > 0 {
		return 0, d.fault("%s: a whole number, not a fraction", t)
	}
	var n uint64 // at most 16 digits (number)
	for _, c := range w {
		n = n*10 + uint64(c-'0')
	}
	switch {
	case n > Bound:
		return 0, d.fault("%s: a number past %d", t, uint64(Bound))
	case neg && n != 0:
		return 0, d.fault("%s: a whole number not negative", t)
	}
	return n, nil
}

// decimal: a price or a quantity, read from its digits (ParseDecimal)
func (d *decoder) decimal() (Decimal, error) {
	c, err := d.begin()
	if err != nil {
		return Decimal{}, err
	}
	if !isNumber(c) {
		return Decimal{}, d.fault("a decimal, not %s", kindOf(c))
	}
	t, err := d.number()
	if err != nil {
		return Decimal{}, err
	}
	x, ok := decimalOf(t)
	if !ok {
		return Decimal{}, d.fault("%s: %v", t, errDecimal)
	}
	return x, nil
}

// record: an object read into a record: exactly its fields, none other, none twice, none missing
func (d *decoder) record(dst reflect.Value, s *shape) error {
	c, err := d.begin()
	if err != nil {
		return err
	}
	if c != '{' {
		return d.fault("an object, not %s", kindOf(c))
	}
	d.i++
	var got uint64
	d.space()
	if d.i < len(d.s) && d.s[d.i] == '}' {
		d.i++
	} else {
		for {
			d.space()
			if d.i >= len(d.s) || d.s[d.i] != '"' {
				return d.syntax("no name")
			}
			name, err := d.text()
			if err != nil {
				return err
			}
			k := -1
			for i := range s.fields {
				if string(name) == s.fields[i].name {
					k = i
					break
				}
			}
			if k < 0 {
				return d.fault("%q is no field of it", name)
			}
			f := &s.fields[k]
			// a name twice in one object: refused, as no form keeps one of the two
			if got&(1<<k) != 0 {
				return fmt.Errorf("%q: a name twice in one object", f.name)
			}
			got |= 1 << k
			d.space()
			if d.i >= len(d.s) || d.s[d.i] != ':' {
				return d.syntax("no : after a name")
			}
			d.i++
			d.at = append(d.at, step{name: f.name})
			if err := d.read(dst.Field(f.index), f.shape); err != nil {
				return err
			}
			d.at = d.at[:len(d.at)-1]
			d.space()
			if d.i >= len(d.s) {
				return d.syntax("an object not closed")
			}
			d.i++
			if d.s[d.i-1] == '}' {
				break
			}
			if d.s[d.i-1] != ',' {
				return d.syntax("no , or } after a value")
			}
		}
	}
	if missing := s.required &^ got; missing != 0 {
		return fmt.Errorf("%s: a field missing", d.place(s.fields[bits.TrailingZeros64(missing)].name))
	}
	return nil
}

// text: a JSON string's characters, its escapes read; a character below U+0020, an escape JSON does not have, and
// half of a character escaped as UTF-16 refused. The bytes of the text where it has no escape, else of d.name: either
// good until the next name is read.
func (d *decoder) text() ([]byte, error) {
	d.i++ // "
	start := d.i
	for d.i < len(d.s) && d.s[d.i] != '"' && d.s[d.i] != '\\' && d.s[d.i] >= 0x20 {
		d.i++
	}
	if d.i < len(d.s) && d.s[d.i] == '"' {
		d.i++
		return d.s[start : d.i-1], nil
	}
	b := append(d.name[:0], d.s[start:d.i]...)
	defer func() { d.name = b[:0] }()
	for {
		if d.i >= len(d.s) {
			return nil, d.syntax("a text not closed")
		}
		c := d.s[d.i]
		switch {
		case c == '"':
			d.i++
			return b, nil
		case c < 0x20:
			return nil, d.syntax("a control character in a text")
		case c != '\\':
			b = append(b, c)
			d.i++
			continue
		}
		if d.i+1 >= len(d.s) {
			return nil, d.syntax("a text not closed")
		}
		e := d.s[d.i+1]
		d.i += 2
		switch e {
		case '"', '\\', '/':
			b = append(b, e)
		case 'b':
			b = append(b, '\b')
		case 'f':
			b = append(b, '\f')
		case 'n':
			b = append(b, '\n')
		case 'r':
			b = append(b, '\r')
		case 't':
			b = append(b, '\t')
		case 'u':
			c1, ok := d.hex4()
			if !ok {
				return nil, d.syntax("an escape \\u not of four hex digits")
			}
			if utf16.IsSurrogate(c1) {
				c2 := rune(-1)
				if d.i+1 < len(d.s) && d.s[d.i] == '\\' && d.s[d.i+1] == 'u' {
					d.i += 2
					c2, ok = d.hex4()
					if !ok {
						return nil, d.syntax("an escape \\u not of four hex digits")
					}
				}
				c1 = utf16.DecodeRune(c1, c2)
				if c1 == utf8.RuneError {
					return nil, d.syntax("half of a character escaped")
				}
			}
			b = utf8.AppendRune(b, c1)
		default:
			return nil, d.syntax("an escape JSON does not have")
		}
	}
}

func (d *decoder) hex4() (rune, bool) {
	if d.i+4 > len(d.s) {
		return 0, false
	}
	var n rune
	for _, c := range d.s[d.i : d.i+4] {
		switch {
		case '0' <= c && c <= '9':
			n = n<<4 | rune(c-'0')
		case 'a' <= c && c <= 'f':
			n = n<<4 | rune(c-'a'+10)
		case 'A' <= c && c <= 'F':
			n = n<<4 | rune(c-'A'+10)
		default:
			return 0, false
		}
	}
	d.i += 4
	return n, true
}

// The writer: the canonical text (SPEC.md, The JSON) of a record
type encoder struct {
	b []byte
}

// text: the text written
func (e *encoder) text() string { return string(e.b) }

func (e *encoder) str(s string) { e.b = append(e.b, s...) }

// write: a value as the canonical text writes it, by its type's shape: a number in its digits, a record its fields in
// the order of their names, no spaces
func (e *encoder) write(v reflect.Value, s *shape) {
	switch s.op {
	case opUint:
		e.b = strconv.AppendUint(e.b, v.Uint(), 10)
	case opDecimal:
		e.b = v.Interface().(Decimal).AppendTo(e.b)
	case opRecord:
		e.b = append(e.b, '{')
		for i, f := range s.sorted {
			if i > 0 {
				e.b = append(e.b, ',')
			}
			e.str(f.quoted)
			e.write(v.Field(f.index), f.shape)
		}
		e.b = append(e.b, '}')
	}
}
