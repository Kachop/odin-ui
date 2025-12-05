package rwb

import "base:runtime"

/*
Functionality for an allocatrd version of Small_Array
Functionality for working with an allocated fixed size slice
*/

Dynamic_Slice :: struct($T: typeid) {
	data:      []T,
	len:       int,
	allocator: runtime.Allocator,
}

make_dynamic_slice :: proc(
	$T: typeid,
	cap: int,
	allocator := context.allocator,
) -> Dynamic_Slice(T) {
	return {make([]T, cap, allocator), 0, allocator}
}

delete_dynamic_slice :: proc(slice: ^$A/Dynamic_Slice) {
	delete(slice.data, slice.allocator)
}

clear_dynamic_slice :: proc(a: ^$A/Dynamic_Slice) {
	a.len = 0
}

dynamic_slice_len :: proc(a: $A/Dynamic_Slice) -> int {
	return a.len
}

cap :: proc(a: $A/Dynamic_Slice) -> int {
	return len(a.data)
}

space :: proc(a: $A/Dynamic_Slice) -> int {
	return len(a.data) - a.len
}

to_slice :: proc(a: ^$A/Dynamic_Slice($T)) -> []T {
	return a.data[:a.len]
}

get :: proc(a: $A/Dynamic_Slice($T), idx: int) -> (val: T, ok: bool) #optional_ok {
	if idx >= 0 && idx <= a.len {
		val = a.data[idx]
		ok = true
		return a.data[idx], true
	}
	return
}

append_dynamic_slice :: proc {
	append_dynamic_slice_back,
	append_dynamic_slice_index,
}

@(private)
append_dynamic_slice_back :: proc(a: ^$A/Dynamic_Slice($T), data: T) -> (ok: bool) {
	if space(a^) > 0 {
		a.data[a.len] = data
		a.len += 1
		ok = true
	}
	return
}

@(private)
append_dynamic_slice_index :: proc(a: ^$A/Dynamic_Slice($T), data: T, index: int) -> (ok: bool) {
	if space(a^) > 0 {
		copy(a.data[index:], a.data[index + 1:])
		a.data[index] = data
		a.len += 1
		ok = true
	}
	return
}

dynamic_slice_unordered_remove :: proc(a: ^$A/Dynamic_Slice, index: int) -> (ok: bool) {
	if a.len > index && index >= 0 {
		a.len -= 1
		a.data[index] = a.data[a.len]
		a.data[a.len] = {}
		ok = true
	}
	return
}

dynamic_slice_ordered_remove :: proc(a: ^$A/Dynamic_Slice, index: int) -> (ok: bool) {
	if a.len > index && index >= 0 {
		copy(a.data[index:], a.data[index + 1:])

		a.len -= 1
		a.data[a.len] = {}
		ok = true
	}
	return
}

dynamic_slice_pop_front :: proc(a: ^$A/Dynamic_Slice($T)) -> (item: T, ok: bool) {
	if a.len > 0 {
		item = a.data[0]
		copy(a.data, a.data[1:])
		a.len -= 1
		ok = true
	}
	return
}

dynamic_slice_pop_back :: proc(a: ^$A/Dynamic_Slice($T)) -> (item: T, ok: bool) {
	if a.len > 0 {
		item = a.data[a.len - 1]
		a.len -= 1
		ok = true
	}
	return
}

dynamic_slice_copy :: proc(to: ^$A/Dynamic_Slice, from: ^A) {
	copy(to.data, from.data)
	to.len = from.len
}
