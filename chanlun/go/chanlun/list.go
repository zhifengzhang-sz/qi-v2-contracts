package chanlun

import (
	"iter"
	"slices"
)

// List: a list of records, of levels or of numbers, kept behind methods, so that no holder can change it: a List given
// to many holders is the one list for each of them. ListOf copies its items in and Slice copies them out; At, All and
// Values give the items as values. Its items are values too (a record, a Decimal, a number, or a List itself), so
// nothing reached through a List changes it. The zero List is empty.
type List[T any] struct {
	items []T
}

// ListOf: a list of the items, copied in: changing the slice after changes nothing in the list.
func ListOf[T any](items ...T) List[T] {
	return List[T]{items: slices.Clone(items)}
}

// Len: the number of items.
func (l List[T]) Len() int { return len(l.items) }

// At: the item at i, from 0; out of range it panics, as a slice's index does.
func (l List[T]) At(i int) T { return l.items[i] }

// Last: the last item, and false if the list is empty.
func (l List[T]) Last() (T, bool) {
	if len(l.items) == 0 {
		var zero T
		return zero, false
	}
	return l.items[len(l.items)-1], true
}

// All: each item with its place, in order.
func (l List[T]) All() iter.Seq2[int, T] {
	return func(yield func(int, T) bool) {
		for i, x := range l.items {
			if !yield(i, x) {
				return
			}
		}
	}
}

// Values: each item, in order.
func (l List[T]) Values() iter.Seq[T] {
	return func(yield func(T) bool) {
		for _, x := range l.items {
			if !yield(x) {
				return
			}
		}
	}
}

// Slice: the items, copied out: changing the slice changes nothing in the list.
func (l List[T]) Slice() []T { return slices.Clone(l.items) }

// Optional: a field that may be not set (SPEC.md, marked ?), a value with no pointer: not set it is left out of the
// JSON, never null. The zero Optional is not set.
type Optional[T any] struct {
	value T
	set   bool
}

// Some: an Optional set to v.
func Some[T any](v T) Optional[T] { return Optional[T]{value: v, set: true} }

// None: an Optional not set, the zero Optional.
func None[T any]() Optional[T] { return Optional[T]{} }

// Get: the value, and whether it is set.
func (o Optional[T]) Get() (T, bool) { return o.value, o.set }

// IsSet: whether it is set.
func (o Optional[T]) IsSet() bool { return o.set }
