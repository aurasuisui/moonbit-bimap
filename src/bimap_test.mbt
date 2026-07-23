// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Unit tests for the BiMap core: insertion semantics (C0-C4), bidirectional
// lookup, removal, and size queries. Black-box via @aurasuisui/bimap.
//
// `Overwritten` results are checked through `classify`, which pattern-matches
// the value into a String (MoonBit cannot construct a cross-package nullary
// enum variant in value position, but matching works fine). The String also
// captures the payloads, so both the variant and its data are asserted.

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

test "C0: insert into empty map returns Neither" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("a"))
}

test "C0: two fresh inserts both return Neither" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(classify(m.insert("b", 2)), "Neither")
  @test.assert_eq(m.len(), 2)
}

test "C1: exact reinsert returns Pair and is idempotent" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(classify(m.insert("a", 1)), "Pair(a, 1)")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("a"))
}

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

test "C1 right after C4: reinserting the surviving pair is Pair" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 4) |> ignore
  m.insert("c", 2) |> ignore
  m.insert("a", 2) |> ignore
  @test.assert_eq(classify(m.insert("a", 2)), "Pair(a, 2)")
  @test.assert_eq(m.len(), 1)
}

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

test "get_by_left miss returns None" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.get_by_left("zzz"), None)
}

test "get_by_right miss returns None" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.get_by_right(999), None)
}

test "contains_left / contains_right" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.contains_left("a"), true)
  @test.assert_eq(m.contains_left("b"), false)
  @test.assert_eq(m.contains_right(1), true)
  @test.assert_eq(m.contains_right(2), false)
}

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

test "remove_by_left on missing key returns None and changes nothing" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.remove_by_left("zzz"), None)
  @test.assert_eq(m.len(), 1)
}

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

test "remove_by_right on missing value returns None" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(m.remove_by_right(999), None)
  @test.assert_eq(m.len(), 1)
}

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

test "remove then reinsert reuses the tombstone path correctly" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  m.remove_by_left("a") |> ignore
  @test.assert_eq(classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("a"))
  @test.assert_eq(m.len(), 1)
}

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
// Size queries / construction
// ---------------------------------------------------------------------------

test "new map is empty" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.len(), 0)
}

test "with_capacity reports at least the requested capacity" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.with_capacity(
    100,
  )
  @test.assert_eq(m.is_empty(), true)
  if m.capacity() < 100 {
    @test.fail("capacity should be >= requested")
  }
}

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
