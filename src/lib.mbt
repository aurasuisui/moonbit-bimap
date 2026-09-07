// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// moonbit-bimap: a bidirectional map (bijection) with reverse lookup,
// insertion-order preservation, and index access.
//
// A `BiMap[L, R]` maintains a one-to-one correspondence between left keys of
// type `L` and right values of type `R`. You can look up the right value for a
// left key (`get_by_left`) and the left key for a right value
// (`get_by_right`). Unlike a plain map, both keys and values are unique
// (a bijection).
//
// On top of the bidirectional core, this library preserves the insertion
// order of left keys and supports positional access (`get_index`,
// `get_index_of_left`, `first`, `last`) — features neither Rust's `bimap`
// crate nor Guava's `BiMap` provide.
//
// # Quick Start
//
// ```
// let m = @aurasuisui/bimap.new()
// m.insert("alice", "admin") |> ignore
// m.insert("bob", "user") |> ignore
//
// m.get_by_left("alice") // Some("admin")  — forward lookup
// m.get_by_right("user") // Some("bob")    — reverse lookup
// m.get_index(0)         // Some(("alice", "admin"))  — by position
// ```

///|
/// Library version string.
pub const VERSION : String = "0.3.0"

///|
/// The result of `insert`, describing which existing pair(s) were displaced.
/// Mirrors Rust `bimap::Overwritten`.
///
/// - `Neither` — a brand-new pair; nothing was displaced (case C0).
/// - `Left(l, old_r)` — the left key `l` was already bound to `old_r`, which is
///   displaced (case C2).
/// - `Right(old_l, r)` — the right value `r` was already bound to `old_l`, which
///   is displaced (case C3).
/// - `Both((l, old_r), (old_l, r))` — both sides conflicted; the two old pairs
///   collapse into the single new pair and the length decreases by one (case C4).
/// - `Pair(l, r)` — the exact pair already existed; the insert is idempotent
///   (case C1).
pub enum Overwritten[L, R] {
  Neither
  Left(L, R)
  Right(L, R)
  Both((L, R), (L, R))
  Pair(L, R)
} derive(Debug, Eq)

///|
/// Create a new, empty `BiMap`.
pub fn[L : Hash + Eq, R] new() -> BiMap[L, R] {
  BiMap::new()
}

///|
/// Create a new, empty `BiMap` with capacity for at least `cap` pairs.
pub fn[L : Hash + Eq, R] with_capacity(cap : Int) -> BiMap[L, R] {
  BiMap::with_capacity(cap)
}

///|
/// Deserialize a `BiMap` from a JSON object (String keys, text order
/// preserved). See `BiMap::from_json`.
///
/// **Free function covers ONLY `BiMap` (P1-1)**: MoonBit free functions
/// cannot be distinguished by return type, so `BiMap` and `BiBTreeMap`
/// cannot share the same `@aurasuisui/bimap.from_json` name — use
/// `BiBTreeMap::from_json(...)` for the sorted variant.
pub fn[R : FromJson + Hash + Eq] from_json(
  json : Json,
) -> BiMap[String, R] raise BiMapDecodeError {
  BiMap::from_json(json)
}

///|
/// Deserialize a `BiMap` from a JSON object, parsing each key from `String`
/// (e.g. integer keys). See `BiMap::from_json_with`; `parse_key` must be
/// total (P1-2). **Free function covers ONLY `BiMap` (P1-1)** — use
/// `BiBTreeMap::from_json_with(...)` for the sorted variant.
pub fn[K : Hash + Eq, R : FromJson + Hash + Eq] from_json_with(
  json : Json,
  parse_key : (String) -> K,
) -> BiMap[K, R] raise BiMapDecodeError {
  BiMap::from_json_with(json, parse_key)
}
