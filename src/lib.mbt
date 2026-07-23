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
pub const VERSION : String = "0.1.0"
