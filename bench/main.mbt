// Timing benchmarks for aurasuisui/bimap (published artifact).
//
// Standalone module, deliberately NOT a workspace member — same layout as
// cmd/: it imports the PUBLISHED aurasuisui/bimap, so the numbers measure
// exactly what users install. (Consequence: to benchmark local library
// changes, publish first; see bench/README.md.)
//
// Uses the official @bench framework (moonbitlang/core/bench): adaptive
// batching, winsorized statistics, monotonic clock per backend. Each closure
// iteration performs N operations; the reported microseconds are per
// ITERATION, so per-op cost = reported / N. Every closure ends in b.keep(...)
// so the computed results are not optimized away.
//
// Run with:
//   moon run --release bench/main.mbt

///|
/// Same LCG as src/model_test.mbt — deterministic probe-key distribution.
fn next_state(state : Int) -> Int {
  (state * 1103515245 + 12345) & 0x7FFF_FFFF
}

///|
/// Build a BiMap with `n` distinct pairs (all C0 inserts): i <-> 2i+1.
fn build_bimap(n : Int) -> @aurasuisui/bimap.BiMap[Int, Int] {
  let m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.new()
  for i in 0..<n {
    m.insert(i, i * 2 + 1) |> ignore
  }
  m
}

///|
/// Build the built-in Map baseline with the same pairs.
fn build_map(n : Int) -> Map[Int, Int] {
  let m : Map[Int, Int] = Map([])
  for i in 0..<n {
    m[i] = i * 2 + 1
  }
  m
}

///|
/// Build a BiBTreeMap with `n` distinct pairs (all C0 inserts): i <-> 2i+1.
fn build_bbtreemap(n : Int) -> @aurasuisui/bimap.BiBTreeMap[Int, Int] {
  let m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::new()
  for i in 0..<n {
    m.insert(i, i * 2 + 1) |> ignore
  }
  m
}

///|
fn main {
  let sizes = [10_000, 100_000]
  let b = @bench.Bench()
  for k in 0..<sizes.length() {
    let n = sizes[k]
    println("# ---- n = \{n} ----")

    // ---------------- BiMap ----------------
    // N fresh-pair inserts (C0 path) = full map construction.
    println("# [bench] bimap.insert-fresh.n\{n}")
    b.bench(name="bimap.insert-fresh.n\{n}", count=5, fn() {
      b.keep(build_bimap(n))
    })

    let bm = build_bimap(n)
    // Forward lookup, all hits, LCG-distributed keys.
    println("# [bench] bimap.get_by_left-hit.n\{n}")
    b.bench(name="bimap.get_by_left-hit.n\{n}", count=5, fn() {
      let mut state = 0x1234_5678
      let mut acc = 0
      for _ in 0..<n {
        state = next_state(state)
        match bm.get_by_left(state % n) {
          Some(v) => acc = acc + v
          None => ()
        }
      }
      b.keep(acc)
    })
    // Reverse lookup, all hits.
    println("# [bench] bimap.get_by_right-hit.n\{n}")
    b.bench(name="bimap.get_by_right-hit.n\{n}", count=5, fn() {
      let mut state = 0x1234_5678
      let mut acc = 0
      for _ in 0..<n {
        state = next_state(state)
        match bm.get_by_right(state % n * 2 + 1) {
          Some(v) => acc = acc + v
          None => ()
        }
      }
      b.keep(acc)
    })

    // Non-overwriting insert on a full map: always the Err path (left key
    // already present; right 0 is never present since all rights are odd).
    let full = build_bimap(n)
    println("# [bench] bimap.insert_no_overwrite-err.n\{n}")
    b.bench(name="bimap.insert_no_overwrite-err.n\{n}", count=5, fn() {
      let mut state = 0x1234_5678
      let mut acc = 0
      for _ in 0..<n {
        state = next_state(state)
        match full.insert_no_overwrite(state % n, 0) {
          Ok(_) => acc = acc + 1
          Err(_) => ()
        }
      }
      b.keep(acc)
    })

    // Build then drain with remove_by_left in REVERSE insertion order: each
    // removal is the last element of the order array, so the O(n)
    // shift-remove in order_remove degenerates to O(1) — this measures the
    // hash-table removal cost fairly.
    println("# [bench] bimap.insert+remove_all-reverse.n\{n}")
    b.bench(name="bimap.insert+remove_all-reverse.n\{n}", count=5, fn() {
      let m = build_bimap(n)
      for i in 0..<n {
        m.remove_by_left(n - 1 - i) |> ignore
      }
      b.keep(m)
    })

    // Head-first drain: each removal shifts the whole order array — O(n^2)
    // total. Measured only at the small size (documented worst case of
    // order-preserving removal; see README "Gotchas" #9 and "Performance").
    if n <= 10_000 {
      println("# [bench] bimap.insert+remove_all-headfirst.n\{n}")
      b.bench(name="bimap.insert+remove_all-headfirst.n\{n}", count=5, fn() {
        let m = build_bimap(n)
        for i in 0..<n {
          m.remove_by_left(i) |> ignore
        }
        b.keep(m)
      })
    }

    // Full traversal in insertion order.
    println("# [bench] bimap.into_array.n\{n}")
    b.bench(name="bimap.into_array.n\{n}", count=5, fn() {
      b.keep(bm.into_array())
    })

    // Full-map hash: one closure iteration hashes the entire N-pair map
    // (order-independent canonical form since 0.1.2: sort + fold, O(n log n)).
    // Reported us is per whole-map hash, NOT per pair.
    println("# [bench] bimap.hash-full.n\{n}")
    b.bench(name="bimap.hash-full.n\{n}", count=5, fn() {
      b.keep(Hash::hash(bm))
    })

    // ---------------- BiBTreeMap (sorted variant) ----------------
    println("# [bench] bbtree.insert-fresh.n\{n}")
    b.bench(name="bbtree.insert-fresh.n\{n}", count=5, fn() {
      b.keep(build_bbtreemap(n))
    })

    let bt = build_bbtreemap(n)
    println("# [bench] bbtree.get_by_left-hit.n\{n}")
    b.bench(name="bbtree.get_by_left-hit.n\{n}", count=5, fn() {
      let mut state = 0x1234_5678
      let mut acc = 0
      for _ in 0..<n {
        state = next_state(state)
        match bt.get_by_left(state % n) {
          Some(v) => acc = acc + v
          None => ()
        }
      }
      b.keep(acc)
    })

    // Range slice over the middle quarter of the key space.
    println("# [bench] bbtree.range-quarter.n\{n}")
    b.bench(name="bbtree.range-quarter.n\{n}", count=5, fn() {
      let lo = n / 4
      let hi = n / 2
      let mut acc = 0
      for pair in bt.range(lo, hi) {
        acc = acc + pair.0 + pair.1
      }
      b.keep(acc)
    })

    // ---------------- built-in Map baseline ----------------
    println("# [bench] map.insert.n\{n}")
    b.bench(name="map.insert.n\{n}", count=5, fn() { b.keep(build_map(n)) })

    let plain = build_map(n)
    println("# [bench] map.get-hit.n\{n}")
    b.bench(name="map.get-hit.n\{n}", count=5, fn() {
      let mut state = 0x1234_5678
      let mut acc = 0
      for _ in 0..<n {
        state = next_state(state)
        match plain.get(state % n) {
          Some(v) => acc = acc + v
          None => ()
        }
      }
      b.keep(acc)
    })

    println("# [bench] map.insert+remove_all.n\{n}")
    b.bench(name="map.insert+remove_all.n\{n}", count=5, fn() {
      let m = build_map(n)
      for i in 0..<n {
        m.remove(i) |> ignore
      }
      b.keep(m)
    })
  }
  println(
    "# moonbit-bimap timing benchmark (@bench, per-iteration microseconds)",
  )
  println("# each iteration performs N ops; per-op cost = reported / N")
  println(
    "# note: bimap.insert+remove_all-headfirst is O(n^2) overall (order shift)",
  )
  println(b.dump_summaries())
}
