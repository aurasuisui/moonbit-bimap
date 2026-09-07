// Copyright (c) 2026 moonbit-bimap contributors
// SPDX-License-Identifier: Apache-2.0

// v0.3.0 from_json test suite (M1 smoke + M4 Tier 0-2). Black-box tests:
// every library entry is reached through the @aurasuisui/bimap. prefix.
// Design authority: docs/plans/v0.3.0.md §4; normative semantics in SPEC
// §12.2/§12.3.
//
// R=Json is TYPE-LEVEL impossible (no Hash/Compare — SPEC §12.1 item 3), so
// no Json-value test exists here by design (documented, not implemented).

// ---------------------------------------------------------------------------
// Shared helpers (black-box style)
// ---------------------------------------------------------------------------

///|
/// Parse JSON text, failing the test on syntax errors.
fn parse_ok(text : String) -> Json raise {
  @json.parse(text) catch {
    e => @test.fail("parse failed: " + Show::to_string(e))
  }
}

///|
/// Int parse_key for from_json_with tests: TOTAL by contract (P1-2) — parse
/// failures are absorbed and mapped to the sentinel -999 (no raise channel).
fn int_parse_key(s : String) -> Int {
  @string.parse_int(s) catch {
    _ => -999
  }
}

///|
/// BiMap::from_json into BiMap[String, Int]; fails the test on any error.
fn from_json_i(text : String) -> @aurasuisui/bimap.BiMap[String, Int] raise {
  @aurasuisui/bimap.from_json(parse_ok(text)) catch {
    e => @test.fail("from_json failed: " + Show::to_string(e))
  }
}

///|
/// BiMap::from_json into BiMap[String, String]; fails the test on any error.
fn from_json_s(text : String) -> @aurasuisui/bimap.BiMap[String, String] raise {
  @aurasuisui/bimap.from_json(parse_ok(text)) catch {
    e => @test.fail("from_json failed: " + Show::to_string(e))
  }
}

///|
/// BiMap::from_json into BiMap[String, Bool]; fails the test on any error.
fn from_json_b(text : String) -> @aurasuisui/bimap.BiMap[String, Bool] raise {
  @aurasuisui/bimap.from_json(parse_ok(text)) catch {
    e => @test.fail("from_json failed: " + Show::to_string(e))
  }
}

///|
/// Catch the BiMapDecodeError of a BiMap[String, Int] decode and return it
/// (the try/catch arms must share a type, so the error escapes via return).
fn err_from_json_i(text : String) -> @aurasuisui/bimap.BiMapDecodeError raise {
  let j = parse_ok(text)
  let _m : @aurasuisui/bimap.BiMap[String, Int] = @aurasuisui/bimap.from_json(j) catch {
    err => return err
  }
  abort("err_from_json_i: expected an error, got success")
}

///|
/// Catch the BiMapDecodeError of a BiMap[String, String] decode.
fn err_from_json_s(text : String) -> @aurasuisui/bimap.BiMapDecodeError raise {
  let j = parse_ok(text)
  let _m : @aurasuisui/bimap.BiMap[String, String] = @aurasuisui/bimap.from_json(
    j,
  ) catch {
    err => return err
  }
  abort("err_from_json_s: expected an error, got success")
}

///|
/// Catch the BiMapDecodeError of a BiMap[String, Bool] decode.
fn err_from_json_b(text : String) -> @aurasuisui/bimap.BiMapDecodeError raise {
  let j = parse_ok(text)
  let _m : @aurasuisui/bimap.BiMap[String, Bool] = @aurasuisui/bimap.from_json(
    j,
  ) catch {
    err => return err
  }
  abort("err_from_json_b: expected an error, got success")
}

///|
/// BiMap::from_json_with into BiMap[Int, Int] via int_parse_key.
fn from_json_with_i(text : String) -> @aurasuisui/bimap.BiMap[Int, Int] raise {
  @aurasuisui/bimap.from_json_with(parse_ok(text), int_parse_key) catch {
    e => @test.fail("from_json_with failed: " + Show::to_string(e))
  }
}

///|
/// Catch the BiMapDecodeError of a BiMap[Int, Int] from_json_with decode.
fn err_from_json_with_i(
  text : String,
) -> @aurasuisui/bimap.BiMapDecodeError raise {
  let j = parse_ok(text)
  let _m : @aurasuisui/bimap.BiMap[Int, Int] = @aurasuisui/bimap.from_json_with(
    j, int_parse_key,
  ) catch {
    err => return err
  }
  abort("err_from_json_with_i: expected an error, got success")
}

///|
/// BiBTreeMap::from_json into BiBTreeMap[String, Int] (method-call path,
/// P1-1: no free function for the sorted variant).
fn btree_from_json_i(
  text : String,
) -> @aurasuisui/bimap.BiBTreeMap[String, Int] raise {
  @aurasuisui/bimap.BiBTreeMap::from_json(parse_ok(text)) catch {
    e => @test.fail("BiBTreeMap::from_json failed: " + Show::to_string(e))
  }
}

///|
/// Catch the BiMapDecodeError of a BiBTreeMap[String, Int] decode.
fn err_btree_from_json_i(
  text : String,
) -> @aurasuisui/bimap.BiMapDecodeError raise {
  let j = parse_ok(text)
  let _m : @aurasuisui/bimap.BiBTreeMap[String, Int] = @aurasuisui/bimap.BiBTreeMap::from_json(
    j,
  ) catch {
    err => return err
  }
  abort("err_btree_from_json_i: expected an error, got success")
}

///|
/// BiBTreeMap::from_json_with into BiBTreeMap[Int, Int] via int_parse_key.
fn btree_from_json_with_i(
  text : String,
) -> @aurasuisui/bimap.BiBTreeMap[Int, Int] raise {
  @aurasuisui/bimap.BiBTreeMap::from_json_with(parse_ok(text), int_parse_key) catch {
    e => @test.fail("BiBTreeMap::from_json_with failed: " + Show::to_string(e))
  }
}

///|
/// Catch the BiMapDecodeError of a BiBTreeMap[Int, Int] from_json_with.
fn err_btree_from_json_with_i(
  text : String,
) -> @aurasuisui/bimap.BiMapDecodeError raise {
  let j = parse_ok(text)
  let _m : @aurasuisui/bimap.BiBTreeMap[Int, Int] = @aurasuisui/bimap.BiBTreeMap::from_json_with(
    j, int_parse_key,
  ) catch {
    err => return err
  }
  abort("err_btree_from_json_with_i: expected an error, got success")
}

///|
/// Assert the error is exactly DuplicateRightValue with the given payload
/// strings (right render, occupied-left render, new-left render).
fn assert_dup(
  err : @aurasuisui/bimap.BiMapDecodeError,
  right : String,
  occupied : String,
  new_left : String,
) -> Unit raise {
  match err {
    @aurasuisui/bimap.DuplicateRightValue(r, l1, l2) => {
      @test.assert_eq(r, right)
      @test.assert_eq(l1, occupied)
      @test.assert_eq(l2, new_left)
    }
    @aurasuisui/bimap.Decode(_) =>
      @test.fail("expected DuplicateRightValue, got Decode")
  }
}

// ---------------------------------------------------------------------------
// M1 smoke: core Map ordering fact
// ---------------------------------------------------------------------------

///|
/// Parse an object string to an ordered Map[String, Int] (fails the test on
/// any error).
fn parse_ordered_map(text : String) -> Map[String, Int] raise {
  @json.from_json(@json.parse(text)) catch {
    _ => @test.fail("smoke: unexpected parse/decode failure")
  }
}

///|
/// Smoke (M1): core @json parsing preserves TEXT key order and resolves
/// duplicate keys last-wins (SPEC §12.1 item 2) — verified end-to-end
/// through the ordered Map into BiMap::from_array -> get_index.
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

// ---------------------------------------------------------------------------
// Tier 0 - BiMap::from_json
// ---------------------------------------------------------------------------

///|
test "from_json: empty object yields an empty map" {
  let m = from_json_i("{}")
  @test.assert_eq(m.len(), 0)
  @test.assert_eq(m.is_empty(), true)
  @test.assert_eq(m.into_array(), [])
}

///|
test "from_json: single pair round-trips both directions" {
  let m = from_json_i("{\"k\":42}")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left("k"), Some(42))
  @test.assert_eq(m.get_by_right(42), Some("k"))
  @test.assert_eq(m.get_index(0), Some(("k", 42)))
}

///|
test "from_json: pair order equals the text key order (get_index and left_keys)" {
  let m = from_json_i("{\"b\":1,\"a\":2,\"c\":3}")
  @test.assert_eq(m.into_array(), [("b", 1), ("a", 2), ("c", 3)])
  @test.assert_eq(m.get_index(0), Some(("b", 1)))
  @test.assert_eq(m.get_index(1), Some(("a", 2)))
  @test.assert_eq(m.get_index(2), Some(("c", 3)))
  @test.assert_eq(m.left_keys(), ["b", "a", "c"])
}

///|
test "from_json: R = String values decode" {
  let m = from_json_s("{\"a\":\"x\",\"b\":\"\"}")
  @test.assert_eq(m.get_by_left("a"), Some("x"))
  @test.assert_eq(m.get_by_left("b"), Some(""))
  @test.assert_eq(m.get_by_right("x"), Some("a"))
}

///|
test "from_json: R = Bool values decode" {
  let m = from_json_b("{\"t\":true,\"f\":false}")
  @test.assert_eq(m.get_by_left("t"), Some(true))
  @test.assert_eq(m.get_by_left("f"), Some(false))
  @test.assert_eq(m.get_by_right(false), Some("f"))
}

///|
test "from_json: duplicate text keys are last-wins" {
  let m = from_json_i("{\"a\":1,\"a\":2,\"b\":3}")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.get_by_left("a"), Some(2))
  // the survivor keeps the first-seen position (C2-style stability)
  @test.assert_eq(m.into_array(), [("a", 2), ("b", 3)])
}

///|
test "from_json: strict right-value conflict raises DuplicateRightValue with exact triple" {
  let err = err_from_json_i("{\"a\":1,\"b\":1}")
  assert_dup(err, "1", "\"a\"", "\"b\"")
  @test.assert_eq(Show::to_string(err), "DuplicateRightValue(1, \"a\", \"b\")")
}

///|
test "from_json: duplicate keys last-wins BEFORE conflict detection" {
  // {"a":1,"b":2,"b":1} last-wins to a=1, b=1 -> then the conflict fires
  // (plan §3.2 example).
  let err = err_from_json_i("{\"a\":1,\"b\":2,\"b\":1}")
  assert_dup(err, "1", "\"a\"", "\"b\"")
}

///|
test "from_json: non-object JSON raises Decode (passthrough) for [], string, number, null" {
  let expected = "Decode(JsonDecodeError((, Map::from_json: expected object)))"
  @test.assert_eq(Show::to_string(err_from_json_i("[]")), expected)
  @test.assert_eq(Show::to_string(err_from_json_i("\"x\"")), expected)
  @test.assert_eq(Show::to_string(err_from_json_i("1")), expected)
  @test.assert_eq(Show::to_string(err_from_json_i("null")), expected)
}

///|
test "from_json: value type mismatch raises Decode passthrough (Int/String/Bool slots)" {
  @test.assert_eq(
    Show::to_string(err_from_json_i("{\"a\":[1]}")),
    "Decode(JsonDecodeError((/a, Int::from_json: expected number)))",
  )
  @test.assert_eq(
    Show::to_string(err_from_json_i("{\"a\":\"x\"}")),
    "Decode(JsonDecodeError((/a, Int::from_json: expected number)))",
  )
  @test.assert_eq(
    Show::to_string(err_from_json_s("{\"a\":1}")),
    "Decode(JsonDecodeError((/a, String::from_json: expected string)))",
  )
  @test.assert_eq(
    Show::to_string(err_from_json_b("{\"a\":1}")),
    "Decode(JsonDecodeError((/a, Bool::from_json: expected boolean)))",
  )
}

///|
test "from_json: error priority - value decode error beats right-value conflict" {
  // Same object has a type error at /a AND a right-value conflict b/c:
  // the Decode wins (plan §3.5).
  let err = err_from_json_i("{\"a\":\"x\",\"b\":1,\"c\":1}")
  @test.assert_eq(
    Show::to_string(err),
    "Decode(JsonDecodeError((/a, Int::from_json: expected number)))",
  )
}

// ---------------------------------------------------------------------------
// Tier 0 - BiMap::from_json_with (Int keys, total parse_key)
// ---------------------------------------------------------------------------

///|
test "from_json_with: Int keys via a total parse_key (internal catch)" {
  let m = from_json_with_i("{\"10\":1,\"-5\":2}")
  @test.assert_eq(m.get_by_left(10), Some(1))
  @test.assert_eq(m.get_by_left(-5), Some(2))
  @test.assert_eq(m.get_by_right(2), Some(-5))
  // parse_key is total (P1-2): an unparseable text key is absorbed, here to
  // the -999 sentinel, instead of raising through a second error channel.
  let n = from_json_with_i("{\"oops\":7}")
  @test.assert_eq(n.get_by_left(-999), Some(7))
}

///|
test "from_json_with: parse_key collisions are last-wins" {
  // "1" and "01" both parse to 1: last wins for the value, first-seen
  // position for the order.
  let m = from_json_with_i("{\"1\":1,\"01\":2}")
  @test.assert_eq(m.len(), 1)
  @test.assert_eq(m.get_by_left(1), Some(2))
  @test.assert_eq(m.into_array(), [(1, 2)])
  // order interplay: a later key does not move the collapsed pair.
  let n = from_json_with_i("{\"2\":9,\"1\":1,\"01\":2}")
  @test.assert_eq(n.into_array(), [(2, 9), (1, 2)])
}

///|
test "from_json_with: parse_key collision then survivor conflict (order-sensitive pair)" {
  // {"1":5,"2":7,"01":7}: after last-wins the survivors are (1,7) and
  // (2,7) -> conflict; "occupied" is the text-earlier survivor "2".
  let err = err_from_json_with_i("{\"1\":5,\"2\":7,\"01\":7}")
  assert_dup(err, "7", "\"2\"", "\"01\"")
  @test.assert_eq(Show::to_string(err), "DuplicateRightValue(7, \"2\", \"01\")")
  // Same pairs in another order: the later "1" overwrites logical key 1 to
  // 5, so the survivors (2,7) and (1,5) do NOT conflict.
  let m = from_json_with_i("{\"2\":7,\"01\":7,\"1\":5}")
  @test.assert_eq(m.len(), 2)
  @test.assert_eq(m.into_array(), [(2, 7), (1, 5)])
}

// ---------------------------------------------------------------------------
// Tier 0 - BiBTreeMap (sorted variant)
// ---------------------------------------------------------------------------

///|
test "BiBTreeMap::from_json: sorted output, input key order irrelevant" {
  let a = btree_from_json_i("{\"b\":1,\"a\":2}")
  let b = btree_from_json_i("{\"a\":2,\"b\":1}")
  @test.assert_eq(a.into_array(), [("a", 2), ("b", 1)])
  @test.assert_eq(a, b)
  @test.assert_eq(a.first(), Some(("a", 2)))
  @test.assert_eq(a.last(), Some(("b", 1)))
}

///|
test "BiBTreeMap::from_json: duplicate text keys are last-wins" {
  let m = btree_from_json_i("{\"a\":1,\"a\":2}")
  @test.assert_eq(m.into_array(), [("a", 2)])
}

///|
test "BiBTreeMap::from_json: conflict error matches the BiMap payload exactly" {
  let err = err_btree_from_json_i("{\"a\":1,\"b\":1}")
  assert_dup(err, "1", "\"a\"", "\"b\"")
  @test.assert_eq(Show::to_string(err), "DuplicateRightValue(1, \"a\", \"b\")")
}

///|
test "BiBTreeMap::from_json: Decode passthrough and error priority" {
  let expected_obj = "Decode(JsonDecodeError((, Map::from_json: expected object)))"
  @test.assert_eq(Show::to_string(err_btree_from_json_i("[]")), expected_obj)
  @test.assert_eq(
    Show::to_string(err_btree_from_json_i("{\"a\":[1]}")),
    "Decode(JsonDecodeError((/a, Int::from_json: expected number)))",
  )
  // type error at /a beats the b/c right-value conflict
  @test.assert_eq(
    Show::to_string(err_btree_from_json_i("{\"a\":\"x\",\"b\":1,\"c\":1}")),
    "Decode(JsonDecodeError((/a, Int::from_json: expected number)))",
  )
}

///|
test "BiBTreeMap::from_json_with: Int keys, parse_key collisions, conflict parity" {
  let m = btree_from_json_with_i("{\"10\":1,\"-5\":2}")
  @test.assert_eq(m.into_array(), [(-5, 2), (10, 1)])
  let n = btree_from_json_with_i("{\"1\":1,\"01\":2}")
  @test.assert_eq(n.into_array(), [(1, 2)])
  let err = err_btree_from_json_with_i("{\"1\":5,\"2\":7,\"01\":7}")
  assert_dup(err, "7", "\"2\"", "\"01\"")
}
// ---------------------------------------------------------------------------
// Tier 1 - QuickCheck round-trips
// ---------------------------------------------------------------------------

///|
test "qc round-trip: BiMap[String, Int] to_json -> from_json preserves content and order" {
  let maps : Array[@aurasuisui/bimap.BiMap[String, Int]] = @quickcheck.samples(
    40,
  )
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    let j = @json.parse(m.to_json().stringify()) catch {
      e =>
        @test.fail(
          "qc: our own ToJson output did not parse: " + Show::to_string(e),
        )
    }
    let m2 = @aurasuisui/bimap.from_json(j) catch {
      e => @test.fail("qc: from_json round-trip failed: " + Show::to_string(e))
    }
    @test.assert_eq(m, m2)
    // order preservation: the insertion order survived the text round-trip
    @test.assert_eq(m.into_array(), m2.into_array())
    i = i + 1
  }
}

///|
test "qc round-trip: BiBTreeMap[String, Int] to_json -> from_json preserves content" {
  let maps : Array[@aurasuisui/bimap.BiBTreeMap[String, Int]] = @quickcheck.samples(
    40,
  )
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    let j = @json.parse(m.to_json().stringify()) catch {
      e =>
        @test.fail(
          "qc: our own ToJson output did not parse: " + Show::to_string(e),
        )
    }
    let m2 = @aurasuisui/bimap.BiBTreeMap::from_json(j) catch {
      e => @test.fail("qc: BiBTreeMap round-trip failed: " + Show::to_string(e))
    }
    @test.assert_eq(m, m2)
    // both sides are canonically sorted, so sequence equality also holds
    @test.assert_eq(m.into_array(), m2.into_array())
    i = i + 1
  }
}

// ---------------------------------------------------------------------------
// Tier 1 - naive Array model (R=Int; no Map/Hash/SortedMap key bookkeeping)
// ---------------------------------------------------------------------------

///|
/// Naive Array model of from_json_with semantics, generic in the logical key
/// type K (needs only Eq — linear scans, no Map/Hash/SortedMap):
/// 1. decode values in text order (core Json decode per value);
/// 2. parse-key last-wins collapse, keeping first-seen key positions;
/// 3. right-value dedup over SURVIVORS in text order of last occurrences.
/// Returns the final pair list in first-seen order, or the conflict triple
/// (right render, occupied-left render, new-left render) per SPEC §12.2.
fn[K : Eq] model_with(
  text : String,
  pk : (String) -> K,
) -> (Array[(K, Int)], (String, String, String)?) raise {
  let raw : Map[String, Json] = match parse_ok(text) {
    Json::Object(o) => o
    _ => @test.fail("model: expected an object")
  }
  // decode in text order (core LinkedHashMap order == text order)
  let texts : Array[String] = []
  let vals : Array[Int] = []
  let raws : Array[Json] = []
  for k, v in raw {
    texts.push(k)
    vals.push(@json.from_json(v))
    raws.push(v)
  }
  // last-wins collapse on logical keys; first-seen positions kept
  let keys : Array[K] = []
  let final_vals : Array[Int] = []
  let final_text : Array[String] = []
  let mut t = 0
  while t < texts.length() {
    let logical = pk(texts[t])
    let mut slot = -1
    let mut s = 0
    while s < keys.length() {
      if keys[s] == logical {
        slot = s
      }
      s = s + 1
    }
    if slot >= 0 {
      final_vals[slot] = vals[t]
      final_text[slot] = texts[t]
    } else {
      keys.push(logical)
      final_vals.push(vals[t])
      final_text.push(texts[t])
    }
    t = t + 1
  }
  // dedup over survivors in text order of last occurrences
  let right_of : Array[Int] = []
  let left_of : Array[String] = []
  let mut u = 0
  while u < texts.length() {
    let logical = pk(texts[u])
    let mut survivor_slot = -1
    let mut s2 = 0
    while s2 < keys.length() {
      if keys[s2] == logical {
        survivor_slot = s2
      }
      s2 = s2 + 1
    }
    if survivor_slot >= 0 && final_text[survivor_slot] == texts[u] {
      let mut dup = -1
      let mut d = 0
      while d < right_of.length() {
        if right_of[d] == vals[u] {
          dup = d
        }
        d = d + 1
      }
      if dup >= 0 {
        return (
          [],
          Some(
            (
              Json::stringify(raws[u]),
              Json::string(left_of[dup]).stringify(),
              Json::string(texts[u]).stringify(),
            ),
          ),
        )
      }
      right_of.push(vals[u])
      left_of.push(texts[u])
    }
    u = u + 1
  }
  let pairs : Array[(K, Int)] = []
  let mut k2 = 0
  while k2 < keys.length() {
    pairs.push((keys[k2], final_vals[k2]))
    k2 = k2 + 1
  }
  (pairs, None)
}

///|
/// Compare actual from_json_with (Int keys) against the model for one text.
fn check_model_int_case(text : String) -> Unit raise {
  let (pairs, conflict) : (Array[(Int, Int)], (String, String, String)?) = model_with(
    text, int_parse_key,
  )
  match conflict {
    Some((r, l1, l2)) => {
      let err = err_from_json_with_i(text)
      match err {
        @aurasuisui/bimap.DuplicateRightValue(r2, l1b, l2b) => {
          @test.assert_eq(r2, r)
          @test.assert_eq(l1b, l1)
          @test.assert_eq(l2b, l2)
        }
        @aurasuisui/bimap.Decode(_) =>
          @test.fail("model: expected DuplicateRightValue, got Decode")
      }
    }
    None => @test.assert_eq(from_json_with_i(text).into_array(), pairs)
  }
}

///|
/// Compare actual from_json (String keys) against the model (identity pk).
fn check_model_str_case(text : String) -> Unit raise {
  let (pairs, conflict) : (Array[(String, Int)], (String, String, String)?) = model_with(
    text,
    fn(k : String) -> String { k },
  )
  match conflict {
    Some((r, l1, l2)) => {
      let err = err_from_json_i(text)
      match err {
        @aurasuisui/bimap.DuplicateRightValue(r2, l1b, l2b) => {
          @test.assert_eq(r2, r)
          @test.assert_eq(l1b, l1)
          @test.assert_eq(l2b, l2)
        }
        @aurasuisui/bimap.Decode(_) =>
          @test.fail("model: expected DuplicateRightValue, got Decode")
      }
    }
    None => @test.assert_eq(from_json_i(text).into_array(), pairs)
  }
}

///|
test "model: handcrafted texts agree with the naive Array model (Int keys)" {
  let cases = [
    "{}", "{\"a\":1}", "{\"b\":1,\"a\":2,\"c\":3}", "{\"a\":1,\"a\":2}", "{\"1\":1,\"01\":2}",
    "{\"2\":9,\"1\":1,\"01\":2}", "{\"1\":5,\"2\":7,\"01\":7}", "{\"2\":7,\"01\":7,\"1\":5}",
    "{\"1\":7,\"2\":7}", "{\"1\":7,\"2\":7,\"01\":7}",
  ]
  let mut i = 0
  while i < cases.length() {
    check_model_int_case(cases[i])
    i = i + 1
  }
}

///|
test "model: handcrafted texts agree with the naive Array model (String keys)" {
  let cases = [
    "{}", "{\"b\":1,\"a\":2}", "{\"a\":1,\"a\":2}", "{\"a\":1,\"b\":1}", "{\"a\":1,\"b\":2,\"b\":1}",
  ]
  let mut i = 0
  while i < cases.length() {
    check_model_str_case(cases[i])
    i = i + 1
  }
}
