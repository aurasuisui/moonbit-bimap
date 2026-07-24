// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// WHITE-BOX invariant tests.
//
// `_wbtest.mbt` files are compiled as part of the package, so they can read the
// private fields of `BiMap` and the private `HashTab` engine directly. This lets
// us assert the STRONG form of the bijection invariants — the actual internal
// counters and bucket layout — not just their black-box observable projection
// (which is what `check_bijection` in property_test.mbt checks).
//
// These catch internal desync that has not yet surfaced observably: a drifting
// `positions` length, a wrong `mask`, a leaked live bucket entry, or a
// miscounted `tombstone_count`.
//
// Invariants asserted (SPEC §4):
//   forward.len == backward.len == order.length() == positions.length() == len
//   positions[order[i]] == i
//   forward.mask == forward.buckets.length() - 1   (and same for backward)
//   bucket counts are powers of two
//   bucket-level mutual inverse: forward[l]==r  <=>  backward[r]==l
//   tombstone_count equals the number of tombstone slots actually in buckets
//   live (non-tombstone) bucket entries == len on both sides

///|
/// Assert every white-box invariant of `m`.
fn check_whitebox[
  L : Hash + Eq + Debug,
  R : Hash + Eq + Debug,
](m : BiMap[L, R]) -> Unit raise {
  // --- five counters agree -------------------------------------------------
  @test.assert_eq(m.forward.len, m.len)
  @test.assert_eq(m.backward.len, m.len)
  @test.assert_eq(m.order.length(), m.len)
  @test.assert_eq(m.positions.length(), m.len)

  // --- positions map is self-consistent ------------------------------------
  let mut i = 0
  while i < m.order.length() {
    let l = m.order[i]
    @test.assert_eq(m.positions.get(l), Some(i))
    i = i + 1
  }

  // --- mask / power-of-two bucket layout on BOTH tables --------------------
  let fcap = m.forward.buckets.length()
  let bcap = m.backward.buckets.length()
  @test.assert_eq(m.forward.mask, fcap - 1)
  @test.assert_eq(m.backward.mask, bcap - 1)
  @test.assert_eq(fcap & (fcap - 1), 0)
  @test.assert_eq(bcap & (bcap - 1), 0)

  // --- bucket-level mutual inverse + live/tombstone accounting (forward) ---
  let mut fb = 0
  let mut f_live = 0
  let mut f_tomb = 0
  while fb < fcap {
    match m.forward.buckets[fb] {
      Some(e) =>
        if e.hash == TOMBSTONE_HASH {
          f_tomb = f_tomb + 1
        } else {
          f_live = f_live + 1
          // every live forward entry l->r has the inverse r->l in backward
          @test.assert_eq(m.backward.get(e.value), Some(e.key))
        }
      None => ()
    }
    fb = fb + 1
  }
  @test.assert_eq(f_live, m.len)
  @test.assert_eq(f_tomb, m.forward.tombstone_count)

  // --- bucket-level mutual inverse + live/tombstone accounting (backward) --
  let mut bb = 0
  let mut b_live = 0
  let mut b_tomb = 0
  while bb < bcap {
    match m.backward.buckets[bb] {
      Some(e) =>
        if e.hash == TOMBSTONE_HASH {
          b_tomb = b_tomb + 1
        } else {
          b_live = b_live + 1
          // every live backward entry r->l has the inverse l->r in forward
          @test.assert_eq(m.forward.get(e.value), Some(e.key))
        }
      None => ()
    }
    bb = bb + 1
  }
  @test.assert_eq(b_live, m.len)
  @test.assert_eq(b_tomb, m.backward.tombstone_count)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

///|
test "wb: invariants hold on an empty map" {
  let m : BiMap[String, Int] = BiMap::new()
  check_whitebox(m)
}

///|
test "wb: invariants hold across the C0-C4 golden sequence" {
  let m : BiMap[String, Int] = BiMap::new()
  m.insert("a", 1) |> ignore
  check_whitebox(m)
  m.insert("b", 2) |> ignore
  check_whitebox(m)
  m.insert("a", 4) |> ignore // C2
  check_whitebox(m)
  m.insert("c", 2) |> ignore // C3
  check_whitebox(m)
  m.insert("a", 2) |> ignore // C4 collapse
  check_whitebox(m)
  @test.assert_eq(m.len, 1)
}

///|
test "wb: removal leaves tombstones but the live/inverse counts stay correct" {
  let m : BiMap[Int, Int] = BiMap::new()
  let mut i = 0
  while i < 20 {
    m.insert(i, i + 100) |> ignore
    i = i + 1
  }
  check_whitebox(m)
  // remove half — creates tombstones; inverse + live counts must still hold
  let mut j = 0
  while j < 20 {
    if j % 2 == 0 {
      m.remove_by_left(j) |> ignore
    }
    j = j + 1
  }
  check_whitebox(m)
  @test.assert_eq(m.len, 10)
}

///|
test "wb: invariants hold across a resize (buckets regrow, mask updates)" {
  let m : BiMap[Int, Int] = BiMap::new()
  @test.assert_eq(m.forward.buckets.length(), 16)
  let mut i = 0
  while i < 100 {
    m.insert(i, i * 3) |> ignore
    if i == 12 || i == 24 || i == 48 || i == 96 {
      check_whitebox(m) // at each 3/4-load resize crossing
    }
    i = i + 1
  }
  check_whitebox(m)
  if m.forward.buckets.length() <= 16 {
    @test.fail("forward buckets should have grown past 16")
  }
  // both tables resized in lockstep (they always hold equal counts)
  @test.assert_eq(m.forward.buckets.length(), m.backward.buckets.length())
}

///|
test "wb: the 25% tombstone threshold triggers a clearing rehash" {
  let m : BiMap[Int, Int] = BiMap::new()
  let mut i = 0
  while i < 50 {
    m.insert(i, i) |> ignore
    i = i + 1
  }
  // Remove one at a time. Once tombstones exceed 25% of the bucket count, an
  // in-place rehash fires and resets tombstone_count to 0; later removals then
  // add a few fresh tombstones. So the count is NOT 0 at the end — but it must
  // DROP at least once (proving the rehash fired) and stay accurate throughout.
  let mut saw_reset = false
  let mut prev_tomb = 0
  let mut j = 0
  while j < 40 {
    m.remove_by_left(j) |> ignore
    let t = m.forward.tombstone_count
    if t < prev_tomb {
      saw_reset = true
    }
    prev_tomb = t
    check_whitebox(m)
    j = j + 1
  }
  @test.assert_eq(m.len, 10)
  if !saw_reset {
    @test.fail("expected the 25% tombstone threshold to trigger a clearing rehash")
  }
}

///|
test "wb: heavy C4 traffic keeps both tables' live counts equal to len" {
  let m : BiMap[Int, Int] = BiMap::new()
  let mut i = 0
  while i < 100 {
    m.insert(i * 2, i * 10) |> ignore
    m.insert(i * 2 + 1, i * 10 + 1) |> ignore
    m.insert(i * 2, i * 10 + 1) |> ignore // C4 collapse
    check_whitebox(m)
    i = i + 1
  }
  @test.assert_eq(m.len, 100)
}

///|
test "wb: invariants hold for a String-keyed map after mixed ops" {
  let m : BiMap[String, Int] = BiMap::from_array([
    ("a", 1),
    ("b", 2),
    ("c", 3),
    ("d", 4),
  ])
  m.insert("a", 2) |> ignore // C4: collapse (a,1)+(b,2) -> (a,2)
  m.remove_by_right(3) |> ignore
  m.insert("e", 5) |> ignore
  check_whitebox(m)
}
