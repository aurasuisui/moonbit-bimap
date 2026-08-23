# tools/diffgen — differential-test fixture generator

Dev tooling for moonbit-bimap's **Tier 1 differential tests** (see
`docs/RELEASE_CHECKLIST.md`). Not part of the MoonBit package itself; excluded
from the workspace and never imported by `src/`.

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

It emits [`src/differential_fixture_test.mbt`](../../src/differential_fixture_test.mbt):
for every step the observed `Overwritten` classification (or `Option`/`Result`/
`Retain` observation) plus the resulting length, and the final pair set. The
MoonBit side (`src/differential_test.mbt`) replays the same streams through the
real `BiMap` and must reproduce every observation. `moon test` runs the
comparison **without needing Rust** — the fixture is checked in.

## Regenerating the fixture

Requires a Rust toolchain (`rustup`/`cargo`) and crates.io access.

```bash
cd tools/diffgen
cargo run --release -- ../../src/differential_fixture_test.mbt
cd ../..
moon fmt          # normalize the generated formatting (CI enforces fmt)
moon test         # the differential tests must pass against the new fixture
```

Regenerate only when the shared op streams change or when re-pinning the
reference crate; commit `Cargo.lock` together with the fixture.

## Scope note

Only the **ported semantics** are diffed (insert / insert_no_overwrite /
remove / lookups / retain as observable `Overwritten` / `Option` / `Result` /
`Retain` values and lengths). Insertion-order preservation and index access
are this library's original extensions — Rust `bimap` has neither — so they
stay covered by `model_test.mbt`'s oracle instead.

[`bimap`]: https://github.com/billyrieger/bimap-rs
