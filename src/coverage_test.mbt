// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Additional coverage: API nooks, mutation-then-query sequences, and
// QuickCheck properties over String-keyed maps.

// ---------------------------------------------------------------------------
// insert_no_overwrite sequences
// ---------------------------------------------------------------------------

test "insert_no_overwrite: several fresh inserts all succeed" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.insert_no_overwrite("a", 1), Ok(()))
  @test.assert_eq(m.insert_no_overwrite("b", 2), Ok(()))
  @test.assert_eq(m.insert_no_overwrite("c", 3), Ok(()))
  @test.assert_eq(m.len(), 3)
}

test "insert_no_overwrite: failure leaves order intact" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert_no_overwrite("a", 99) |> ignore // fails
  @test.assert_eq(m.into_array(), [("a", 1), ("b", 2)])
}

test "insert_no_overwrite then insert: strict guard then forced" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.insert_no_overwrite("a", 1), Ok(()))
  @test.assert_eq(m.insert_no_overwrite("a", 2), Err(("a", 2)))
  // now force the overwrite via insert
  match m.insert("a", 2) {
    @aurasuisui/bimap.Left("a", 1) => ()
    _ => @test.fail("expected Left(a, 1)")
  }
  @test.assert_eq(m.get_by_left("a"), Some(2))
}

// ---------------------------------------------------------------------------
// Query-after-mutation sequences
// ---------------------------------------------------------------------------

test "into_array after a C2 rebind shows the new right" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("a", 100) |> ignore
  @test.assert_eq(m.into_array(), [("a", 100), ("b", 2)])
}

test "into_array after a C3 takeover drops the old left" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("z", 1) |> ignore // z takes 1 from a
  @test.assert_eq(m.into_array(), [("b", 2), ("z", 1)])
}

test "into_array after a C4 collapse has one fewer pair" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("a", 2) |> ignore
  @test.assert_eq(m.into_array(), [("a", 2)])
}

test "lefts after removals skips removed keys" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  m.remove_by_left("b") |> ignore
  let lefts : Array[String] = []
  for l in m.lefts() {
    lefts.push(l)
  }
  @test.assert_eq(lefts, ["a", "c"])
}

test "rights after a C2 rebind reflects the new value" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("a", 100) |> ignore
  let rights : Array[Int] = []
  for r in m.rights() {
    rights.push(r)
  }
  @test.assert_eq(rights, [100, 2])
}

test "iter count matches len after mixed ops" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 50 {
    m.insert(i, i * 2) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 25 {
    m.remove_by_left(j) |> ignore
    j = j + 1
  }
  let mut count = 0
  for _p in m.iter() {
    count = count + 1
  }
  @test.assert_eq(count, m.len())
  @test.assert_eq(count, 25)
}

// ---------------------------------------------------------------------------
// get_index / first / last edge cases
// ---------------------------------------------------------------------------

test "get_index_of_right equals get_index_of_left of its partner" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  @test.assert_eq(m.get_index_of_right(1), m.get_index_of_left("a"))
  @test.assert_eq(m.get_index_of_right(2), m.get_index_of_left("b"))
  @test.assert_eq(m.get_index_of_right(3), m.get_index_of_left("c"))
}

test "first/last track insertions" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(1, 1) |> ignore
  @test.assert_eq(m.first(), Some((1, 1)))
  @test.assert_eq(m.last(), Some((1, 1)))
  m.insert(2, 2) |> ignore
  @test.assert_eq(m.first(), Some((1, 1)))
  @test.assert_eq(m.last(), Some((2, 2)))
  m.insert(3, 3) |> ignore
  @test.assert_eq(m.last(), Some((3, 3)))
}

test "get_index walks the whole map in order" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  @test.assert_eq(m.get_index(0), Some(("a", 1)))
  @test.assert_eq(m.get_index(1), Some(("b", 2)))
  @test.assert_eq(m.get_index(2), Some(("c", 3)))
  @test.assert_eq(m.get_index(3), None)
}

// ---------------------------------------------------------------------------
// copy / to_inverse independence (both directions)
// ---------------------------------------------------------------------------

test "copy independence: editing copy leaves original intact" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let c = m.copy()
  c.remove_by_left("a") |> ignore
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.contains_left("a"), true)
  @test.assert_eq(c.len(), 1)
}

test "to_inverse independence: editing inverse leaves original intact" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let inv = m.to_inverse()
  inv.remove_by_left(1) |> ignore
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.contains_right(1), true)
  @test.assert_eq(inv.len(), 1)
}

test "to_inverse of to_inverse round-trips lookups" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let rt = m.to_inverse().to_inverse()
  @test.assert_eq(rt.get_by_left("a"), Some(1))
  @test.assert_eq(rt.get_by_left("b"), Some(2))
  @test.assert_eq(rt.get_by_left("c"), Some(3))
}

// ---------------------------------------------------------------------------
// QuickCheck over String-keyed maps
// ---------------------------------------------------------------------------

test "qc: String-keyed generated maps satisfy invariants" {
  let maps : Array[@aurasuisui/bimap.BiMap[String, Int]] = @quickcheck.samples(
    30,
  )
  let mut i = 0
  while i < maps.length() {
    check_bijection(maps[i])
    i = i + 1
  }
}

test "qc: removing random left keys keeps invariants" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, Int]] = @quickcheck.samples(30)
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    let keys = m.into_array()
    let mut j = 0
    while j < keys.length() {
      if j % 2 == 1 {
        let (l, _) = keys[j]
        m.remove_by_left(l) |> ignore
      }
      j = j + 1
    }
    check_bijection(m)
    i = i + 1
  }
}

test "qc: removing random right keys keeps invariants" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, Int]] = @quickcheck.samples(30)
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    let pairs = m.into_array()
    let mut j = 0
    while j < pairs.length() {
      if j % 3 == 0 {
        let (_, r) = pairs[j]
        m.remove_by_right(r) |> ignore
      }
      j = j + 1
    }
    check_bijection(m)
    i = i + 1
  }
}

test "qc: insert_no_overwrite never breaks invariants" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(30)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
    let mut i = 0
    while i < pairs.length() {
      let (l, r) = pairs[i]
      m.insert_no_overwrite(l, r) |> ignore
      i = i + 1
    }
    check_bijection(m)
    c = c + 1
  }
}

// ---------------------------------------------------------------------------
// Capacity / internal hygiene
// ---------------------------------------------------------------------------

test "capacity stays a power of two through growth" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 500 {
    m.insert(i, i) |> ignore
    let cap = m.capacity()
    @test.assert_eq(cap & (cap - 1), 0)
    i = i + 1
  }
}

test "len never exceeds the number of inserted distinct pairs" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 100 {
    m.insert(i % 10, i) |> ignore // only 10 distinct left keys
    if m.len() > 10 {
      @test.fail("len exceeded distinct left-key count")
    }
    i = i + 1
  }
}

test "reinserting all after a full drain restores content" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  let saved = m.into_array()
  m.remove_by_left("a") |> ignore
  m.remove_by_left("b") |> ignore
  m.remove_by_left("c") |> ignore
  @test.assert_eq(m.is_empty(), true)
  let mut i = 0
  while i < saved.length() {
    let (l, r) = saved[i]
    m.insert(l, r) |> ignore
    i = i + 1
  }
  @test.assert_eq(m.into_array(), saved)
}

test "contains_left/right agree with get_by_left/right" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  @test.assert_eq(m.contains_left("a"), m.get_by_left("a").is_some())
  @test.assert_eq(m.contains_left("zzz"), m.get_by_left("zzz").is_some())
  @test.assert_eq(m.contains_right(2), m.get_by_right(2).is_some())
  @test.assert_eq(m.contains_right(999), m.get_by_right(999).is_some())
}

test "Eq and Hash agree across copy" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let c = m.copy()
  @test.assert_eq(m, c)
  @test.assert_eq(Hash::hash(m), Hash::hash(c))
}
