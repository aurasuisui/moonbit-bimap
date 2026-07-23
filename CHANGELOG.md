# Changelog

All notable changes to `moonbit-bimap` are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project
adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-07-24

### Added
- `BiMap[L, R]` bidirectional map (bijection) built on two inverse Robin Hood hash tables.
- Insertion semantics aligned with Rust `bimap`:
  - `insert(l, r) -> Overwritten[L, R]` with `Neither` / `Left` / `Right` / `Both` / `Pair`
    (covers cases C0–C4, including the C4 collapse where `len` decreases by 1).
  - `insert_no_overwrite(l, r) -> Result[Unit, (L, R)]` (both conflict checks run before any
    mutation, so a C4-shaped conflict returns `Err` without collapsing).
- Bidirectional lookup: `get_by_left`, `get_by_right`, `contains_left`, `contains_right`,
  `remove_by_left`, `remove_by_right`.
- **Insertion-order preservation** (original addition over Rust/Guava): `iter`, `lefts`,
  `rights`, `into_array` yield pairs in left-key insertion order.
- **Index-based access** (original addition): `get_index`, `get_index_of_left`,
  `get_index_of_right`, `first`, `last`.
- Inverse copy: `to_inverse() -> BiMap[R, L]` (independent copy, not a live view).
- Construction: `new`, `with_capacity`, `from_array` (last-wins on duplicates, per Rust
  `FromIterator`), `default`, `copy` (deep).
- Traits: `Debug`, `Default`, `Show`, `Eq` (**order-independent**), `Hash`
  (**order-independent**, commutative per-pair-fingerprint sum), `ToJson` (keys via
  `l.to_string()`, no mangling), QuickCheck `Arbitrary`.
- Fail-fast iterators (mutation-version snapshot + `abort` on mid-iteration mutation).
- Internal `HashTab` Robin Hood engine adapted from `aurasuisui/indexmap` v0.3.3 (ordering
  decoupled; tombstone deletion + 25%-tombstone rehash + 3/4 load factor preserved).
- Examples: `cmd/username_email`, `cmd/country_code`.
- Test suite: **203 tests** — unit (C0–C4 matrix, lookup, removal, index access), QuickCheck
  property tests guarding the bijection invariants, boundary key/value types, and stress
  tests (10k insert/remove, resize cascade, tombstone buildup, 20k-op deterministic fuzz).
- CI: five-step pipeline (`fmt --check` / `check` / `info` + `git diff --exit-code` / `test`
  / `build`).

### Notes / Deviations from SPEC
Every choice below follows the SPEC's own guidance ("when SPEC is unclear, follow the Rust
`bimap` crate's real behavior, or pick the simpler / more testable / more bijection-intuitive
option, and record it here").

- **Order-preserving C2/C4 (deliberate extension).** A rebind (C2) and a collapse (C4) keep
  the surviving left key's existing insertion position; only a C3 takeover appends the new
  left key at the end. Rust `bimap`'s `insert` is implemented as `remove_by_left` +
  `remove_by_right` + `insert_unchecked`, which would move a rebound key to the end of the
  order. Since this library's headline feature is *order preservation*, the position-stable
  behavior was chosen and is covered by dedicated tests (e.g. "C2 rebinding keeps the left
  key's insertion position"). The returned `Overwritten` payloads and `len` changes match
  Rust exactly.
- **C1 short-circuit.** `insert` checks `forward.get(l) == Some(r)` and returns
  `Pair(l, r)` before calling `put_pair` (SPEC §4's recommended approach), so `put_pair`
  only handles C0/C2/C3/C4. Equivalent to Rust's `remove_by_left`-then-compare, but clearer
  and it prevents `(Some(r), Some(l))` from being mis-read as a C4 collapse.
- **`Arbitrary` requires `R : Hash + Eq`.** SPEC §7 listed `R : @quickcheck.Arbitrary` only,
  but generating a `BiMap` goes through `from_array`/`insert`, and the backward table hashes
  right values — so `R` must be `Hash + Eq`. (indexmap's `Arbitrary` does not need this
  because it hashes keys only.) The impl adds the bound.
- **`into_array`'s `R` bound relaxed** to `[L : Hash + Eq, R]`: it only reads through
  `forward.get` (which needs `L`), so the `Debug`/`Show`/`ToJson` impls — which constrain `R`
  to just `Debug`/`Show`/`ToJson` per SPEC §7 — can enumerate pairs.
- **Fail-fast `abort` is not in-process testable** (the MoonBit test framework cannot assert
  on a panic). The version-snapshot + `abort` logic is verified by inspection and a manual
  reproduction; see README "Known Issues". All non-panicking iterator behavior is tested.
- Minor toolchain-driven choices: `positions.length()` (deprecated `size()` avoided),
  qualified trait calls `Hash::hash` / `Show::to_string` / `Show::output` / `ToJson::to_json`
  (deprecated dot-form on multi-bound type parameters avoided), and the `raise` effect
  annotation (deprecated `!` avoided).

### Acknowledgements
- Robin Hood engine adapted from `aurasuisui/indexmap` (Apache-2.0).
- BiMap semantics ported from Rust `bimap` crate v0.6.3 (MIT/Apache-2.0) and Guava `BiMap`
  (Apache-2.0). Order preservation and index access are original additions.
