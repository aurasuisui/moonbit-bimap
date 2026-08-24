# tools/diffgen — differential-test fixture generator

Dev tooling for moonbit-bimap's **Tier 1 differential tests** (see
`docs/RELEASE_CHECKLIST.md`). Not part of the MoonBit package itself; standalone
(not part of the root package) and never imported by `src/`.

## What it does

Runs the **reference implementation** — the Rust [`bimap`] crate **v0.6.3**,
pinned, the porting source documented in `docs/SPEC.md` §0 — over the two
operation streams shared with the MoonBit tests:

1. the golden C0–C4 sequence (same as `bimap_test.mbt` / `model_test.mbt`),
2. the 6000-step deterministic LCG stream (same seed/moduli/op mapping as
   `model_test.mbt`: `op = state % 5`, `l = (state >> 6) % 15`,
   `r = (state >> 14) % 15`; ops = insert / remove_by_left / remove_by_right /
   insert_no_overwrite / retain with the deterministic predicate
   `(l + r) % 3 != 0`).

It emits TWO fixtures:

1. [`src/differential_fixture_test.mbt`](../../src/differential_fixture_test.mbt)
   (BiHashMap): every step's `Overwritten` classification (or `Option`/`Result`/
   `Retain` observation) + length, then the final pair SET. Replayed by
   `src/differential_test.mbt`.
2. [`src/bbtreemap_diff_fixture_test.mbt`](../../src/bbtreemap_diff_fixture_test.mbt)
   (BiBTreeMap): the SAME golden + LCG streams, then the final pair list IN
   ITERATION ORDER (ascending by left key) — the sorted-terminal-state check,
   stronger than the BiMap side's membership-only comparison. Replayed by
   `src/bbtreemap_diff_test.mbt`.

`moon test` runs both comparisons **without needing Rust** — the fixtures are
checked in.

## Regenerating the fixture

Requires a Rust toolchain (`rustup`/`cargo`) and crates.io access.

```bash
cd tools/diffgen
cargo run --release -- ../../src/differential_fixture_test.mbt ../../src/bbtreemap_diff_fixture_test.mbt
cd ../..
moon fmt          # normalize the generated formatting (CI enforces fmt)
moon test         # the differential tests must pass against the new fixtures
```

Regenerate only when the shared op streams change or when re-pinning the
reference crate; commit `Cargo.lock` together with the fixture.

## Scope note

Only the **ported semantics** are diffed (insert / insert_no_overwrite /
remove / retain as observable `Overwritten` / `Option` / `Result` / `Retain`
values and lengths, plus the BiBTreeMap iteration order). Insertion-order
preservation and index access are `BiMap`-only original extensions, and
`BiBTreeMap`'s `range`/`left_keys`/`right_values`/`first`/`last`/
`get_or_insert_*` surface is this library's own (boundary semantics pinned by
`bbtreemap_test.mbt`) — none of these are diffed.

[`bimap`]: https://github.com/billyrieger/bimap-rs
