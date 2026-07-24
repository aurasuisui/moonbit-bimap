// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Iterator-contract tests beyond basic order/count (which traits_test.mbt
// covers): independence of simultaneous iterators, and the observable effect of
// the `size_hint` passed to `Iter::new`.
//
// NOTE on size_hint: MoonBit's `Iter[T]` exposes no public accessor to read the
// size hint back — it is an input to `Iter::new` that combinators like
// `collect` use to pre-allocate. So, like the fail-fast `abort`, it cannot be
// asserted directly. We assert its OBSERVABLE effect instead: `collect()`
// materializes exactly the right elements in the right order (a wrong size_hint
// would surface as a mis-sized / truncated materialization).

// ---------------------------------------------------------------------------
// Independence of simultaneous iterators
// ---------------------------------------------------------------------------

///|
test "iter: two simultaneous iterators advance independently" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  let it1 = m.iter()
  let it2 = m.iter()
  // pull one from it1; it2 must still start at the beginning
  @test.assert_eq(it1.next(), Some(("a", 1)))
  @test.assert_eq(it2.next(), Some(("a", 1)))
  @test.assert_eq(it2.next(), Some(("b", 2)))
  // it1 resumes from where IT left off, unaffected by it2
  @test.assert_eq(it1.next(), Some(("b", 2)))
  @test.assert_eq(it1.next(), Some(("c", 3)))
  @test.assert_eq(it1.next(), Some(("d", 4)))
  @test.assert_eq(it1.next(), None)
  // it2 continues its own cursor
  @test.assert_eq(it2.next(), Some(("c", 3)))
  @test.assert_eq(it2.next(), Some(("d", 4)))
  @test.assert_eq(it2.next(), None)
}

///|
test "iter: a fresh iterator is unaffected by a partially consumed one" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let partial = m.iter()
  partial.next() |> ignore // consume one element
  partial.next() |> ignore
  // a brand-new iterator still yields the entire sequence
  let full = m.iter()
  @test.assert_eq(full.collect(), [("a", 1), ("b", 2), ("c", 3)])
}

///|
test "iter: lefts and rights iterators interleaved stay independent" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let ls = m.lefts()
  let rs = m.rights()
  @test.assert_eq(ls.next(), Some("a"))
  @test.assert_eq(rs.next(), Some(1))
  @test.assert_eq(rs.next(), Some(2))
  @test.assert_eq(ls.next(), Some("b"))
  @test.assert_eq(ls.next(), Some("c"))
  @test.assert_eq(ls.next(), None)
  @test.assert_eq(rs.next(), Some(3))
  @test.assert_eq(rs.next(), None)
}

// ---------------------------------------------------------------------------
// size_hint observable effect via collect()
// ---------------------------------------------------------------------------

///|
test "iter: collect() materializes the full sequence in order (size_hint effect)" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  @test.assert_eq(m.iter().collect(), [("b", 2), ("a", 1), ("c", 3)])
  @test.assert_eq(m.lefts().collect(), ["b", "a", "c"])
  @test.assert_eq(m.rights().collect(), [2, 1, 3])
}

///|
test "iter: collect() count equals len after mixed ops (size_hint stays correct)" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 40 {
    m.insert(i, i * 2) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 15 {
    m.remove_by_left(j) |> ignore
    j = j + 1
  }
  let pairs : Array[(Int, Int)] = m.iter().collect()
  @test.assert_eq(pairs.length(), m.len())
  @test.assert_eq(pairs.length(), 25)
  @test.assert_eq(m.lefts().collect().length(), 25)
  @test.assert_eq(m.rights().collect().length(), 25)
}

///|
test "iter: collect() on an empty map yields an empty array" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  let pairs : Array[(String, Int)] = m.iter().collect()
  @test.assert_eq(pairs.length(), 0)
  let lefts : Array[String] = m.lefts().collect()
  @test.assert_eq(lefts.length(), 0)
}
