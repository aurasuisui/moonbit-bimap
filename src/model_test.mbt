// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Differential / model-based tests (RELEASE_TEST_CHECKLIST Tier 1).
//
// Unlike `check_bijection` (which only asserts the map is self-consistent),
// these tests drive the SAME operation sequence through the real `BiMap` AND a
// naive `Array[(Int, Int)]` oracle, then assert the two agree on the EXACT
// content and order after every step. This catches bugs where the map stays
// internally consistent but picks the WRONG survivor (e.g. a mis-bookkept C4
// collapse) — something the self-consistency check cannot see.
//
// The oracle deliberately models THIS library's documented semantics (CHANGELOG
// "Notes / Deviations"): a rebind (C2) and a collapse (C4) keep the surviving
// left key's insertion position; only a C3 takeover appends the new left key.

// ---------------------------------------------------------------------------
// The naive oracle: an Array[(Int, Int)] in insertion order
// ---------------------------------------------------------------------------

///|
/// Index of the pair whose left key is `l`, or None.
fn oracle_index_of_left(arr : Array[(Int, Int)], l : Int) -> Int? {
  let mut i = 0
  while i < arr.length() {
    let (ll, _) = arr[i]
    if ll == l {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Index of the pair whose right value is `r`, or None.
fn oracle_index_of_right(arr : Array[(Int, Int)], r : Int) -> Int? {
  let mut i = 0
  while i < arr.length() {
    let (_, rr) = arr[i]
    if rr == r {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Shift-remove the element at index `i` (manual, to avoid relying on any
/// particular Array-removal API).
fn oracle_remove_at(arr : Array[(Int, Int)], i : Int) -> Unit {
  let mut k = i
  let last = arr.length() - 1
  while k < last {
    arr[k] = arr[k + 1]
    k = k + 1
  }
  arr.pop() |> ignore
}

///|
/// Model `insert`, matching the library's order-preserving C0-C4 semantics.
fn oracle_insert(arr : Array[(Int, Int)], l : Int, r : Int) -> Unit {
  let il = oracle_index_of_left(arr, l)
  let ir = oracle_index_of_right(arr, r)
  match (il, ir) {
    (Some(i), Some(j)) => {
      let (_, r_at_i) = arr[i]
      if r_at_i == r {
        // C1: exact pair already present → no change.
        ()
      } else {
        // C4: (l, r_at_i) and (l0, r) collapse into (l, r). l keeps position i;
        // the pair at j (which holds r) is removed.
        arr[i] = (l, r)
        oracle_remove_at(arr, j)
      }
    }
    (Some(i), None) =>
      // C2: rebind l to r, keeping l's position.
      arr[i] = (l, r)
    (None, Some(j)) => {
      // C3: r was bound to another left key at j; drop it, append (l, r).
      oracle_remove_at(arr, j)
      arr.push((l, r))
    }
    (None, None) =>
      // C0: fresh pair.
      arr.push((l, r))
  }
}

///|
/// Model `remove_by_left`.
fn oracle_remove_left(arr : Array[(Int, Int)], l : Int) -> Unit {
  match oracle_index_of_left(arr, l) {
    Some(i) => oracle_remove_at(arr, i)
    None => ()
  }
}

///|
/// Model `remove_by_right`.
fn oracle_remove_right(arr : Array[(Int, Int)], r : Int) -> Unit {
  match oracle_index_of_right(arr, r) {
    Some(i) => oracle_remove_at(arr, i)
    None => ()
  }
}

///|
/// Model `insert_no_overwrite`: insert only if neither side is present.
fn oracle_insert_no_overwrite(
  arr : Array[(Int, Int)],
  l : Int,
  r : Int,
) -> Unit {
  if oracle_index_of_left(arr, l) is Some(_) ||
    oracle_index_of_right(arr, r) is Some(_) {
    ()
  } else {
    arr.push((l, r))
  }
}

///|
/// Model `retain`: keep only the pairs satisfying `pred`, preserving the
/// relative order of the kept pairs.
fn oracle_retain(arr : Array[(Int, Int)], pred : (Int, Int) -> Bool) -> Unit {
  let mut w = 0
  let mut i = 0
  while i < arr.length() {
    let (l, r) = arr[i]
    if pred(l, r) {
      arr[w] = (l, r)
      w = w + 1
    }
    i = i + 1
  }
  while arr.length() > w {
    arr.pop() |> ignore
  }
}

///|
/// Assert the real map agrees with the oracle on exact content, order, and len.
fn assert_matches_oracle(
  m : @aurasuisui/bimap.BiMap[Int, Int],
  oracle : Array[(Int, Int)],
) -> Unit raise {
  @test.assert_eq(m.into_array(), oracle)
  @test.assert_eq(m.len(), oracle.length())
}

// ---------------------------------------------------------------------------
// Hand-crafted differential sequences
// ---------------------------------------------------------------------------

///|
test "model: the Rust golden C0-C4 sequence matches the oracle step by step" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let oracle : Array[(Int, Int)] = []
  // mirror of the golden sequence in bimap_test.mbt, but with Int keys
  let ops = [(1, 10), (2, 20), (1, 40), (3, 20), (1, 20), (1, 20)]
  let mut i = 0
  while i < ops.length() {
    let (l, r) = ops[i]
    m.insert(l, r) |> ignore
    oracle_insert(oracle, l, r)
    assert_matches_oracle(m, oracle)
    i = i + 1
  }
}

///|
test "model: a C3 handoff chain matches the oracle (right value passed along)" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let oracle : Array[(Int, Int)] = []
  // right value 7 is handed from left key 1 -> 2 -> 3 -> 4 (C3 each time)
  let keys = [1, 2, 3, 4]
  let mut i = 0
  while i < keys.length() {
    m.insert(keys[i], 7) |> ignore
    oracle_insert(oracle, keys[i], 7)
    assert_matches_oracle(m, oracle)
    i = i + 1
  }
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_right(7), Some(4))
}

///|
test "model: repeated C4 collapses match the oracle and keep len correct" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let oracle : Array[(Int, Int)] = []
  let mut i = 0
  while i < 30 {
    // build two disjoint pairs then collapse them
    m.insert(i * 2, i * 100) |> ignore
    oracle_insert(oracle, i * 2, i * 100)
    m.insert(i * 2 + 1, i * 100 + 1) |> ignore
    oracle_insert(oracle, i * 2 + 1, i * 100 + 1)
    m.insert(i * 2, i * 100 + 1) |> ignore // C4 collapse
    oracle_insert(oracle, i * 2, i * 100 + 1)
    assert_matches_oracle(m, oracle)
    i = i + 1
  }
}

// ---------------------------------------------------------------------------
// Randomized differential testing (step-by-step agreement)
// ---------------------------------------------------------------------------

///|
test "model: 6000 deterministic mixed ops agree with the oracle after every step" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let oracle : Array[(Int, Int)] = []
  let mut state = 0x1234_5678
  let mut i = 0
  while i < 6000 {
    // LCG for reproducibility; tiny keyspace (mod 15) forces constant C2/C3/C4.
    // Five ops; the retain predicate is deterministic and shared VERBATIM with
    // tools/diffgen (the Rust-side differential fixture generator).
    state = (state * 1103515245 + 12345) & 0x7FFF_FFFF
    let op = state % 5
    let l = (state >> 6) % 15
    let r = (state >> 14) % 15
    if op == 0 {
      m.insert(l, r) |> ignore
      oracle_insert(oracle, l, r)
    } else if op == 1 {
      m.remove_by_left(l) |> ignore
      oracle_remove_left(oracle, l)
    } else if op == 2 {
      m.remove_by_right(r) |> ignore
      oracle_remove_right(oracle, r)
    } else if op == 3 {
      m.insert_no_overwrite(l, r) |> ignore
      oracle_insert_no_overwrite(oracle, l, r)
    } else {
      let pred = fn(l : Int, r : Int) -> Bool { (l + r) % 3 != 0 }
      m.retain(pred)
      oracle_retain(oracle, pred)
    }
    assert_matches_oracle(m, oracle)
    i = i + 1
  }
}

///|
test "qc: random op sequences agree with the oracle model" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(60)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
    let oracle : Array[(Int, Int)] = []
    let mut i = 0
    while i < pairs.length() {
      let (l0, r0) = pairs[i]
      // small keyspace so collisions (C2/C3/C4) happen frequently
      let l = l0 % 8
      let r = r0 % 8
      if i % 3 == 0 {
        m.insert(l, r) |> ignore
        oracle_insert(oracle, l, r)
      } else if i % 3 == 1 {
        m.remove_by_left(l) |> ignore
        oracle_remove_left(oracle, l)
      } else {
        m.remove_by_right(r) |> ignore
        oracle_remove_right(oracle, r)
      }
      assert_matches_oracle(m, oracle)
      i = i + 1
    }
    c = c + 1
  }
}
