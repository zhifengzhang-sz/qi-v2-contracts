package chanlun

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
// which the contract refuses. Here the text is read from its first byte to its last straight into the records' types
// (records.go) by their fields' tags, each array's items counted before they are read (items), so that a run's text
// is gone over a few times at most, never more than its types are deep; no tree of the whole text is built, so
// reading a run holds the text and the run, little more. It refuses what is not JSON and what the contract does not allow of any JSON (text not UTF-8,
// a name twice in one object, a number not written in digits), a name that is no field, a field missing that is not
// optional, null, and a value of another kind. The rules come after (rules.go).

// A record's fields, by their tags, and how each is read and written; a type's, how a value of it is read and written
type op uint8

const (
	opUint    op = iota // a whole number, a uint64
	opBool              // a boolean
	opDecimal           // a price or a quantity, a Decimal
	opCodec             // a List or an Optional, read and written by its own methods (codec)
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
	required uint64  // a record's fields not optional, a bit each by their place in fields
	least    int     // the fewest bytes of text a value of it takes: 0, true, [], a record of its fields not optional
}

var shapes sync.Map // reflect.Type → *shape

var (
	decimalType = reflect.TypeFor[Decimal]()
	codecType   = reflect.TypeFor[codec]()
)

func opOf(t reflect.Type) op {
	switch {
	case t == decimalType:
		return opDecimal
	case reflect.PointerTo(t).Implements(codecType):
		return opCodec
	case t.Kind() == reflect.Uint64:
		return opUint
	case t.Kind() == reflect.Bool:
		return opBool
	case t.Kind() == reflect.Struct:
		return opRecord
	}
	return opNone
}

func shapeOf(t reflect.Type) *shape {
	if s, ok := shapes.Load(t); ok {
		return s.(*shape)
	}
	s := &shape{op: opOf(t), least: 1} // a number's 0, a record's {, and its fields below
	switch s.op {
	case opBool:
		s.least = len("true")
	case opCodec:
		s.least = len("[]")
	}
	if s.op == opRecord {
		for i := range t.NumField() {
			sf := t.Field(i)
			name, ok := sf.Tag.Lookup("chanlun")
			if !ok {
				continue
			}
			if len(s.fields) == 64 {
				panic("chanlun: a record of more than 64 fields")
			}
			f := field{name: name, quoted: strconv.Quote(name) + ":", index: i, shape: shapeOf(sf.Type)}
			// an Optional may be left out; every other field is required, and is in the fewest bytes of the record
			if _, optional := reflect.Zero(sf.Type).Interface().(interface{ IsSet() bool }); !optional {
				s.required |= 1 << len(s.fields)
				s.least += len(f.quoted) + f.shape.least + 1 // its name, its value, and , or }
			}
			s.fields = append(s.fields, f)
		}
		s.sorted = slices.Clone(s.fields)
		slices.SortFunc(s.sorted, func(a, b field) int { return strings.Compare(a.name, b.name) })
	}
	v, _ := shapes.LoadOrStore(t, s)
	return v.(*shape)
}

// codec: what List and Optional give the JSON: each reads itself from the text and writes itself, and an Optional not
// set is not written
type codec interface {
	readJSON(d *decoder) error
	writeJSON(e *encoder)
	written() bool
}

// A place in the JSON as the TypeScript form names it: the names and places from the top, joined by ., klines.5.date;
// the top itself "the JSON". Kept as steps while reading, and made a text only for a fault.
type step struct {
	name  string // a field's or a part's name, or "" for a place in an array
	index int
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
		if s.name != "" {
			b.WriteString(s.name)
		} else {
			b.WriteString(strconv.Itoa(s.index))
		}
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

// parse: data read into dst, a record's or a run's type: the text one JSON value, its numbers well written, and
// nothing after it
func parse(data []byte, dst reflect.Value) error {
	if !utf8.Valid(data) {
		return fmt.Errorf("text not UTF-8")
	}
	d := decoder{s: data, at: make([]step, 0, 8)}
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
		return 0, d.fault("null, where a field not set is left out")
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
	case opBool:
		b, err := d.boolean()
		dst.SetBool(b)
		return err
	case opDecimal:
		x, err := d.decimal()
		*dst.Addr().Interface().(*Decimal) = x
		return err
	case opCodec:
		return dst.Addr().Interface().(codec).readJSON(d)
	case opRecord:
		return d.record(dst, s)
	}
	return d.fault("a field of a type the JSON does not read (%s)", dst.Type())
}

// readInto: the value at the place read into *p, of a field's type
func readInto[T any](d *decoder, p *T) error {
	switch q := any(p).(type) {
	case *uint64:
		n, err := d.whole()
		*q = n
		return err
	case *Decimal:
		x, err := d.decimal()
		*q = x
		return err
	case *bool:
		b, err := d.boolean()
		*q = b
		return err
	case codec:
		return q.readJSON(d)
	}
	return d.read(reflect.ValueOf(p).Elem(), shapeOf(reflect.TypeFor[T]()))
}

func (d *decoder) boolean() (bool, error) {
	c, err := d.begin()
	switch {
	case err != nil:
		return false, err
	case c == 't':
		d.i += len("true")
		return true, nil
	case c == 'f':
		d.i += len("false")
		return false, nil
	}
	return false, d.fault("a boolean, not %s", kindOf(c))
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
// exactly. A time, a position, a bar and a count are whole numbers from 0 to Bound.
const Bound = 1<<53 - 1

// whole: a whole number from 0 to Bound, as a time, a position, a bar and a count are (-0 is 0)
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

// record: an object read into a record: exactly its fields, none other, none twice, none missing but an optional one
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

// items: how many items the array that begins at the place holds, by its commas outside any text, array or object in
// it, and its bytes between [ and ]: so that its items are read into a list of their number, not one grown and copied
// as it is read. Only a measure: the array is read after, and refused then if it is not JSON.
func (d *decoder) items() (n, length int) {
	depth, some := 0, false
	for i := d.i + 1; i < len(d.s); i++ {
		switch c := d.s[i]; c {
		case '"':
			for i++; i < len(d.s) && d.s[i] != '"'; i++ {
				if d.s[i] == '\\' {
					i++
				}
			}
		case '[', '{':
			depth++
		case ']', '}':
			if depth == 0 {
				if some {
					n++
				}
				return n, i - d.i - 1
			}
			depth--
		case ',':
			if depth == 0 {
				n++
			}
		}
		if i < len(d.s) {
			if c := d.s[i]; c != ' ' && c != '\t' && c != '\n' && c != '\r' {
				some = true
			}
		}
	}
	return n, len(d.s) - d.i - 1
}

// list: the items of an array, room made for as many as it holds, then each read by item into the place it will
// keep, and the array's end found. The room is never more than its bytes hold of items of least bytes each, so that a
// text that is not JSON, [,,,] among them, makes no more room than one that is.
func (d *decoder) list(least int, room func(n int), item func(i int) error) error {
	c, err := d.begin()
	if err != nil {
		return err
	}
	if c != '[' {
		return d.fault("an array, not %s", kindOf(c))
	}
	n, length := d.items()
	room(min(n, (length+1)/(least+1)))
	d.i++
	d.space()
	if d.i < len(d.s) && d.s[d.i] == ']' {
		d.i++
		return nil
	}
	for i := 0; ; i++ {
		d.at = append(d.at, step{index: i})
		if err := item(i); err != nil {
			return err
		}
		d.at = d.at[:len(d.at)-1]
		d.space()
		if d.i >= len(d.s) {
			return d.syntax("an array not closed")
		}
		d.i++
		switch d.s[d.i-1] {
		case ']':
			return nil
		case ',':
		default:
			return d.syntax("no , or ] after a value")
		}
	}
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

func (l *List[T]) readJSON(d *decoder) error {
	var items []T
	s := shapeOf(reflect.TypeFor[T]())
	room := func(n int) {
		if n > 0 {
			items = make([]T, 0, n)
		}
	}
	err := d.list(s.least, room, func(int) error {
		var zero T
		items = append(items, zero)
		p := &items[len(items)-1]
		if s.op == opRecord {
			return d.record(reflect.ValueOf(p).Elem(), s)
		}
		return readInto(d, p)
	})
	if err != nil {
		return err
	}
	l.items = items
	return nil
}

func (l *List[T]) written() bool { return true }

func (o *Optional[T]) readJSON(d *decoder) error {
	if err := readInto(d, &o.value); err != nil {
		return err
	}
	o.set = true
	return nil
}

func (o *Optional[T]) written() bool { return o.set }

// The writer: the canonical text (SPEC.md, The JSON), held as it is written in pieces of about a chunk each, never
// grown and copied, then copied once into the text it gives
type encoder struct {
	b      []byte   // the piece being written
	pieces [][]byte // the pieces written before it
}

const chunk = 1 << 20

// cut: the piece being written put by once it is a chunk long, and a new one begun
func (e *encoder) cut() {
	if len(e.b) >= chunk {
		e.pieces = append(e.pieces, e.b)
		e.b = make([]byte, 0, chunk+chunk/8)
	}
}

// text: the text written, in one string
func (e *encoder) text() string {
	n := len(e.b)
	for _, p := range e.pieces {
		n += len(p)
	}
	var t strings.Builder
	t.Grow(n)
	for _, p := range e.pieces {
		t.Write(p)
	}
	t.Write(e.b)
	return t.String()
}

func (e *encoder) str(s string) { e.b = append(e.b, s...) }

func (e *encoder) uint(n uint64) { e.b = strconv.AppendUint(e.b, n, 10) }

func (e *encoder) decimal(x Decimal) { e.b = x.appendTo(e.b) }

func (e *encoder) boolean(v bool) { e.b = strconv.AppendBool(e.b, v) }

// write: a value as the canonical text writes it, by its type's shape: a number in its digits, a boolean true or
// false, an array of numbers [, its numbers separated by ,, ], a record its fields in the order of their names, a field
// not set left out, no spaces
func (e *encoder) write(v reflect.Value, s *shape) {
	switch s.op {
	case opUint:
		e.uint(v.Uint())
	case opBool:
		e.boolean(v.Bool())
	case opDecimal:
		e.decimal(*v.Addr().Interface().(*Decimal))
	case opCodec:
		v.Addr().Interface().(codec).writeJSON(e)
	case opRecord:
		e.b = append(e.b, '{')
		first := true
		for _, f := range s.sorted {
			x := v.Field(f.index)
			if f.shape.op == opCodec && !x.Addr().Interface().(codec).written() {
				continue
			}
			if !first {
				e.b = append(e.b, ',')
			}
			first = false
			e.str(f.quoted)
			e.write(x, f.shape)
		}
		e.b = append(e.b, '}')
	}
}

// writeInto: *p as the canonical text writes it, of a field's type
func writeInto[T any](e *encoder, p *T) {
	switch q := any(p).(type) {
	case *uint64:
		e.uint(*q)
	case *Decimal:
		e.decimal(*q)
	case *bool:
		e.boolean(*q)
	case codec:
		q.writeJSON(e)
	default:
		e.write(reflect.ValueOf(p).Elem(), shapeOf(reflect.TypeFor[T]()))
	}
}

func (l *List[T]) writeJSON(e *encoder) {
	e.b = append(e.b, '[')
	for i := range l.items {
		if i > 0 {
			e.b = append(e.b, ',')
		}
		writeInto(e, &l.items[i])
	}
	e.b = append(e.b, ']')
}

func (o *Optional[T]) writeJSON(e *encoder) { writeInto(e, &o.value) }
