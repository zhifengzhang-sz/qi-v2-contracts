package chanlun

import (
	"fmt"
	"reflect"
	"slices"
	"strconv"
	"strings"
	"sync"
	"unicode/utf16"
	"unicode/utf8"
)

// The contract's JSON (SPEC.md, The JSON), read by hand: encoding/json alone takes a name twice (the last wins),
// replaces bytes that are not UTF-8 and reads a number with an exponent and a field it does not know, each of which the
// contract refuses. Here the text is read once into values that keep each number's digits, refusing what is not JSON
// and what the contract does not allow of any JSON (text not UTF-8, a name twice in one object, a number not written in
// digits); then each record is read from them into its type (records.go) by its fields' tags, refusing a name that is
// no field, a field missing that is not optional, null, and a value of another kind. The rules come after (rules.go).

// A JSON value as read: a number keeps its digits, an object its names in their order.
type value struct {
	kind  kind
	text  string   // a number's digits, a string's characters
	b     bool     // a boolean's value
	items []value  // an array's items, an object's values
	names []string // an object's names
}

type kind uint8

const (
	jNull kind = iota
	jBool
	jNumber
	jString
	jArray
	jObject
)

func (k kind) String() string {
	return [...]string{"null", "a boolean", "a number", "a text", "an array", "an object"}[k]
}

// deepest: the most arrays and objects one inside another that are read. A run's JSON has at most four (the run, a part,
// a level or a record, and a record or its extremes); beyond deepest no record is, and the text is refused before the
// stack grows with it.
const deepest = 64

type reader struct {
	s     []byte
	i     int
	depth int
}

func (r *reader) fault(what string) error {
	return fmt.Errorf("not JSON: %s at byte %d", what, r.i)
}

// parse: the text as one JSON value, its numbers well written; anything else after it refused
func parse(data []byte) (value, error) {
	if !utf8.Valid(data) {
		return value{}, fmt.Errorf("text not UTF-8")
	}
	r := reader{s: data}
	v, err := r.value()
	if err != nil {
		return value{}, err
	}
	r.space()
	if r.i != len(r.s) {
		return value{}, r.fault("text after the value")
	}
	return v, nil
}

func (r *reader) space() {
	for r.i < len(r.s) {
		switch r.s[r.i] {
		case ' ', '\t', '\n', '\r':
			r.i++
		default:
			return
		}
	}
}

func (r *reader) value() (value, error) {
	r.space()
	if r.i >= len(r.s) {
		return value{}, r.fault("the text ends where a value is")
	}
	switch c := r.s[r.i]; {
	case c == '{':
		return r.object()
	case c == '[':
		return r.array()
	case c == '"':
		s, err := r.string()
		return value{kind: jString, text: s}, err
	case c == '-' || ('0' <= c && c <= '9'):
		return r.number()
	}
	for _, w := range []struct {
		word string
		v    value
	}{{"true", value{kind: jBool, b: true}}, {"false", value{kind: jBool}}, {"null", value{kind: jNull}}} {
		if strings.HasPrefix(string(r.s[r.i:min(r.i+len(w.word), len(r.s))]), w.word) {
			r.i += len(w.word)
			return w.v, nil
		}
	}
	return value{}, r.fault("no value")
}

func (r *reader) enter() error {
	r.depth++
	if r.depth > deepest {
		return r.fault(fmt.Sprintf("arrays and objects more than %d deep", deepest))
	}
	return nil
}

func (r *reader) object() (value, error) {
	if err := r.enter(); err != nil {
		return value{}, err
	}
	defer func() { r.depth-- }()
	r.i++ // {
	v := value{kind: jObject}
	var seen map[string]bool
	r.space()
	if r.i < len(r.s) && r.s[r.i] == '}' {
		r.i++
		return v, nil
	}
	for {
		r.space()
		if r.i >= len(r.s) || r.s[r.i] != '"' {
			return value{}, r.fault("no name")
		}
		name, err := r.string()
		if err != nil {
			return value{}, err
		}
		// a name twice in one object: refused, as no form keeps one of the two
		if len(v.names) >= 8 && seen == nil {
			seen = make(map[string]bool, 16)
			for _, n := range v.names {
				seen[n] = true
			}
		}
		if (seen != nil && seen[name]) || (seen == nil && slices.Contains(v.names, name)) {
			return value{}, fmt.Errorf("%q: a name twice in one object", name)
		}
		if seen != nil {
			seen[name] = true
		}
		r.space()
		if r.i >= len(r.s) || r.s[r.i] != ':' {
			return value{}, r.fault("no : after a name")
		}
		r.i++
		x, err := r.value()
		if err != nil {
			return value{}, err
		}
		v.names, v.items = append(v.names, name), append(v.items, x)
		r.space()
		if r.i >= len(r.s) {
			return value{}, r.fault("an object not closed")
		}
		r.i++
		switch r.s[r.i-1] {
		case '}':
			return v, nil
		case ',':
		default:
			return value{}, r.fault("no , or } after a value")
		}
	}
}

func (r *reader) array() (value, error) {
	if err := r.enter(); err != nil {
		return value{}, err
	}
	defer func() { r.depth-- }()
	r.i++ // [
	v := value{kind: jArray}
	r.space()
	if r.i < len(r.s) && r.s[r.i] == ']' {
		r.i++
		return v, nil
	}
	for {
		x, err := r.value()
		if err != nil {
			return value{}, err
		}
		v.items = append(v.items, x)
		r.space()
		if r.i >= len(r.s) {
			return value{}, r.fault("an array not closed")
		}
		r.i++
		switch r.s[r.i-1] {
		case ']':
			return v, nil
		case ',':
		default:
			return value{}, r.fault("no , or ] after a value")
		}
	}
}

// string: a JSON string's characters, its escapes read; a character below U+0020, an escape JSON does not have, and
// half of a character escaped as UTF-16 refused
func (r *reader) string() (string, error) {
	r.i++ // "
	start := r.i
	for r.i < len(r.s) && r.s[r.i] != '"' && r.s[r.i] != '\\' && r.s[r.i] >= 0x20 {
		r.i++
	}
	if r.i < len(r.s) && r.s[r.i] == '"' {
		r.i++
		return string(r.s[start : r.i-1]), nil
	}
	b := []byte(string(r.s[start:r.i]))
	for {
		if r.i >= len(r.s) {
			return "", r.fault("a text not closed")
		}
		c := r.s[r.i]
		switch {
		case c == '"':
			r.i++
			return string(b), nil
		case c < 0x20:
			return "", r.fault("a control character in a text")
		case c != '\\':
			b = append(b, c)
			r.i++
			continue
		}
		if r.i+1 >= len(r.s) {
			return "", r.fault("a text not closed")
		}
		e := r.s[r.i+1]
		r.i += 2
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
			c1, ok := r.hex4()
			if !ok {
				return "", r.fault("an escape \\u not of four hex digits")
			}
			if utf16.IsSurrogate(c1) {
				c2 := rune(-1)
				if r.i+1 < len(r.s) && r.s[r.i] == '\\' && r.s[r.i+1] == 'u' {
					r.i += 2
					c2, ok = r.hex4()
					if !ok {
						return "", r.fault("an escape \\u not of four hex digits")
					}
				}
				c1 = utf16.DecodeRune(c1, c2)
				if c1 == utf8.RuneError {
					return "", r.fault("half of a character escaped")
				}
			}
			b = utf8.AppendRune(b, c1)
		default:
			return "", r.fault("an escape JSON does not have")
		}
	}
}

func (r *reader) hex4() (rune, bool) {
	if r.i+4 > len(r.s) {
		return 0, false
	}
	n, err := strconv.ParseUint(string(r.s[r.i:r.i+4]), 16, 32)
	if err != nil {
		return 0, false
	}
	r.i += 4
	return rune(n), true
}

// number: a JSON number, refused unless written as the contract writes a number (SPEC.md, The JSON): in digits, no
// exponent; a whole number of at most 16 digits, or a decimal of at most 6 digits after the point and 15 from the
// first that is not 0, the last not 0. Its kind and bound are its field's (whole, ParseDecimal).
func (r *reader) number() (value, error) {
	start := r.i
	for r.i < len(r.s) && strings.IndexByte("-+.eE0123456789", r.s[r.i]) >= 0 {
		r.i++
	}
	t := string(r.s[start:r.i])
	_, w, f, ok := digits(t)
	if !ok || (f == "" && len(w) > 16) || (f != "" && (len(f) > decimalFraction || significant(w, f) > decimalDigits)) {
		return value{}, fmt.Errorf("%s: a number in digits, a whole number of at most 16, a decimal of at most 6 after the point and 15 in all", t)
	}
	return value{kind: jNumber, text: t}, nil
}

// Bound: the largest whole number of the contract, either way (SPEC.md, Units): 2⁵³ − 1, which every JSON reader holds
// exactly. A time, a position, a bar and a count are whole numbers from 0 to Bound.
const Bound = 1<<53 - 1

// whole: a whole number from 0 to Bound, as a time, a position, a bar and a count are (-0 is 0)
func whole(v *value) (uint64, error) {
	if v.kind != jNumber {
		return 0, fmt.Errorf("a whole number, not %s", v.kind)
	}
	neg, w, f, _ := digits(v.text)
	if f != "" {
		return 0, fmt.Errorf("%s: a whole number, not a fraction", v.text)
	}
	n, err := strconv.ParseUint(w, 10, 64)
	if err != nil || n > Bound {
		return 0, fmt.Errorf("%s: a number past %d", v.text, uint64(Bound))
	}
	if neg && n != 0 {
		return 0, fmt.Errorf("%s: a whole number not negative", v.text)
	}
	return n, nil
}

// A record's fields, by their tags: in the order of the type, and in the order of their names (ASCII), the canonical
// text's
type field struct {
	name     string
	index    int
	optional bool
}

type fields struct {
	list   []field
	sorted []field
	byName map[string]int
}

var fieldsCache sync.Map // reflect.Type → *fields

func fieldsOf(t reflect.Type) *fields {
	if f, ok := fieldsCache.Load(t); ok {
		return f.(*fields)
	}
	fs := &fields{byName: map[string]int{}}
	for i := range t.NumField() {
		sf := t.Field(i)
		name, ok := sf.Tag.Lookup("chanlun")
		if !ok {
			continue
		}
		_, opt := reflect.Zero(sf.Type).Interface().(optional)
		fs.byName[name] = len(fs.list)
		fs.list = append(fs.list, field{name: name, index: i, optional: opt})
	}
	fs.sorted = slices.Clone(fs.list)
	slices.SortFunc(fs.sorted, func(a, b field) int { return strings.Compare(a.name, b.name) })
	f, _ := fieldsCache.LoadOrStore(t, fs)
	return f.(*fields)
}

// What List and Optional give the JSON: List reads and writes its items, Optional its value
type fromJSON interface {
	fromJSON(v *value, at string) error
}

type optional interface {
	jsonValue() (reflect.Value, bool)
}

type list interface {
	jsonItems() []reflect.Value
}

func (l *List[T]) fromJSON(v *value, at string) error {
	if v.kind != jArray {
		return fmt.Errorf("%s: an array, not %s", place(at), v.kind)
	}
	items := make([]T, len(v.items))
	for i := range v.items {
		if err := decode(reflect.ValueOf(&items[i]).Elem(), &v.items[i], join(at, strconv.Itoa(i))); err != nil {
			return err
		}
	}
	l.items = items
	return nil
}

func (l List[T]) jsonItems() []reflect.Value {
	vs := make([]reflect.Value, len(l.items))
	for i := range l.items {
		vs[i] = reflect.ValueOf(l.items[i])
	}
	return vs
}

func (o *Optional[T]) fromJSON(v *value, at string) error {
	var x T
	if err := decode(reflect.ValueOf(&x).Elem(), v, at); err != nil {
		return err
	}
	*o = Some(x)
	return nil
}

func (o Optional[T]) jsonValue() (reflect.Value, bool) { return reflect.ValueOf(o.value), o.set }

var decimalType = reflect.TypeFor[Decimal]()

// A place in the JSON as the TypeScript form names it: the names and places from the top, joined by ., klines.5.date;
// the top itself "the JSON"
func join(at, name string) string {
	if at == "" {
		return name
	}
	return at + "." + name
}

func place(at string) string {
	if at == "" {
		return "the JSON"
	}
	return at
}

// decode: the value v read into dst, of a record's type or of one of its fields' types, at the place `at`
func decode(dst reflect.Value, v *value, at string) error {
	if v.kind == jNull {
		return fmt.Errorf("%s: null, where a field not set is left out", place(at))
	}
	if d, ok := dst.Addr().Interface().(fromJSON); ok {
		return d.fromJSON(v, at)
	}
	switch t := dst.Type(); {
	case t == decimalType:
		if v.kind != jNumber {
			return fmt.Errorf("%s: a decimal, not %s", place(at), v.kind)
		}
		d, err := ParseDecimal(v.text)
		if err != nil {
			return fmt.Errorf("%s: %s: %w", place(at), v.text, err)
		}
		dst.Set(reflect.ValueOf(d))
	case t.Kind() == reflect.Uint64:
		n, err := whole(v)
		if err != nil {
			return fmt.Errorf("%s: %w", place(at), err)
		}
		dst.SetUint(n)
	case t.Kind() == reflect.Bool:
		if v.kind != jBool {
			return fmt.Errorf("%s: a boolean, not %s", place(at), v.kind)
		}
		dst.SetBool(v.b)
	case t.Kind() == reflect.Struct:
		return decodeRecord(dst, v, at)
	default:
		return fmt.Errorf("%s: a field of a type the JSON does not read (%s)", place(at), t)
	}
	return nil
}

// decodeRecord: an object read into a record: exactly its fields, none other, none missing but an optional one
func decodeRecord(dst reflect.Value, v *value, at string) error {
	if v.kind != jObject {
		return fmt.Errorf("%s: an object, not %s", place(at), v.kind)
	}
	fs := fieldsOf(dst.Type())
	got := make([]bool, len(fs.list))
	for k, name := range v.names {
		i, ok := fs.byName[name]
		if !ok {
			return fmt.Errorf("%s: %q is no field of it", place(at), name)
		}
		got[i] = true
		if err := decode(dst.Field(fs.list[i].index), &v.items[k], join(at, name)); err != nil {
			return err
		}
	}
	for i, f := range fs.list {
		if !got[i] && !f.optional {
			return fmt.Errorf("%s: a field missing", join(at, f.name))
		}
	}
	return nil
}

// writeRecord: a record as the canonical text writes it (SPEC.md, The JSON): its fields in the order of their names,
// a field not set left out, no spaces
func writeRecord(b *strings.Builder, v reflect.Value) {
	fs := fieldsOf(v.Type())
	b.WriteByte('{')
	first := true
	for _, f := range fs.sorted {
		x := v.Field(f.index)
		if o, ok := x.Interface().(optional); ok {
			inner, set := o.jsonValue()
			if !set {
				continue
			}
			x = inner
		}
		if !first {
			b.WriteByte(',')
		}
		first = false
		b.WriteString(strconv.Quote(f.name))
		b.WriteByte(':')
		writeValue(b, x)
	}
	b.WriteByte('}')
}

// writeValue: a field's value: a number in its digits, a boolean true or false, an array of numbers [, its numbers
// separated by ,, ]
func writeValue(b *strings.Builder, x reflect.Value) {
	if l, ok := x.Interface().(list); ok {
		b.WriteByte('[')
		for i, item := range l.jsonItems() {
			if i > 0 {
				b.WriteByte(',')
			}
			writeValue(b, item)
		}
		b.WriteByte(']')
		return
	}
	switch t := x.Type(); {
	case t == decimalType:
		b.WriteString(x.Interface().(Decimal).String())
	case t.Kind() == reflect.Uint64:
		b.WriteString(strconv.FormatUint(x.Uint(), 10))
	case t.Kind() == reflect.Bool:
		b.WriteString(strconv.FormatBool(x.Bool()))
	case t.Kind() == reflect.Struct:
		writeRecord(b, x)
	}
}
