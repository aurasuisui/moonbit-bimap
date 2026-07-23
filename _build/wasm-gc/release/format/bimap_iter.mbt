// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Fail-fast iterators over a BiMap, in left-key insertion order. Each iterator
// snapshots the map's `version` at creation; any structural mutation bumps the
// version, so a subsequent `next()` aborts (genuine fail-fast, as fixed in
// indexmap 0.3.3).

///|
/// Return a lazy iterator over `(left, right)` pairs in left-key insertion
/// order. Supports `for (l, r) in m { ... }`. Aborts if the map is mutated
/// during iteration.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::iter(
  self : BiMap[L, R],
) -> Iter[(L, R)] {
  let mut pos = 0
  let len = self.order.length()
  let version = self.version
  Iter::new(
    fn() -> (L, R)? {
      if self.version != version {
        abort("BiMap: map mutated during iteration")
      }
      while pos < len {
        let l = self.order[pos]
        pos = pos + 1
        match self.forward.get(l) {
          Some(r) => return Some((l, r))
          None => continue
        }
      }
      None
    },
    size_hint=len,
  )
}

///|
/// Return a lazy iterator over the left keys in insertion order. Aborts if the
/// map is mutated during iteration.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::lefts(
  self : BiMap[L, R],
) -> Iter[L] {
  let mut pos = 0
  let len = self.order.length()
  let version = self.version
  Iter::new(
    fn() -> L? {
      if self.version != version {
        abort("BiMap: map mutated during iteration")
      }
      while pos < len {
        let l = self.order[pos]
        pos = pos + 1
        if self.forward.contains(l) {
          return Some(l)
        }
      }
      None
    },
    size_hint=len,
  )
}

///|
/// Return a lazy iterator over the right values in insertion order. Aborts if
/// the map is mutated during iteration.
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::rights(
  self : BiMap[L, R],
) -> Iter[R] {
  let mut pos = 0
  let len = self.order.length()
  let version = self.version
  Iter::new(
    fn() -> R? {
      if self.version != version {
        abort("BiMap: map mutated during iteration")
      }
      while pos < len {
        let l = self.order[pos]
        pos = pos + 1
        match self.forward.get(l) {
          Some(r) => return Some(r)
          None => continue
        }
      }
      None
    },
    size_hint=len,
  )
}
