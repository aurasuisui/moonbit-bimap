// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Stress / scaling tests: large insert-remove workloads, the resize cascade,
// tombstone buildup and rehash, heavy C4 traffic, and a long deterministic
// mixed-operation fuzz. The invariants must hold throughout.
// (`check_bijection` is shared from property_test.mbt.)

test "stress: 10k sequential inserts keep invariants and lookups hit" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 10000 {
    m.insert(i, i * 2) |> ignore
    i = i + 1
  }
  @test.assert_eq(m.len(), 10000)
  check_bijection(m)
  // sample lookups across the whole range, both directions
  let mut j = 0
  while j < 10000 {
    @test.assert_eq(m.get_by_left(j), Some(j * 2))
    @test.assert_eq(m.get_by_right(j * 2), Some(j))
    j = j + 101
  }
}

test "stress: insert 10k then remove 5k keeps counts and survivors correct" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 10000 {
    m.insert(i, i + 100000) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 5000 {
    m.remove_by_left(j) |> ignore
    j = j + 1
  }
  @test.assert_eq(m.len(), 5000)
  check_bijection(m)
  // removed keys are gone from both sides
  @test.assert_eq(m.get_by_left(0), None)
  @test.assert_eq(m.get_by_right(100000), None)
  // survivors resolve
  @test.assert_eq(m.get_by_left(5000), Some(105000))
  @test.assert_eq(m.get_by_right(109999), Some(9999))
}

test "stress: resize cascade from 16 keeps invariants at each crossing" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  @test.assert_eq(m.capacity(), 16)
  let mut i = 0
  while i < 1000 {
    m.insert(i, i + 5000) |> ignore
    // 3/4 load factor => resizes near len 12, 24, 48, 96, 192, 384, 768
    if i == 12 ||
      i == 24 ||
      i == 48 ||
      i == 96 ||
      i == 192 ||
      i == 384 ||
      i == 768 {
      check_bijection(m)
    }
    i = i + 1
  }
  check_bijection(m)
  if m.capacity() <= 16 {
    @test.fail("capacity should have grown past 16")
  }
}

test "stress: tombstone buildup then rehash stays correct" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 5000 {
    m.insert(i, i) |> ignore
    i = i + 1
  }
  // remove 4000 (tombstones trigger the 25% in-place rehash)
  let mut j = 0
  while j < 4000 {
    m.remove_by_left(j) |> ignore
    j = j + 1
  }
  @test.assert_eq(m.len(), 1000)
  check_bijection(m)
  // the surviving keys 4000..4999 still resolve on both sides
  let mut k = 4000
  while k < 5000 {
    @test.assert_eq(m.get_by_left(k), Some(k))
    @test.assert_eq(m.get_by_right(k), Some(k))
    k = k + 1
  }
}

test "stress: heavy C4 traffic keeps len consistent and non-negative" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut i = 0
  while i < 1000 {
    // build two disjoint pairs, then collapse them with one C4 insert
    m.insert(i * 2, i * 10) |> ignore
    m.insert(i * 2 + 1, i * 10 + 1) |> ignore
    m.insert(i * 2, i * 10 + 1) |> ignore
    if m.len() < 0 {
      @test.fail("len went negative during C4 collapses")
    }
    i = i + 1
  }
  @test.assert_eq(m.len(), 1000)
  check_bijection(m)
}

test "stress: 20000 deterministic mixed operations end in a valid state" {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  let mut state = 12345
  let mut i = 0
  while i < 20000 {
    // simple LCG so the workload is reproducible without a random source
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF
    let op = state % 3
    let key = (state >> 8) % 500
    let val = (state >> 16) % 500
    if op == 0 {
      m.insert(key, val) |> ignore
    } else if op == 1 {
      m.remove_by_left(key) |> ignore
    } else {
      m.remove_by_right(val) |> ignore
    }
    i = i + 1
  }
  check_bijection(m)
}
