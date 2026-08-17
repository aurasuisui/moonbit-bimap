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
pub impl[L : Hash + Eq, R : Hash + Eq] Eq for BiMap[L, R] with fn equal(
  self,
  other,
) {
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
/// Order-independent hash: the per-pair fingerprints are combined with addition
/// (a commutative operation), so shuffling the insertion order does not change
/// the hash — consistent with the order-independent `Eq`.
///
/// Note: a commutative combination is weaker against deliberate hash-collision
/// attacks than an order-sensitive one. That is acceptable for a set-like
/// container; take care if you use a BiMap as a key in another hash container.
pub impl[L : Hash + Eq, R : Hash + Eq] Hash for BiMap[L, R] with fn hash_combine(
  self,
  hasher,
) {
  let arr = self.into_array()
  let mut acc : Int = 0
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    acc = acc + pair_fingerprint(l, r)
    i = i + 1
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
pub impl[L : Hash + Eq, R : Hash + Eq] Default for BiMap[L, R] with fn default() {
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
