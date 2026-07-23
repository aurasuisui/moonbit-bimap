// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Tests for the trait implementations (order-independent Eq/Hash, Debug, Show,
// ToJson, Default) and the fail-fast iterators.

// ---------------------------------------------------------------------------
// Order-independent Eq
// ---------------------------------------------------------------------------

///|
test "Eq: same pairs in different insertion order are equal" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let m2 = @aurasuisui/bimap.BiMap::from_array([("c", 3), ("a", 1), ("b", 2)])
  @test.assert_eq(m1, m2)
}

///|
test "Eq: reflexive" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  @test.assert_eq(m, m)
}

///|
test "Eq: symmetric" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let m2 = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1)])
  @test.assert_eq(m1, m2)
  @test.assert_eq(m2, m1)
}

///|
test "Eq: different right values are not equal" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let m2 = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 3)])
  @test.assert_not_eq(m1, m2)
}

///|
test "Eq: different lengths are not equal" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let m2 = @aurasuisui/bimap.BiMap::from_array([("a", 1)])
  @test.assert_not_eq(m1, m2)
}

///|
test "Eq: a left key mapped differently is not equal" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let m2 = @aurasuisui/bimap.BiMap::from_array([("a", 2), ("b", 1)])
  @test.assert_not_eq(m1, m2)
}

// ---------------------------------------------------------------------------
// Order-independent Hash
// ---------------------------------------------------------------------------

///|
test "Hash: same pairs in different order hash equally" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
  let m2 = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("c", 3), ("a", 1)])
  @test.assert_eq(Hash::hash(m1), Hash::hash(m2))
}

///|
test "Hash: equal maps have equal hashes (Eq => Hash)" {
  let m1 = @aurasuisui/bimap.BiMap::from_array([("x", 10), ("y", 20)])
  let m2 = @aurasuisui/bimap.BiMap::from_array([("y", 20), ("x", 10)])
  @test.assert_eq(m1, m2)
  @test.assert_eq(Hash::hash(m1), Hash::hash(m2))
}

///|
test "Hash: empty maps hash equally" {
  let m1 : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  let m2 : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(Hash::hash(m1), Hash::hash(m2))
}

// ---------------------------------------------------------------------------
// Show
// ---------------------------------------------------------------------------

///|
test "Show renders BiMap{left <-> right, ...} in insertion order" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1)])
  @test.assert_eq(m.to_string(), "BiMap{b <-> 2, a <-> 1}")
}

///|
test "Show of empty map" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.to_string(), "BiMap{}")
}

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------

///|
test "Debug renders an opaque BiMap representation" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  debug_inspect(
    m,
    content=(
      #|<BiMap: { "a": 1, "b": 2 }>
    ),
  )
}

// ---------------------------------------------------------------------------
// Default
// ---------------------------------------------------------------------------

///|
test "default() produces an empty map" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = Default::default()
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.len(), 0)
}

// ---------------------------------------------------------------------------
// ToJson
// ---------------------------------------------------------------------------

///|
test "ToJson keys are left.to_string() with no mangling" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let expected : Map[String, Json] = Map([])
  expected["a"] = ToJson::to_json(1)
  expected["b"] = ToJson::to_json(2)
  @test.assert_eq(m.to_json(), Json::object(expected))
}

///|
test "ToJson with integer left keys uses their decimal text" {
  let m = @aurasuisui/bimap.BiMap::from_array([(1, "one"), (2, "two")])
  let expected : Map[String, Json] = Map([])
  expected["1"] = ToJson::to_json("one")
  expected["2"] = ToJson::to_json("two")
  @test.assert_eq(m.to_json(), Json::object(expected))
}

///|
test "ToJson handles composite right values" {
  let m = @aurasuisui/bimap.BiMap::from_array([("primes", [2, 3, 5])])
  let expected : Map[String, Json] = Map([])
  expected["primes"] = ToJson::to_json([2, 3, 5])
  @test.assert_eq(m.to_json(), Json::object(expected))
}

// ---------------------------------------------------------------------------
// Iteration
// ---------------------------------------------------------------------------

///|
test "iter yields pairs in insertion order" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  let collected : Array[(String, Int)] = []
  let it = m.iter()
  while true {
    match it.next() {
      Some(p) => collected.push(p)
      None => break
    }
  }
  @test.assert_eq(collected, [("b", 2), ("a", 1), ("c", 3)])
}

///|
test "for-in over iter() works" {
  let m = @aurasuisui/bimap.BiMap::from_array([("a", 1), ("b", 2)])
  let mut sum = 0
  for p in m.iter() {
    let (_, r) = p
    sum = sum + r
  }
  @test.assert_eq(sum, 3)
}

///|
test "lefts yields left keys in insertion order" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  let collected : Array[String] = []
  for l in m.lefts() {
    collected.push(l)
  }
  @test.assert_eq(collected, ["b", "a", "c"])
}

///|
test "rights yields right values in insertion order" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  let collected : Array[Int] = []
  for r in m.rights() {
    collected.push(r)
  }
  @test.assert_eq(collected, [2, 1, 3])
}

///|
test "iterating twice gives the same order (idempotent)" {
  let m = @aurasuisui/bimap.BiMap::from_array([("b", 2), ("a", 1), ("c", 3)])
  let first : Array[(String, Int)] = []
  for p in m.iter() {
    first.push(p)
  }
  let second : Array[(String, Int)] = []
  for p in m.iter() {
    second.push(p)
  }
  @test.assert_eq(first, second)
}

///|
test "iter on empty map yields nothing" {
  let m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.new()
  let mut count = 0
  for p in m.iter() {
    ignore(p)
    count = count + 1
  }
  @test.assert_eq(count, 0)
}

// NOTE: the fail-fast path (mutating the map mid-iteration triggers `abort`)
// cannot be exercised in-process — MoonBit panics are not catchable by the
// test framework, and there is no `#[ignore]` test attribute. The behavior is
// verified by inspection of bimap_iter.mbt (version snapshot + abort) and the
// reproduction snippet below; see README "Known Issues".
//
//   let m = BiMap::from_array([("a", 1), ("b", 2), ("c", 3)])
//   let it = m.iter()
//   it.next() |> ignore
//   m.insert("z", 99) |> ignore   // bumps version
//   it.next() |> ignore            // aborts: "BiMap: map mutated during iteration"
