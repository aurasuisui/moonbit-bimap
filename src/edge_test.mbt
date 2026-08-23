// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Focused edge-case unit tests across the whole API surface.

// ---------------------------------------------------------------------------
// Insert semantics: deeper coverage
// ---------------------------------------------------------------------------

///|
test "C0 into a map with tombstones reuses slots" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.len(), 0)
  let r = m.insert("b", 2)
  match r {
    @aurasuisui/bimap.Neither => ()
    _ => @test.fail("expected Neither")
  }
  @test.assert_eq(m.get_by_left("b"), Some(2))
}

///|
test "C2: repeated rebinds of the same left key" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  match m.insert("a", 2) {
    @aurasuisui/bimap.Left("a", 1) => ()
    _ => @test.fail("expected Left(a, 1)")
  }
  match m.insert("a", 3) {
    @aurasuisui/bimap.Left("a", 2) => ()
    _ => @test.fail("expected Left(a, 2)")
  }
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(3))
  @test.assert_eq(m.get_by_right(1), None)
  @test.assert_eq(m.get_by_right(2), None)
}

///|
test "C2 does not disturb unrelated pairs" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  m.insert("b", 20) |> ignore
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_left("c"), Some(3))
  @test.assert_eq(m.get_by_right(2), None)
  @test.assert_eq(m.get_by_right(20), Some("b"))
  @test.assert_eq(m.len(), 3)
}

///|
test "C3: a right value handed across several left keys" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 1) |> ignore // takes 1 from a
  @test.assert_eq(m.get_by_left("a"), None)
  @test.assert_eq(m.get_by_right(1), Some("b"))
  m.insert("c", 1) |> ignore // takes 1 from b
  @test.assert_eq(m.get_by_left("b"), None)
  @test.assert_eq(m.get_by_right(1), Some("c"))
  @test.assert_eq(m.len(), 1)
}

///|
test "C3 does not disturb unrelated pairs" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  m.insert("z", 2) |> ignore // z takes right value 2 from b
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_left("c"), Some(3))
  @test.assert_eq(m.get_by_left("b"), None)
  @test.assert_eq(m.get_by_right(2), Some("z"))
  @test.assert_eq(m.len(), 3)
}

///|
test "C4 collapses non-adjacent pairs and keeps survivor order" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  // collapse (a,1) and (d,4) into (a,4)
  match m.insert("a", 4) {
    @aurasuisui/bimap.Both(("a", 1), ("d", 4)) => ()
    _ => @test.fail("expected Both((a,1),(d,4))")
  }
  @test.assert_eq(m.len(), 3)
  @test.assert_eq(m.get_index_of_left("a"), Some(0))
  @test.assert_eq(m.get_index_of_left("b"), Some(1))
  @test.assert_eq(m.get_index_of_left("c"), Some(2))
  @test.assert_eq(m.get_by_left("d"), None)
}

///|
test "C1 idempotence does not bump observable order" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.insert("a", 1) |> ignore // C1, no-op
  m.insert("b", 2) |> ignore // C1, no-op
  @test.assert_eq(m.into_array(), [("a", 1), ("b", 2)])
}

///|
test "insert the same left with two rights then back" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("a", 2) |> ignore
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(2), None)
}

// ---------------------------------------------------------------------------
// Lookup
// ---------------------------------------------------------------------------

///|
test "get_by_left resolves every key after batch insert" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_left("b"), Some(2))
  @test.assert_eq(m.get_by_left("c"), Some(3))
  @test.assert_eq(m.get_by_left("d"), Some(4))
}

///|
test "get_by_right resolves every value after batch insert" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  @test.assert_eq(m.get_by_right(1), Some("a"))
  @test.assert_eq(m.get_by_right(2), Some("b"))
  @test.assert_eq(m.get_by_right(3), Some("c"))
  @test.assert_eq(m.get_by_right(4), Some("d"))
}

///|
test "contains reflects removal on both sides" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.contains_left("a"), false)
  @test.assert_eq(m.contains_right(1), false)
  @test.assert_eq(m.contains_left("b"), true)
  @test.assert_eq(m.contains_right(2), true)
}

///|
test "get returns updated value after C2 rebind" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  m.insert("a", 99) |> ignore
  @test.assert_eq(m.get_by_left("a"), Some(99))
  @test.assert_eq(m.get_by_right(99), Some("a"))
}

///|
test "get returns new owner after C3 takeover" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  m.insert("b", 1) |> ignore
  @test.assert_eq(m.get_by_right(1), Some("b"))
  @test.assert_eq(m.get_by_left("b"), Some(1))
}

// ---------------------------------------------------------------------------
// Removal
// ---------------------------------------------------------------------------

///|
test "remove_by_left returns the removed right value" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.remove_by_left("a"), Some(1))
  @test.assert_eq(m.remove_by_left("b"), Some(2))
}

///|
test "remove_by_right returns the removed left key" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.remove_by_right(1), Some("a"))
  @test.assert_eq(m.remove_by_right(2), Some("b"))
}

///|
test "remove the first element" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.first(), Some(("b", 2)))
  @test.assert_eq(m.get_index_of_left("b"), Some(0))
}

///|
test "remove the last element" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  m.remove_by_left("c") |> ignore
  @test.assert_eq(m.last(), Some(("b", 2)))
  @test.assert_eq(m.len(), 2)
}

///|
test "remove the only element leaves an empty map" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_eq(m.remove_by_left("a"), Some(1))
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.first(), None)
  @test.assert_eq(m.last(), None)
}

///|
test "remove all elements one by one (forward)" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  @test.assert_eq(m.remove_by_left("a"), Some(1))
  @test.assert_eq(m.remove_by_left("b"), Some(2))
  @test.assert_eq(m.remove_by_left("c"), Some(3))
  @test.assert_eq(m.remove_by_left("d"), Some(4))
  @test.assert_eq(m.is_empty(), true)
}

///|
test "remove all elements in reverse insertion order" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  @test.assert_eq(m.remove_by_left("d"), Some(4))
  @test.assert_eq(m.remove_by_left("c"), Some(3))
  @test.assert_eq(m.remove_by_left("b"), Some(2))
  @test.assert_eq(m.remove_by_left("a"), Some(1))
  @test.assert_eq(m.is_empty(), true)
}

///|
test "removing a missing key after draining returns None" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.remove_by_left("a"), None)
  @test.assert_eq(m.remove_by_right(1), None)
}

///|
test "interleaved insert and remove stay consistent" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 100 {
    m.insert(i, i * 3) |> ignore
    if i % 2 == 0 {
      m.remove_by_left(i / 2) |> ignore
    }
    i = i + 1
  }
  // every present key resolves on both sides
  let arr = m.into_array()
  let mut j = 0
  while j < arr.length() {
    let (l, r) = arr[j]
    @test.assert_eq(m.get_by_right(r), Some(l))
    j = j + 1
  }
}

///|
test "remove then contains is false on both directions" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  m.remove_by_right(1) |> ignore
  @test.assert_eq(m.contains_left("a"), false)
  @test.assert_eq(m.contains_right(1), false)
}

// ---------------------------------------------------------------------------
// Index access
// ---------------------------------------------------------------------------

///|
test "get_index with negative index returns None" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_eq(m.get_index(-5), None)
}

///|
test "get_index equal to len returns None" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.get_index(2), None)
}

///|
test "get_index_of_left reindexes after a middle removal" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  m.remove_by_left("b") |> ignore
  @test.assert_eq(m.get_index_of_left("a"), Some(0))
  @test.assert_eq(m.get_index_of_left("c"), Some(1))
  @test.assert_eq(m.get_index_of_left("d"), Some(2))
  @test.assert_eq(m.get_index_of_left("b"), None)
}

///|
test "get_index_of_right reindexes after removal" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.get_index_of_right(2), Some(0))
  @test.assert_eq(m.get_index_of_right(3), Some(1))
  @test.assert_eq(m.get_index_of_right(1), None)
}

///|
test "first after removing the first element advances" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.first(), Some(("b", 2)))
}

///|
test "last after removing the last element retreats" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.remove_by_left("b") |> ignore
  @test.assert_eq(m.last(), Some(("a", 1)))
}

///|
test "get_index in the middle" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
    ("e", 5),
  ])
  @test.assert_eq(m.get_index(2), Some(("c", 3)))
}

///|
test "get_index_of_left agrees with iteration position for all keys" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("d", 4),
    ("b", 2),
    ("e", 5),
    ("a", 1),
    ("c", 3),
  ])
  let arr = m.into_array()
  let mut i = 0
  while i < arr.length() {
    let (l, _) = arr[i]
    @test.assert_eq(m.get_index_of_left(l), Some(i))
    i = i + 1
  }
}

///|
test "C2 rebind leaves the index unchanged" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  m.insert("b", 200) |> ignore
  @test.assert_eq(m.get_index_of_left("b"), Some(1))
  @test.assert_eq(m.get_index(1), Some(("b", 200)))
}

// ---------------------------------------------------------------------------
// Construction / capacity
// ---------------------------------------------------------------------------

///|
test "from_array on an empty array yields an empty map" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.BiMap::from_array([],
  )
  @test.assert_eq(m.is_empty(), true)
}

///|
test "from_array on a single pair" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.first(), Some(("a", 1)))
}

///|
test "from_array where every pair shares the left key" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("a", 2), ("a", 3)])
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(3))
}

///|
test "from_array where every pair shares the right value" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 1), ("c", 1)])
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_right(1), Some("c"))
}

///|
test "with_capacity(0) still works" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.with_capacity(
    0,
  )
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.get_by_left("a"), Some(1))
}

///|
test "with_capacity rounds up to a power of two" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.with_capacity(
    17,
  )
  // capacity must be a power of two >= 17
  let cap = m.capacity()
  @test.assert_eq(cap & (cap - 1), 0)
  if cap < 17 {
    @test.fail("capacity must be >= requested")
  }
}

///|
test "capacity is always at least len" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 200 {
    m.insert(i, i) |> ignore
    if m.capacity() < m.len() {
      @test.fail("capacity dropped below len")
    }
    i = i + 1
  }
}

///|
test "copy of an empty map is empty and independent" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  let c = m.copy()
  c.insert("x", 1) |> ignore
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(c.len(), 1)
}

///|
test "mutating the original does not affect an earlier copy" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  let c = m.copy()
  m.insert("b", 2) |> ignore
  @test.assert_eq(c.len(), 1)
  @test.assert_eq(c.contains_left("b"), false)
  @test.assert_eq(m.len(), 2)
}

///|
test "to_inverse of an empty map is empty" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  let inv = m.to_inverse()
  @test.assert_eq(inv.is_empty(), true)
}

///|
test "to_inverse of a single pair swaps it" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  let inv = m.to_inverse()
  @test.assert_eq(inv.get_by_left(1), Some("a"))
  @test.assert_eq(inv.get_by_right("a"), Some(1))
}

// ---------------------------------------------------------------------------
// Eq / Hash extras
// ---------------------------------------------------------------------------

///|
test "Eq: two empty maps are equal" {
  let a : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  let b : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(a, b)
}

///|
test "Eq: empty is not equal to non-empty" {
  let a : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  let b = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_not_eq(a, b)
}

///|
test "Hash: hashing the same map twice is stable" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(Hash::hash(m), Hash::hash(m))
}

///|
test "Eq: same pair set reached by different operation paths is equal" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let m2 : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m2.insert("a", 5) |> ignore // (a,5)
  m2.insert("b", 2) |> ignore // (a,5),(b,2)
  m2.insert("c", 5) |> ignore // C3: c takes 5 from a -> (b,2),(c,5)
  m2.insert("a", 1) |> ignore // C0 -> (b,2),(c,5),(a,1)
  m2.remove_by_left("c") |> ignore // (b,2),(a,1)
  // m2 holds {(a,1),(b,2)} like m1, but in a different insertion order
  @test.assert_eq(m2, m1)
}

// ---------------------------------------------------------------------------
// Show / ToJson / Default extras
// ---------------------------------------------------------------------------

///|
test "Show of a single pair" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_eq(m.to_string(), "BiMap{a <-> 1}")
}

///|
test "Show reflects removal" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.to_string(), "BiMap{b <-> 2}")
}

///|
test "ToJson of an empty map is an empty object" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  let expected : Map[String, Json] = Map([])
  @test.assert_eq(m.to_json(), Json::object(expected))
}

///|
test "ToJson of a single pair" {
  let m = @aurasuisui/bimap.BiMap::from_array([("k", 7)])
  let expected : Map[String, Json] = Map([])
  expected["k"] = ToJson::to_json(7)
  @test.assert_eq(m.to_json(), Json::object(expected))
}

///|
test "Default then insert behaves like new" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = Default::default()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.len(), 1)
}

// ---------------------------------------------------------------------------
// Views + entry helpers (v0.2.0 M2, ORIGINAL extension — no Rust counterpart)
// ---------------------------------------------------------------------------

// Compile-time pins for minimal trait bounds (0053-style guard): each helper
// carries EXACTLY the bounds its method requires, so an over-constrained
// signature would fail to compile here. In particular left_keys must work with
// NO bounds at all.

///|
fn[L, R] left_keys_zero_bound(m : @aurasuisui/bimap.BiMap[L, R]) -> Array[L] {
  m.left_keys()
}

///|
fn[L : Hash + Eq, R] right_values_one_bound(
  m : @aurasuisui/bimap.BiMap[L, R],
) -> Array[R] {
  m.right_values()
}

///|
fn[L : Hash + Eq, R : Eq] contains_pair_two_bound(
  m : @aurasuisui/bimap.BiMap[L, R],
  l : L,
  r : R,
) -> Bool {
  m.contains_pair(l, r)
}

///|
test "contains_pair: the exact pair (C1 state) is true" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.contains_pair("a", 1), true)
  @test.assert_eq(m.contains_pair("b", 2), true)
}

///|
test "contains_pair: half-present sides and absent pairs are false" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_eq(m.contains_pair("a", 2), false) // l present, r wrong
  @test.assert_eq(m.contains_pair("b", 1), false) // r present, l wrong
  @test.assert_eq(m.contains_pair("b", 2), false) // both absent
}

///|
test "contains_pair on an empty map is false" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.contains_pair("a", 1), false)
}

///|
test "left_keys returns the insertion-ordered snapshot" {
  let m = @aurasuisui/bimap.BiMap::from_array([("d", 4), ("b", 2), ("a", 1)])
  @test.assert_eq(m.left_keys(), ["d", "b", "a"])
}

///|
test "left_keys snapshot is independent in both directions" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let keys = m.left_keys()
  keys.push("zzz") // mutating the snapshot must not touch the map
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.contains_left("zzz"), false)
  @test.assert_eq(m.left_keys(), ["a", "b"])
  m.remove_by_left("a") |> ignore // mutating the map must not touch the snapshot
  @test.assert_eq(keys, ["a", "b", "zzz"])
}

///|
test "right_values returns the insertion-ordered snapshot" {
  let m = @aurasuisui/bimap.BiMap::from_array([("d", 4), ("b", 2), ("a", 1)])
  @test.assert_eq(m.right_values(), [4, 2, 1])
}

///|
test "right_values snapshot is independent" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let vals = m.right_values()
  vals.push(99)
  @test.assert_eq(m.contains_right(99), false)
  @test.assert_eq(m.right_values(), [1, 2])
}

///|
test "left_keys and right_values on an empty map are empty" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.left_keys(), [])
  @test.assert_eq(m.right_values(), [])
}

///|
test "left_keys/right_values agree with each other pair by pair" {
  let m = @aurasuisui/bimap.BiMap::from_array([("d", 4), ("b", 2), ("a", 1)])
  let ks = m.left_keys()
  let vs = m.right_values()
  @test.assert_eq(ks.length(), m.len())
  let mut i = 0
  while i < ks.length() {
    @test.assert_eq(m.get_by_left(ks[i]), Some(vs[i]))
    i = i + 1
  }
}

///|
test "minimal bounds: the views/membership pins compile and run" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(left_keys_zero_bound(m), ["a", "b"])
  @test.assert_eq(right_values_one_bound(m), [1, 2])
  @test.assert_eq(contains_pair_two_bound(m, "a", 1), true)
  @test.assert_eq(contains_pair_two_bound(m, "a", 2), false)
}

///|
test "get_or_insert_left: present key returns its right, no mutation" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let it = m.iter() // an active iterator: the get path must not bump version
  @test.assert_eq(m.get_or_insert_left("a", 99), 1)
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.into_array(), [("a", 1), ("b", 2)])
  @test.assert_eq(m.get_by_right(99), None)
  @test.assert_eq(it.next(), Some(("a", 1)))
  @test.assert_eq(it.next(), Some(("b", 2)))
}

///|
test "get_or_insert_left: absent key + free right inserts and returns r" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_eq(m.get_or_insert_left("b", 2), 2)
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left("b"), Some(2))
  @test.assert_eq(m.get_by_right(2), Some("b"))
}

///|
test "get_or_insert_left: C3 takeover evicts the old owner of r" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  // "c" is absent but 2 is bound to "b": full insert semantics, NOT
  // "insert only when both sides are free" — b is evicted entirely.
  @test.assert_eq(m.get_or_insert_left("c", 2), 2)
  @test.assert_eq(m.len(), 2) // takeover: net length unchanged
  @test.assert_eq(m.get_by_left("c"), Some(2))
  @test.assert_eq(m.get_by_right(2), Some("c"))
  @test.assert_eq(m.contains_left("b"), false)
  @test.assert_eq(m.contains_pair("c", 2), true) // l <-> r holds after the call
}

///|
test "get_or_insert_right: present value returns its left, no mutation" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.get_or_insert_right(1, "zzz"), "a")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.into_array(), [("a", 1), ("b", 2)])
}

///|
test "get_or_insert_right: absent value + free left inserts and returns l" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_eq(m.get_or_insert_right(2, "b"), "b")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_right(2), Some("b"))
  @test.assert_eq(m.get_by_left("b"), Some(2))
}

///|
test "get_or_insert_right: C2 rebind evicts the old right of l" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  // 3 is absent but "b" is bound to 2: full insert semantics — the pair
  // (b, 2) is evicted by a C2 rebind of b onto 3.
  @test.assert_eq(m.get_or_insert_right(3, "b"), "b")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left("b"), Some(3))
  @test.assert_eq(m.get_by_right(2), None)
  @test.assert_eq(m.contains_pair("b", 3), true) // l <-> r holds after the call
}
