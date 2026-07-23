# Changelog

All notable changes to `moonbit-bimap` are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project
adheres to [Semantic Versioning](https://semver.org/).

<!--
执行会话:按实际完成情况填写 [0.1.0]。每条对应一个真实落地的功能/修复。
若你偏离了 SPEC(以 Rust bimap 行为为准),在 "Notes" 里记一笔偏差与理由。
-->

## [0.1.0] - 2026-08-XX

### Added
- `BiMap[L, R]` bidirectional map (bijection) with two inverse Robin Hood hash tables.
- Insertion semantics aligned with Rust `bimap`:
  - `insert(l, r) -> Overwritten[L, R]` with `Neither` / `Left` / `Right` / `Both` / `Pair`
    (covers cases C0–C4, including the C4 collapse where `len` decreases by 1).
  - `insert_no_overwrite(l, r) -> Result[Unit, (L, R)]`.
- Bidirectional lookup: `get_by_left`, `get_by_right`, `contains_left`, `contains_right`,
  `remove_by_left`, `remove_by_right`.
- **Insertion-order preservation** (original addition over Rust/Guava): `iter`, `lefts`,
  `rights` yield pairs in left-key insertion order.
- **Index-based access** (original addition): `get_index`, `get_index_of_left`,
  `get_index_of_right`, `first`, `last`.
- Inverse copy: `to_inverse() -> BiMap[R, L]`.
- Construction: `new`, `with_capacity`, `from_array` (last-wins on duplicates), `default`, `copy`.
- Traits: `Debug`, `Default`, `Show`, `Eq` (**order-independent**), `Hash` (**order-independent**,
  commutative pair-hash combination), `ToJson` (keys via `l.to_string()`), QuickCheck `Arbitrary`.
- Fail-fast iterators (mutation-version snapshot).
- Internal `HashTab` Robin Hood engine adapted from `aurasuisui/indexmap` (order decoupled).
- Examples: `cmd/user_email`, `cmd/country_code`.
- Test suite: ~NNN tests (unit + QuickCheck property tests for the bijection invariants +
  stress). <!-- 执行会话:把 NNN 换成真实测试数 -->
- CI: five-step pipeline (fmt --check / check / info+diff / test / build).

### Notes / Deviations from SPEC
<!-- 执行会话:如有任何与 SPEC.md 不一致之处,逐条记录在此(选了什么、为什么)。无则删掉本节或写 "None". -->
- None.

### Acknowledgements
- Robin Hood engine adapted from `aurasuisui/indexmap` (Apache-2.0).
- BiMap semantics ported from Rust `bimap` crate (MIT/Apache-2.0) and Guava `BiMap` (Apache-2.0).
