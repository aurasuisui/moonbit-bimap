# moonbit-bimap

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![CI](https://github.com/aurasuisui/moonbit-bimap/actions/workflows/ci.yml/badge.svg)](https://github.com/aurasuisui/moonbit-bimap/actions/workflows/ci.yml)

A **bidirectional map** (bijection) for MoonBit — port of Rust's [`bimap`](https://crates.io/crates/bimap) crate / Guava `BiMap`, **extended with insertion-order preservation and index-based access** (which neither Rust nor Guava provides).

A `BiMap[L, R]` keeps keys **and** values in one-to-one correspondence: you can look up
left→right *and* right→left, and every insertion maintains the bijection invariant.

```moonbit
let m = @aurasuisui/bimap.new()
m.insert("alice", "admin") |> ignore
m.insert("bob", "user") |> ignore

// Forward and reverse lookup:
println(m.get_by_left("alice"))     // Some("admin")
println(m.get_by_right("user"))     // Some("bob")

// Index access (insertion order preserved):
println(m.get_index(0))             // Some(("alice", "admin"))
```

## Why a BiMap? (vs the built-in `Map` and vs `indexmap`)

| Feature | built-in `Map` | **BiMap** | `indexmap` |
|---|---|---|---|
| key → value | ✅ | ✅ | ✅ |
| **value → key (reverse)** | ❌ | ✅ | ❌ |
| **index access `get_index(i)`** | ❌ | ✅ | ✅ |
| keys unique | ✅ | ✅ | ✅ |
| **values also unique (bijection)** | ❌ | ✅ | ❌ |
| preserves insertion order | impl-defined | ✅ | ✅ |
| `Eq`/`Hash` semantics | order-independent | **order-independent** | **order-sensitive** |

`BiMap` and `indexmap` solve **orthogonal** problems — *Bi* = bidirectional (one-to-one,
reverse lookup); *Index* = positional access. They share only the underlying hash table
(as any two maps share arrays). This package is a fresh library, not a fork of `indexmap`.

## Features

- **Bidirectional lookup** — `get_by_left` / `get_by_right`, `contains_left` / `contains_right`
- **Bijection-enforcing insertion** — `insert` returns an `Overwritten` enum describing what was displaced (including the classic C4 collapse, see below)
- **Non-overwriting insertion** — `insert_no_overwrite` returns `Result[Unit, (L, R)]`
- **Insertion-order iteration** — `iter()` yields pairs in the order left keys were inserted
- **Index-based access** — `get_index(i)`, `get_index_of_left`, `get_index_of_right`, `first()`, `last()`
- **Inverse copy** — `to_inverse() -> BiMap[R, L]` (a copy, not a live view)
- **Standard traits** — `Debug`, `Default`, `Show`, `Eq`/`Hash` (**order-independent**), `ToJson`, plus QuickCheck `Arbitrary`

## Installation

```json
{ "dependencies": { "aurasuisui/bimap": "0.1.0" } }
```

## The five insertion cases (C0–C4)

Inserting `(l, r)` into a bijection has five sub-cases — the crux of a correct BiMap:

| Case | Condition | `insert` returns | `len` change |
|---|---|---|---|
| **C0** | neither `l` nor `r` present | `Neither` | +1 |
| **C1** | the exact pair `(l, r)` already present | `Pair(l, r)` | 0 |
| **C2** | `l` was bound to `r'≠r`; `r` free | `Left(l, r')` | 0 |
| **C3** | `r` was bound to `l'≠l`; `l` free | `Right(l', r)` | 0 |
| **C4** | `l→r'` **and** `l'→r` both exist | `Both((l,r'), (l',r))` | **−1** |

> **C4 collapses two pairs into one** — `insert` can *reduce* the map's size! This mirrors
> Rust `bimap`'s `Overwritten::Both` exactly.

```moonbit
let m = @aurasuisui/bimap.new()
m.insert("a", 1) |> ignore   // Neither      {a↔1}
m.insert("b", 2) |> ignore   // Neither      {a↔1, b↔2}
m.insert("a", 4) |> ignore   // Left(a, 1)   {a↔4, b↔2}
m.insert("c", 2) |> ignore   // Right(b, 2)  {a↔4, c↔2}
let r = m.insert("a", 2)     // Both((a,4),(c,2))  {a↔2}  — len 2→1!
```

## Gotchas

1. **`insert` can shrink the map** (C4 collapse). Check the returned `Overwritten` if you
   need to know what was displaced.
2. **`Eq` and `Hash` are order-independent.** A `BiMap` is a *set of pairs*; two maps with
   the same pairs in different insertion order **are** equal and hash the same. This is the
   **opposite** of the author's `indexmap`, whose `Eq`/`Hash` are order-sensitive. Because
   `Hash` combines pair hashes commutatively, it is weaker against collision attacks — fine
   for a collection, but be mindful if using a `BiMap` as a key in another hash container.
3. **`to_inverse()` returns a copy**, not a live view. Mutating the inverse does not affect
   the original (MoonBit's ownership model favors copies over shared live views; this matches
   Rust `bimap`'s method-based access rather than Guava's live `inverse()`).
4. **`ToJson` keys use `l.to_string()`** (`L : Show`), so `String` keys serialize verbatim.
5. **Don't mutate the map while an iterator is active** — iterators are fail-fast (they
   snapshot a mutation counter and abort if the map changes mid-iteration).
6. **`from_array` resolves duplicate pairs by "last wins"** (via `insert`), matching Rust's
   `FromIterator`.

## API Overview

| Category | Methods |
|---|---|
| Construct | `new()`, `with_capacity(n)`, `from_array(pairs)`, `default()`, `copy()` |
| Query | `len()`, `is_empty()`, `capacity()` |
| Insert | `insert(l, r) -> Overwritten`, `insert_no_overwrite(l, r) -> Result[Unit,(L,R)]` |
| Forward | `get_by_left(l)`, `contains_left(l)`, `remove_by_left(l) -> R?` |
| Reverse | `get_by_right(r)`, `contains_right(r)`, `remove_by_right(r) -> L?` |
| Index | `get_index(i)`, `get_index_of_left(l)`, `get_index_of_right(r)`, `first()`, `last()` |
| Iterate | `iter()`, `lefts()`, `rights()`, `into_array()` |
| Convert | `to_inverse() -> BiMap[R, L]` |
| Traits | `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson`, `Arbitrary` |

## Design

- **Two inverse Robin Hood hash tables** (`forward: L→R`, `backward: R→L`) keep the bijection.
- **One shared `order` array + `positions` map** tracks left-key insertion order, enabling
  index access without a second order structure on the backward table.
- All mutations funnel through private `put_pair` / `remove_pair_*` helpers that maintain the
  invariants: `∀(l,r)∈forward ⟺ backward[r]==l`, and five consistent counters.
- The Robin Hood engine is adapted from the author's `aurasuisui/indexmap` (see below).

## Examples

Runnable example packages live in [`cmd/`](cmd/):

- `cmd/user_email` — username ↔ email bidirectional lookup
- `cmd/country_code` — country name ↔ ISO code (`"China" ↔ "CN"`)

## Development

```bash
moon check   # type check
moon test    # run all tests
moon fmt     # format
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the architecture deep-dive and test conventions.

## Acknowledgements & Licensing

- The **Robin Hood hash-table engine** is adapted from the author's
  [`aurasuisui/indexmap`](https://github.com/aurasuisui/moonbit-indexmap) (Apache-2.0).
- The **BiMap semantics** (`insert`/`insert_no_overwrite`, `Overwritten`, bidirectional
  lookup) are ported from the Rust [`bimap`](https://github.com/billyrieger/bimap-rs) crate
  (MIT / Apache-2.0), with conceptual reference to Guava `BiMap` (Apache-2.0).
  Order preservation and index access are original additions.

## License

Apache 2.0 — see [LICENSE](LICENSE).

Built for the **2026 MoonBit Open Source Ecosystem Hackathon (August)**.
