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
/// Render (String, Int) pairs like [(bob, 2), (alice, 1)].
fn render_si(pairs : Array[(String, Int)]) -> String {
  let sb = StringBuilder()
  let mut first = true
  for pair in pairs {
    let (l, r) = pair
    if !first {
      sb.write_string(", ")
    }
    sb.write_string("(")
    sb.write_string(l)
    sb.write_string(", ")
    sb.write_string(Show::to_string(r))
    sb.write_string(")")
    first = false
  }
  "[" + sb.to_string() + "]"
}

///|
/// Render (Int, Int) pairs like [(10, 10), (20, 20)].
fn render_ii(pairs : Array[(Int, Int)]) -> String {
  let sb = StringBuilder()
  let mut first = true
  for pair in pairs {
    let (l, r) = pair
    if !first {
      sb.write_string(", ")
    }
    sb.write_string("(")
    sb.write_string(Show::to_string(l))
    sb.write_string(", ")
    sb.write_string(Show::to_string(r))
    sb.write_string(")")
    first = false
  }
  "[" + sb.to_string() + "]"
}

///|
fn main {
  // Equal-length keys: core String Compare orders by length first, so with
  // same-length keys the BiBTreeMap output below is visibly lexicographic
  // (SPEC §12.3 note; mixed-length keys sort by length, not dictionary order).
  let text = "{\"bob\":2,\"amy\":1,\"cat\":3}"
  let json = parse_text(text)

  println("=== BiMap::from_json (free function, P1-1) ===")
  let m : @bimap.BiMap[String, Int] = @bimap.from_json(json) catch {
    e => {
      println("decode failed: \{e}")
      return
    }
  }
  println("pairs in TEXT key order: " + render_si(m.into_array()))
  match m.get_index(0) {
    Some((l, r)) =>
      println(
        "get_index(0) = Some((" + l + ", " + Show::to_string(r) + "))",
      )
    None => println("get_index(0) = None")
  }

  println("=== BiBTreeMap::from_json (method call) ===")
  let s : @bimap.BiBTreeMap[String, Int] = @bimap.BiBTreeMap::from_json(
    json,
  ) catch {
    e => {
      println("decode failed: \{e}")
      return
    }
  }
  println("pairs sorted by left key: " + render_si(s.into_array()))

  println("=== from_json_with: total parse_key for Int keys ===")
  let keys_json = parse_text("{\"10\":10,\"20\":20}")
  let n : @bimap.BiMap[Int, Int] = @bimap.from_json_with(keys_json, int_parse_key) catch {
    e => {
      println("decode failed: \{e}")
      return
    }
  }
  println("Int-keyed map: " + render_ii(n.into_array()))

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
  let verdict = if m == m2 {
    "true"
  } else {
    "false"
  }
  println("from_json(to_json()) == original: " + verdict)
}
