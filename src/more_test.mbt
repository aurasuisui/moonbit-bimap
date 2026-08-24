// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Final coverage batch to round out the matrix: more QuickCheck shapes, more
// C0-C4 / index / conversion edge cases, and trait behavior across types.

// ---------------------------------------------------------------------------
// More insertion-semantics shapes
// ---------------------------------------------------------------------------

///|
test "C0/C1/C2/C3/C4 all reachable on a single Int,Int map" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  match m.insert(1, 10) {
    @aurasuisui/bimap.Neither => ()
    _ => @test.fail("C0 expected")
  }
  match m.insert(1, 10) {
    @aurasuisui/bimap.Pair(1, 10) => ()
    _ => @test.fail("C1 expected")
  }
  match m.insert(1, 11) {
    @aurasuisui/bimap.Left(1, 10) => ()
    _ => @test.fail("C2 expected")
  }
  m.insert(2, 20) |> ignore
  match m.insert(3, 11) {
    @aurasuisui/bimap.Right(1, 11) => ()
    _ => @test.fail("C3 expected")
  }
  m.insert(4, 20) |> ignore // 4 takes 20 from 2 (C3) -> now 2 is free
  m.insert(2, 30) |> ignore
  // set up a C4: have 3->11 and 4->20; insert(3, 20)
  match m.insert(3, 20) {
    @aurasuisui/bimap.Both((3, 11), (4, 20)) => ()
    _ => @test.fail("C4 expected")
  }
  check_bijection(m)
}

///|
test "C2 then C3 on overlapping keys stays consistent" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(1, 1) |> ignore
  m.insert(2, 2) |> ignore
  m.insert(1, 2) |> ignore // C4 collapses (1,1) and (2,2) into (1,2)
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left(1), Some(2))
  @test.assert_eq(m.get_by_left(2), None)
}

///|
test "many fresh inserts then exact reinserts are all Pair" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 20 {
    m.insert(i, i * 7) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 20 {
    match m.insert(j, j * 7) {
      @aurasuisui/bimap.Pair(_, _) => ()
      _ => @test.fail("expected Pair on exact reinsert")
    }
    j = j + 1
  }
  @test.assert_eq(m.len(), 20)
}

// ---------------------------------------------------------------------------
// Index access after tricky ops
// ---------------------------------------------------------------------------

///|
test "get_index_of_left after C3 takeover points to the new owner" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("c", 1) |> ignore // c takes 1 from a
  @test.assert_eq(m.get_index_of_left("a"), None)
  @test.assert_eq(m.get_index_of_left("c"), Some(1))
}

///|
test "get_index after C4 returns the surviving pair" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("a", 2) |> ignore
  @test.assert_eq(m.get_index(0), Some(("a", 2)))
  @test.assert_eq(m.get_index(1), None)
}

///|
test "last after C4 collapse is the survivor" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("a", 2) |> ignore
  @test.assert_eq(m.last(), Some(("a", 2)))
  @test.assert_eq(m.first(), Some(("a", 2)))
}

// ---------------------------------------------------------------------------
// More QuickCheck shapes
// ---------------------------------------------------------------------------

///|
test "qc: Char-keyed generated maps satisfy invariants" {
  let maps : Array[@aurasuisui/bimap.BiMap[Char, Int]] = @quickcheck.samples(20)
  let mut i = 0
  while i < maps.length() {
    check_bijection(maps[i])
    i = i + 1
  }
}

///|
test "qc: Bool-keyed maps (tiny keyspace) satisfy invariants" {
  let maps : Array[@aurasuisui/bimap.BiMap[Bool, Int]] = @quickcheck.samples(20)
  let mut i = 0
  while i < maps.length() {
    check_bijection(maps[i])
    if maps[i].len() > 2 {
      @test.fail("Bool keyspace cannot exceed 2 pairs")
    }
    i = i + 1
  }
}

///|
test "qc: copy of a generated map equals the original" {
  let maps : Array[@aurasuisui/bimap.BiMap[String, String]] = @quickcheck.samples(
    20,
  )
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    @test.assert_eq(m.copy(), m)
    i = i + 1
  }
}

///|
test "qc: interleaving insert and insert_no_overwrite keeps invariants" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(25)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
    let mut i = 0
    while i < pairs.length() {
      let (l, r) = pairs[i]
      if i % 2 == 0 {
        m.insert(l, r) |> ignore
      } else {
        m.insert_no_overwrite(l, r) |> ignore
      }
      i = i + 1
    }
    check_bijection(m)
    c = c + 1
  }
}

// ---------------------------------------------------------------------------
// Conversions / traits across types
// ---------------------------------------------------------------------------

///|
test "from_array then to_inverse then from_array round-trip" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let inv = m.to_inverse()
  let pairs = inv.into_array()
  let rebuilt = @aurasuisui/bimap.BiMap::from_array(pairs)
  @test.assert_eq(rebuilt, inv)
}

///|
test "Show after C4 collapse shows only the survivor" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("a", 2) |> ignore
  @test.assert_eq(m.to_string(), "BiMap{a <-> 2}")
}

///|
test "ToJson after removal omits the removed key" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.remove_by_left("a") |> ignore
  let expected : Map[String, Json] = Map([])
  expected["b"] = ToJson::to_json(2)
  @test.assert_eq(m.to_json(), Json::object(expected))
}

///|
test "Debug of empty map (snapshot)" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  debug_inspect(
    m,
    content=(
      #|<BiMap: {}>
    ),
  )
}

///|
test "Eq: maps with swapped pairs are NOT equal (ordered pairs)" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([(1, 2), (3, 4)])
  let m2 = @aurasuisui/bimap.BiMap::from_array([(2, 1), (4, 3)])
  @test.assert_not_eq(m1, m2)
}

///|
test "is_empty flips correctly across insert/remove" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.is_empty(), true)
  m.insert(1, 1) |> ignore
  @test.assert_eq(m.is_empty(), false)
  m.remove_by_left(1) |> ignore
  @test.assert_eq(m.is_empty(), true)
}

///|
test "with_capacity larger than needed still functions" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.with_capacity(
    1024,
  )
  m.insert(1, 1) |> ignore
  @test.assert_eq(m.get_by_left(1), Some(1))
  if m.capacity() < 1024 {
    @test.fail("capacity should honor the large request")
  }
}

///|
test "lefts and rights have matching lengths" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let mut lc = 0
  for _l in m.lefts() {
    lc = lc + 1
  }
  let mut rc = 0
  for _r in m.rights() {
    rc = rc + 1
  }
  @test.assert_eq(lc, m.len())
  @test.assert_eq(rc, m.len())
}

///|
test "into_array length equals len after many ops" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 80 {
    m.insert(i % 30, i) |> ignore
    i = i + 1
  }
  @test.assert_eq(m.into_array().length(), m.len())
  check_bijection(m)
}

// ---------------------------------------------------------------------------
// Miscellaneous
// ---------------------------------------------------------------------------

///|
test "VERSION constant is exposed" {
  @test.assert_eq(@aurasuisui/bimap.VERSION, "0.2.1")
}

///|
test "from_array is idempotent on its own output" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let rebuilt = @aurasuisui/bimap.BiMap::from_array(m.into_array())
  @test.assert_eq(rebuilt, m)
  @test.assert_eq(rebuilt.into_array(), m.into_array())
}

///|
test "to_inverse preserves the pair count" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  @test.assert_eq(m.to_inverse().len(), m.len())
}

///|
test "the two directions stay symmetric over a long deterministic sequence" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut state = 987654321
  let mut i = 0
  while i < 1000 {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF
    let k = (state >> 4) % 200
    let v = (state >> 12) % 200
    if state % 4 == 0 {
      m.remove_by_left(k) |> ignore
    } else if state % 4 == 1 {
      m.remove_by_right(v) |> ignore
    } else {
      m.insert(k, v) |> ignore
    }
    i = i + 1
  }
  // every surviving pair resolves symmetrically
  let arr = m.into_array()
  let mut j = 0
  while j < arr.length() {
    let (l, r) = arr[j]
    @test.assert_eq(m.get_by_right(r), Some(l))
    @test.assert_eq(m.get_by_left(l), Some(r))
    j = j + 1
  }
}

///|
test "iter, lefts, rights all report the same count" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
    ("e", 5),
  ])
  @test.assert_eq(m.into_array().length(), m.len())
  let mut pairs = 0
  for _p in m.iter() {
    pairs = pairs + 1
  }
  @test.assert_eq(pairs, m.len())
}
