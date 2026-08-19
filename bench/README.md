# bench/ — timing benchmarks for moonbit-bimap

Native-backend timing benchmarks built on the official
[`@bench`](https://docs.moonbitlang.com/) framework
(`moonbitlang/core/bench`: adaptive batching, winsorized statistics,
monotonic clock). Dev tooling; **excluded from the root workspace** and not
part of the library package surface.

## What it measures

For each size N ∈ {10 000, 100 000}, on `Int ↔ Int` maps with distinct pairs
`i ↔ 2i+1` and an LCG probe distribution (same LCG as `src/model_test.mbt`):

| benchmark | operation |
|---|---|
| `bimap.insert-fresh.nN` | N fresh-pair inserts (C0 path) = full construction |
| `bimap.get_by_left-hit.nN` | N forward lookups, all hits |
| `bimap.get_by_right-hit.nN` | N reverse lookups, all hits |
| `bimap.insert_no_overwrite-err.nN` | N conflict checks on a full map (Err path) |
| `bimap.insert+remove_all-reverse.nN` | build then drain in reverse insertion order (each `order` shift degenerates to O(1)) |
| `bimap.insert+remove_all-headfirst.nN` | same, but draining in insertion order — the documented O(n²) worst case; run only at n = 10 000 |
| `bimap.into_array.nN` | full traversal in insertion order |
| `map.insert.nN` / `map.get-hit.nN` / `map.insert+remove_all.nN` | same ops on the built-in `Map` baseline |

Every closure iteration performs N ops and ends in `Bench::keep` so results
are not optimized away. Reported numbers are **microseconds per iteration**;
per-op cost = reported ÷ N. Each bench uses `count=5` winsorized samples.

## Running

```bash
moon run --release bench/main.mbt
```

The module resolves the **published** `aurasuisui/bimap` (see `moon.mod`),
exactly like `cmd/` — so the numbers measure what users install. To benchmark
local library changes, publish first (or temporarily point `bench/moon.mod`
at the new version). The first run also pays a one-time release build.

Output is the `@bench` JSON summary array (`name`, `mean`, `median`,
`std_dev`, …, in µs); the derived per-op table quoted in the root README
"Performance" section is computed from `median ÷ N`.

## Caveats

- Single machine, single run session — treat numbers as indicative of
  constant-factor behavior (BiMap vs built-in `Map`), not absolute
  performance. Re-run when quoting fresh numbers.
- `insert+remove_all-reverse` mixes build and drain; per-op remove cost ≈
  (that bench − `insert-fresh`) ÷ N.
- **Head-first drain is O(n²) overall** — `order_remove` shifts the order
  array (O(n) worst case per removal). The headfirst bench exists to measure
  that worst case and is therefore capped at n = 10 000; see README
  "Performance" and Gotcha #9.
- No CI regression gate: this is a manual benchmark (see
  `docs/RELEASE_CHECKLIST.md` Tier 3 and CHANGELOG "Future work").
