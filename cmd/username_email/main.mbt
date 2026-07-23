// Example: a bidirectional username <-> email directory.
//
// A BiMap guarantees a one-to-one correspondence: every username has exactly
// one email and every email belongs to exactly one username. Lookups work in
// both directions, and the insertion order of usernames is preserved.
//
// Run with (after `aurasuisui/bimap` is published / resolvable):
//   moon run cmd/username_email

///|
/// Render an optional string for display.
fn show(opt : String?) -> String {
  match opt {
    Some(s) => s
    None => "<unassigned>"
  }
}

///|
fn main {
  let directory : @bimap.BiMap[String, String] = @bimap.new()
  directory.insert("alice", "alice@example.com") |> ignore
  directory.insert("bob", "bob@example.com") |> ignore
  directory.insert("carol", "carol@example.com") |> ignore

  println("=== forward lookup: username -> email ===")
  println("alice -> \{show(directory.get_by_left("alice"))}")
  println("bob   -> \{show(directory.get_by_left("bob"))}")
  println("dave  -> \{show(directory.get_by_left("dave"))}")

  println("=== reverse lookup: email -> username ===")
  println(
    "carol@example.com -> \{show(directory.get_by_right("carol@example.com"))}",
  )
  println(
    "bob@example.com   -> \{show(directory.get_by_right("bob@example.com"))}",
  )

  println("=== all pairs in insertion order ===")
  for pair in directory.iter() {
    let (name, email) = pair
    println("\{name} <-> \{email}")
  }

  println("=== rebind bob's email (C2: one username, new email) ===")
  directory.insert("bob", "robert@example.com") |> ignore
  println("bob -> \{show(directory.get_by_left("bob"))}")
  println(
    "bob@example.com now owned by -> \{show(directory.get_by_right("bob@example.com"))}",
  )
}
