// Example: from_json round-trips for BiMap and BiBTreeMap (v0.3.0).
//
// Demonstrates:
//   - text -> Json (@json.parse), then STRICT bijection validation on decode;
//   - BiMap::from_json free function: insertion order = JSON text key order;
//   - BiBTreeMap::from_json method call (P1-1): sorted output, input key
//     order irrelevant;
//   - from_json_with with a TOTAL parse_key (P1-2): parse failures absorbed
//     inside parse_key, no raise channel;
//   - the DuplicateRightValue conflict error (no silent C3 eviction);
//   - the lossless text round-trip from_json(m.to_json()) == m.
//
// Run with (after aurasuisui/bimap@0.3.0 is published / resolvable):
//   moon run cmd/json_roundtrip

///|
/// Parse JSON text; abort the example with a message on syntax errors.
fn parse_text(text : String) -> Json {
  @json.parse(text) catch {
    e => {
      println("parse failed: \{e}")
      abort("example: JSON parse failed")
    }
  }
}

///|
/// Total Int parse_key (P1-2): catch parse failures and fall back to 0.
fn int_parse_key(k : String) -> Int {
  @string.parse_int(k) catch {
    _ => 0
  }
}

///|
fn main {
  let text = "{\"bob\":2,\"alice\":1,\"carol\":3}"
  let json = parse_text(text)

  println("=== BiMap::from_json (free function, P1-1) ===")
  let m : @bimap.BiMap[String, Int] = @bimap.from_json(json) catch {
    e => {
      println("decode failed: \{e}")
      return
    }
  }
  println("pairs in TEXT key order: \{m.into_array()}")
  println("get_index(0) = \{m.get_index(0)}")

  println("=== BiBTreeMap::from_json (method call) ===")
  let s : @bimap.BiBTreeMap[String, Int] = @bimap.BiBTreeMap::from_json(
    json,
  ) catch {
    e => {
      println("decode failed: \{e}")
      return
    }
  }
  println("pairs sorted by left key: \{s.into_array()}")

  println("=== from_json_with: total parse_key for Int keys ===")
  let keys_json = parse_text("{\"10\":10,\"20\":20}")
  let n : @bimap.BiMap[Int, Int] = @bimap.from_json_with(keys_json, int_parse_key) catch {
    e => {
      println("decode failed: \{e}")
      return
    }
  }
  println("Int-keyed map: \{n.into_array()}")

  println("=== strict bijection validation ===")
  let conflict_json = parse_text("{\"a\":1,\"b\":1}")
  let _bad : @bimap.BiMap[String, Int] = @bimap.from_json(conflict_json) catch {
    e => {
      println("expected error: \{e}")
      return
    }
  }
  println("unexpected: duplicate right value was silently accepted")

  println("=== lossless text round-trip ===")
  let text2 = m.to_json().stringify()
  println("to_json -> \{text2}")
  let m2 : @bimap.BiMap[String, Int] = @bimap.from_json(parse_text(text2)) catch {
    e => {
      println("round-trip failed: \{e}")
      return
    }
  }
  println("from_json(to_json()) == original: \{m == m2}")
}
