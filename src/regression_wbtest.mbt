// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Regression tests for the tombstone-cluster probe bug (fixed 2026-08,
// found during retain development): with tombstones present, the Robin Hood
// early cutoff in the insert search could stop before an existing key whose
// recorded distance looked "too small", insert a DUPLICATE entry, and make
// lookups return stale values — silently breaking the bijection. The fix
// removes the cutoff (scan to the first empty slot) and normalizes hashes so
// they can never equal the tombstone sentinel.

///|
test "regression: QuickCheck sample 40 (tombstone clusters + negative keys)" {
  // The exact sequence that exposed the bug: C3/C4 churn creates tombstones
  // in both tables while later keys' homes fall inside older clusters.
  let pairs = [
    (0, 0),
    (0, 0),
    (0, 1),
    (-2, 2),
    (-3, 3),
    (-1, -3),
    (-5, 0),
    (2, 3),
    (2, 0),
    (3, 6),
    (3, 9),
    (-4, 5),
    (4, -3),
    (-6, -6),
    (3, 0),
    (11, -10),
    (7, -9),
    (-8, 13),
    (-16, 9),
    (4, 14),
    (-4, 14),
    (-12, -3),
    (-10, -11),
    (18, 20),
    (-7, -1),
    (21, -21),
    (-11, 16),
    (11, -21),
    (-26, 0),
    (-23, 4),
    (-2, -21),
    (-14, -9),
    (5, 0),
  ]
  let m : BiMap[Int, Int] = BiMap::new()
  let mut i = 0
  while i < pairs.length() {
    let (l0, r0) = pairs[i]
    m.insert(l0 % 12, r0 % 12) |> ignore
    // the bijection must hold after EVERY step, not just at the end
    check_whitebox(m)
    check_no_duplicate_keys(m)
    i = i + 1
  }
  // final state: full inverse agreement through the public API
  let arr = m.into_array()
  let mut j = 0
  while j < arr.length() {
    let (l, r) = arr[j]
    @test.assert_eq(m.get_by_left(l), Some(r))
    @test.assert_eq(m.get_by_right(r), Some(l))
    j = j + 1
  }
}

///|
test "regression: random inserts never duplicate a live bucket entry" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(60)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : BiMap[Int, Int] = BiMap::new()
    let mut i = 0
    while i < pairs.length() {
      let (l0, r0) = pairs[i]
      m.insert(l0, r0) |> ignore
      i = i + 1
    }
    check_no_duplicate_keys(m)
    check_whitebox(m)
    c = c + 1
  }
}

///|
struct SentinelKey {
  id : Int
} derive(Eq, Debug)

///|
impl Hash for SentinelKey with fn hash_combine(self, hasher) {
  // Adversarial: every key contributes the same value (a constant hash,
  // like CollidingKey, but seeded from the tombstone sentinel value).
  Hash::hash_combine(self.id * 0 - 1, hasher)
}

///|
test "regression: normalize_hash can never return the tombstone sentinel" {
  // A live entry whose stored hash equals TOMBSTONE_HASH would be invisible
  // to probes; normalize_hash deflects exactly that value. The triggering
  // key hash (-1) is a 1-in-2^N event and cannot be constructed end-to-end
  // (the hasher mixes contributions), so the normalization is unit-tested
  // directly here.
  @test.assert_eq(normalize_hash(-1), 0)
  @test.assert_eq(normalize_hash(0), 0)
  @test.assert_eq(normalize_hash(5), 5)
  @test.assert_eq(normalize_hash(-2), -2)
}

///|
test "regression: constant-hash keys stay visible across tombstone churn" {
  let k1 : SentinelKey = { id: 1 }
  let k2 : SentinelKey = { id: 2 }
  let m : BiMap[SentinelKey, Int] = BiMap::new()
  m.insert(k1, 10) |> ignore
  m.insert(k2, 20) |> ignore
  m.remove_by_left(k1) |> ignore // create a real tombstone in the cluster
  m.insert(k1, 30) |> ignore // reinsert over the tombstone-laden table
  @test.assert_eq(m.get_by_left(k1), Some(30))
  @test.assert_eq(m.get_by_right(30), Some(k1))
  @test.assert_eq(m.get_by_left(k2), Some(20))
  @test.assert_eq(m.len(), 2)
  check_no_duplicate_keys(m)
}
