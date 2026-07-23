// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Boundary key/value type coverage (TESTS.md §10): the library is generic over
// `L : Hash + Eq` and `R : Hash + Eq`, so exercise several concrete
// instantiations and edge-case key values.

// ---------------------------------------------------------------------------
// BiMap[Int, Int]
// ---------------------------------------------------------------------------

test "BiMap[Int, Int]: basic CRUD" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(1, 100) |> ignore
  m.insert(2, 200) |> ignore
  @test.assert_eq(m.get_by_left(1), Some(100))
  @test.assert_eq(m.get_by_right(200), Some(2))
  @test.assert_eq(m.remove_by_left(1), Some(100))
  @test.assert_eq(m.len(), 1)
}

test "BiMap[Int, Int]: negative and zero keys" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(0, 0) |> ignore
  m.insert(-1, -100) |> ignore
  m.insert(-999999, 42) |> ignore
  @test.assert_eq(m.get_by_left(0), Some(0))
  @test.assert_eq(m.get_by_left(-1), Some(-100))
  @test.assert_eq(m.get_by_right(42), Some(-999999))
  @test.assert_eq(m.len(), 3)
}

test "BiMap[Int, Int]: large keys" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(1_000_000_000, 1) |> ignore
  m.insert(2_000_000_000, 2) |> ignore
  @test.assert_eq(m.get_by_left(1_000_000_000), Some(1))
  @test.assert_eq(m.get_by_right(2), Some(2_000_000_000))
}

// ---------------------------------------------------------------------------
// BiMap[Int, String]
// ---------------------------------------------------------------------------

test "BiMap[Int, String]: basic CRUD" {
  let m : @aurasuisui/bimap.BiMap[Int, String] = @aurasuisui/bimap.new()
  m.insert(1, "one") |> ignore
  m.insert(2, "two") |> ignore
  @test.assert_eq(m.get_by_left(1), Some("one"))
  @test.assert_eq(m.get_by_right("two"), Some(2))
  @test.assert_eq(m.remove_by_right("one"), Some(1))
  @test.assert_eq(m.len(), 1)
}

test "BiMap[Int, String]: C2/C3 with string rights" {
  let m : @aurasuisui/bimap.BiMap[Int, String] = @aurasuisui/bimap.new()
  m.insert(1, "x") |> ignore
  match m.insert(1, "y") {
    @aurasuisui/bimap.Left(1, "x") => ()
    _ => @test.fail("expected Left(1, x)")
  }
  match m.insert(2, "y") {
    @aurasuisui/bimap.Right(1, "y") => ()
    _ => @test.fail("expected Right(1, y)")
  }
  @test.assert_eq(m.get_by_right("y"), Some(2))
}

// ---------------------------------------------------------------------------
// BiMap[String, String]
// ---------------------------------------------------------------------------

test "BiMap[String, String]: basic CRUD" {
  let m : @aurasuisui/bimap.BiMap[String, String] = @aurasuisui/bimap.new()
  m.insert("alice", "admin") |> ignore
  m.insert("bob", "user") |> ignore
  @test.assert_eq(m.get_by_left("alice"), Some("admin"))
  @test.assert_eq(m.get_by_right("user"), Some("bob"))
  @test.assert_eq(m.len(), 2)
}

test "BiMap[String, String]: empty-string key and value" {
  let m : @aurasuisui/bimap.BiMap[String, String] = @aurasuisui/bimap.new()
  m.insert("", "") |> ignore
  @test.assert_eq(m.get_by_left(""), Some(""))
  @test.assert_eq(m.get_by_right(""), Some(""))
  m.insert("k", "") |> ignore // "" right value taken over by k (C3)
  @test.assert_eq(m.get_by_right(""), Some("k"))
  @test.assert_eq(m.get_by_left(""), None)
}

// ---------------------------------------------------------------------------
// BiMap[Bool, Int]
// ---------------------------------------------------------------------------

test "BiMap[Bool, Int]: basic CRUD over the two boolean keys" {
  let m : @aurasuisui/bimap.BiMap[Bool, Int] = @aurasuisui/bimap.new()
  m.insert(true, 1) |> ignore
  m.insert(false, 0) |> ignore
  @test.assert_eq(m.get_by_left(true), Some(1))
  @test.assert_eq(m.get_by_left(false), Some(0))
  @test.assert_eq(m.get_by_right(1), Some(true))
  @test.assert_eq(m.len(), 2)
}

test "BiMap[Bool, Int]: rebinding a boolean key (C2)" {
  let m : @aurasuisui/bimap.BiMap[Bool, Int] = @aurasuisui/bimap.new()
  m.insert(true, 1) |> ignore
  match m.insert(true, 99) {
    @aurasuisui/bimap.Left(true, 1) => ()
    _ => @test.fail("expected Left(true, 1)")
  }
  @test.assert_eq(m.get_by_left(true), Some(99))
  @test.assert_eq(m.get_by_right(1), None)
}

// ---------------------------------------------------------------------------
// BiMap[Char, Int]
// ---------------------------------------------------------------------------

test "BiMap[Char, Int]: basic CRUD" {
  let m : @aurasuisui/bimap.BiMap[Char, Int] = @aurasuisui/bimap.new()
  m.insert('a', 1) |> ignore
  m.insert('z', 26) |> ignore
  @test.assert_eq(m.get_by_left('a'), Some(1))
  @test.assert_eq(m.get_by_right(26), Some('z'))
  @test.assert_eq(m.remove_by_left('a'), Some(1))
  @test.assert_eq(m.len(), 1)
}

test "BiMap[Char, Int]: order preserved across char keys" {
  let m : @aurasuisui/bimap.BiMap[Char, Int] = @aurasuisui/bimap.new()
  m.insert('c', 3) |> ignore
  m.insert('a', 1) |> ignore
  m.insert('b', 2) |> ignore
  let lefts : Array[Char] = []
  for l in m.lefts() {
    lefts.push(l)
  }
  @test.assert_eq(lefts, ['c', 'a', 'b'])
}

// ---------------------------------------------------------------------------
// BiMap[String, Bool]
// ---------------------------------------------------------------------------

test "BiMap[String, Bool]: basic CRUD" {
  let m : @aurasuisui/bimap.BiMap[String, Bool] = @aurasuisui/bimap.new()
  m.insert("yes", true) |> ignore
  m.insert("no", false) |> ignore
  @test.assert_eq(m.get_by_left("yes"), Some(true))
  @test.assert_eq(m.get_by_right(false), Some("no"))
}

// ---------------------------------------------------------------------------
// Cross-type Eq / Hash / conversions
// ---------------------------------------------------------------------------

test "BiMap[Int, Int]: order-independent Eq" {
  let a = @aurasuisui/bimap.BiMap::from_array([(1, 10), (2, 20), (3, 30)])
  let b = @aurasuisui/bimap.BiMap::from_array([(3, 30), (1, 10), (2, 20)])
  @test.assert_eq(a, b)
  @test.assert_eq(Hash::hash(a), Hash::hash(b))
}

test "BiMap[Char, Int]: copy preserves content" {
  let m : @aurasuisui/bimap.BiMap[Char, Int] = @aurasuisui/bimap.new()
  m.insert('x', 1) |> ignore
  m.insert('y', 2) |> ignore
  let c = m.copy()
  @test.assert_eq(c.get_by_left('x'), Some(1))
  @test.assert_eq(c.get_by_right(2), Some('y'))
}

test "BiMap[Int, String]: to_inverse swaps to BiMap[String, Int]" {
  let m : @aurasuisui/bimap.BiMap[Int, String] = @aurasuisui/bimap.new()
  m.insert(1, "one") |> ignore
  m.insert(2, "two") |> ignore
  let inv : @aurasuisui/bimap.BiMap[String, Int] = m.to_inverse()
  @test.assert_eq(inv.get_by_left("one"), Some(1))
  @test.assert_eq(inv.get_by_right(2), Some("two"))
}

test "BiMap[Int, Int]: Show rendering" {
  let m = @aurasuisui/bimap.BiMap::from_array([(1, 10), (2, 20)])
  @test.assert_eq(m.to_string(), "BiMap{1 <-> 10, 2 <-> 20}")
}

test "BiMap[Int, Int]: ToJson uses decimal-text keys" {
  let m = @aurasuisui/bimap.BiMap::from_array([(1, 10), (2, 20)])
  let expected : Map[String, Json] = Map([])
  expected["1"] = ToJson::to_json(10)
  expected["2"] = ToJson::to_json(20)
  @test.assert_eq(m.to_json(), Json::object(expected))
}

test "single-element map: first == last across a C2 rebind" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(5, 50) |> ignore
  @test.assert_eq(m.first(), m.last())
  m.insert(5, 500) |> ignore
  @test.assert_eq(m.first(), Some((5, 500)))
  @test.assert_eq(m.first(), m.last())
}
