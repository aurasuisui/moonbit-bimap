// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// QuickCheck generation tests: exercise the `Arbitrary` instance and re-check
// the invariants and order-independent Eq/Hash on randomly generated maps.
// (`check_bijection` is shared from property_test.mbt within the test module.)

///|
test "qc: generated BiMaps satisfy the bijection invariants" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, Int]] = @quickcheck.samples(50)
  let mut i = 0
  while i < maps.length() {
    check_bijection(maps[i])
    i = i + 1
  }
}

///|
test "qc: generated BiMaps report a consistent length" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, String]] = @quickcheck.samples(
    40,
  )
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    @test.assert_eq(m.into_array().length(), m.len())
    i = i + 1
  }
}

///|
test "qc: Eq/Hash are order-independent on random maps (reverse insertion)" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, Int]] = @quickcheck.samples(50)
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    let pairs = m.into_array()
    // Rebuild the same pair set in reverse insertion order.
    let rev : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
    let mut j = pairs.length() - 1
    while j >= 0 {
      let (l, r) = pairs[j]
      rev.insert(l, r) |> ignore
      j = j - 1
    }
    @test.assert_eq(m, rev)
    @test.assert_eq(Hash::hash(m), Hash::hash(rev))
    i = i + 1
  }
}

///|
test "qc: copy() yields an equal map" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, Int]] = @quickcheck.samples(40)
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    @test.assert_eq(m.copy(), m)
    check_bijection(m.copy())
    i = i + 1
  }
}

///|
test "qc: to_inverse is an involution on random maps" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, Int]] = @quickcheck.samples(40)
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    @test.assert_eq(m.to_inverse().to_inverse(), m)
    i = i + 1
  }
}

///|
test "qc: to_inverse flips every lookup" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, Int]] = @quickcheck.samples(40)
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    let inv = m.to_inverse()
    let pairs = m.into_array()
    let mut j = 0
    while j < pairs.length() {
      let (l, r) = pairs[j]
      @test.assert_eq(inv.get_by_left(r), Some(l))
      @test.assert_eq(inv.get_by_right(l), Some(r))
      j = j + 1
    }
    i = i + 1
  }
}
