// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Trait implementations for BiBTreeMap.
//
// Semantics mirror BiMap exactly: `Eq` is SET equality (two maps are equal
// iff they contain the same pairs — trivially the same sorted sequence for
// sorted maps), and `Hash` reuses the same sorted-fingerprint canonical
// form (pair_fingerprint + sort-fold, shared with bimap_traits.mbt), so the
// hardening notes from README Gotcha #2 apply verbatim.
//
// Bounds are minimized per impl: `Compare` implies `Eq` (builtin), so
// `Eq`/`Default` need nothing beyond the two `Compare` bounds.

// ---------------------------------------------------------------------------
// Eq / Hash (set semantics, same algorithm as BiMap)
// ---------------------------------------------------------------------------

///|
/// Set equality: two BiBTreeMaps are equal iff they contain the same
/// (left, right) pairs. For sorted maps this coincides with sequence equality
/// of the ascending pair lists (both sides are canonical), so the
/// implementation compares `into_array()` directly — which also keeps the
/// bounds minimal at `[L : Eq, R : Eq]` (no `Compare` needed here).
pub impl[L : Eq, R : Eq] Eq for BiBTreeMap[L, R] with fn equal(self, other) {
  self.into_array() == other.into_array()
}

///|
/// Same sorted-fingerprint canonical form as BiMap's hash: per-pair
/// `pair_fingerprint` (shared helper), sort, then an order-sensitive
/// FNV-1a-style fold mixing the length in first. Equal pair sets hash equal
/// regardless of construction history; cost O(n log n) (the sort). Hash
/// values are not required to agree across backends (64-bit constants).
pub impl[L : Hash, R : Hash] Hash for BiBTreeMap[L, R] with fn hash_combine(
  self,
  hasher,
) {
  let arr = self.into_array()
  let fps : Array[Int] = []
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    fps.push(pair_fingerprint(l, r))
    i = i + 1
  }
  fps.sort()
  // FNV-1a 64 constants, assembled arithmetically (MoonBit integer literals
  // are range-limited): basis 0xcbf29ce484222325, prime 0x100000001b3.
  let fnv_basis = (0xcbf2_9ce4 << 32) + 0x8422_2325
  let fnv_prime = (1 << 40) + (1 << 8) + 0xb3
  let mut acc = fnv_basis
  acc = acc.lxor(self.len()) * fnv_prime // mix the length in first
  let mut j = 0
  while j < fps.length() {
    acc = acc.lxor(fps[j]) * fnv_prime
    j = j + 1
  }
  Hash::hash_combine(acc, hasher)
}

// ---------------------------------------------------------------------------
// Debug / Show / Default
// ---------------------------------------------------------------------------

///|
/// Debug representation: `BiBTreeMap{ left: right, ... }` in ascending
/// left-key order.
pub impl[L : Debug, R : Debug] Debug for BiBTreeMap[L, R] with fn to_repr(self) {
  let entries : Array[(Repr, Repr)] = []
  let arr = self.into_array()
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    entries.push((Debug::to_repr(l), Debug::to_repr(r)))
    i = i + 1
  }
  Repr::opaque_("BiBTreeMap", Repr::map(entries))
}

///|
/// Human-readable rendering: `BiBTreeMap{left <-> right, ...}` in ascending
/// left-key order.
pub impl[L : Show, R : Show] Show for BiBTreeMap[L, R] with fn output(
  self,
  logger,
) {
  logger.write_string("BiBTreeMap{")
  let mut first = true
  let arr = self.into_array()
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    if !first {
      logger.write_string(", ")
    }
    Show::output(l, logger)
    logger.write_string(" <-> ")
    Show::output(r, logger)
    first = false
    i = i + 1
  }
  logger.write_string("}")
}

///|
/// The default BiBTreeMap is empty.
pub impl[L : Compare, R : Compare] Default for BiBTreeMap[L, R] with fn default() {
  BiBTreeMap::new()
}

// ---------------------------------------------------------------------------
// ToJson
// ---------------------------------------------------------------------------

///|
/// Serialize to a JSON object `{ "<left>": <right-json>, ... }` in ascending
/// left-key order. Object keys are the left key's `Show` rendering
/// (`to_string`), so a `String` left key appears verbatim.
pub impl[L : Show, R : ToJson] ToJson for BiBTreeMap[L, R] with fn to_json(self) {
  let obj : Map[String, Json] = Map([])
  let arr = self.into_array()
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    obj[Show::to_string(l)] = ToJson::to_json(r)
    i = i + 1
  }
  Json::object(obj)
}

// ---------------------------------------------------------------------------
// QuickCheck Arbitrary
// ---------------------------------------------------------------------------

///|
/// Generate random BiBTreeMaps for property-based testing (via `from_array`,
/// so the generated map always satisfies the bijection invariants).
pub impl[
  L : @quickcheck.Arbitrary + Compare,
  R : @quickcheck.Arbitrary + Compare,
] @quickcheck.Arbitrary for BiBTreeMap[L, R] with fn arbitrary(size, r0) {
  let pairs : Array[(L, R)] = @quickcheck.Arbitrary::arbitrary(size, r0)
  BiBTreeMap::from_array(pairs)
}
