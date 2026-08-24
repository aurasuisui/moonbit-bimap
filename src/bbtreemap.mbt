// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// BiBTreeMap: the SORTED bijection. Two core SortedMaps (forward L->R and
// backward R->L, each a balanced BST ordered by its key) plus a length
// counter and a fail-fast mutation counter. There is NO insertion order and
// NO index access: ordering is replaced by the sorted order of the left keys
// (SPEC §11 difference table).
//
// Invariant chokepoints (mirror of BiMap): EVERY mutation funnels through
// `put_pair` (insert path), `remove_by_left` / `remove_by_right`
// (single-pair removal), or `retain` (bulk removal). These are the only
// places that touch forward + backward together, so the bijection invariant
// ("two tables are mutual inverses, the counters agree") is maintained in
// exactly one place per operation kind. `copy` / `to_inverse` construct
// NEW maps and never mutate their source.

///|
/// A bidirectional map (bijection) between left keys of type `L` and right
/// values of type `R`, kept in SORTED order: `iter()` and the snapshot
/// accessors yield pairs ascending by left key, `first()` / `last()`
/// return the smallest / largest left key, and `range(lo, hi)` slices by
/// left key (inclusive both ends). Unlike `BiMap`, there is no insertion
/// order and no index access.
///
/// Both sides stay unique: inserting a pair whose left OR right already
/// exists displaces the conflicting pair(s), exactly like `BiMap` (the same
/// C0–C4 semantics and the same `Overwritten` result enum).
struct BiBTreeMap[L, R] {
  forward : @sorted_map.SortedMap[L, R]
  backward : @sorted_map.SortedMap[R, L]
  mut len : Int
  mut version : Int
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

///|
/// Create a new, empty `BiBTreeMap`. Both `Compare` bounds are needed to
/// construct the two empty SortedMaps.
pub fn[L : Compare, R : Compare] BiBTreeMap::new() -> BiBTreeMap[L, R] {
  {
    forward: @sorted_map.SortedMap([]),
    backward: @sorted_map.SortedMap([]),
    len: 0,
    version: 0,
  }
}

// ---------------------------------------------------------------------------
// Private: the single insert chokepoint
// ---------------------------------------------------------------------------

///|
/// Insert the pair `(l, r)`, displacing conflicting pairs, and return the
/// displaced `(old_right?, old_left?)`. Handles cases C0/C2/C3/C4; the
/// caller (`insert`) short-circuits the exact-reinsert case C1 first.
///
/// This is the ONLY function that mutates forward + backward on the insert
/// path. core SortedMap's `set` returns Unit (no displaced value), so the
/// displaced sides are read via `get` BEFORE any mutation (the plan's
/// "get 预判 + set" pattern).
fn[L : Compare, R : Compare] BiBTreeMap::put_pair(
  self : BiBTreeMap[L, R],
  l : L,
  r : R,
) -> (R?, L?) {
  let old_r = self.forward.get(l)
  let old_l = self.backward.get(r)
  self.version = self.version + 1
  match (old_r, old_l) {
    (None, None) => {
      // C0: fresh pair.
      self.forward.set(l, r)
      self.backward.set(r, l)
      self.len = self.len + 1
      (None, None)
    }
    (Some(r0), None) => {
      // C2: l rebinds from r0 to r; r0 loses its left key.
      self.backward.remove(r0) |> ignore
      self.forward.set(l, r)
      self.backward.set(r, l)
      (Some(r0), None)
    }
    (None, Some(l0)) => {
      // C3: r was bound to l0; l takes it over. l0 is removed entirely.
      self.forward.remove(l0) |> ignore
      self.backward.set(r, l)
      self.forward.set(l, r)
      (None, Some(l0))
    }
    (Some(r0), Some(l0)) => {
      // C4: both (l, r0) and (l0, r) exist and collapse into the single pair
      // (l, r). l != l0 and r != r0 here (C1 is short-circuited by the
      // caller). Net length decreases by 1.
      self.forward.remove(l0) |> ignore
      self.backward.remove(r0) |> ignore
      self.forward.set(l, r)
      self.backward.set(r, l)
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
/// Cases (identical to `BiMap::insert` and to Rust bimap's BiBTreeMap):
/// - **C0** neither side present → `Neither`, length +1.
/// - **C1** the exact pair already present → `Pair(l, r)`, no change (idempotent).
/// - **C2** `l` already bound to another right → `Left(l, old_r)`, length unchanged.
/// - **C3** `r` already bound to another left → `Right(old_l, r)`, length unchanged.
/// - **C4** both sides conflict → `Both((l, old_r), (old_l, r))`, length **−1**
///   (the two old pairs collapse into one).
pub fn[L : Compare, R : Compare] BiBTreeMap::insert(
  self : BiBTreeMap[L, R],
  l : L,
  r : R,
) -> Overwritten[L, R] {
  // C1 short-circuit: the exact pair already exists → idempotent, no change.
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
fn[L : Compare, R : Compare] BiBTreeMap::finish_insert(
  self : BiBTreeMap[L, R],
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

///|
/// Insert `(l, r)` only if NEITHER side is already present. If the left key
/// or the right value already exists, the map is left unchanged and the
/// attempted pair is returned in `Err((l, r))`; otherwise the pair is
/// inserted and `Ok(())` is returned. Aligns with Rust bimap's
/// `BiBTreeMap::insert_no_overwrite`.
pub fn[L : Compare, R : Compare] BiBTreeMap::insert_no_overwrite(
  self : BiBTreeMap[L, R],
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
// Bidirectional lookup
// ---------------------------------------------------------------------------

///|
/// Return the right value bound to left key `l` (forward lookup).
pub fn[L : Compare, R] BiBTreeMap::get_by_left(
  self : BiBTreeMap[L, R],
  l : L,
) -> R? {
  self.forward.get(l)
}

///|
/// Return the left key bound to right value `r` (reverse lookup).
pub fn[L, R : Compare] BiBTreeMap::get_by_right(
  self : BiBTreeMap[L, R],
  r : R,
) -> L? {
  self.backward.get(r)
}

///|
/// Return `true` if left key `l` is present.
pub fn[L : Compare, R] BiBTreeMap::contains_left(
  self : BiBTreeMap[L, R],
  l : L,
) -> Bool {
  self.forward.contains(l)
}

///|
/// Return `true` if right value `r` is present.
pub fn[L, R : Compare] BiBTreeMap::contains_right(
  self : BiBTreeMap[L, R],
  r : R,
) -> Bool {
  self.backward.contains(r)
}

///|
/// Return `true` if the exact pair `(l, r)` is present — the C1 condition
/// `get_by_left(l) == Some(r)`. O(log n): only the forward table is
/// consulted. `R` needs only `Eq` (for the `==`), not `Compare` —
/// `Compare` implies `Eq` but the forward lookup never compares right values.
pub fn[L : Compare, R : Eq] BiBTreeMap::contains_pair(
  self : BiBTreeMap[L, R],
  l : L,
  r : R,
) -> Bool {
  self.forward.get(l) == Some(r)
}

// ---------------------------------------------------------------------------
// Removal (the removal chokepoints)
// ---------------------------------------------------------------------------

///|
/// Remove the pair keyed by left key `l`, returning its right value if
/// present. Cleans up both tables.
pub fn[L : Compare, R : Compare] BiBTreeMap::remove_by_left(
  self : BiBTreeMap[L, R],
  l : L,
) -> R? {
  match self.forward.get(l) {
    None => None
    Some(r) => {
      self.forward.remove(l) |> ignore
      self.backward.remove(r) |> ignore
      self.len = self.len - 1
      self.version = self.version + 1
      Some(r)
    }
  }
}

///|
/// Remove the pair keyed by right value `r`, returning its left key if
/// present. Cleans up both tables.
pub fn[L : Compare, R : Compare] BiBTreeMap::remove_by_right(
  self : BiBTreeMap[L, R],
  r : R,
) -> L? {
  match self.backward.get(r) {
    None => None
    Some(l) => {
      self.backward.remove(r) |> ignore
      self.forward.remove(l) |> ignore
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
/// bimap's `BiBTreeMap::retain`, btree.rs). The predicate is evaluated
/// exactly once per pair, in ascending left-key order, on a snapshot; the
/// kept pairs stay sorted. If nothing is removed this is a no-op and the
/// version is NOT bumped (active iterators stay valid). The predicate must
/// not mutate the map.
///
/// Mutation chokepoint #3 (bulk removal): per-pair removal from the two
/// SortedMaps (each removal is O(log n); no order array to compact here).
pub fn[L : Compare, R : Compare] BiBTreeMap::retain(
  self : BiBTreeMap[L, R],
  f : (L, R) -> Bool,
) -> Unit {
  // Pass 1: snapshot + collect removed pairs; predicate runs once per pair.
  let arr = self.forward.to_array()
  let removed : Array[(L, R)] = []
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    if !f(l, r) {
      removed.push((l, r))
    }
    i = i + 1
  }
  if removed.is_empty() {
    return
  }
  // Pass 2: remove each pair from both tables.
  let mut k = 0
  while k < removed.length() {
    let (l, r) = removed[k]
    self.forward.remove(l) |> ignore
    self.backward.remove(r) |> ignore
    k = k + 1
  }
  self.len = self.len - removed.length()
  self.version = self.version + 1
}

// ---------------------------------------------------------------------------
// Size queries
// ---------------------------------------------------------------------------

///|
/// Return the number of pairs in the map.
pub fn[L, R] BiBTreeMap::len(self : BiBTreeMap[L, R]) -> Int {
  self.len
}

///|
/// Return `true` if the map contains no pairs.
pub fn[L, R] BiBTreeMap::is_empty(self : BiBTreeMap[L, R]) -> Bool {
  self.len == 0
}

// ---------------------------------------------------------------------------
// Sorted dividends: first / last / range
// ---------------------------------------------------------------------------

///|
/// Return the pair with the SMALLEST left key, or `None` if the map is
/// empty. (Unlike `BiMap::first`, which returns the earliest-inserted
/// pair — see SPEC §11.)
pub fn[L, R] BiBTreeMap::first(self : BiBTreeMap[L, R]) -> (L, R)? {
  self.forward.iter().next()
}

///|
/// Return the pair with the LARGEST left key, or `None` if the map is
/// empty. O(n): walks the sorted iterator to its end. (Unlike
/// `BiMap::last`, which returns the most-recently-inserted pair — see
/// SPEC §11.)
pub fn[L, R] BiBTreeMap::last(self : BiBTreeMap[L, R]) -> (L, R)? {
  let mut last : (L, R)? = None
  let inner = self.forward.iter()
  while inner.next() is Some(pair) {
    last = Some(pair)
  }
  last
}

///|
/// Return a lazy fail-fast iterator over the pairs whose left key lies in
/// `[lo, hi]` — **INCLUSIVE on both ends** (the boundary semantics of core
/// `SortedMap::range`, which is the engine this wraps; Rust's
/// `left_range(a..b)` idiom is end-EXCLUSIVE, so ours matches `a..=b` —
/// see SPEC §11). Pairs come in ascending left-key order. Aborts if the map
/// is mutated during iteration.
///
/// The reverse-side analogue (Rust's `right_range`) is deliberately
/// deferred to v0.2.x (recorded in SPEC §11).
pub fn[L : Compare, R] BiBTreeMap::range(
  self : BiBTreeMap[L, R],
  lo : L,
  hi : L,
) -> Iter[(L, R)] {
  let inner = self.forward.range(lo, hi).iter()
  let version = self.version
  Iter::new(fn() {
    if self.version != version {
      abort("BiBTreeMap: map mutated during iteration")
    }
    inner.next()
  })
}

// ---------------------------------------------------------------------------
// Iteration / snapshots
// ---------------------------------------------------------------------------

///|
/// Return a lazy fail-fast iterator over `(left, right)` pairs in ASCENDING
/// left-key order. Aborts if the map is mutated during iteration.
pub fn[L, R] BiBTreeMap::iter(self : BiBTreeMap[L, R]) -> Iter[(L, R)] {
  let inner = self.forward.iter()
  let version = self.version
  Iter::new(
    fn() -> (L, R)? {
      if self.version != version {
        abort("BiBTreeMap: map mutated during iteration")
      }
      inner.next()
    },
    size_hint=self.len,
  )
}

///|
/// Return all pairs as an array in ascending left-key order.
pub fn[L, R] BiBTreeMap::into_array(self : BiBTreeMap[L, R]) -> Array[(L, R)] {
  self.forward.to_array()
}

///|
/// Return a snapshot of the left keys as an array, in ascending order. This
/// is an independent COPY: mutating the returned array does not affect the
/// map. **Zero trait bounds** — the sorted twin of `BiMap::left_keys`.
pub fn[L, R] BiBTreeMap::left_keys(self : BiBTreeMap[L, R]) -> Array[L] {
  let arr = self.forward.to_array()
  let result : Array[L] = []
  let mut i = 0
  while i < arr.length() {
    let (l, _) = arr[i]
    result.push(l)
    i = i + 1
  }
  result
}

///|
/// Return a snapshot of the right values as an array, in the ascending order
/// OF THEIR LEFT KEYS. This is an independent COPY: mutating the returned
/// array does not affect the map. **Zero trait bounds.**
///
/// (Same-name-different-contract vs Rust: bimap's `BiBTreeMap::right_values()`
/// is a lazy iterator ascending by RIGHT value — this is an eager snapshot
/// ascending by left key; see SPEC §11.)
pub fn[L, R] BiBTreeMap::right_values(self : BiBTreeMap[L, R]) -> Array[R] {
  let arr = self.forward.to_array()
  let result : Array[R] = []
  let mut i = 0
  while i < arr.length() {
    let (_, r) = arr[i]
    result.push(r)
    i = i + 1
  }
  result
}

// ---------------------------------------------------------------------------
// Entry-style helpers (original extension — NOT in Rust bimap v0.6.3)
// ---------------------------------------------------------------------------

///|
/// Return the right value currently bound to left key `l`; if `l` is
/// absent, insert the pair `(l, r)` and return `r`. The sorted twin of
/// `BiMap::get_or_insert_left` with identical semantics (see SPEC §6.8):
/// the get path does not mutate (no version bump); the insert path runs full
/// `insert` semantics — a right value already bound to another left key is
/// taken over by a C3 eviction (NOT "insert only when both sides are free").
pub fn[L : Compare, R : Compare] BiBTreeMap::get_or_insert_left(
  self : BiBTreeMap[L, R],
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
/// Return the left key currently bound to right value `r`; if `r` is
/// absent, insert the pair `(l, r)` and return `l`. The sorted twin of
/// `BiMap::get_or_insert_right` with identical semantics (see SPEC §6.8):
/// the get path does not mutate (no version bump); the insert path runs full
/// `insert` semantics — a left key already bound to another right value is
/// rebinding by a C2 eviction (NOT "insert only when both sides are free").
pub fn[L : Compare, R : Compare] BiBTreeMap::get_or_insert_right(
  self : BiBTreeMap[L, R],
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

// ---------------------------------------------------------------------------
// Construction / conversion
// ---------------------------------------------------------------------------

///|
/// Build a `BiBTreeMap` from an array of pairs. Pairs are inserted in order
/// through `insert`, so on a conflict the LATER pair wins (aligning with
/// Rust `FromIterator`). For example `from_array([("a",1), ("a",2)])`
/// yields `{ "a" <-> 2 }`.
pub fn[L : Compare, R : Compare] BiBTreeMap::from_array(
  pairs : Array[(L, R)],
) -> BiBTreeMap[L, R] {
  let m = BiBTreeMap::new()
  let mut i = 0
  while i < pairs.length() {
    let (l, r) = pairs[i]
    m.insert(l, r) |> ignore
    i = i + 1
  }
  m
}

///|
/// Return an independent deep copy (both SortedMaps are copied structurally).
/// Mutating the copy does not affect the original (and vice versa). Zero
/// trait bounds.
pub fn[L, R] BiBTreeMap::copy(self : BiBTreeMap[L, R]) -> BiBTreeMap[L, R] {
  {
    forward: self.forward.copy(),
    backward: self.backward.copy(),
    len: self.len,
    version: 0,
  }
}

///|
/// Return an independent copy with the two sides swapped: a
/// `BiBTreeMap[R, L]` whose left keys are this map's right values. The
/// swap is exact because the two tables are mutual inverses: the new forward
/// table is a copy of this backward table (ordered by old right = new left),
/// and vice versa — so the result is a VALID sorted bijection built without
/// re-insertion. This is a COPY, not a live view. Zero trait bounds.
pub fn[L, R] BiBTreeMap::to_inverse(
  self : BiBTreeMap[L, R],
) -> BiBTreeMap[R, L] {
  {
    forward: self.backward.copy(),
    backward: self.forward.copy(),
    len: self.len,
    version: 0,
  }
}
