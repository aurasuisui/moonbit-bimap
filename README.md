# moonbit-bimap

> Work in progress — see `docs/` for the design. Full README is finalized at M5.

A bidirectional map (bijection) for MoonBit with reverse lookup, insertion-order
preservation, and index access. Ported from Rust's [`bimap`](https://crates.io/crates/bimap)
crate / Guava `BiMap`, with ordering and positional access as additional features.
