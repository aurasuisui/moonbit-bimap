// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Additional public API: non-overwriting insert, positional (index) access,
// construction / conversion helpers, snapshot collection views, and the
// original entry-style helpers. All mutations still funnel through the
// invariant chokepoints in bimap.mbt (put_pair / remove_by_* / retain) —
// in particular get_or_insert_left/right go through the public `insert`.

// ---------------------------------------------------------------------------
// Non-overwriting insert
// ---------------------------------------------------------------------------

///|
/// Insert `(l, r)` only if NEITHER side is already present. If the left key or
/// the right value already exists, the map is left unchanged and the attempted
/// pair is returned in `Err((l, r))`; otherwise the pair is inserted and
/// `Ok(())` is returned. Aligns with Rust `bimap::insert_no_overwrite`.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::insert_no_overwrite(
  self : BiMap[L, R],
  l : L,
  r : R,
) -> Result[Unit, (L, R)] {
  // Both conflict checks happen BEFORE any mutation.
  if self.forward.contains(l) || self.backward.contains(r) {
    Err((l, r))
  } else {
    self.put_pair(l, r) |> ignore
    Ok(())
  }
}

// ---------------------------------------------------------------------------
// Positional (index) access — the ordering dividend
// ---------------------------------------------------------------------------

///|
/// Return the pair at insertion-order index `i`, or `None` if `i` is out of
/// bounds.
pub fn[L : Hash + Eq, R] BiMap::get_index(
  self : BiMap[L, R],
  i : Int,
) -> (L, R)? {
  if i < 0 || i >= self.order.length() {
    return None
  }
  let l = self.order[i]
  match self.forward.get(l) {
    Some(r) => Some((l, r))
    None => None
  }
}

///|
/// Return the insertion-order index of left key `l`, or `None` if absent.
pub fn[L : Hash + Eq, R] BiMap::get_index_of_left(
  self : BiMap[L, R],
  l : L,
) -> Int? {
  self.positions.get(l)
}

///|
/// Return the insertion-order index of the pair whose right value is `r`, or
/// `None` if absent. This is a convenience for
/// `get_index_of_left(get_by_right(r))`: the order array only stores left keys,
/// so a right value's index is the index of the left key it is paired with.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::get_index_of_right(
  self : BiMap[L, R],
  r : R,
) -> Int? {
  match self.backward.get(r) {
    Some(l) => self.positions.get(l)
    None => None
  }
}

///|
/// Return the earliest-inserted pair, or `None` if the map is empty.
pub fn[L : Hash + Eq, R] BiMap::first(self : BiMap[L, R]) -> (L, R)? {
  self.get_index(0)
}

///|
/// Return the most-recently-inserted pair, or `None` if the map is empty.
pub fn[L : Hash + Eq, R] BiMap::last(self : BiMap[L, R]) -> (L, R)? {
  if self.order.length() == 0 {
    return None
  }
  self.get_index(self.order.length() - 1)
}

// ---------------------------------------------------------------------------
// Construction / conversion
// ---------------------------------------------------------------------------

///|
/// Build a `BiMap` from an array of pairs. Pairs are inserted in order through
/// `insert`, so on a conflict the LATER pair wins (aligning with Rust
/// `FromIterator`). For example `from_array([("a",1), ("a",2)])` yields
/// `{ "a" <-> 2 }`.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::from_array(
  pairs : Array[(L, R)],
) -> BiMap[L, R] {
  let m = BiMap::with_capacity(pairs.length())
  let mut i = 0
  while i < pairs.length() {
    let (l, r) = pairs[i]
    m.insert(l, r) |> ignore
    i = i + 1
  }
  m
}

///|
/// Return an independent deep copy. Mutating the copy does not affect the
/// original (and vice versa). Insertion order is preserved.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::copy(
  self : BiMap[L, R],
) -> BiMap[L, R] {
  let result = BiMap::with_capacity(self.order.length())
  let mut i = 0
  while i < self.order.length() {
    let l = self.order[i]
    match self.forward.get(l) {
      Some(r) => result.insert(l, r) |> ignore
      None => ()
    }
    i = i + 1
  }
  result
}

///|
/// Return an independent copy with the two sides swapped: a `BiMap[R, L]`
/// whose left keys are this map's right values (in the same pair order). This
/// is a COPY, not a live view — mutating it does not affect the original.
/// (This differs from Guava's live `inverse()` and matches Rust bimap's
/// method-based reverse access.)
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::to_inverse(
  self : BiMap[L, R],
) -> BiMap[R, L] {
  let result : BiMap[R, L] = BiMap::with_capacity(self.order.length())
  let mut i = 0
  while i < self.order.length() {
    let l = self.order[i]
    match self.forward.get(l) {
      Some(r) => result.insert(r, l) |> ignore
      None => ()
    }
    i = i + 1
  }
  result
}

// ---------------------------------------------------------------------------
// Collection snapshot views (original extension)
// ---------------------------------------------------------------------------

///|
/// Return a snapshot of the left keys as an array, in insertion order. This
/// is an independent COPY: mutating the returned array does not affect the
/// map.
///
/// **Zero trait bounds** — this is the whole point vs `lefts()`: usable from
/// generic code that holds a `BiMap[L, R]` without any `Hash`/`Eq` on either
/// side (see SPEC §6).
pub fn[L, R] BiMap::left_keys(self : BiMap[L, R]) -> Array[L] {
  self.order.copy()
}

///|
/// Return a snapshot of the right values as an array, in the insertion order
/// of their left keys. This is an independent COPY: mutating the returned
/// array does not affect the map.
///
/// Reading a right value requires resolving its left key in the forward
/// table, hence `L : Hash + Eq`; `R` itself is unconstrained.
///
/// (Rust bimap's same-named `right_values()` is a lazy iterator in hash-table
/// order; this is an insertion-ordered eager snapshot — see SPEC §6.6.)
pub fn[L : Hash + Eq, R] BiMap::right_values(self : BiMap[L, R]) -> Array[R] {
  let result : Array[R] = []
  let mut i = 0
  while i < self.order.length() {
    let l = self.order[i]
    match self.forward.get(l) {
      Some(r) => result.push(r)
      None => ()
    }
    i = i + 1
  }
  result
}

// ---------------------------------------------------------------------------
// Entry-style helpers (original extension — NOT in Rust bimap v0.6.3)
// ---------------------------------------------------------------------------

///|
/// Return the right value currently bound to left key `l`; if `l` is absent,
/// insert the pair `(l, r)` and return `r`.
///
/// **Original extension**: verified absent from bimap-rs 0.6.3 — unlike
/// `retain` this is NOT a port, so there is no differential oracle and the
/// semantics are pinned by tests (SPEC §6).
///
/// Surprise surface: when the insert path runs (`l` absent), full `insert`
/// semantics apply — after the call `l ↔ r` is guaranteed to hold, but if `r`
/// was already bound to another left key, that pair is evicted by a C3
/// takeover (this is NOT "insert only when both sides are free"). When `l` is
/// present the map is NOT mutated (no version bump; active iterators stay
/// valid) and its current right value is returned.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::get_or_insert_left(
  self : BiMap[L, R],
  l : L,
  r : R,
) -> R {
  match self.forward.get(l) {
    Some(r0) => r0
    None => {
      self.insert(l, r) |> ignore
      r
    }
  }
}

///|
/// Return the left key currently bound to right value `r`; if `r` is absent,
/// insert the pair `(l, r)` and return `l`.
///
/// **Original extension**: verified absent from bimap-rs 0.6.3 — unlike
/// `retain` this is NOT a port, so there is no differential oracle and the
/// semantics are pinned by tests (SPEC §6).
///
/// Surprise surface: when the insert path runs (`r` absent), full `insert`
/// semantics apply — after the call `l ↔ r` is guaranteed to hold, but if `l`
/// was already bound to another right value, that pair is evicted by a C2
/// rebind (this is NOT "insert only when both sides are free"). When `r` is
/// present the map is NOT mutated (no version bump; active iterators stay
/// valid) and its current left key is returned.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::get_or_insert_right(
  self : BiMap[L, R],
  r : R,
  l : L,
) -> L {
  match self.backward.get(r) {
    Some(l0) => l0
    None => {
      self.insert(l, r) |> ignore
      l
    }
  }
}
