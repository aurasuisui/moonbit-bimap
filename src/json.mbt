// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// from_json / from_json_with for BiMap (and, from M3, BiBTreeMap): the
// deserialization entry point with STRICT bijection validation, plus the
// shared BiMapDecodeError type.
//
// This is a data ENTRY point, not a mutation chokepoint: after validating the
// input (whole-object decode first, then O(n) right-value dedup) the map is
// built through the PUBLIC construction path (from_array), so the private
// forward/backward/order/positions fields are never touched here (AGENTS.md
// discipline). Design authority: docs/plans/v0.3.0.md; normative semantics
// in SPEC §12.

// ---------------------------------------------------------------------------
// Error type
// ---------------------------------------------------------------------------

///|
/// Error raised by `from_json` / `from_json_with`.
///
/// Toolchain ruling (moonc v0.10.12): a plain `enum` cannot be raised
/// ([4127] "Type is not an error type") — error types must be declared as
/// `suberror`. The public surface (name, variants, payloads, derives)
/// matches docs/plans/v0.3.0.md §2 exactly.
pub(all) suberror BiMapDecodeError {
  ///
  /// JSON syntax/type error from the core @json decoder, passed through
  /// unchanged. Raised for non-object inputs (core's "Map::from_json:
  /// expected object") and for any value whose JSON type does not decode as
  /// `R`. Value decode errors take priority over conflict detection
  /// (plan §3.5, SPEC §12).
  Decode(@json.JsonDecodeError)
  ///
  /// Strict bijection conflict: two different left keys decode to the same
  /// right value. Payload order (plan §2): (right-value rendering, occupied
  /// left-key rendering, conflicting new left-key rendering) — all three are
  /// PRE-rendered strings:
  /// - right value: `Json::stringify()` of the raw JSON node of the
  ///   incoming pair (ruling 2026-09: R has no Show bound, and core
  ///   `Show for Json` is deprecated — stringify is compact and stable);
  /// - left keys: the text keys, rendered as JSON strings
  ///   (`Json::string(k).stringify()` — quoting/escaping follow stringify).
  DuplicateRightValue(String, String, String)
} derive(Debug, Eq)

///|
/// Hand-written Show — the stable text rendering shared by error messages
/// and the Tier-2 golden snapshots (plan §2). The format is LOCKED (recorded
/// in SPEC §12.2; do not change without updating SPEC and the golden tests):
///
/// - `DuplicateRightValue(1, "a", "b")` — the pre-rendered payload strings
///   joined with ", ";
/// - `Decode(<core JsonDecodeError Show>)` — core's derived Show, which
///   includes the JSON-pointer path, e.g.
///   `Decode(JsonDecodeError((/a, "Int::from_json: expected number")))`.
pub impl Show for BiMapDecodeError with fn output(self, logger) {
  match self {
    Decode(err) => {
      logger.write_string("Decode(")
      Show::output(err, logger)
      logger.write_string(")")
    }
    DuplicateRightValue(right, first_left, new_left) => {
      logger.write_string("DuplicateRightValue(")
      logger.write_string(right)
      logger.write_string(", ")
      logger.write_string(first_left)
      logger.write_string(", ")
      logger.write_string(new_left)
      logger.write_string(")")
    }
  }
}

// ---------------------------------------------------------------------------
// Private helpers (shared by both map types)
// ---------------------------------------------------------------------------

///|
/// Identity parse_key for the String-keyed `from_json` (P1-2: total by
/// construction).
fn identity_parse_key(k : String) -> String {
  k
}

///|
/// Render a text key exactly like a JSON object key: `Json::string(k)`
/// stringified — quoting and escaping rules follow stringify output (the
/// ruling's "引号规则随 stringify 输出").
fn render_key(k : String) -> String {
  Json::string(k).stringify()
}

///|
/// Raw JSON node for a text key of the decoded object. Guaranteed present:
/// `obj` was decoded from `json` by core's Map decoder, so every text key
/// exists in the raw object (the abort branch is unreachable).
fn raw_node_of(raw : Map[String, Json], k : String) -> Json {
  match raw.get(k) {
    Some(j) => j
    None =>
      abort(
        "BiMap::from_json_with: unreachable - decoded key missing from the raw object",
      )
  }
}

// ---------------------------------------------------------------------------
// BiMap deserialization
// ---------------------------------------------------------------------------

///|
/// Deserialize a `BiMap` from a JSON object. Object keys become `String`
/// left keys; the map's insertion order equals the TEXT key order of the
/// JSON (core Map preserves order — the M1 ordering smoke test pins this),
/// and duplicate text keys are last-wins (§3.2).
///
/// Strict bijection validation: two different left keys decoding to the same
/// right value raise `DuplicateRightValue` — the whole parse fails, no
/// partial map, no silent C3 eviction (the deviation from Rust bimap's serde,
/// which silently overwrites; SPEC §12.1). Non-object input or any value
/// decode failure raises `Decode` with core's `@json.JsonDecodeError`
/// passed through; value decode errors take priority over conflict detection
/// (§3.5). For a `String`-keyed map `from_json(m.to_json()) == m` holds
/// (Eq set semantics) with the same pair order.
pub fn[R : FromJson + Hash + Eq] BiMap::from_json(
  json : Json,
) -> BiMap[String, R] raise BiMapDecodeError {
  BiMap::from_json_with(json, identity_parse_key)
}

///|
/// Deserialize a `BiMap` from a JSON object, mapping each object key through
/// `parse_key : (String) -> K` before inserting.
///
/// **`parse_key` MUST be total (P1-2)**: the signature has no raise channel,
/// so a parse failure must be absorbed inside parse_key (e.g. catch
/// `@string.parse_int` and fall back to a default value). parse_key
/// collisions (two text keys mapping to the same logical key) are last-wins,
/// like duplicate text keys (§3.2, P2 ruling). All other semantics — text
/// order preservation, strict right-value conflict errors, error priority —
/// are identical to `BiMap::from_json`.
pub fn[K : Hash + Eq, R : FromJson + Hash + Eq] BiMap::from_json_with(
  json : Json,
  parse_key : (String) -> K,
) -> BiMap[K, R] raise BiMapDecodeError {
  // Step 1 — whole-object decode (§3.5 error priority): any value decode
  // error, or a non-object input, raises Decode (core's error passed
  // through) BEFORE any conflict detection. core Map is insertion-ordered
  // and resolves duplicate text keys last-wins (§3.2), so `obj` is the
  // text-ordered, last-wins pair sequence.
  let obj : Map[String, R] = @json.from_json(json) catch {
    err => raise Decode(err)
  }
  // Step 2 — raw object for conflict rendering. Guaranteed `Object` by the
  // successful decode above (the abort branch is unreachable).
  let raw : Map[String, Json] = match json {
    Json::Object(raw) => raw
    _ =>
      abort(
        "BiMap::from_json_with: unreachable - a non-object decoded as a Map",
      )
  }
  // Step 3 — parse_key collapse, last wins (§3.2, P2 ruling: parse_key
  // collisions are structurally the same as duplicate text keys). We keep:
  // - entries + logicals: text order, for the dedup pass below;
  // - final_pairs: logical key -> decoded value; overwriting a logical key
  //   keeps its FIRST-seen position (core Map semantics) — C2-style position
  //   stability — so the resulting BiMap order is the order of first
  //   occurrences of the logical keys (indexmap-aligned);
  // - final_text: logical key -> its LAST text key (survivor marker);
  // - raw_nodes: per text key, for rendering the incoming pair's right.
  let entries = obj.to_array()
  let logicals : Array[K] = []
  let final_pairs : Map[K, R] = Map([])
  let final_text : Map[K, String] = Map([])
  let raw_nodes : Array[Json] = []
  for i in 0..<entries.length() {
    let (k, v) = entries[i]
    let logical = parse_key(k)
    logicals.push(logical)
    final_pairs[logical] = v
    final_text[logical] = k
    raw_nodes.push(raw_node_of(raw, k))
  }
  // Step 4 — O(n) right-value dedup BEFORE any insertion (§3.4): an insert
  // with a duplicate right value would silently C3-evict the earlier pair,
  // which is unacceptable for deserialization — the whole parse fails with
  // DuplicateRightValue and no partial map is produced. The dedup walks the
  // SURVIVING pairs (last text occurrence per logical key) in text order, so
  // the "occupied" payload is the earlier text key.
  let seen : Map[R, String] = Map([])
  for i in 0..<entries.length() {
    let (k, v) = entries[i]
    let logical = logicals[i]
    if final_text.get(logical) == Some(k) {
      match seen.get(v) {
        Some(first_left) =>
          raise DuplicateRightValue(
            Json::stringify(raw_nodes[i]),
            render_key(first_left),
            render_key(k),
          )
        None => seen[v] = k
      }
    }
  }
  // Step 5 — build through the public construction path. Keys are unique and
  // right values are deduped, so from_array only performs C0 inserts;
  // final_pairs iterates in first-seen logical-key order.
  let pairs : Array[(K, R)] = []
  for k, v in final_pairs {
    pairs.push((k, v))
  }
  BiMap::from_array(pairs)
}
