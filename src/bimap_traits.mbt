// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Trait implementations for BiMap.
//
// The important ones are `Eq` and `Hash`, which are ORDER-INDEPENDENT: a BiMap
// is fundamentally a SET of (left, right) pairs, so two maps are equal iff they
// contain the same pairs regardless of insertion order, and their hash is a
// commutative accumulation over the pairs. This is the deliberate opposite of
// indexmap, whose Eq/Hash are insertion-order sensitive.

// ---------------------------------------------------------------------------
// Order-independent Eq / Hash
// ---------------------------------------------------------------------------

///|
/// Order-sensitive fingerprint of a single pair, used as the per-pair term in
/// the order-independent map hash. Multiplying the left hash by a constant
/// before adding the right hash keeps `(l, r)` distinct from `(r, l)`.
fn[L : Hash, R : Hash] pair_fingerprint(l : L, r : R) -> Int {
  Hash::hash(l) * 0x9E3779B9 + Hash::hash(r)
}

///|
/// Order-independent equality: two BiMaps are equal iff they contain the same
/// (left, right) pairs, regardless of insertion order.
pub impl[L : Hash + Eq, R : Eq] Eq for BiMap[L, R] with fn equal(self, other) {
  if self.len != other.len {
    return false
  }
  let arr = self.into_array()
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    match other.get_by_left(l) {
      Some(r2) => if r != r2 { return false }
      None => return false
    }
    i = i + 1
  }
  true
}

///|
/// Order-independent hash. Because `Eq` is order-independent (a BiMap is a
/// SET of pairs), `Hash` must be too: the combination must not depend on
/// insertion order. This implementation builds the canonical form of the pair
/// set — the SORTED sequence of per-pair fingerprints — and folds it with an
/// order-sensitive FNV-1a-style mix:
///
/// 1. `pair_fingerprint(l, r)` (order-sensitive WITHIN a pair, so `(l, r)`
///    differs from `(r, l)`);
/// 2. sort the fingerprints — a bijection never contains duplicate pairs, so
///    the sorted sequence is a perfect canonical form of the pair set;
/// 3. fold `acc = lxor(acc, f) * FNV_PRIME` (FNV-1a style), mixing the length
///    in first.
///
/// The sort destroys the linear structure of the commutative sum this
/// replaces, under which cross-swapped maps like `{(a,b),(c,d)}` and
/// `{(a,d),(c,b)}` collided by algebraic identity for ANY key hashes. Now a
/// collision requires the fingerprint MULTISETS to match, which in turn
/// needs hash-level control over the keys (see README Gotcha #2).
///
/// Cost: O(n log n) per hash (the sort). The 64-bit FNV constants assume the
/// 64-bit `Int` of the current backends; overflow wraps (defined behavior),
/// and hash values are not required to agree across backends.
pub impl[L : Hash + Eq, R : Hash] Hash for BiMap[L, R] with fn hash_combine(
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
/// Debug representation: `BiMap{ left: right, ... }` in insertion order.
pub impl[L : Debug + Hash + Eq, R : Debug] Debug for BiMap[L, R] with fn to_repr(
  self,
) {
  let entries : Array[(Repr, Repr)] = []
  let arr = self.into_array()
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    entries.push((Debug::to_repr(l), Debug::to_repr(r)))
    i = i + 1
  }
  Repr::opaque_("BiMap", Repr::map(entries))
}

///|
/// Human-readable rendering: `BiMap{left <-> right, ...}` in insertion order.
pub impl[L : Show + Hash + Eq, R : Show] Show for BiMap[L, R] with fn output(
  self,
  logger,
) {
  logger.write_string("BiMap{")
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
/// The default BiMap is empty.
pub impl[L : Hash + Eq, R] Default for BiMap[L, R] with fn default() {
  BiMap::new()
}

// ---------------------------------------------------------------------------
// ToJson
// ---------------------------------------------------------------------------

///|
/// Serialize to a JSON object `{ "<left>": <right-json>, ... }` in insertion
/// order. Object keys are the left key's `Show` rendering (`to_string`), so a
/// `String` left key appears verbatim (no `String("...")` mangling).
pub impl[L : Show + Hash + Eq, R : ToJson] ToJson for BiMap[L, R] with fn to_json(
  self,
) {
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
/// Generate random BiMaps for property-based testing (via `from_array`, so the
/// generated map always satisfies the bijection invariants).
///
/// Unlike indexmap's `Arbitrary` (whose value type needs no `Hash`/`Eq`), a
/// BiMap hashes BOTH sides for its backward table, so `R` must also be
/// `Hash + Eq`.
pub impl[
  L : @quickcheck.Arbitrary + Hash + Eq,
  R : @quickcheck.Arbitrary + Hash + Eq,
] @quickcheck.Arbitrary for BiMap[L, R] with fn arbitrary(size, r0) {
  let pairs : Array[(L, R)] = @quickcheck.Arbitrary::arbitrary(size, r0)
  BiMap::from_array(pairs)
}
