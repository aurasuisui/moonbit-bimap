// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Tier 2 robustness coverage: genericity over user-defined key types (proving
// the `L : Hash + Eq` / `R : Hash + Eq` bounds work for arbitrary types defined
// OUTSIDE the library), exact integer boundary keys, and capacity stability
// across fill -> drain -> refill cycles.

// ---------------------------------------------------------------------------
// A user-defined key type (defined here, in the test package, i.e. a different
// module from the library) to prove cross-module genericity.
// ---------------------------------------------------------------------------

///|
struct Point {
  x : Int
  y : Int
} derive(Hash, Eq, Debug)

///|
test "custom struct as the LEFT key: CRUD + C2/C3 + removal" {
  let m : @aurasuisui/bimap.BiMap[Point, Int] = @aurasuisui/bimap.new()
  let a = { x: 1, y: 2 }
  let b = { x: 3, y: 4 }
  m.insert(a, 100) |> ignore
  m.insert(b, 200) |> ignore
  @test.assert_eq(m.len(), 2)
  // a structurally-equal key (a fresh value, not the same reference) resolves
  @test.assert_eq(m.get_by_left({ x: 1, y: 2 }), Some(100))
  @test.assert_eq(m.get_by_right(200), Some({ x: 3, y: 4 }))
  // C2: rebind a structurally-equal left key
  match m.insert({ x: 1, y: 2 }, 999) {
    @aurasuisui/bimap.Left(_, 100) => ()
    _ => @test.fail("expected Left(_, 100) on struct-key rebind")
  }
  @test.assert_eq(m.get_by_right(100), None)
  // C3: a new left key takes over right value 200
  match m.insert({ x: 5, y: 6 }, 200) {
    @aurasuisui/bimap.Right(_, 200) => ()
    _ => @test.fail("expected Right(_, 200) on struct-key takeover")
  }
  @test.assert_eq(m.get_by_left({ x: 3, y: 4 }), None)
  // removal by a structurally-equal key
  @test.assert_eq(m.remove_by_left({ x: 5, y: 6 }), Some(200))
  @test.assert_eq(m.len(), 1)
}

///|
test "custom struct on BOTH sides: BiMap[Point, Point] is a valid bijection" {
  let m : @aurasuisui/bimap.BiMap[Point, Point] = @aurasuisui/bimap.new()
  let k1 = { x: 0, y: 0 }
  let k2 = { x: 1, y: 1 }
  let v1 = { x: 10, y: 20 }
  let v2 = { x: 30, y: 40 }
  m.insert(k1, v1) |> ignore
  m.insert(k2, v2) |> ignore
  @test.assert_eq(m.get_by_left({ x: 0, y: 0 }), Some({ x: 10, y: 20 }))
  @test.assert_eq(m.get_by_right({ x: 30, y: 40 }), Some({ x: 1, y: 1 }))
  // reverse copy swaps the two struct-typed sides
  let inv : @aurasuisui/bimap.BiMap[Point, Point] = m.to_inverse()
  @test.assert_eq(inv.get_by_left({ x: 10, y: 20 }), Some({ x: 0, y: 0 }))
  @test.assert_eq(inv.len(), 2)
  // order-independent Eq/Hash work for struct-keyed maps too
  let m2 : @aurasuisui/bimap.BiMap[Point, Point] = @aurasuisui/bimap.new()
  m2.insert(k2, v2) |> ignore
  m2.insert(k1, v1) |> ignore // reversed insertion order
  @test.assert_eq(m, m2)
  @test.assert_eq(Hash::hash(m), Hash::hash(m2))
}

// ---------------------------------------------------------------------------
// Exact integer boundary keys
// ---------------------------------------------------------------------------

// MoonBit's `Int` width is backend-dependent (64-bit on native/wasm-gc, possibly
// narrower elsewhere) and there is no `Int::MIN`/`Int::MAX` constant. So we use
// the 32-bit extremes, which are representable on EVERY backend. `int_lo` is
// computed rather than written as a literal so no intermediate overflows.

///|
test "Int boundary keys (32-bit extremes / 0 / -1) all work on both sides" {
  let int_hi = 2147483647 // 2^31 - 1
  let int_lo = 0 - 2147483647 - 1 // -(2^31)
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(int_lo, int_hi) |> ignore
  m.insert(0, 0) |> ignore
  m.insert(-1, 1) |> ignore
  m.insert(int_hi, int_lo) |> ignore
  @test.assert_eq(m.len(), 4)
  @test.assert_eq(m.get_by_left(int_lo), Some(int_hi))
  @test.assert_eq(m.get_by_left(int_hi), Some(int_lo))
  @test.assert_eq(m.get_by_right(int_hi), Some(int_lo))
  @test.assert_eq(m.get_by_right(int_lo), Some(int_hi))
  @test.assert_eq(m.get_by_left(0), Some(0))
  // removal at the extremes
  @test.assert_eq(m.remove_by_left(int_lo), Some(int_hi))
  @test.assert_eq(m.get_by_right(int_hi), None)
  @test.assert_eq(m.len(), 3)
}

///|
test "Int extremes are distinct keys (no wraparound collision)" {
  let int_hi = 2147483647
  let int_lo = 0 - 2147483647 - 1
  let m : @aurasuisui/bimap.BiMap[Int, String] = @aurasuisui/bimap.new()
  m.insert(int_lo, "min") |> ignore
  m.insert(int_hi, "max") |> ignore
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left(int_lo), Some("min"))
  @test.assert_eq(m.get_by_left(int_hi), Some("max"))
}

// ---------------------------------------------------------------------------
// Capacity stability across fill -> drain -> refill
// ---------------------------------------------------------------------------

///|
test "capacity is stable across fill -> drain -> refill (no unbounded growth)" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  // first fill: capacity grows to fit 200 pairs
  let mut i = 0
  while i < 200 {
    m.insert(i, i) |> ignore
    i = i + 1
  }
  let cap_after_first_fill = m.capacity()
  // drain to empty (no shrink expected; capacity retained)
  let mut j = 0
  while j < 200 {
    m.remove_by_left(j) |> ignore
    j = j + 1
  }
  @test.assert_eq(m.len(), 0)
  // refill to the same size: must NOT grow beyond the first fill's peak
  let mut k = 0
  while k < 200 {
    m.insert(k + 1000, k) |> ignore
    k = k + 1
  }
  @test.assert_eq(m.len(), 200)
  @test.assert_eq(m.capacity(), cap_after_first_fill)
}

///|
test "three fill/drain cycles leave the map healthy and capacity bounded" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut peak = 0
  let mut round = 0
  while round < 3 {
    let mut i = 0
    while i < 100 {
      m.insert(round * 1000 + i, i) |> ignore
      i = i + 1
    }
    if m.capacity() > peak {
      peak = m.capacity()
    }
    @test.assert_eq(m.len(), 100)
    let mut j = 0
    while j < 100 {
      m.remove_by_left(round * 1000 + j) |> ignore
      j = j + 1
    }
    @test.assert_eq(m.len(), 0)
    round = round + 1
  }
  // after all cycles the capacity never exceeded the recorded peak
  if m.capacity() > peak {
    @test.fail("capacity grew beyond the peak across fill/drain cycles")
  }
}
