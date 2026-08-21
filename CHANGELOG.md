# Changelog

All notable changes to `moonbit-bimap` are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project
adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **`retain(pred)` on `BiMap`** — a PORT of Rust bimap's `retain` (present on
  both of its map types; the crate's `retain_calls_f_once` matches our
  exactly-once predicate semantics). Keeps the pairs satisfying the predicate
  in O(n) (snapshot + per-pair three-structure removal + in-place `order`
  compaction — deliberately avoiding the O(n²) head-drain cost), preserving
  the relative insertion order of kept pairs. A retain that removes nothing
  is a no-op and does NOT bump the version (active iterators stay valid).
  Registered as the third mutation chokepoint (bimap.mbt header, CLAUDE/AGENTS
  /CONTRIBUTING discipline sections, SPEC §4).
- **Differential stream extended to five ops**: the shared LCG stream
  (model_test ↔ diffgen ↔ differential_test, kept verbatim-consistent) now
  includes retain with the deterministic predicate `(l + r) % 3 != 0`; the
  regenerated fixture diffs retain against the real crate step by step (1241
  retain observations) — ahead of the v0.2.0 plan's M3 schedule.
  Test suite: 238 → 247.

## [0.1.3] - 2026-08-23

### Fixed
- **HashTab probe-corruption bug (engine-level, present since v0.1.0).** With
  tombstones present, the Robin Hood early cutoff in the insert search
  (`robin_hood_find`) could stop at an entry whose recorded distance looked
  "too poor" relative to the probe distance — unsound once deletions leave
  tombstones and later insertions place entries with small recorded distances
  inside older clusters. The search then missed the existing key and inserted
  a DUPLICATE live entry, making lookups return stale values and silently
  breaking the bijection. Found by a QuickCheck property (sample 40: C3/C4
  tombstone churn + negative keys); root-caused by dumping the corrupted
  buckets (two live entries for one key). Fix: the insert search now scans to
  the first empty slot (no cutoff; the `probe_find` used by get/remove was
  already cutoff-free), and `normalize_hash` ensures a stored hash can never
  equal the tombstone sentinel -1 (a key hashing to -1 would otherwise become
  invisible to probes). Regression coverage: `src/regression_wbtest.mbt`
  (exact sample-40 sequence with per-step whitebox invariants,
  duplicate-live-key bucket scans, sentinel normalization, and an
  end-to-end `fn hash -> -1` sentinel-key test) plus a duplicate-key scan
  helper in `bimap_wbtest.mbt`. No public API change; mbti unaffected
  (engine internals).
- **Note for `aurasuisui/indexmap`**: the engine was adapted from its v0.3.3,
  which shares the tombstone + cutoff pattern; the same bug exists there for
  releases <=0.3.3. Its v0.4.0 has switched to tombstone-free backshift
  deletion, so only users pinned to an older version are affected — no patch
  needed upstream, just upgrade guidance.

### Process
- **发布前检查:RELEASE_CHECKLIST 全绿 @ d0e3acc**(2026-08-23,0.1.3 hotfix)。
  版本号四处一致;跨后端矩阵 wasm-gc 与 native 均 238/238;五步 CI 于 main 全绿;
  Rust 产物门禁(cargo clean + 发布后 zip 抽查)通过;`cmd/*` 对已发布包解析验证通过。

## [0.1.2] - 2026-08-20

### Added
- **Differential tests against the real Rust `bimap` crate v0.6.3** — the
  porting source itself is now the oracle (RELEASE_CHECKLIST Tier 1; closes
  the last "真实未达标" entry in its gap registry). `tools/diffgen` (Rust,
  dev-only, workspace-excluded) runs the reference crate over the two shared
  streams — the golden C0–C4 sequence and `model_test.mbt`'s 6000-step LCG —
  and generates `src/differential_fixture_test.mbt`; `src/differential_test.mbt`
  replays the same streams through the real `BiMap` and compares every step's
  `Overwritten` / `Option` / `Result` observation and length, plus the final
  pair set. `moon test` needs no Rust toolchain (the fixture is checked in;
  regeneration instructions in `tools/diffgen/README.md`). Test suite:
  229 → 232.
- **Timing benchmarks** (`bench/`, official `@bench` framework; native
  backend, `--release`; imports the published package like `cmd/`, excluded
  from the workspace): per-op numbers at n = 10 000 / 100 000 for insert,
  forward/reverse lookup, conflict-checked `insert_no_overwrite`, traversal,
  and drain, against built-in `Map` as baseline. Headline results quoted in
  README "Performance"; reproduce with `moon run --release bench/main.mbt`.

### Changed
- **Hardened the order-independent map hash** (structural-weakness removal,
  not a correctness fix: `Eq`/lookups untouched). The retired commutative
  per-pair-fingerprint sum was *linear*: cross-swapped maps `{(a,b),(c,d)}`
  vs `{(a,d),(c,b)}` collided by algebraic identity for ANY key hashes — no
  hash control needed to exploit it. The new combiner builds the pair set's
  canonical form — the sorted fingerprint sequence (a bijection has no
  duplicate pairs) — and folds it with an FNV-1a-style order-sensitive mix
  (64-bit constants, length mixed in first). Collisions now reduce to equal
  fingerprint multisets, requiring hash-level control over the keys
  (README Gotcha #2 states the remaining boundary). Hash values change —
  the 0.x series is the cheap window for this; nothing persists hashes.
  Cost: O(n log n) per map hash (the sort). Signatures/mbti unchanged
  (impl body only). Test suite: 232 → 234 (cross-swapped Int-key pair sets
  provably split; order independence re-verified with a non-trivial sort).

### Notes
- **Confirmed against the crate**: Rust `bimap`'s `remove_by_left/right`
  returns the whole removed `(L, R)` pair; this library's
  `remove_by_left(l) -> R?` / `remove_by_right(r) -> L?` (SPEC §5) is
  informationally equivalent — the differential fixture encodes the observable
  side, and all 6000 steps agree.
- Only the **ported** semantics are diffed; insertion-order preservation and
  index access are original extensions with no Rust counterpart and stay
  covered by `model_test.mbt`'s oracle.
- The golden sequence produced by the real crate matches SPEC §0's recorded
  Rust behavior exactly (independently re-verified against v0.6.3).
- **Removal complexity documented (bench-confirmed).** `order_remove` is an
  O(len) shift, so draining n pairs head-first (in insertion order) is O(n²)
  overall — measured ≈ 133 µs/op at n = 10 000, ≈ 90× the tail-first drain.
  Added as README Gotcha #9 + "Performance" section, SPEC §5 note, and a
  capped headfirst bench; bulk clear-outs should drain in reverse insertion
  order or rebuild. Not a behavior change — a documented complexity.
- The CI-regression-gate half of the v0.1.1 "performance benchmark + CI
  gate" future-work item remains open (needs stable CI timing
  infrastructure); the local-benchmark half is now done (`bench/`).

### Process
- **发布前检查:RELEASE_CHECKLIST 全绿 @ b8bc775**(2026-08-20,0.1.2 发布)。
  版本号四处一致(moon.mod / `lib.mbt::VERSION` / README 安装说明 / CHANGELOG 标题,
  另同步 CLAUDE.md / AGENTS.md / MOONBIT_REF 镜像);零依赖声明成立;接口快照已提交
  (mbti diff 仅 VERSION 行);跨后端手动矩阵 wasm-gc 与 native 均 234/234;SPDX 头与
  三处署名留存;五步 CI 于 main 全绿(含 mbti 门禁)。Rust 构建产物门禁(0.1.2 起新增项)
  已执行:发布前 `cargo clean` 清空 `tools/diffgen/target/`,发布后 zip 清单抽查确认。
  注:0.10.8 工具链 `moon publish` 无 `--dry-run`,同 0.1.1 以直接发布 + `cmd/*` 对
  已发布包的解析验证替代。

## [0.1.1] - 2026-08-18

### Added (test suite — no public API or behavior change)
Expanded the test suite from 203 to 229 tests, closing the high-value gaps in
`TEST_CHECKLIST.md`:

- **Differential / model tests** (`model_test.mbt`): identical op sequences are
  driven through the real `BiMap` and a naive `Array[(L,R)]` oracle, asserting
  exact content+order agreement after every step — catches wrong-survivor bugs
  the self-consistency check cannot see.
- **White-box invariant tests** (`bimap_wbtest.mbt`, MoonBit `_wbtest.mbt`):
  assert the strong form of the invariants on the private fields — five-counter
  agreement, `positions[order[i]]==i`, `mask`/power-of-two buckets on both
  tables, bucket-level mutual inverse, and `tombstone_count` accuracy (including
  proof that the 25% tombstone rehash fires).
- **Iterator-contract tests** (`iter_test.mbt`): simultaneous iterators advance
  independently; `collect()` materializes the right count/order (the observable
  effect of `size_hint`).
- **Genericity / robustness** (`generics_test.mbt`): a user-defined struct used
  as the left key and on both sides; portable 32-bit `Int` boundary keys;
  capacity stays bounded across fill→drain→refill cycles.
- **HashDoS** (`bimap_wbtest.mbt`): a constant-hash key floods one probe chain;
  the table stays correct and removal works, with `max_probe_distance` shown to
  degrade ~linearly (the documented commutative-hash weakness, README Gotcha #2).

### Changed
- **Trait bounds minimized across the public API** (18 signatures, all moonc
  `[0053]` unused-bound warnings eliminated). Completes the minimization begun
  with `into_array` (see its note below in the v0.1.0 section):
  - Write-path / two-sided methods keep `L : Hash + Eq, R : Hash + Eq`:
    `insert`, `insert_no_overwrite`, `remove_by_left`, `remove_by_right`,
    `from_array`, `copy`, `to_inverse`, `get_index_of_right`.
  - One-sided read-only methods now constrain only the side they query:
    `new`, `with_capacity`, `get_by_left`, `contains_left`, `get_index`,
    `get_index_of_left`, `first`, `last`, `iter`, `lefts`, `rights` are
    `[L : Hash + Eq, R]`; `get_by_right`, `contains_right` are
    `[L, R : Hash + Eq]`.
  - Trait impls tighten likewise: `Eq` keeps `R : Eq` (value comparison) but
    drops `R : Hash`; `Hash` keeps `R : Hash` but drops `R : Eq`; `Default`
    needs only `L : Hash + Eq`.
  Relaxing bounds is strictly source-compatible (no caller can break) and
  matches Rust's bounds-on-methods convention; `pkg.generated.mbti`
  regenerated. No behavior change (229/229 tests). SPEC §7/§8 and the
  MOONBIT_REF examples were updated to match (including fixing the
  pre-existing SPEC §7 `Arbitrary` drift noted under v0.1.0). This supersedes
  the "tolerate warnings" strategy inherited from indexmap: the project now
  targets zero warnings — `moon check --deny-warn` and `moon test --deny-warn`
  pass locally; CI intentionally stays without `--deny-warn` because it tracks
  `version: latest`.

### Removed
- Private, never-called `HashTab::new()` (default-capacity constructor of the
  internal engine; all construction goes through `with_capacity`). No public
  API change.

### Fixed
- Remaining moonc 0.10.8 warnings: deprecated free `to_repr(x)` replaced with
  the qualified `Debug::to_repr(x)` in the `Debug` impl, deprecated
  `.is_some()` calls in tests replaced with the `is Some(_)` pattern form, and
  `from_array([])` in an edge test now carries an explicit
  `BiMap[String, Int]` annotation instead of leaving the type variables to
  default to `Unit`.

### Notes
- **Thread safety stated explicitly**: README Gotcha #8 — `BiMap` is not
  thread-safe (mutable + fail-fast iterators).
- `size_hint` is passed to `Iter::new` but MoonBit exposes no public accessor to
  read it back, so (like the fail-fast `abort`) it is asserted only via its
  observable effect (`collect()`), not directly.
- `Int` boundary tests use the portable 32-bit extremes: MoonBit's `Int` width
  is backend-dependent and there is no `Int::MIN`/`Int::MAX` constant.

### Future work (tracked, not in scope for v0.1.0)
- **Performance benchmark + CI regression gate** — `bench_test.mbt` is a
  correctness stress suite, not a timing benchmark; a real perf gate needs
  external timing tooling in CI.
- **Cross-backend testing** — deliberately kept as a **manual pre-release
  convention, not a CI matrix** (decision recorded in `docs/RELEASE_CHECKLIST.md`
  "手动约定", the SSOT for this policy): the library is pure MoonBit with no
  backend-specific code, and automating every backend would lengthen CI for
  little gain. For 0.1.1, `wasm-gc` and `native` were run manually (229/229
  each); future releases follow the same convention. An earlier draft of this
  entry recommended a CI matrix; the manual convention supersedes it.
- **Mutation testing** — no standard MoonBit mutation tool yet; deferred.
- **Differential testing vs Rust `bimap`** — `model_test.mbt` only diffs against a naive
  `Array` oracle, not the Rust origin crate. A real cross-implementation diff (shared op
  stream → Rust `Overwritten` values) is the remaining item to reach the "standard library"
  bar; tracked for v0.1.x.

### Process
- **Release gate documented.** `docs/RELEASE_CHECKLIST.md` is now the single source for the
  pre-publish checklist: Tier 0–4 coverage + a non-test "release gate" section (version-stamp
  consistency across `moon.mod`/`lib.mbt::VERSION`/README badge/CHANGELOG title, zero-dependency
  claim, `moon publish --dry-run`, `pkg.generated.mbti` diff, `cmd/*` examples runnable against
  the published version, SPDX/attribution retention, five-step CI green) + a gap registry. The
  convention: every `moon publish` / version bump must clear it and log a checkmark line in
  this CHANGELOG. Cross-backend (`wasm-gc`/`native`) is a manual pre-release check by convention,
  not an automated CI matrix. Integrated into the `docs/` hub and the Doc Sync Convention in
  `CONTRIBUTING.md`. Supersedes the ad-hoc `TEST_CHECKLIST.md` in the parent workspace.
- **发布前检查:RELEASE_CHECKLIST 全绿 @ 03b8798**(2026-08-18,0.1.1 发布)。版本号四处一致
  (moon.mod / `lib.mbt::VERSION` / README 安装说明 / CHANGELOG 标题,另同步 CLAUDE.md /
  AGENTS.md / MOONBIT_REF 镜像);零依赖声明成立;接口快照已提交(mbti diff 仅 VERSION 行);
  跨后端手动矩阵 wasm-gc 与 native 均 229/229;SPDX 头与三处署名留存;五步 CI 于 main 全绿。
  注:0.10.8 工具链的 `moon publish` 已无 `--dry-run` 旗标,该门禁项以直接发布 +
  `cmd/*` 对已发布包的解析验证替代。

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
