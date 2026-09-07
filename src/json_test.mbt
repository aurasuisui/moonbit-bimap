// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// Milestone 1 (v0.3.0 from_json): ordering smoke test.
//
// Verifies the core fact pinned in SPEC §12.1 item 2 — that @json parsing
// preserves TEXT key order and resolves duplicate keys last-wins (core Map is
// a LinkedHashMap). These are the load-bearing guarantees that, in M2/M3,
// make BiMap::from_json round-trip text order into insertion order and make
// BiBTreeMap input order irrelevant.
//
// NOTE: the real "from_json -> get_index order == text order" assertion lands
// as a Tier-0 test in M4 (json_test.mbt), once from_json/from_json_with
// exist. This milestone's smoke test proves the same conclusion end-to-end
// using only what already exists: @json.parse -> @json.from_json (ordered
// Map) -> BiMap::from_array -> get_index.

///|
/// Parse an object string to an ordered Map[String, Int], failing the test on
/// any parse/decode error (a smoke test must not silently swallow errors).
fn parse_ordered_map(text : String) -> Map[String, Int] raise {
  @json.from_json(@json.parse(text)) catch {
    _ => @test.fail("smoke: unexpected parse/decode failure")
  }
}

///|
test "smoke: JSON text key order flows into BiMap insertion order (core Map preserves order)" {
  // Distinct keys: text order {"b","a"} must survive into insertion order.
  let m = @aurasuisui/bimap.BiMap::from_array(
    parse_ordered_map("{\"b\":1,\"a\":2}").to_array(),
  )
  @test.assert_eq(m.get_index(0), Some(("b", 1)))
  @test.assert_eq(m.get_index(1), Some(("a", 2)))
  @test.assert_eq(m.left_keys(), ["b", "a"])

  // Duplicate key: last wins, and the survivor keeps the first-seen position.
  let d = @aurasuisui/bimap.BiMap::from_array(
    parse_ordered_map("{\"a\":1,\"a\":2}").to_array(),
  )
  @test.assert_eq(d.len(), 1)
  @test.assert_eq(d.get_index(0), Some(("a", 2)))
}
