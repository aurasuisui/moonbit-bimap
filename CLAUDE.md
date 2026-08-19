# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`aurasuisui/bimap` — a **bidirectional map (bijection)** for MoonBit, published on mooncakes.io.
A port of Rust's `bimap` crate, **extended** with insertion-order preservation and index-based
access (neither Rust nor Guava has these). Pure MoonBit, zero dependencies (does **not** depend
on the author's `aurasuisui/indexmap`; the Robin Hood engine is adapted, not imported).

## Commands

```bash
moon check          # type check
moon test           # run all tests (234)
moon fmt            # format (CI enforces `moon fmt --check`)
moon build          # build
```

Run a subset of tests:

```bash
moon test -f "*C4*"            # only tests whose name matches the glob ('*' and '?')
moon test -i 0 src/bimap_test.mbt   # only the 0-th test in one file (single file required)
moon test -p .                 # tests in a specific package
moon test -u                   # regenerate test snapshots (only for debug_inspect tests)
```

The five-step CI (`.github/workflows/ci.yml`) that must all stay green:

```
moon fmt --check → moon check → moon info && git diff --exit-code → moon test → moon build
```

**The `moon info && git diff --exit-code` step is load-bearing:** `src/pkg.generated.mbti` is a
checked-in interface snapshot. If you change any public signature, run `moon info` and commit the
regenerated `pkg.generated.mbti`, or CI fails.

### `cmd/` examples are excluded from the workspace

`moon.work` has `members = ["."]` only — the `cmd/*` example packages are intentionally **not**
workspace members (they import the *published* `aurasuisui/bimap@0.1.1`, matching indexmap's
layout). Root `moon check`/`moon test` never touches them. To exercise one, it must resolve the
published package: `moon run cmd/username_email`. Don't add `cmd/*` to `moon.work` members.
The `bench/` timing-benchmark module follows the same layout (imports the *published* package,
workspace-excluded): `moon run --release bench/main.mbt` — see `bench/README.md`.

## Architecture

### Data layout (`src/bimap.mbt`)

```
BiMap[L, R]
├── forward  : HashTab[L, R]   # left→right Robin Hood table
├── backward : HashTab[R, L]   # right→left table (reverse lookup only — NO order field)
├── order    : Array[L]        # left keys in insertion order (the single source of order)
├── positions: Map[L, Int]     # left key → index in `order` (O(1) get_index_of_left)
├── len      : Int   (mut)
└── version  : Int   (mut)     # mutation counter for fail-fast iterators
```

`HashTab[K, V]` (`src/hashtable.mbt`) is a **pure** open-addressing Robin Hood table
(`buckets: Array[Entry?]`, `len`, `mask`, `tombstone_count`, `max_probe_distance`) with
tombstone deletion, a 25%-tombstone rehash threshold, 3/4 load factor, and a power-of-2
capacity (`MIN_CAPACITY = 16`). It carries **no ordering** — ordering lives entirely in the
`BiMap` layer. Only `len` and `version` are `mut` on `BiMap`; the table/array/map fields are
mutated in place through their own methods, never reassigned.

### The bijection invariants (must ALWAYS hold)

```
∀ (l, r) ∈ forward  ⟺  backward[r] == l      # two sides strictly inverse
forward.len == backward.len == order.length() == positions.length() == self.len
positions[order[i]] == i
```

**Discipline (the #1 source of bugs):** every mutation funnels through the private helpers
`put_pair` (insert path) and `remove_by_left` / `remove_by_right` (removal path). **Public
methods must never sync the two tables themselves.** The `check_bijection` helper in
`property_test.mbt` asserts the black-box form of these invariants — when in doubt, it's the
guard.

### Insertion: five cases (C0–C4)

`insert(l, r)` first short-circuits **C1** (`forward.get(l) == Some(r)` → return `Pair(l, r)`,
no mutation). This short-circuit is essential: without it `(Some(r), Some(l))` would be
misread as a C4 collapse. `put_pair` then handles C0/C2/C3/C4 and returns
`(old_right?, old_left?)`, which `insert` maps to the `Overwritten` enum (`src/lib.mbt`):

| Case | `insert` returns | `len` |
|---|---|---|
| C0 both free | `Neither` | +1 |
| C1 exact pair present | `Pair(l, r)` | 0 |
| C2 `l→r'`, rebind | `Left(l, r')` | 0 |
| C3 `l'→r`, takeover | `Right(l', r)` | 0 |
| C4 `l→r'` AND `l'→r` | `Both((l,r'),(l',r))` | **−1** (collapse) |

`insert_no_overwrite(l, r) -> Result[Unit, (L, R)]` runs both conflict checks **before any
mutation**, so a C4-shaped conflict returns `Err` without collapsing.

### Two deliberate deviations from Rust (documented in CHANGELOG "Notes / Deviations")

1. **Order-preserving C2/C4.** A rebind (C2) and collapse (C4) keep the surviving left key's
   existing insertion position; only a C3 takeover appends the new left key. Rust's
   remove-then-reinsert would move a rebound key to the end — this library chooses
   position-stability because order preservation is the headline feature. `Overwritten`
   payloads and `len` changes still match Rust exactly.
2. **Order-independent `Eq`/`Hash`.** A `BiMap` is a *set of pairs*; `Hash` combines per-pair
   fingerprints with a **commutative sum** so insertion order doesn't change the hash. This is
   the **opposite** of `indexmap` (order-sensitive) and is an intentional, documented gotcha.

## Testing conventions

- Tests are **black-box**: always the `@aurasuisui/bimap.` prefix. `src/moon.pkg` imports
  `moonbitlang/core/{test,quickcheck,debug}`.
- `debug_inspect(value, content="...")` for snapshot-style assertions — but **avoid it inside
  loops with varying values** (it generates unstable `moon test -u` snapshots); use
  `@test.assert_eq` / `@test.fail` there.
- `Overwritten` results are checked via a `classify` helper that pattern-matches the enum into a
  `String` — MoonBit can't construct a cross-package nullary variant in value position, but
  matching works and captures the payload.
- Helper functions that call `@test.assert_eq` must be declared `-> Unit raise` (assertions
  raise on failure).
- The fail-fast `abort` (mid-iteration mutation) is **not in-process testable** — the MoonBit
  test framework can't assert on a panic. That logic in `src/bimap_iter.mbt` is verified by
  inspection/manual reproduction only (see README "Known Issues"); don't try to write a test
  that expects the abort.

## Style (enforced loosely by `moon fmt --check`)

- `snake_case` functions, `PascalCase` types, `UPPER_CASE` constants.
- Public API gets a `///|` doc block; internal helpers documented too.
- **Qualified trait calls**: `Hash::hash(x)`, `Show::to_string(x)`, `ToJson::to_json(x)` — avoid
  the deprecated dot-form on multi-bound type parameters.
- `positions.length()` not `.size()`; `raise` effect annotation not the deprecated `!`.

## Source map

- `src/lib.mbt` — public re-exports (`new`/`with_capacity`), `VERSION`, `Overwritten` enum.
- `src/hashtable.mbt` — private Robin Hood engine (adapted from indexmap; no ordering).
- `src/bimap.mbt` — BiMap core: two inverse tables + `order` + `positions` + `put_pair`.
- `src/bimap_api.mbt` — `insert_no_overwrite`, index access, `from_array`/`copy`/`to_inverse`.
- `src/bimap_iter.mbt` — fail-fast `iter`/`lefts`/`rights`.
- `src/bimap_traits.mbt` — `Debug`/`Default`/`Show`/`Eq`/`Hash`/`ToJson`/`Arbitrary`.
- `src/bimap_wbtest.mbt` — white-box invariant + HashDoS tests (`_wbtest.mbt`; reads private fields).
- `*_test.mbt` — see CONTRIBUTING.md "Testing Guide" for which file covers what.

## Documentation map & reading order

The full doc map lives in **`docs/README.md`** (the hub). For a new session:
**CLAUDE.md (this) → README.md (product) → CONTRIBUTING.md (how to dev) → `docs/SPEC.md`
(API truth, only when touching public API).** For a task session (test/fix/feature), follow
**`docs/SESSION_PLAYBOOK.md`** (discuss-plan → execute → stuck-rules → watchdog → write-back).

Key docs: `docs/SPEC.md` (API source of truth when behavior is ambiguous), `docs/MOONBIT_REF.md`
(MoonBit idiom cheatsheet), `docs/RELEASE_CHECKLIST.md` (**release gate — run before every
`moon publish`**), `docs/DEVPLAN.md` (archived design rationale), `docs/申报书.md`
(hackathon application).

**Before you finish any task**, follow the Doc Sync Convention in CONTRIBUTING.md (update
SPEC/README/CHANGELOG as the change demands) and update the `docs/README.md` map if you add or
remove a doc — this is how knowledge carries across independent sessions. **Before any
`moon publish` / version bump**, run `docs/RELEASE_CHECKLIST.md` (release gate) end-to-end.

## Licensing / provenance

Apache-2.0. Robin Hood engine adapted from `aurasuisui/indexmap` (Apache-2.0); BiMap semantics
ported from Rust `bimap` (MIT/Apache-2.0), conceptually from Guava `BiMap` (Apache-2.0); order
preservation and index access are original. Keep attribution in README/CONTRIBUTING if you touch
those files.
