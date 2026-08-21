// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Property tests guarding the core bijection invariants (SPEC §4):
//   - the two tables are mutual inverses
//   - order.length() == len() (and, via uniqueness below, forward/backward
//     lengths agree too)
//   - left keys are unique and right values are unique (the bijection)
// These are the highest-value tests: any desync between forward, backward,
// order, positions, or len is caught here.

///|
/// Assert every black-box observable invariant of `m`.
fn[L : Hash + Eq + Debug, R : Hash + Eq + Debug] check_bijection(
  m : @aurasuisui/bimap.BiMap[L, R],
) -> Unit raise {
  let arr = m.into_array()
  // order/forward count agrees with self.len
  @test.assert_eq(arr.length(), m.len())
  // inverse holds for every pair; accumulate lefts/rights to check uniqueness
  let lefts : Map[L, Int] = Map([])
  let rights : Map[R, Int] = Map([])
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    @test.assert_eq(m.get_by_left(l), Some(r))
    @test.assert_eq(m.get_by_right(r), Some(l))
    @test.assert_eq(m.contains_left(l), true)
    @test.assert_eq(m.contains_right(r), true)
    lefts[l] = 1
    rights[r] = 1
    i = i + 1
  }
  // distinct lefts == distinct rights == len  =>  five counts agree
  @test.assert_eq(lefts.length(), m.len())
  @test.assert_eq(rights.length(), m.len())
}

// ---------------------------------------------------------------------------
// Random operation sequences (QuickCheck)
// ---------------------------------------------------------------------------

///|
test "qc: invariants hold after random inserts" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(50)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
    let mut i = 0
    while i < pairs.length() {
      let (l, r) = pairs[i]
      m.insert(l, r) |> ignore
      i = i + 1
    }
    check_bijection(m)
    c = c + 1
  }
}

///|
test "qc: invariants hold after mixed insert / remove operations" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(50)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
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
    check_bijection(m)
    c = c + 1
  }
}

///|
test "qc: invariants hold after insert-all then remove-half" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(40)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
    let mut i = 0
    while i < pairs.length() {
      let (l, r) = pairs[i]
      m.insert(l, r) |> ignore
      i = i + 1
    }
    // remove roughly half by left key
    let snapshot = m.into_array()
    let mut j = 0
    while j < snapshot.length() {
      if j % 2 == 0 {
        let (l, _) = snapshot[j]
        m.remove_by_left(l) |> ignore
      }
      j = j + 1
    }
    check_bijection(m)
    c = c + 1
  }
}

///|
test "qc: invariants hold on small-key maps (forces many C2/C3/C4)" {
  // Keys/values drawn from a tiny range so collisions (and thus C2/C3/C4)
  // happen constantly.
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(50)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
    let mut i = 0
    while i < pairs.length() {
      let (l, r) = pairs[i]
      m.insert(l % 4, r % 4) |> ignore
      i = i + 1
    }
    check_bijection(m)
    c = c + 1
  }
}

///|
test "qc: retain keeps exactly the satisfying pairs; invariants hold" {
  // QuickCheck-generated maps, then retain with the shared deterministic
  // predicate; the result must equal the filtered oracle and stay a valid
  // bijection.
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(60)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
    let oracle : Array[(Int, Int)] = []
    let mut i = 0
    while i < pairs.length() {
      let (l0, r0) = pairs[i]
      let l = l0 % 12
      let r = r0 % 12
      m.insert(l, r) |> ignore
      oracle_insert(oracle, l, r)
      i = i + 1
    }
    let pred = fn(l : Int, r : Int) -> Bool { (l + r) % 3 != 0 }
    m.retain(pred)
    oracle_retain(oracle, pred)
    assert_matches_oracle(m, oracle)
    check_bijection(m)
    c = c + 1
  }
}

// ---------------------------------------------------------------------------
// Deterministic invariant checks around the tricky cases
// ---------------------------------------------------------------------------

///|
test "invariants hold after a C4 collapse" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  m.insert(1, 10) |> ignore
  m.insert(2, 20) |> ignore
  m.insert(3, 30) |> ignore
  // C4: 1 -> 10 and 2 -> 20 collapse into 1 -> 20
  m.insert(1, 20) |> ignore
  @test.assert_eq(m.len(), 2)
  check_bijection(m)
  @test.assert_eq(m.get_by_left(1), Some(20))
  @test.assert_eq(m.get_by_left(2), None)
  @test.assert_eq(m.get_by_right(10), None)
}

///|
test "invariants hold across many C4/C3 collisions" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 50 {
    m.insert(i, i + 100) |> ignore
    i = i + 1
  }
  @test.assert_eq(m.len(), 50)
  // Each insert(j, (j+1)+100) collides on the right with pair (j+1, ..); the
  // first is a C4 collapse (len -1) and the rest are C3 take-overs (len flat).
  // The point is to hammer the collision paths while keeping invariants intact.
  let mut j = 0
  while j < 49 {
    m.insert(j, j + 1 + 100) |> ignore
    check_bijection(m)
    j = j + 1
  }
  @test.assert_eq(m.len(), 49)
  check_bijection(m)
}

///|
test "invariants hold across grow/shrink cycles" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut round = 0
  while round < 5 {
    let mut i = 0
    while i < 30 {
      m.insert(round * 100 + i, i) |> ignore
      i = i + 1
    }
    check_bijection(m)
    let mut k = 0
    while k < 30 {
      m.remove_by_left(round * 100 + k) |> ignore
      k = k + 1
    }
    check_bijection(m)
    round = round + 1
  }
  @test.assert_eq(m.len(), 0)
}
