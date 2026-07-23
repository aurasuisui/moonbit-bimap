// Example: country name <-> ISO 3166-1 alpha-2 code lookup.
//
// Demonstrates the three things a BiMap adds over a plain map: reverse lookup
// (code -> name), positional access (the n-th country inserted), and the
// non-overwriting insert that refuses to break the one-to-one invariant.
//
// Run with (after `aurasuisui/bimap` is published / resolvable):
//   moon run cmd/country_code

///|
/// Render an optional string.
fn opt(o : String?) -> String {
  match o {
    Some(s) => s
    None => "<?>"
  }
}

///|
/// Render an optional pair.
fn pair(o : (String, String)?) -> String {
  match o {
    Some((l, r)) => l + " <-> " + r
    None => "<?>"
  }
}

///|
/// Render an optional index.
fn intopt(o : Int?) -> String {
  match o {
    Some(i) => i.to_string()
    None => "<?>"
  }
}

///|
fn main {
  let countries : @bimap.BiMap[String, String] = @bimap.new()
  countries.insert("China", "CN") |> ignore
  countries.insert("United States", "US") |> ignore
  countries.insert("Japan", "JP") |> ignore
  countries.insert("Germany", "DE") |> ignore

  println("=== name -> code ===")
  println("China -> \{opt(countries.get_by_left("China"))}")
  println("Japan -> \{opt(countries.get_by_left("Japan"))}")

  println("=== code -> name (reverse) ===")
  println("US -> \{opt(countries.get_by_right("US"))}")
  println("DE -> \{opt(countries.get_by_right("DE"))}")

  println("=== positional access (insertion order) ===")
  println("first inserted: \{pair(countries.first())}")
  println("third inserted: \{pair(countries.get_index(2))}")
  println("index of 'Japan': \{intopt(countries.get_index_of_left("Japan"))}")

  println("=== strict, non-overwriting insert ===")
  match countries.insert_no_overwrite("France", "FR") {
    Ok(_) => println("added France <-> FR")
    Err((l, r)) => println("refused \{l} <-> \{r}: a side already exists")
  }
  match countries.insert_no_overwrite("China", "XX") {
    Ok(_) => println("added China <-> XX")
    Err((l, r)) => println("refused \{l} <-> \{r}: a side already exists")
  }
}
