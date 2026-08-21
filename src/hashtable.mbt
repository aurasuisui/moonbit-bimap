// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// HashTab: a private, pure Robin Hood open-addressing hash table.
//
// Internalized from aurasuisui/indexmap v0.3.3 (Apache-2.0) with the
// order / positions / version logic removed — ordering and fail-fast are
// the BiMap layer's responsibility. This engine only provides
// insert / get / remove / contains / rehash over an unordered key space.

///|
/// Minimum capacity of the hash table (power of two).
const MIN_CAPACITY : Int = 16

///|
/// Sentinel probe distance — entry has never been displaced.
const NO_DISTANCE : Int = -1

///|
/// Sentinel hash value marking a tombstone (deleted) entry.
const TOMBSTONE_HASH : Int = -1

///|
/// Normalize a key hash so it can never equal the tombstone sentinel: a live
/// entry whose hash equals TOMBSTONE_HASH would be invisible to probes
/// (indistinguishable from a deleted slot). Hash::hash can return any Int —
/// -1 included — so every stored/compared hash goes through this.
fn normalize_hash(hash : Int) -> Int {
  if hash == TOMBSTONE_HASH {
    0
  } else {
    hash
  }
}

///|
/// Load factor numerator (3/4 = 0.75).
const LOAD_FACTOR_NUMERATOR : Int = 3

///|
/// Load factor denominator.
const LOAD_FACTOR_DENOMINATOR : Int = 4

///|
/// An entry stored in a bucket. `key` and `hash` are immutable to preserve
/// probe-chain integrity; `distance` is mutable for Robin Hood insertion.
priv struct Entry[K, V] {
  key : K
  value : V
  hash : Int
  mut distance : Int
}

///|
/// The pure hash table. Holds no ordering information.
priv struct HashTab[K, V] {
  mut buckets : Array[Entry[K, V]?]
  mut len : Int
  mut mask : Int
  mut tombstone_count : Int
  mut max_probe_distance : Int
}

// ---------------------------------------------------------------------------
// Internal: utility functions
// ---------------------------------------------------------------------------

///|
/// Check if the current occupancy exceeds the resize threshold.
fn should_resize_impl(len : Int, capacity : Int) -> Bool {
  len * LOAD_FACTOR_DENOMINATOR >= capacity * LOAD_FACTOR_NUMERATOR
}

///|
/// Compute the next power of two greater than or equal to `n`.
fn next_power_of_two_impl(n : Int) -> Int {
  if n <= 1 {
    return 1
  }
  let mut p = 1
  while p < n {
    p = p << 1
  }
  p
}

///|
/// Simple linear probe to locate an existing key. Returns (index, found).
fn[K : Eq, V] HashTab::probe_find(
  self : HashTab[K, V],
  key : K,
  hash : Int,
) -> (Int, Bool) {
  let start = hash & self.mask
  let mut i = start
  while true {
    match self.buckets[i] {
      None => return (i, false)
      Some(entry) =>
        if entry.hash != TOMBSTONE_HASH &&
          entry.hash == hash &&
          entry.key == key {
          return (i, true)
        }
    }
    i = (i + 1) & self.mask
    if i == start {
      return (i, false)
    }
  }
  (0, false)
}

///|
/// Find a bucket using Robin Hood hashing, reusing the first tombstone seen.
/// Returns (insert_or_found_index, found).
///
/// NOTE: this scan deliberately has NO Robin Hood early cutoff. With
/// tombstones present, an entry whose home lies inside an older cluster can
/// carry a recorded distance smaller than the searcher's probe distance; an
/// `entry.distance < dist` cutoff would then stop before reaching an existing
/// key further on, and the subsequent insert would create a DUPLICATE entry —
/// silently breaking lookups (and BiMap's bijection). Scanning to the first
/// empty slot keeps insertion correct at a small probe-cost.
fn[K : Eq, V] HashTab::robin_hood_find(
  self : HashTab[K, V],
  key : K,
  hash : Int,
) -> (Int, Bool) {
  let start = hash & self.mask
  let mut i = start
  let mut first_tombstone : Int = -1

  while true {
    match self.buckets[i] {
      None => {
        let insert_at = if first_tombstone >= 0 { first_tombstone } else { i }
        return (insert_at, false)
      }
      Some(entry) =>
        if entry.hash == TOMBSTONE_HASH {
          if first_tombstone < 0 {
            first_tombstone = i
          }
        } else if entry.hash == hash && entry.key == key {
          return (i, true)
        }
    }
    i = (i + 1) & self.mask
    if i == start {
      return (i, false)
    }
  }
  (0, false)
}

///|
/// Insert an entry at the given bucket index using Robin Hood displacement.
fn[K, V] HashTab::robin_hood_insert_at(
  self : HashTab[K, V],
  entry_param : Entry[K, V],
  start_idx : Int,
  hash : Int,
) -> Unit {
  let mut entry = entry_param
  let mut i = start_idx
  let mut dist = if start_idx == (hash & self.mask) {
    0
  } else {
    (start_idx - (hash & self.mask)) & self.mask
  }
  // Defense in depth: the load-factor invariant guarantees a free/tombstone
  // slot, so this loop terminates well within `cap` steps.
  let cap = self.buckets.length()
  let mut steps = 0

  while true {
    if steps > cap {
      abort("HashTab: robin_hood_insert_at found no free slot (table full)")
    }
    steps = steps + 1
    match self.buckets[i] {
      None => {
        entry.distance = dist
        self.buckets[i] = Some(entry)
        if dist > self.max_probe_distance {
          self.max_probe_distance = dist
        }
        return
      }
      Some(existing) => {
        if existing.hash == TOMBSTONE_HASH {
          entry.distance = dist
          self.buckets[i] = Some(entry)
          self.tombstone_count = self.tombstone_count - 1
          if dist > self.max_probe_distance {
            self.max_probe_distance = dist
          }
          return
        }
        if existing.distance >= 0 && existing.distance < dist {
          entry.distance = dist
          self.buckets[i] = Some(entry)
          if dist > self.max_probe_distance {
            self.max_probe_distance = dist
          }
          entry = existing
          dist = existing.distance + 1
        } else {
          dist = dist + 1
        }
      }
    }
    i = (i + 1) & self.mask
  }
}

///|
/// Rebuild the table in-place at `new_cap`, clearing all tombstones.
/// Iterates the live bucket entries (HashTab has no order array).
fn[K, V] HashTab::rehash(self : HashTab[K, V], new_cap : Int) -> Unit {
  let cap = if new_cap > 0 { new_cap } else { self.buckets.length() }
  let new_buckets : Array[Entry[K, V]?] = Array::make(cap, None)
  let new_mask = cap - 1
  let mut new_len = 0
  let mut new_max_probe = 0

  let mut pos = 0
  while pos < self.buckets.length() {
    match self.buckets[pos] {
      Some(entry) =>
        if entry.hash != TOMBSTONE_HASH {
          let mut dist = 0
          let mut i = entry.hash & new_mask
          let mut to_insert = {
            key: entry.key,
            value: entry.value,
            hash: entry.hash,
            distance: 0,
          }
          while true {
            match new_buckets[i] {
              None => {
                to_insert.distance = dist
                new_buckets[i] = Some(to_insert)
                new_len = new_len + 1
                if dist > new_max_probe {
                  new_max_probe = dist
                }
                break
              }
              Some(existing) =>
                if existing.distance >= 0 && existing.distance < dist {
                  to_insert.distance = dist
                  new_buckets[i] = Some(to_insert)
                  if dist > new_max_probe {
                    new_max_probe = dist
                  }
                  to_insert = existing
                  dist = existing.distance + 1
                } else {
                  dist = dist + 1
                }
            }
            i = (i + 1) & new_mask
          }
        }
      None => ()
    }
    pos = pos + 1
  }

  self.buckets = new_buckets
  self.mask = new_mask
  self.len = new_len
  self.tombstone_count = 0
  self.max_probe_distance = new_max_probe
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

///|
/// Create a new hash table with at least `cap` buckets (rounded to a power of
/// two, never below MIN_CAPACITY).
fn[K, V] HashTab::with_capacity(cap : Int) -> HashTab[K, V] {
  let real_cap = if cap < MIN_CAPACITY {
    MIN_CAPACITY
  } else {
    next_power_of_two_impl(cap)
  }
  let mask = real_cap - 1
  {
    buckets: Array::make(real_cap, None),
    len: 0,
    mask,
    tombstone_count: 0,
    max_probe_distance: 0,
  }
}

// ---------------------------------------------------------------------------
// Core operations
// ---------------------------------------------------------------------------

///|
/// Insert `key -> value`. If `key` already exists, its value is updated and
/// the previous value is returned; otherwise returns None.
fn[K : Hash + Eq, V] HashTab::insert(
  self : HashTab[K, V],
  key : K,
  value : V,
) -> V? {
  let hash = normalize_hash(Hash::hash(key))
  if should_resize_impl(self.len + self.tombstone_count, self.buckets.length()) {
    self.rehash(self.buckets.length() * 2)
  }
  let (bucket_idx, found) = self.robin_hood_find(key, hash)
  if found {
    match self.buckets[bucket_idx] {
      Some(entry) => {
        let old = entry.value
        let new_entry = {
          key: entry.key,
          value,
          hash: entry.hash,
          distance: entry.distance,
        }
        self.buckets[bucket_idx] = Some(new_entry)
        return Some(old)
      }
      None => return None
    }
  } else {
    let new_entry = { key, value, hash, distance: NO_DISTANCE }
    self.robin_hood_insert_at(new_entry, bucket_idx, hash)
    self.len = self.len + 1
    return None
  }
}

///|
/// Get the value associated with `key`.
fn[K : Hash + Eq, V] HashTab::get(self : HashTab[K, V], key : K) -> V? {
  let hash = normalize_hash(Hash::hash(key))
  let (idx, found) = self.probe_find(key, hash)
  if found {
    match self.buckets[idx] {
      Some(entry) => Some(entry.value)
      None => None
    }
  } else {
    None
  }
}

///|
/// Remove `key`, returning its value if present. Leaves a tombstone; triggers
/// an in-place rehash once tombstones exceed 25% of the buckets.
fn[K : Hash + Eq, V] HashTab::remove(self : HashTab[K, V], key : K) -> V? {
  let hash = normalize_hash(Hash::hash(key))
  let (idx, found) = self.probe_find(key, hash)
  if !found {
    return None
  }
  match self.buckets[idx] {
    None => return None
    Some(entry) => {
      let removed_value = entry.value
      self.buckets[idx] = Some({
        key: entry.key,
        value: entry.value,
        hash: TOMBSTONE_HASH,
        distance: NO_DISTANCE,
      })
      self.tombstone_count = self.tombstone_count + 1
      self.len = self.len - 1
      let total = self.len + self.tombstone_count
      if self.tombstone_count * 4 > self.buckets.length() && total > 0 {
        self.rehash(self.buckets.length())
      }
      return Some(removed_value)
    }
  }
}

///|
/// Return `true` if `key` is present.
fn[K : Hash + Eq, V] HashTab::contains(self : HashTab[K, V], key : K) -> Bool {
  let (_, found) = self.probe_find(key, normalize_hash(Hash::hash(key)))
  found
}

///|
/// Current number of buckets.
fn[K, V] HashTab::capacity(self : HashTab[K, V]) -> Int {
  self.buckets.length()
}
