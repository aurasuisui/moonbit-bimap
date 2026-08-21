// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// BiMap core: two hash tables (forward L->R and backward R->L) plus a single
// insertion-order array and position map for the left keys.
//
// Invariant chokepoints: EVERY mutation funnels through `put_pair` (insert
// path), `remove_by_left` / `remove_by_right` (single-pair removal path), or
// `retain` (bulk removal path: per-pair table removal + in-place order
// compaction). These are the only places that touch forward + backward +
// order + positions together, so the bijection invariant ("two tables are
// mutual inverses, five counts agree") is maintained in exactly one place
// per operation kind.

///|
/// A bidirectional map maintaining a one-to-one correspondence (a bijection)
/// between left keys of type `L` and right values of type `R`.
///
/// Both sides are unique: inserting a pair whose left OR right already exists
/// displaces the conflicting pair(s). Lookups work in both directions
/// (`get_by_left` / `get_by_right`), and the insertion order of left keys is
/// preserved and indexable (`get_index`, `get_index_of_left`, `first`, `last`).
struct BiMap[L, R] {
  forward : HashTab[L, R]
  backward : HashTab[R, L]
  order : Array[L]
  positions : Map[L, Int]
  mut len : Int
  mut version : Int
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

///|
/// Create a new, empty `BiMap` with default capacity.
pub fn[L : Hash + Eq, R] BiMap::new() -> BiMap[L, R] {
  BiMap::with_capacity(MIN_CAPACITY)
}

///|
/// Create a new, empty `BiMap` with capacity for at least `cap` pairs.
pub fn[L : Hash + Eq, R] BiMap::with_capacity(cap : Int) -> BiMap[L, R] {
  let real_cap = if cap < MIN_CAPACITY {
    MIN_CAPACITY
  } else {
    next_power_of_two_impl(cap)
  }
  {
    forward: HashTab::with_capacity(real_cap),
    backward: HashTab::with_capacity(real_cap),
    order: [],
    positions: Map([], capacity=real_cap),
    len: 0,
    version: 0,
  }
}

// ---------------------------------------------------------------------------
// Private: order maintenance
// ---------------------------------------------------------------------------

///|
/// Append left key `l` to the insertion order and record its position.
fn[L : Hash + Eq, R] BiMap::order_push(self : BiMap[L, R], l : L) -> Unit {
  self.order.push(l)
  self.positions[l] = self.order.length() - 1
}

///|
/// Shift-remove left key `l` from the insertion order, fixing the positions of
/// all later keys (O(n)). No-op if `l` is not present.
fn[L : Hash + Eq, R] BiMap::order_remove(self : BiMap[L, R], l : L) -> Unit {
  match self.positions.get(l) {
    None => ()
    Some(pos) => {
      let mut i = pos
      let last_idx = self.order.length() - 1
      while i < last_idx {
        let next = self.order[i + 1]
        self.order[i] = next
        self.positions[next] = i
        i = i + 1
      }
      self.order.pop() |> ignore
      self.positions.remove(l) |> ignore
    }
  }
}

// ---------------------------------------------------------------------------
// Private: the single insert chokepoint
// ---------------------------------------------------------------------------

///|
/// Insert the pair `(l, r)`, displacing conflicting pairs, and return the
/// displaced `(old_right?, old_left?)`. Handles cases C0/C2/C3/C4; the caller
/// (`insert`) short-circuits the exact-reinsert case C1 before reaching here.
///
/// This is the ONLY function that mutates forward + backward + order +
/// positions on the insert path, which keeps the bijection invariant local.
fn[L : Hash + Eq, R : Hash + Eq] BiMap::put_pair(
  self : BiMap[L, R],
  l : L,
  r : R,
) -> (R?, L?) {
  let old_r = self.forward.get(l)
  let old_l = self.backward.get(r)
  self.version = self.version + 1
  match (old_r, old_l) {
    (None, None) => {
      // C0: fresh pair.
      self.forward.insert(l, r) |> ignore
      self.backward.insert(r, l) |> ignore
      self.order_push(l)
      self.len = self.len + 1
      (None, None)
    }
    (Some(r0), None) => {
      // C2: l rebinds from r0 to r; r0 loses its left key. l keeps its order
      // position (rebinding does not change insertion order).
      self.backward.remove(r0) |> ignore
      self.forward.insert(l, r) |> ignore
      self.backward.insert(r, l) |> ignore
      (Some(r0), None)
    }
    (None, Some(l0)) => {
      // C3: r was bound to l0; l takes it over. l0 is removed entirely and l
      // enters at the end of the order. Net length unchanged.
      self.forward.remove(l0) |> ignore
      self.backward.remove(r) |> ignore
      self.order_remove(l0)
      self.forward.insert(l, r) |> ignore
      self.backward.insert(r, l) |> ignore
      self.order_push(l)
      (None, Some(l0))
    }
    (Some(r0), Some(l0)) => {
      // C4: both (l, r0) and (l0, r) exist and collapse into the single pair
      // (l, r). Here l != l0 and r != r0 (C1 is short-circuited by the caller).
      // l keeps its order position; l0 is removed. Net length decreases by 1.
      self.forward.remove(l0) |> ignore
      self.backward.remove(r0) |> ignore
      self.order_remove(l0)
      self.forward.insert(l, r) |> ignore
      self.backward.insert(r, l) |> ignore
      self.len = self.len - 1
      (Some(r0), Some(l0))
    }
  }
}

// ---------------------------------------------------------------------------
// Insertion
// ---------------------------------------------------------------------------

///|
/// Insert the pair `(l, r)`, displacing any conflicting pair(s), and report
/// what was overwritten via the returned `Overwritten` value.
///
/// Cases:
/// - **C0** neither side present → `Neither`, length +1.
/// - **C1** the exact pair already present → `Pair(l, r)`, no change (idempotent).
/// - **C2** `l` already bound to another right → `Left(l, old_r)`, length unchanged.
/// - **C3** `r` already bound to another left → `Right(old_l, r)`, length unchanged.
/// - **C4** both sides conflict → `Both((l, old_r), (old_l, r))`, length **−1**
///   (the two old pairs collapse into one).
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::insert(
  self : BiMap[L, R],
  l : L,
  r : R,
) -> Overwritten[L, R] {
  // C1 short-circuit: the exact pair already exists → idempotent, no change.
  // This must be checked before put_pair, otherwise (Some(r), Some(l)) would
  // be mis-handled as a C4 collapse.
  match self.forward.get(l) {
    Some(r0) =>
      if r0 == r {
        Overwritten::Pair(l, r)
      } else {
        self.finish_insert(l, r)
      }
    None => self.finish_insert(l, r)
  }
}

///|
/// Run `put_pair` and map the displaced pair(s) onto the `Overwritten` enum.
fn[L : Hash + Eq, R : Hash + Eq] BiMap::finish_insert(
  self : BiMap[L, R],
  l : L,
  r : R,
) -> Overwritten[L, R] {
  let (old_r, old_l) = self.put_pair(l, r)
  match (old_r, old_l) {
    (None, None) => Overwritten::Neither
    (Some(r0), None) => Overwritten::Left(l, r0)
    (None, Some(l0)) => Overwritten::Right(l0, r)
    (Some(r0), Some(l0)) => Overwritten::Both((l, r0), (l0, r))
  }
}

// ---------------------------------------------------------------------------
// Bidirectional lookup
// ---------------------------------------------------------------------------

///|
/// Return the right value bound to left key `l` (forward lookup).
pub fn[L : Hash + Eq, R] BiMap::get_by_left(self : BiMap[L, R], l : L) -> R? {
  self.forward.get(l)
}

///|
/// Return the left key bound to right value `r` (reverse lookup).
pub fn[L, R : Hash + Eq] BiMap::get_by_right(self : BiMap[L, R], r : R) -> L? {
  self.backward.get(r)
}

///|
/// Return `true` if left key `l` is present.
pub fn[L : Hash + Eq, R] BiMap::contains_left(
  self : BiMap[L, R],
  l : L,
) -> Bool {
  self.forward.contains(l)
}

///|
/// Return `true` if right value `r` is present.
pub fn[L, R : Hash + Eq] BiMap::contains_right(
  self : BiMap[L, R],
  r : R,
) -> Bool {
  self.backward.contains(r)
}

// ---------------------------------------------------------------------------
// Removal (the removal chokepoints)
// ---------------------------------------------------------------------------

///|
/// Remove the pair keyed by left key `l`, returning its right value if present.
/// Cleans up both tables and the order/position bookkeeping.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::remove_by_left(
  self : BiMap[L, R],
  l : L,
) -> R? {
  match self.forward.get(l) {
    None => None
    Some(r) => {
      self.forward.remove(l) |> ignore
      self.backward.remove(r) |> ignore
      self.order_remove(l)
      self.len = self.len - 1
      self.version = self.version + 1
      Some(r)
    }
  }
}

///|
/// Remove the pair keyed by right value `r`, returning its left key if present.
/// Cleans up both tables and the order/position bookkeeping.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::remove_by_right(
  self : BiMap[L, R],
  r : R,
) -> L? {
  match self.backward.get(r) {
    None => None
    Some(l) => {
      self.backward.remove(r) |> ignore
      self.forward.remove(l) |> ignore
      self.order_remove(l)
      self.len = self.len - 1
      self.version = self.version + 1
      Some(l)
    }
  }
}

// ---------------------------------------------------------------------------
// Bulk removal (the third mutation chokepoint)
// ---------------------------------------------------------------------------

///|
/// Keep only the pairs satisfying `f`, removing the rest (a port of Rust
/// `bimap`'s `retain`, which exists on both of its map types). The predicate
/// is evaluated exactly once per pair, in insertion order, on a snapshot; the
/// kept pairs preserve their relative insertion order. If nothing is removed
/// this is a no-op and the version is NOT bumped (active iterators stay
/// valid). The predicate must not mutate the map.
///
/// Mutation chokepoint #3 (bulk removal): per-pair removal from
/// forward/backward/positions followed by an in-place compaction of `order`
/// (which fixes the `positions` indices as it goes) — O(n) overall, avoiding
/// the O(n²) cost of head-first per-element removal (README Gotcha #9).
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::retain(
  self : BiMap[L, R],
  f : (L, R) -> Bool,
) -> Unit {
  // Pass 1: snapshot + collect removed left keys; predicate runs once per pair.
  let arr = self.into_array()
  let removed : Array[L] = []
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    if !f(l, r) {
      removed.push(l)
    }
    i = i + 1
  }
  if removed.is_empty() {
    return
  }
  // Pass 2: remove each pair from both tables and the position map.
  let mut k = 0
  while k < removed.length() {
    let l = removed[k]
    match self.forward.remove(l) {
      Some(r) => {
        self.backward.remove(r) |> ignore
        self.positions.remove(l) |> ignore
      }
      None => ()
    }
    k = k + 1
  }
  // Pass 3: compact `order` in place; `positions` now holds exactly the kept
  // keys, so membership decides survival and indices are fixed on the fly.
  let mut w = 0
  let mut j = 0
  while j < self.order.length() {
    let l = self.order[j]
    if self.positions.get(l) is Some(_) {
      self.order[w] = l
      self.positions[l] = w
      w = w + 1
    }
    j = j + 1
  }
  while self.order.length() > w {
    self.order.pop() |> ignore
  }
  self.len = self.len - removed.length()
  self.version = self.version + 1
}

// ---------------------------------------------------------------------------
// Size queries
// ---------------------------------------------------------------------------

///|
/// Return the number of pairs in the map.
pub fn[L, R] BiMap::len(self : BiMap[L, R]) -> Int {
  self.len
}

///|
/// Return `true` if the map contains no pairs.
pub fn[L, R] BiMap::is_empty(self : BiMap[L, R]) -> Bool {
  self.len == 0
}

///|
/// Return the current bucket capacity of the underlying forward table.
pub fn[L, R] BiMap::capacity(self : BiMap[L, R]) -> Int {
  self.forward.capacity()
}

// ---------------------------------------------------------------------------
// Snapshot
// ---------------------------------------------------------------------------

///|
/// Return all pairs as an array in left-key insertion order.
pub fn[L : Hash + Eq, R] BiMap::into_array(self : BiMap[L, R]) -> Array[(L, R)] {
  let result : Array[(L, R)] = []
  let mut i = 0
  while i < self.order.length() {
    let l = self.order[i]
    match self.forward.get(l) {
      Some(r) => result.push((l, r))
      None => ()
    }
    i = i + 1
  }
  result
}
