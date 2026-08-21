// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Unit tests for the BiMap core: insertion semantics (C0-C4), bidirectional
// lookup, removal, and size queries. Black-box via @aurasuisui/bimap.
//
// `Overwritten` results are checked through `classify`, which pattern-matches
// the value into a String (MoonBit cannot construct a cross-package nullary
// enum variant in value position, but matching works fine). The String also
// captures the payloads, so both the variant and its data are asserted.

///|
fn[L : Show, R : Show] classify(
  o : @aurasuisui/bimap.Overwritten[L, R],
) -> String {
  match o {
    @aurasuisui/bimap.Neither => "Neither"
    @aurasuisui/bimap.Left(l, r) => "Left(\{l}, \{r})"
    @aurasuisui/bimap.Right(l, r) => "Right(\{l}, \{r})"
    @aurasuisui/bimap.Both((l1, r1), (l2, r2)) =>
      "Both((\{l1}, \{r1}), (\{l2}, \{r2}))"
    @aurasuisui/bimap.Pair(l, r) => "Pair(\{l}, \{r})"
  }
}

// ---------------------------------------------------------------------------
// C0-C4 insertion semantics
// ---------------------------------------------------------------------------

///|
test "C0: insert into empty map returns Neither" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("a"))
}

///|
test "C0: two fresh inserts both return Neither" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(classify(m.insert("b", 2)), "Neither")
  @test.assert_eq(m.len(), 2)
}

///|
test "C1: exact reinsert returns Pair and is idempotent" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(classify(m.insert("a", 1)), "Pair(a, 1)")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("a"))
}

///|
test "C2: rebinding a left key returns Left with the old right" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  @test.assert_eq(classify(m.insert("a", 4)), "Left(a, 1)")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left("a"), Some(4))
  @test.assert_eq(m.get_by_right(1), None)
  @test.assert_eq(m.get_by_right(4), Some("a"))
}

///|
test "C3: rebinding a right value returns Right with the old left" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  @test.assert_eq(classify(m.insert("c", 2)), "Right(b, 2)")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left("b"), None)
  @test.assert_eq(m.get_by_right(2), Some("c"))
  @test.assert_eq(m.get_by_left("c"), Some(2))
}

///|
test "C4: both-sides conflict collapses two pairs into one" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 4) |> ignore
  m.insert("c", 2) |> ignore
  @test.assert_eq(classify(m.insert("a", 2)), "Both((a, 4), (c, 2))")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(2))
  @test.assert_eq(m.get_by_right(2), Some("a"))
  // both old pairs are fully cleared
  @test.assert_eq(m.get_by_right(4), None)
  @test.assert_eq(m.get_by_left("c"), None)
}

///|
test "C1 right after C4: reinserting the surviving pair is Pair" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 4) |> ignore
  m.insert("c", 2) |> ignore
  m.insert("a", 2) |> ignore
  @test.assert_eq(classify(m.insert("a", 2)), "Pair(a, 2)")
  @test.assert_eq(m.len(), 1)
}

///|
test "reproduce the full Rust bimap golden sequence" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(classify(m.insert("b", 2)), "Neither")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(classify(m.insert("a", 4)), "Left(a, 1)")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(classify(m.insert("c", 2)), "Right(b, 2)")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(classify(m.insert("a", 2)), "Both((a, 4), (c, 2))")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(classify(m.insert("a", 2)), "Pair(a, 2)")
  @test.assert_eq(m.len(), 1)
}

///|
test "C2 rebinding keeps the left key's insertion position" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  m.insert("c", 3) |> ignore
  m.insert("b", 99) |> ignore // rebind b; order should stay [a, b, c]
  let arr = m.into_array()
  @test.assert_eq(arr.length(), 3)
  @test.assert_eq(arr[0], ("a", 1))
  @test.assert_eq(arr[1], ("b", 99))
  @test.assert_eq(arr[2], ("c", 3))
}

///|
test "empty-string key behaves normally" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(classify(m.insert("", 0)), "Neither")
  @test.assert_eq(m.get_by_left(""), Some(0))
  @test.assert_eq(classify(m.insert("", 0)), "Pair(, 0)")
  @test.assert_eq(classify(m.insert("", 5)), "Left(, 0)")
  @test.assert_eq(m.get_by_left(""), Some(5))
}

// ---------------------------------------------------------------------------
// Bidirectional lookup
// ---------------------------------------------------------------------------

///|
test "get_by_left miss returns None" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.get_by_left("zzz"), None)
}

///|
test "get_by_right miss returns None" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.get_by_right(999), None)
}

///|
test "contains_left / contains_right" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.contains_left("a"), true)
  @test.assert_eq(m.contains_left("b"), false)
  @test.assert_eq(m.contains_right(1), true)
  @test.assert_eq(m.contains_right(2), false)
}

///|
test "lookup symmetry: get_by_left(l)==Some(r) iff get_by_right(r)==Some(l)" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  m.insert("c", 3) |> ignore
  let arr = m.into_array()
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    @test.assert_eq(m.get_by_left(l), Some(r))
    @test.assert_eq(m.get_by_right(r), Some(l))
    i = i + 1
  }
}

// ---------------------------------------------------------------------------
// Removal
// ---------------------------------------------------------------------------

///|
test "remove_by_left removes both directions" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  @test.assert_eq(m.remove_by_left("a"), Some(1))
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), None)
  @test.assert_eq(m.get_by_right(1), None)
  @test.assert_eq(m.get_by_left("b"), Some(2))
}

///|
test "remove_by_left on missing key returns None and changes nothing" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.remove_by_left("zzz"), None)
  @test.assert_eq(m.len(), 1)
}

///|
test "remove_by_right removes both directions" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  @test.assert_eq(m.remove_by_right(2), Some("b"))
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_right(2), None)
  @test.assert_eq(m.get_by_left("b"), None)
  @test.assert_eq(m.get_by_left("a"), Some(1))
}

///|
test "remove_by_right on missing value returns None" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.remove_by_right(999), None)
  @test.assert_eq(m.len(), 1)
}

///|
test "removal shrinks the order, keeping remaining indices correct" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  m.insert("c", 3) |> ignore
  m.remove_by_left("b") |> ignore
  let arr = m.into_array()
  @test.assert_eq(arr.length(), 2)
  @test.assert_eq(arr[0], ("a", 1))
  @test.assert_eq(arr[1], ("c", 3))
}

///|
test "remove then reinsert reuses the tombstone path correctly" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.remove_by_left("a") |> ignore
  @test.assert_eq(classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("a"))
  @test.assert_eq(m.len(), 1)
}

///|
test "drain to empty then is_empty" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  m.remove_by_left("a") |> ignore
  m.remove_by_left("b") |> ignore
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.len(), 0)
  @test.assert_eq(m.into_array().length(), 0)
}

// ---------------------------------------------------------------------------
// Bulk removal: retain
// ---------------------------------------------------------------------------

///|
test "retain keeps only pairs matching the predicate" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  m.retain(fn(_, r) { r % 2 == 0 })
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.into_array(), [("b", 2), ("d", 4)])
}

///|
test "retain preserves the relative insertion order of kept pairs" {
  let m = @aurasuisui/bimap.BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
    ("e", 5),
  ])
  m.retain(fn(l, _) { l == "a" || l == "c" || l == "e" })
  @test.assert_eq(m.into_array(), [("a", 1), ("c", 3), ("e", 5)])
  @test.assert_eq(m.get_index_of_left("e"), Some(2))
}

///|
test "retain-all is a no-op and does not invalidate iterators" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let it = m.iter()
  m.retain(fn(_, _) { true })
  // no version bump happened -> the pre-retain iterator still works
  // (a wrongful bump would abort here and fail the test)
  @test.assert_eq(it.next(), Some(("a", 1)))
  @test.assert_eq(it.next(), Some(("b", 2)))
  @test.assert_eq(m.len(), 2)
}

///|
test "retain-none empties the map" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  m.retain(fn(_, _) { false })
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.first(), None)
  @test.assert_eq(m.into_array().length(), 0)
}

///|
test "retain on an empty map is a no-op" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.retain(fn(_, _) { false })
  @test.assert_eq(m.is_empty(), true)
}

///|
test "retain evaluates the predicate exactly once per pair" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let calls = [0]
  m.retain(fn(_, _) {
    calls[0] = calls[0] + 1
    true
  })
  @test.assert_eq(calls[0], 3)
}

///|
test "retain works on a C4-collapsed state" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(1, 10) |> ignore
  m.insert(2, 20) |> ignore
  m.insert(1, 20) |> ignore // C4: collapses to {1 <-> 20}
  m.retain(fn(l, _) { l == 1 })
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left(1), Some(20))
  @test.assert_eq(m.get_by_right(20), Some(1))
}

// ---------------------------------------------------------------------------
// Size queries / construction
// ---------------------------------------------------------------------------

///|
test "new map is empty" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.len(), 0)
}

///|
test "with_capacity reports at least the requested capacity" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.with_capacity(
    100,
  )
  @test.assert_eq(m.is_empty(), true)
  if m.capacity() < 100 {
    @test.fail("capacity should be >= requested")
  }
}

///|
test "into_array preserves insertion order" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("b", 2) |> ignore
  m.insert("a", 1) |> ignore
  m.insert("c", 3) |> ignore
  let arr = m.into_array()
  @test.assert_eq(arr.length(), 3)
  @test.assert_eq(arr[0], ("b", 2))
  @test.assert_eq(arr[1], ("a", 1))
  @test.assert_eq(arr[2], ("c", 3))
}

// ---------------------------------------------------------------------------
// insert_no_overwrite
// ---------------------------------------------------------------------------

///|
test "insert_no_overwrite: fresh insert returns Ok" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.insert_no_overwrite("a", 1), Ok(()))
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
}

///|
test "insert_no_overwrite: left conflict returns Err and changes nothing" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.insert_no_overwrite("a", 99), Err(("a", 99)))
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(99), None)
}

///|
test "insert_no_overwrite: right conflict returns Err and changes nothing" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.insert_no_overwrite("z", 1), Err(("z", 1)))
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("z"), None)
  @test.assert_eq(m.get_by_right(1), Some("a"))
}

///|
test "insert_no_overwrite: both-sides conflict (C4 shape) returns Err, no collapse" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 4) |> ignore
  m.insert("c", 2) |> ignore
  @test.assert_eq(m.insert_no_overwrite("a", 2), Err(("a", 2)))
  // unlike insert(), nothing collapses
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left("a"), Some(4))
  @test.assert_eq(m.get_by_left("c"), Some(2))
}

///|
test "insert_no_overwrite: exact existing pair returns Err" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.insert_no_overwrite("a", 1), Err(("a", 1)))
  @test.assert_eq(m.len(), 1)
}

// ---------------------------------------------------------------------------
// Index access
// ---------------------------------------------------------------------------

///|
test "get_index: first and last by position" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  @test.assert_eq(m.get_index(0), Some(("b", 2)))
  @test.assert_eq(m.get_index(2), Some(("c", 3)))
  @test.assert_eq(m.get_index(1), Some(("a", 1)))
}

///|
test "get_index: out of bounds returns None" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.get_index(-1), None)
  @test.assert_eq(m.get_index(2), None)
  @test.assert_eq(m.get_index(100), None)
}

///|
test "get_index_of_left: hit and miss" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  @test.assert_eq(m.get_index_of_left("b"), Some(0))
  @test.assert_eq(m.get_index_of_left("a"), Some(1))
  @test.assert_eq(m.get_index_of_left("c"), Some(2))
  @test.assert_eq(m.get_index_of_left("zzz"), None)
}

///|
test "get_index_of_right: hit and miss" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  @test.assert_eq(m.get_index_of_right(2), Some(0))
  @test.assert_eq(m.get_index_of_right(1), Some(1))
  @test.assert_eq(m.get_index_of_right(3), Some(2))
  @test.assert_eq(m.get_index_of_right(999), None)
}

///|
test "first / last on non-empty and empty maps" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  @test.assert_eq(m.first(), Some(("b", 2)))
  @test.assert_eq(m.last(), Some(("c", 3)))
  let empty : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(empty.first(), None)
  @test.assert_eq(empty.last(), None)
}

///|
test "single element: first == last" {
  let m = @aurasuisui/bimap.BiMap::from_array([("x", 42)])
  @test.assert_eq(m.first(), Some(("x", 42)))
  @test.assert_eq(m.last(), Some(("x", 42)))
}

///|
test "insertion order == iteration order == index order" {
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
    @test.assert_eq(m.get_index(i), Some(arr[i]))
    let (l, _) = arr[i]
    @test.assert_eq(m.get_index_of_left(l), Some(i))
    i = i + 1
  }
}

///|
test "C4 collapse reindexes the survivors correctly" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  // collapse (a,1) and (b,2) into (a,2)
  m.insert("a", 2) |> ignore
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_index(0), Some(("a", 2)))
  @test.assert_eq(m.get_index(1), Some(("c", 3)))
  @test.assert_eq(m.get_index_of_left("c"), Some(1))
}

// ---------------------------------------------------------------------------
// Construction / conversion
// ---------------------------------------------------------------------------

///|
test "from_array with no duplicates" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  @test.assert_eq(m.len(), 3)
  @test.assert_eq(m.get_by_left("b"), Some(2))
  @test.assert_eq(m.get_by_right(3), Some("c"))
}

///|
test "from_array with duplicate left keys: last wins" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("a", 2)])
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(2))
  @test.assert_eq(m.get_by_right(1), None)
}

///|
test "from_array triggering C4 keeps the count correct" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 4), ("c", 2), ("a", 2)])
  // (a,4) then (c,2) then (a,2) collapses to a single pair (a,2)
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(2))
}

///|
test "copy is a deep, independent copy" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let c = m.copy()
  @test.assert_eq(c.len(), 2)
  @test.assert_eq(c.into_array(), m.into_array())
  // mutate the copy; the original is untouched
  c.insert("z", 99) |> ignore
  @test.assert_eq(c.len(), 3)
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.contains_left("z"), false)
}

///|
test "to_inverse swaps sides and is a copy" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let inv : @aurasuisui/bimap.BiMap[Int, String] = m.to_inverse()
  @test.assert_eq(inv.len(), 2)
  @test.assert_eq(inv.get_by_left(1), Some("a"))
  @test.assert_eq(inv.get_by_left(2), Some("b"))
  @test.assert_eq(inv.get_by_right("a"), Some(1))
  // mutating the inverse does not affect the original
  inv.insert(99, "z") |> ignore
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.contains_left("z"), false)
}

///|
test "to_inverse is an involution: m.to_inverse().to_inverse() == m (as pairs)" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let twice = m.to_inverse().to_inverse()
  @test.assert_eq(twice.into_array(), m.into_array())
}

///|
test "to_inverse preserves pair order" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  let inv = m.to_inverse()
  let arr = inv.into_array()
  @test.assert_eq(arr[0], (2, "b"))
  @test.assert_eq(arr[1], (1, "a"))
  @test.assert_eq(arr[2], (3, "c"))
}
