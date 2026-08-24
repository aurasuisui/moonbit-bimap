// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Unit + property tests for BiBTreeMap: C0-C4 matrix, sorted-order
// assertions, removal symmetry, first/last/range (sorted dividends), the
// M2-parallel views/entry helpers, retain, traits, and QuickCheck invariant
// checks. Black-box via @aurasuisui/bimap.

///|
fn[L : Show, R : Show] bbtree_classify(
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

///|
/// Assert every black-box observable invariant of a sorted bijection: the two
/// sides are mutual inverses, both sides are unique, the pair list is
/// STRICTLY ascending by left key, and first/last agree with its ends.
fn[L : Compare + Hash + Debug, R : Compare + Hash + Debug] check_bbtree_bijection(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
) -> Unit raise {
  let arr = m.into_array()
  @test.assert_eq(arr.length(), m.len())
  let lefts : Map[L, Int] = Map([])
  let rights : Map[R, Int] = Map([])
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    @test.assert_eq(m.get_by_left(l), Some(r))
    @test.assert_eq(m.get_by_right(r), Some(l))
    @test.assert_eq(m.contains_left(l), true)
    @test.assert_eq(m.contains_right(r), true)
    if i > 0 {
      // strictly ascending by left key (bijection ⟹ left keys unique)
      @test.assert_eq(Compare::compare(arr[i - 1].0, l) < 0, true)
    }
    lefts[l] = 1
    rights[r] = 1
    i = i + 1
  }
  @test.assert_eq(lefts.length(), m.len())
  @test.assert_eq(rights.length(), m.len())
  match (m.first(), m.last(), arr.length() > 0) {
    (Some(fl), Some(ll), true) => {
      @test.assert_eq(fl, arr[0])
      @test.assert_eq(ll, arr[arr.length() - 1])
    }
    (None, None, false) => ()
    _ => @test.fail("first/last disagree with the pair list ends")
  }
}

// ---------------------------------------------------------------------------
// C0-C4 insertion semantics
// ---------------------------------------------------------------------------

///|
test "C0: insert into empty map returns Neither" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  @test.assert_eq(bbtree_classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("a"))
}

///|
test "C0: two fresh inserts both return Neither and stay sorted" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  @test.assert_eq(bbtree_classify(m.insert("b", 2)), "Neither")
  @test.assert_eq(bbtree_classify(m.insert("a", 1)), "Neither")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.into_array(), [("a", 1), ("b", 2)])
}

///|
test "C1: exact reinsert returns Pair and is idempotent" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(bbtree_classify(m.insert("a", 1)), "Pair(a, 1)")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("a"))
}

///|
test "C2: rebinding a left key returns Left with the old right" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(bbtree_classify(m.insert("a", 2)), "Left(a, 1)")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(2))
  @test.assert_eq(m.get_by_right(1), None)
  @test.assert_eq(m.get_by_right(2), Some("a"))
}

///|
test "C3: a right value handed to a new left key returns Right" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m.insert("a", 1) |> ignore
  @test.assert_eq(bbtree_classify(m.insert("b", 1)), "Right(a, 1)")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), None)
  @test.assert_eq(m.get_by_left("b"), Some(1))
  @test.assert_eq(m.get_by_right(1), Some("b"))
}

///|
test "C4: both sides conflict, collapse to one pair, len decreases" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m.insert("a", 1) |> ignore
  m.insert("b", 2) |> ignore
  @test.assert_eq(bbtree_classify(m.insert("a", 2)), "Both((a, 1), (b, 2))")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.into_array(), [("a", 2)])
  @test.assert_eq(m.get_by_right(1), None)
  @test.assert_eq(m.contains_left("b"), false)
}

///|
test "C1 after a C4 collapse stays idempotent" {
  let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m.insert(1, 10) |> ignore
  m.insert(2, 20) |> ignore
  m.insert(1, 20) |> ignore // C4: collapse
  @test.assert_eq(bbtree_classify(m.insert(1, 20)), "Pair(1, 20)")
  @test.assert_eq(m.len(), 1)
}

///|
test "insert_no_overwrite refuses conflicts and inserts fresh pairs" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  @test.assert_eq(m.insert_no_overwrite("a", 1), Ok(()))
  @test.assert_eq(m.insert_no_overwrite("a", 2), Err(("a", 2)))
  @test.assert_eq(m.insert_no_overwrite("b", 1), Err(("b", 1)))
  @test.assert_eq(m.insert_no_overwrite("b", 2), Ok(()))
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.into_array(), [("a", 1), ("b", 2)])
}

// ---------------------------------------------------------------------------
// Lookup
// ---------------------------------------------------------------------------

///|
test "get_by_left resolves every key after batch insert" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("d", 4),
    ("b", 2),
    ("a", 1),
    ("c", 3),
  ])
  @test.assert_eq(m.get_by_left("a"), Some(1))
  @test.assert_eq(m.get_by_left("b"), Some(2))
  @test.assert_eq(m.get_by_left("c"), Some(3))
  @test.assert_eq(m.get_by_left("d"), Some(4))
}

///|
test "get_by_right resolves every value after batch insert" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("d", 4),
    ("b", 2),
    ("a", 1),
    ("c", 3),
  ])
  @test.assert_eq(m.get_by_right(1), Some("a"))
  @test.assert_eq(m.get_by_right(2), Some("b"))
  @test.assert_eq(m.get_by_right(3), Some("c"))
  @test.assert_eq(m.get_by_right(4), Some("d"))
}

///|
test "contains reflects removal on both sides" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.contains_left("a"), false)
  @test.assert_eq(m.contains_right(1), false)
  @test.assert_eq(m.contains_left("b"), true)
  @test.assert_eq(m.contains_right(2), true)
}

///|
test "get returns updated value after C2 rebind" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1)])
  m.insert("a", 99) |> ignore
  @test.assert_eq(m.get_by_left("a"), Some(99))
  @test.assert_eq(m.get_by_right(99), Some("a"))
}

///|
test "get returns new owner after C3 takeover" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1)])
  m.insert("b", 1) |> ignore
  @test.assert_eq(m.get_by_right(1), Some("b"))
  @test.assert_eq(m.get_by_left("b"), Some(1))
}

// ---------------------------------------------------------------------------
// Removal
// ---------------------------------------------------------------------------

///|
test "remove_by_left returns the removed right value" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.remove_by_left("a"), Some(1))
  @test.assert_eq(m.remove_by_left("b"), Some(2))
  @test.assert_eq(m.is_empty(), true)
}

///|
test "remove_by_right returns the removed left key" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.remove_by_right(1), Some("a"))
  @test.assert_eq(m.remove_by_right(2), Some("b"))
  @test.assert_eq(m.is_empty(), true)
}

///|
test "removing the minimum then the maximum element" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.first(), Some(("b", 2)))
  m.remove_by_left("c") |> ignore
  @test.assert_eq(m.last(), Some(("b", 2)))
  @test.assert_eq(m.len(), 1)
}

///|
test "remove the only element leaves an empty map" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1)])
  @test.assert_eq(m.remove_by_left("a"), Some(1))
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.first(), None)
  @test.assert_eq(m.last(), None)
}

///|
test "removing a missing key after draining returns None" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1)])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.remove_by_left("a"), None)
  @test.assert_eq(m.remove_by_right(1), None)
}

///|
test "interleaved insert and remove stay consistent" {
  let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  let mut i = 0
  while i < 100 {
    m.insert(i, i * 3) |> ignore
    if i % 2 == 0 {
      m.remove_by_left(i / 2) |> ignore
    }
    i = i + 1
  }
  let arr = m.into_array()
  let mut j = 0
  while j < arr.length() {
    let (l, r) = arr[j]
    @test.assert_eq(m.get_by_right(r), Some(l))
    j = j + 1
  }
  check_bbtree_bijection(m)
}

// ---------------------------------------------------------------------------
// Sorted dividends: iter / first / last / range
// ---------------------------------------------------------------------------

///|
test "iter yields pairs in ascending left-key order" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("d", 4),
    ("b", 2),
    ("a", 1),
  ])
  @test.assert_eq(m.iter().to_array(), [("a", 1), ("b", 2), ("d", 4)])
}

///|
test "into_array is ascending even after interleaved mutations" {
  let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  let mut i = 0
  while i < 50 {
    m.insert(i * 7 % 40, i) |> ignore
    i = i + 1
  }
  let arr = m.into_array()
  let mut j = 1
  while j < arr.length() {
    @test.assert_eq(arr[j - 1].0 < arr[j].0, true)
    j = j + 1
  }
}

///|
test "first is the smallest left key" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("m", 3),
    ("a", 1),
    ("z", 2),
  ])
  @test.assert_eq(m.first(), Some(("a", 1)))
}

///|
test "last is the largest left key" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("m", 3),
    ("a", 1),
    ("z", 2),
  ])
  @test.assert_eq(m.last(), Some(("z", 2)))
}

///|
test "first and last are None on an empty map" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  @test.assert_eq(m.first(), None)
  @test.assert_eq(m.last(), None)
}

///|
test "first/last advance after removing the extremes" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(m.first(), Some(("b", 2)))
  m.remove_by_left("c") |> ignore
  @test.assert_eq(m.last(), Some(("b", 2)))
}

///|
test "range [lo, hi] is inclusive on BOTH ends" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  // "b"..="c" in Rust terms — both endpoints included
  @test.assert_eq(m.range("b", "c").to_array(), [("b", 2), ("c", 3)])
}

///|
test "range with lo == hi yields the single matching pair" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  @test.assert_eq(m.range("b", "b").to_array(), [("b", 2)])
}

///|
test "range with lo == hi on an absent key yields nothing" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("c", 3)])
  @test.assert_eq(m.range("b", "b").to_array(), [])
}

///|
test "range with lo > hi is empty" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  @test.assert_eq(m.range("c", "a").to_array(), [])
}

///|
test "range bounds absent from the map include interior pairs" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("a", 1),
    ("c", 3),
    ("e", 5),
  ])
  @test.assert_eq(m.range("b", "d").to_array(), [("c", 3)])
}

///|
test "range over the whole key space equals into_array" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("d", 4),
    ("b", 2),
    ("a", 1),
  ])
  @test.assert_eq(m.range("a", "d").to_array(), m.into_array())
}

///|
test "range on an empty map is empty" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  @test.assert_eq(m.range("a", "z").to_array(), [])
}

///|
test "range stays correct after C2/C3/C4 mutations" {
  let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m.insert(1, 10) |> ignore
  m.insert(2, 20) |> ignore
  m.insert(3, 30) |> ignore
  m.insert(2, 99) |> ignore // C2 rebind
  m.insert(4, 10) |> ignore // C3 takeover of 10 from key 1
  m.insert(4, 30) |> ignore // C4: collapse (4,10)+(3,30) -> (4,30)
  @test.assert_eq(m.range(1, 4).to_array(), [(2, 99), (4, 30)])
}

// ---------------------------------------------------------------------------
// Views / entry helpers (M2 parallel)
// ---------------------------------------------------------------------------

///|
test "contains_pair: the exact pair (C1 state) is true" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.contains_pair("a", 1), true)
  @test.assert_eq(m.contains_pair("b", 2), true)
}

///|
test "contains_pair: half-present sides and absent pairs are false" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1)])
  @test.assert_eq(m.contains_pair("a", 2), false)
  @test.assert_eq(m.contains_pair("b", 1), false)
  @test.assert_eq(m.contains_pair("b", 2), false)
}

///|
test "contains_pair on an empty map is false" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  @test.assert_eq(m.contains_pair("a", 1), false)
}

///|
test "left_keys returns keys in ascending order" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("d", 4),
    ("b", 2),
    ("a", 1),
  ])
  @test.assert_eq(m.left_keys(), ["a", "b", "d"])
}

///|
test "left_keys snapshot is independent in both directions" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  let keys = m.left_keys()
  keys.push("zzz")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.contains_left("zzz"), false)
  @test.assert_eq(m.left_keys(), ["a", "b"])
  m.remove_by_left("a") |> ignore
  @test.assert_eq(keys, ["a", "b", "zzz"])
}

///|
test "right_values follows LEFT-key order (not right-value order)" {
  // the sorted-map counterpart of BiMap::right_values: pairs ascending by
  // left key, so the values come out in left-key order
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("b", 20),
    ("a", 10),
    ("c", 30),
  ])
  @test.assert_eq(m.right_values(), [10, 20, 30])
}

///|
test "right_values snapshot is independent" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  let vals = m.right_values()
  vals.push(99)
  @test.assert_eq(m.contains_right(99), false)
  @test.assert_eq(m.right_values(), [1, 2])
}

///|
test "left_keys and right_values on an empty map are empty" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  @test.assert_eq(m.left_keys(), [])
  @test.assert_eq(m.right_values(), [])
}

///|
test "get_or_insert_left: present key returns its right, no mutation" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  let it = m.iter() // the get path must not bump version
  @test.assert_eq(m.get_or_insert_left("a", 99), 1)
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.into_array(), [("a", 1), ("b", 2)])
  @test.assert_eq(m.get_by_right(99), None)
  @test.assert_eq(it.next(), Some(("a", 1)))
  @test.assert_eq(it.next(), Some(("b", 2)))
}

///|
test "get_or_insert_left: absent key + free right inserts and returns r" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1)])
  @test.assert_eq(m.get_or_insert_left("b", 2), 2)
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left("b"), Some(2))
  @test.assert_eq(m.get_by_right(2), Some("b"))
}

///|
test "get_or_insert_left: C3 takeover evicts the old owner of r" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.get_or_insert_left("c", 2), 2)
  @test.assert_eq(m.len(), 2) // takeover: net length unchanged
  @test.assert_eq(m.get_by_left("c"), Some(2))
  @test.assert_eq(m.get_by_right(2), Some("c"))
  @test.assert_eq(m.contains_left("b"), false)
  @test.assert_eq(m.contains_pair("c", 2), true)
}

///|
test "get_or_insert_right: present value returns its left, no mutation" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  let it = m.iter() // the get path must not bump version
  @test.assert_eq(m.get_or_insert_right(1, "zzz"), "a")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.into_array(), [("a", 1), ("b", 2)])
  @test.assert_eq(it.next(), Some(("a", 1)))
  @test.assert_eq(it.next(), Some(("b", 2)))
}

///|
test "get_or_insert_right: absent value + free left inserts and returns l" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1)])
  @test.assert_eq(m.get_or_insert_right(2, "b"), "b")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_right(2), Some("b"))
  @test.assert_eq(m.get_by_left("b"), Some(2))
}

///|
test "get_or_insert_right: C2 rebind evicts the old right of l" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m.get_or_insert_right(3, "b"), "b")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left("b"), Some(3))
  @test.assert_eq(m.get_by_right(2), None)
  @test.assert_eq(m.contains_pair("b", 3), true)
}

// ---------------------------------------------------------------------------
// retain
// ---------------------------------------------------------------------------

///|
test "retain keeps only pairs matching the predicate" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  m.retain(fn(_, r) { r % 2 == 0 })
  @test.assert_eq(m.into_array(), [("b", 2)])
}

///|
test "retain-all is a no-op and does not invalidate iterators" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  let it = m.iter()
  m.retain(fn(_, _) { true })
  @test.assert_eq(it.next(), Some(("a", 1)))
  @test.assert_eq(it.next(), Some(("b", 2)))
  @test.assert_eq(m.len(), 2)
}

///|
test "retain-none empties the map" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  m.retain(fn(_, _) { false })
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.first(), None)
}

///|
test "retain on an empty map is a no-op" {
  let m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m.retain(fn(_, _) { false })
  @test.assert_eq(m.is_empty(), true)
}

///|
test "retain evaluates the predicate exactly once per pair" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
  ])
  let calls = [0]
  m.retain(fn(_, _) {
    calls[0] = calls[0] + 1
    true
  })
  @test.assert_eq(calls[0], 3)
}

///|
test "retain works on a C4-collapsed state" {
  let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m.insert(1, 10) |> ignore
  m.insert(2, 20) |> ignore
  m.insert(1, 20) |> ignore // C4: collapses to {1 <-> 20}
  m.retain(fn(l, _) { l == 1 })
  @test.assert_eq(m.into_array(), [(1, 20)])
}

// ---------------------------------------------------------------------------
// Construction / conversion
// ---------------------------------------------------------------------------

///|
test "from_array resolves duplicate lefts last-wins" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("a", 2)])
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("a"), Some(2))
}

///|
test "from_array resolves duplicate rights last-wins" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 1)])
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_right(1), Some("b"))
}

///|
test "copy is independent in both directions" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  let c = m.copy()
  c.insert("c", 3) |> ignore
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.contains_left("c"), false)
  m.remove_by_left("a") |> ignore
  @test.assert_eq(c.len(), 3)
  @test.assert_eq(c.get_by_left("a"), Some(1))
  check_bbtree_bijection(c)
}

///|
test "to_inverse swaps sides and stays a valid sorted bijection" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("b", 20), ("a", 10)])
  let inv = m.to_inverse()
  @test.assert_eq(inv.into_array(), [(10, "a"), (20, "b")])
  @test.assert_eq(inv.get_by_right("a"), Some(10))
  inv.insert(30, "c") |> ignore
  @test.assert_eq(m.len(), 2) // a COPY, not a live view
  check_bbtree_bijection(inv)
}

///|
test "new and default both start empty" {
  let a : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  let b : @aurasuisui/bimap.BiBTreeMap[String, Int] = Default::default()
  @test.assert_eq(a.is_empty(), true)
  @test.assert_eq(b.is_empty(), true)
  @test.assert_eq(a, b)
}

// ---------------------------------------------------------------------------
// Traits
// ---------------------------------------------------------------------------

///|
test "Eq: same pair set reached by different paths is equal" {
  let m1 = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  let m2 : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  m2.insert("b", 2) |> ignore
  m2.insert("a", 1) |> ignore
  @test.assert_eq(m1, m2)
}

///|
test "Eq: empty is not equal to non-empty" {
  let a : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  let b = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1)])
  @test.assert_not_eq(a, b)
}

///|
test "Hash: equal pair sets hash equal" {
  let m1 = @aurasuisui/bimap.BiBTreeMap::from_array([("a", 1), ("b", 2)])
  let m2 = @aurasuisui/bimap.BiBTreeMap::from_array([("b", 2), ("a", 1)])
  @test.assert_eq(Hash::hash(m1), Hash::hash(m2))
}

///|
test "Show renders pairs in ascending order" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("b", 2), ("a", 1)])
  @test.assert_eq(m.to_string(), "BiBTreeMap{a <-> 1, b <-> 2}")
}

///|
test "ToJson of a single pair" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("k", 7)])
  let expected : Map[String, Json] = Map([])
  expected["k"] = ToJson::to_json(7)
  @test.assert_eq(m.to_json(), Json::object(expected))
}

// ---------------------------------------------------------------------------
// Minimal trait-bound pins (0053-style: over-constrained signatures would
// fail to compile here)
// ---------------------------------------------------------------------------

///|
fn[L, R] zero_bound_first(m : @aurasuisui/bimap.BiBTreeMap[L, R]) -> (L, R)? {
  m.first()
}

///|
fn[L, R] zero_bound_last(m : @aurasuisui/bimap.BiBTreeMap[L, R]) -> (L, R)? {
  m.last()
}

///|
fn[L, R] zero_bound_into_array(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
) -> Array[(L, R)] {
  m.into_array()
}

///|
fn[L, R] zero_bound_iter_all(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
) -> Array[(L, R)] {
  m.iter().to_array()
}

///|
fn[L, R] zero_bound_copy(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
) -> @aurasuisui/bimap.BiBTreeMap[L, R] {
  m.copy()
}

///|
fn[L, R] zero_bound_inverse(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
) -> @aurasuisui/bimap.BiBTreeMap[R, L] {
  m.to_inverse()
}

///|
fn[L, R] zero_bound_left_keys(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
) -> Array[L] {
  m.left_keys()
}

///|
fn[L, R] zero_bound_right_values(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
) -> Array[R] {
  m.right_values()
}

///|
fn[L : Compare, R] one_bound_range(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
  lo : L,
  hi : L,
) -> Array[(L, R)] {
  m.range(lo, hi).to_array()
}

///|
fn[L, R : Compare] one_bound_get_right(
  m : @aurasuisui/bimap.BiBTreeMap[L, R],
  r : R,
) -> L? {
  m.get_by_right(r)
}

///|
test "minimal bounds: zero-bound and one-side pins compile and run" {
  let m = @aurasuisui/bimap.BiBTreeMap::from_array([("b", 2), ("a", 1)])
  @test.assert_eq(zero_bound_first(m), Some(("a", 1)))
  @test.assert_eq(zero_bound_last(m), Some(("b", 2)))
  @test.assert_eq(zero_bound_into_array(m), [("a", 1), ("b", 2)])
  @test.assert_eq(zero_bound_iter_all(m), [("a", 1), ("b", 2)])
  @test.assert_eq(zero_bound_copy(m), m)
  @test.assert_eq(zero_bound_inverse(m).get_by_left(1), Some("a"))
  @test.assert_eq(zero_bound_left_keys(m), ["a", "b"])
  @test.assert_eq(zero_bound_right_values(m), [1, 2])
  @test.assert_eq(one_bound_range(m, "a", "b"), [("a", 1), ("b", 2)])
  @test.assert_eq(one_bound_get_right(m, 2), Some("b"))
}

// ---------------------------------------------------------------------------
// QuickCheck invariant guards
// ---------------------------------------------------------------------------

///|
test "qc: sorted bijection invariants hold after random inserts" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(50)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
    let mut i = 0
    while i < pairs.length() {
      let (l, r) = pairs[i]
      m.insert(l, r) |> ignore
      i = i + 1
    }
    check_bbtree_bijection(m)
    c = c + 1
  }
}

///|
test "qc: invariants hold after mixed insert / remove operations" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(50)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
    let mut i = 0
    while i < pairs.length() {
      let (l, r) = pairs[i]
      if i % 3 == 0 {
        m.insert(l, r) |> ignore
      } else if i % 3 == 1 {
        m.remove_by_left(l) |> ignore
      } else {
        m.remove_by_right(r) |> ignore
      }
      i = i + 1
    }
    check_bbtree_bijection(m)
    c = c + 1
  }
}

///|
test "qc: invariants hold on small-key maps (forces many C2/C3/C4)" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(50)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
    let mut i = 0
    while i < pairs.length() {
      let (l, r) = pairs[i]
      m.insert(l % 4, r % 4) |> ignore
      i = i + 1
    }
    check_bbtree_bijection(m)
    c = c + 1
  }
}

///|
test "qc: retain keeps exactly the satisfying pairs; invariants hold" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(60)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m = @aurasuisui/bimap.BiBTreeMap::from_array(pairs)
    m.retain(fn(l : Int, r : Int) -> Bool { (l + r) % 3 != 0 })
    let arr = m.into_array()
    let mut i = 0
    while i < arr.length() {
      let (l, r) = arr[i]
      @test.assert_eq((l + r) % 3 != 0, true)
      i = i + 1
    }
    check_bbtree_bijection(m)
    c = c + 1
  }
}
