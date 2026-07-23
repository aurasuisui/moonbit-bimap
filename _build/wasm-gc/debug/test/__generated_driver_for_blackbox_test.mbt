// #region Define traits with default implementations

///|
/// is_being_cancelled may be unused if there's no async test
#warnings("-unused_value")
trait MoonBit_Async_Test_Driver {
  fn run_async_tests(@moonbitlang/core/prelude.Array[async () -> Unit]) -> Unit = _
  fn is_being_cancelled() -> Bool = _
}

///|
impl MoonBit_Async_Test_Driver with fn run_async_tests(_) {
  ()
}

///|
impl MoonBit_Async_Test_Driver with fn is_being_cancelled() {
  false
}

///|
trait MoonBit_Test_Driver {
  /// returns if the test is found and executed
  fn run_test(
    @moonbitlang/core/prelude.Array[async () -> Unit],
    String,
    Int,
    () -> Unit,
    (String, String, Bool) -> Unit,
    (Error) -> String,
  ) -> Bool raise MoonBitTestDriverInternalSkipTest = _
}

///|
impl MoonBit_Test_Driver with fn run_test(_, _, _, _, _, _) {
  false
}

// #endregion
// #region Define abstract types for namespace with implementation declarations

///|
priv type MoonBit_Test_Driver_Internal_No_Args

///|
impl MoonBit_Test_Driver for MoonBit_Test_Driver_Internal_No_Args

///|
priv type MoonBit_Test_Driver_Internal_With_Args

///|
impl MoonBit_Test_Driver for MoonBit_Test_Driver_Internal_With_Args

///|
priv type MoonBit_Test_Driver_Internal_Async_No_Args

///|
impl MoonBit_Test_Driver for MoonBit_Test_Driver_Internal_Async_No_Args

///|
priv type MoonBit_Test_Driver_Internal_Async_With_Args

///|
impl MoonBit_Test_Driver for MoonBit_Test_Driver_Internal_Async_With_Args

///|
priv type MoonBit_Test_Driver_Internal_With_Bench_Args

///|
impl MoonBit_Test_Driver for MoonBit_Test_Driver_Internal_With_Bench_Args

///|
priv type MoonBit_Async_Test_Driver_Impl

///|
impl MoonBit_Async_Test_Driver for MoonBit_Async_Test_Driver_Impl

///|
extend MoonBit_Test_Driver_Internal_No_Args with MoonBit_Test_Driver::{run_test}

///|
extend MoonBit_Test_Driver_Internal_With_Args with MoonBit_Test_Driver::{
  run_test,
}

///|
extend MoonBit_Test_Driver_Internal_Async_No_Args with MoonBit_Test_Driver::{
  run_test,
}

///|
extend MoonBit_Test_Driver_Internal_Async_With_Args with MoonBit_Test_Driver::{
  run_test,
}

///|
extend MoonBit_Test_Driver_Internal_With_Bench_Args with MoonBit_Test_Driver::{
  run_test,
}

///|
extend MoonBit_Async_Test_Driver_Impl with MoonBit_Async_Test_Driver::{
  run_async_tests,
  is_being_cancelled,
}

///|
// `is_being_cancelled` is only called from async-test templates. This shared
// scaffold is also generated for packages without async tests, so reference
// the method value to keep strict warning lists from treating the explicit
// extend as unused without invoking cancellation logic during initialization.
fn init {
  ignore(MoonBit_Async_Test_Driver_Impl::is_being_cancelled)
}

// #endregion

// #region Utility Types

///|
/// Maybe unused if there's no tests
#warnings("-unused_type_declaration")
priv struct MoonBitTestDriverInternalTestMap[F](
  @moonbitlang/core/prelude.Map[
    String,
    @moonbitlang/core/prelude.Map[Int, (F, ReadOnlyArray[String])],
  ]
)

///|
priv suberror MoonBitTestDriverInternalSkipTest {
  MoonBitTestDriverInternalSkipTest(name~ : String)
}

// #endregion
///|
fn moonbit_test_driver_internal_error_to_string(x : Error) -> String = "%error.to_string"

///|
#cfg(any(target="native", target="llvm"))
fn string_get(s : String, index : Int) -> Int = "%string_get"

///|
#cfg(not(target="js"))
fn moonbit_unsafe_char_from_int(x : Int) -> Char = "%identity"

///|
#cfg(any(target="native", target="llvm"))
const MOONBIT_TEST_DRIVER_INTERNAL_IS_NATIVE = true

///|
#cfg(not(any(target="native", target="llvm")))
const MOONBIT_TEST_DRIVER_INTERNAL_IS_NATIVE = false

// =========================================================
// ================== BEGIN WASM SPECIFIC ==================
// =========================================================

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn moonbit_test_driver_internal_get_file_name(
  file_name : MoonbitTestDriverInternalExternString,
) -> String {
  moonbit_test_driver_internal_string_from_extern(file_name)
}

///|
#cfg(any(target="wasm", target="wasm-gc"))
#external
type MoonbitTestDriverInternalStringReadHandle

///|
#cfg(any(target="wasm", target="wasm-gc"))
#external
type MoonbitTestDriverInternalExternString

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn moonbit_test_driver_internal_begin_read_string(
  s : MoonbitTestDriverInternalExternString,
) -> MoonbitTestDriverInternalStringReadHandle = "__moonbit_fs_unstable" "begin_read_string"

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn moonbit_test_driver_internal_string_read_char(
  handle : MoonbitTestDriverInternalStringReadHandle,
) -> Int = "__moonbit_fs_unstable" "string_read_char"

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn moonbit_test_driver_internal_finish_read_string(
  handle : MoonbitTestDriverInternalStringReadHandle,
) = "__moonbit_fs_unstable" "finish_read_string"

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn fixedarray_to_bytes(arr : FixedArray[Byte]) -> Bytes = "%identity"

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn moonbit_test_driver_internal_string_from_extern(
  e : MoonbitTestDriverInternalExternString,
) -> String {
  let buf = FixedArray::make(512, Byte::default())
  let mut len = 0
  let handle = moonbit_test_driver_internal_begin_read_string(e)
  while true {
    let ch = moonbit_test_driver_internal_string_read_char(handle)
    if ch == -1 {
      break
    } else {
      let written_bytes_len = buf.set_utf16le_char(
        len,
        moonbit_unsafe_char_from_int(ch),
      )
      len += written_bytes_len
    }
  }
  moonbit_test_driver_internal_finish_read_string(handle)
  fixedarray_to_bytes(buf).to_unchecked_string(offset=0, length=len).to_string()
}

// =========================================================
// =================== END WASM SPECIFIC ===================
// =========================================================

// =========================================================
// ============== BEGIN NATIVE/LLVM SPECIFIC ===============
// =========================================================

///|
#cfg(any(target="native", target="llvm"))
fn moonbit_test_driver_internal_native_parse_args() -> @moonbitlang/core/prelude.Array[
  (String, Int),
] {
  fn moonbit_test_driver_internal_parse_int_(s : String) -> Int {
    let mut res = 0
    let len = s.length()
    for i in 0..<len {
      res = res * 10 + (string_get(s, i) - '0')
    }
    res
  }

  fn moonbit_test_driver_internal_utf8_bytes_to_mbt_string(
    bytes : Bytes,
  ) -> String {
    let res = @moonbitlang/core/prelude.StringBuilder::new()
    let len = bytes.length()
    let mut i = 0
    while i < len {
      let mut c = bytes[i].to_int()
      if c < 0x80 {
        res.write_char(moonbit_unsafe_char_from_int(c))
        i += 1
      } else if c < 0xE0 {
        if i + 1 >= len {
          break
        }
        c = ((c & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
        res.write_char(moonbit_unsafe_char_from_int(c))
        i += 2
      } else if c < 0xF0 {
        if i + 2 >= len {
          break
        }
        c = ((c & 0x0F) << 12) |
          ((bytes[i + 1].to_int() & 0x3F) << 6) |
          (bytes[i + 2].to_int() & 0x3F)
        res.write_char(moonbit_unsafe_char_from_int(c))
        i += 3
      } else {
        if i + 3 >= len {
          break
        }
        c = ((c & 0x07) << 18) |
          ((bytes[i + 1].to_int() & 0x3F) << 12) |
          ((bytes[i + 2].to_int() & 0x3F) << 6) |
          (bytes[i + 3].to_int() & 0x3F)
        c -= 0x10000
        res.write_char(moonbit_unsafe_char_from_int((c >> 10) + 0xD800))
        res.write_char(moonbit_unsafe_char_from_int((c & 0x3FF) + 0xDC00))
        i += 4
      }
    }
    res.to_string()
  }

  fn moonbit_test_driver_internal_get_cli_args_internal() -> @moonbitlang/core/prelude.Array[
    String,
  ] {
    let tmp = moonbit_test_driver_internal_get_cli_args_ffi()
    let res = @moonbitlang/core/prelude.Array::new(capacity=tmp.length())
    for i in 0..<tmp.length() {
      res.push(moonbit_test_driver_internal_utf8_bytes_to_mbt_string(tmp[i]))
    }
    res
  }

  fn moonbit_test_driver_internal_split_mbt_string(
    s : String,
    sep : Char,
  ) -> @moonbitlang/core/prelude.Array[String] {
    let res = []
    let mut i = 0
    let mut start = 0
    while i < s.length() {
      if moonbit_unsafe_char_from_int(string_get(s, i)) == sep {
        res.push(s.unsafe_substring(start~, end=i))
        start = i + 1
      }
      i += 1
    }
    if start < s.length() {
      res.push(s.unsafe_substring(start~, end=s.length()))
    }
    res
  }

  let file_and_index = []
  let cli_args = moonbit_test_driver_internal_get_cli_args_internal()
  let test_args = moonbit_test_driver_internal_split_mbt_string(
    cli_args[1],
    '/',
  )
  for arg in test_args {
    let file_and_range = moonbit_test_driver_internal_split_mbt_string(arg, ':')
    let file = file_and_range[0]
    let range = file_and_range[1]
    let start_and_end = moonbit_test_driver_internal_split_mbt_string(
      range, '-',
    )
    let start = moonbit_test_driver_internal_parse_int_(start_and_end[0])
    let end = moonbit_test_driver_internal_parse_int_(start_and_end[1])
    for i in start..<end {
      file_and_index.push((file, i))
    }
  }
  file_and_index
}

///|
#cfg(any(target="native", target="llvm"))
fn moonbit_test_driver_internal_get_cli_args_ffi() -> FixedArray[Bytes] = "$moonbit.get_cli_args"

// =========================================================
// =============== END NATIVE/LLVM SPECIFIC ================
// =========================================================

// =========================================================
// -================== BEGIN JS SPECIFIC ===================
// =========================================================

///|
#cfg(target="js")
#external
type MoonBitTestDriverInternalTestEntry

///|
#cfg(target="js")
extern "js" fn MoonBitTestDriverInternalTestEntry::filename(
  self : Self,
) -> String =
  #| (entry) => entry[0]

///|
#cfg(target="js")
extern "js" fn MoonBitTestDriverInternalTestEntry::index(self : Self) -> Int =
  #| (entry) => entry[1]

///|
/// JavaScript error captured by the generated test driver.
pub(all) suberror MoonBitTestDriverInternalJsError {
  MoonBitTestDriverInternalJsError(String)
}

///|
/// Maybe unused if there's no tests
#cfg(target="js")
#warnings("-unused_value")
fn moonbit_test_driver_internal_catch_error(
  f : () -> Unit raise,
  on_ok~ : () -> Unit,
  on_err~ : (Error) -> Unit,
) -> Unit {
  moonbit_test_driver_internal_js_catch(
    on_err=err_str => on_err(MoonBitTestDriverInternalJsError(err_str)),
    () => {
      try f() catch {
        err => on_err(err)
      } noraise {
        _ => on_ok()
      }
    },
  )
}

///|
#cfg(target="js")
extern "js" fn moonbit_test_driver_internal_js_catch(
  f : () -> Unit,
  on_err~ : (String) -> Unit,
) =
  #| (f, on_err) => {
  #|   try {
  #|     f()
  #|   } catch (err) {
  #|     const msg = err.stack.toString()
  #|     on_err(msg)
  #|   }
  #| }

///|
/// Maybe unused if there's no tests
#cfg(not(target="js"))
#warnings("-unused_value")
fn moonbit_test_driver_internal_catch_error(
  f : () -> Unit raise,
  on_ok~ : () -> Unit,
  on_err~ : (Error) -> Unit,
) -> Unit {
  try f() catch {
    err => on_err(err)
  } noraise {
    _ => on_ok()
  }
}

// =========================================================
// -=================== END JS SPECIFIC ====================
// =========================================================
// This file is introduced when tests without args is needed

///|
let moonbit_test_driver_internal_no_args_tests : MoonBitTestDriverInternalTestMap[
  () -> Unit raise,
] = {
  "types_test.mbt": {
    0: (__test_74797065735f746573742e6d6274_0, ["BiMap[Int, Int]: basic CRUD"]),
    1: (__test_74797065735f746573742e6d6274_1, ["BiMap[Int, Int]: negative and zero keys"]),
    2: (__test_74797065735f746573742e6d6274_2, ["BiMap[Int, Int]: large keys"]),
    3: (__test_74797065735f746573742e6d6274_3, ["BiMap[Int, String]: basic CRUD"]),
    4: (__test_74797065735f746573742e6d6274_4, ["BiMap[Int, String]: C2/C3 with string rights"]),
    5: (__test_74797065735f746573742e6d6274_5, ["BiMap[String, String]: basic CRUD"]),
    6: (__test_74797065735f746573742e6d6274_6, ["BiMap[String, String]: empty-string key and value"]),
    7: (__test_74797065735f746573742e6d6274_7, ["BiMap[Bool, Int]: basic CRUD over the two boolean keys"]),
    8: (__test_74797065735f746573742e6d6274_8, ["BiMap[Bool, Int]: rebinding a boolean key (C2)"]),
    9: (__test_74797065735f746573742e6d6274_9, ["BiMap[Char, Int]: basic CRUD"]),
    10: (__test_74797065735f746573742e6d6274_10, ["BiMap[Char, Int]: order preserved across char keys"]),
    11: (__test_74797065735f746573742e6d6274_11, ["BiMap[String, Bool]: basic CRUD"]),
    12: (__test_74797065735f746573742e6d6274_12, ["BiMap[Int, Int]: order-independent Eq"]),
    13: (__test_74797065735f746573742e6d6274_13, ["BiMap[Char, Int]: copy preserves content"]),
    14: (__test_74797065735f746573742e6d6274_14, ["BiMap[Int, String]: to_inverse swaps to BiMap[String, Int]"]),
    15: (__test_74797065735f746573742e6d6274_15, ["BiMap[Int, Int]: Show rendering"]),
    16: (__test_74797065735f746573742e6d6274_16, ["BiMap[Int, Int]: ToJson uses decimal-text keys"]),
    17: (__test_74797065735f746573742e6d6274_17, ["single-element map: first == last across a C2 rebind"]),
  },
  "traits_test.mbt": {
    0: (__test_7472616974735f746573742e6d6274_0, ["Eq: same pairs in different insertion order are equal"]),
    1: (__test_7472616974735f746573742e6d6274_1, ["Eq: reflexive"]),
    2: (__test_7472616974735f746573742e6d6274_2, ["Eq: symmetric"]),
    3: (__test_7472616974735f746573742e6d6274_3, ["Eq: different right values are not equal"]),
    4: (__test_7472616974735f746573742e6d6274_4, ["Eq: different lengths are not equal"]),
    5: (__test_7472616974735f746573742e6d6274_5, ["Eq: a left key mapped differently is not equal"]),
    6: (__test_7472616974735f746573742e6d6274_6, ["Hash: same pairs in different order hash equally"]),
    7: (__test_7472616974735f746573742e6d6274_7, ["Hash: equal maps have equal hashes (Eq => Hash)"]),
    8: (__test_7472616974735f746573742e6d6274_8, ["Hash: empty maps hash equally"]),
    9: (__test_7472616974735f746573742e6d6274_9, ["Show renders BiMap{left <-> right, ...} in insertion order"]),
    10: (__test_7472616974735f746573742e6d6274_10, ["Show of empty map"]),
    11: (__test_7472616974735f746573742e6d6274_11, ["Debug renders an opaque BiMap representation"]),
    12: (__test_7472616974735f746573742e6d6274_12, ["default() produces an empty map"]),
    13: (__test_7472616974735f746573742e6d6274_13, ["ToJson keys are left.to_string() with no mangling"]),
    14: (__test_7472616974735f746573742e6d6274_14, ["ToJson with integer left keys uses their decimal text"]),
    15: (__test_7472616974735f746573742e6d6274_15, ["ToJson handles composite right values"]),
    16: (__test_7472616974735f746573742e6d6274_16, ["iter yields pairs in insertion order"]),
    17: (__test_7472616974735f746573742e6d6274_17, ["for-in over iter() works"]),
    18: (__test_7472616974735f746573742e6d6274_18, ["lefts yields left keys in insertion order"]),
    19: (__test_7472616974735f746573742e6d6274_19, ["rights yields right values in insertion order"]),
    20: (__test_7472616974735f746573742e6d6274_20, ["iterating twice gives the same order (idempotent)"]),
    21: (__test_7472616974735f746573742e6d6274_21, ["iter on empty map yields nothing"]),
  },
  "property_test.mbt": {
    0: (__test_70726f70657274795f746573742e6d6274_0, ["qc: invariants hold after random inserts"]),
    1: (__test_70726f70657274795f746573742e6d6274_1, ["qc: invariants hold after mixed insert / remove operations"]),
    2: (__test_70726f70657274795f746573742e6d6274_2, ["qc: invariants hold after insert-all then remove-half"]),
    3: (__test_70726f70657274795f746573742e6d6274_3, ["qc: invariants hold on small-key maps (forces many C2/C3/C4)"]),
    4: (__test_70726f70657274795f746573742e6d6274_4, ["invariants hold after a C4 collapse"]),
    5: (__test_70726f70657274795f746573742e6d6274_5, ["invariants hold across many C4/C3 collisions"]),
    6: (__test_70726f70657274795f746573742e6d6274_6, ["invariants hold across grow/shrink cycles"]),
  },
  "more_test.mbt": {
    0: (__test_6d6f72655f746573742e6d6274_0, ["C0/C1/C2/C3/C4 all reachable on a single Int,Int map"]),
    1: (__test_6d6f72655f746573742e6d6274_1, ["C2 then C3 on overlapping keys stays consistent"]),
    2: (__test_6d6f72655f746573742e6d6274_2, ["many fresh inserts then exact reinserts are all Pair"]),
    3: (__test_6d6f72655f746573742e6d6274_3, ["get_index_of_left after C3 takeover points to the new owner"]),
    4: (__test_6d6f72655f746573742e6d6274_4, ["get_index after C4 returns the surviving pair"]),
    5: (__test_6d6f72655f746573742e6d6274_5, ["last after C4 collapse is the survivor"]),
    6: (__test_6d6f72655f746573742e6d6274_6, ["qc: Char-keyed generated maps satisfy invariants"]),
    7: (__test_6d6f72655f746573742e6d6274_7, ["qc: Bool-keyed maps (tiny keyspace) satisfy invariants"]),
    8: (__test_6d6f72655f746573742e6d6274_8, ["qc: copy of a generated map equals the original"]),
    9: (__test_6d6f72655f746573742e6d6274_9, ["qc: interleaving insert and insert_no_overwrite keeps invariants"]),
    10: (__test_6d6f72655f746573742e6d6274_10, ["from_array then to_inverse then from_array round-trip"]),
    11: (__test_6d6f72655f746573742e6d6274_11, ["Show after C4 collapse shows only the survivor"]),
    12: (__test_6d6f72655f746573742e6d6274_12, ["ToJson after removal omits the removed key"]),
    13: (__test_6d6f72655f746573742e6d6274_13, ["Debug of empty map (snapshot)"]),
    14: (__test_6d6f72655f746573742e6d6274_14, ["Eq: maps with swapped pairs are NOT equal (ordered pairs)"]),
    15: (__test_6d6f72655f746573742e6d6274_15, ["is_empty flips correctly across insert/remove"]),
    16: (__test_6d6f72655f746573742e6d6274_16, ["with_capacity larger than needed still functions"]),
    17: (__test_6d6f72655f746573742e6d6274_17, ["lefts and rights have matching lengths"]),
    18: (__test_6d6f72655f746573742e6d6274_18, ["into_array length equals len after many ops"]),
    19: (__test_6d6f72655f746573742e6d6274_19, ["VERSION constant is exposed"]),
    20: (__test_6d6f72655f746573742e6d6274_20, ["from_array is idempotent on its own output"]),
    21: (__test_6d6f72655f746573742e6d6274_21, ["to_inverse preserves the pair count"]),
    22: (__test_6d6f72655f746573742e6d6274_22, ["the two directions stay symmetric over a long deterministic sequence"]),
    23: (__test_6d6f72655f746573742e6d6274_23, ["iter, lefts, rights all report the same count"]),
  },
  "edge_test.mbt": {
    0: (__test_656467655f746573742e6d6274_0, ["C0 into a map with tombstones reuses slots"]),
    1: (__test_656467655f746573742e6d6274_1, ["C2: repeated rebinds of the same left key"]),
    2: (__test_656467655f746573742e6d6274_2, ["C2 does not disturb unrelated pairs"]),
    3: (__test_656467655f746573742e6d6274_3, ["C3: a right value handed across several left keys"]),
    4: (__test_656467655f746573742e6d6274_4, ["C3 does not disturb unrelated pairs"]),
    5: (__test_656467655f746573742e6d6274_5, ["C4 collapses non-adjacent pairs and keeps survivor order"]),
    6: (__test_656467655f746573742e6d6274_6, ["C1 idempotence does not bump observable order"]),
    7: (__test_656467655f746573742e6d6274_7, ["insert the same left with two rights then back"]),
    8: (__test_656467655f746573742e6d6274_8, ["get_by_left resolves every key after batch insert"]),
    9: (__test_656467655f746573742e6d6274_9, ["get_by_right resolves every value after batch insert"]),
    10: (__test_656467655f746573742e6d6274_10, ["contains reflects removal on both sides"]),
    11: (__test_656467655f746573742e6d6274_11, ["get returns updated value after C2 rebind"]),
    12: (__test_656467655f746573742e6d6274_12, ["get returns new owner after C3 takeover"]),
    13: (__test_656467655f746573742e6d6274_13, ["remove_by_left returns the removed right value"]),
    14: (__test_656467655f746573742e6d6274_14, ["remove_by_right returns the removed left key"]),
    15: (__test_656467655f746573742e6d6274_15, ["remove the first element"]),
    16: (__test_656467655f746573742e6d6274_16, ["remove the last element"]),
    17: (__test_656467655f746573742e6d6274_17, ["remove the only element leaves an empty map"]),
    18: (__test_656467655f746573742e6d6274_18, ["remove all elements one by one (forward)"]),
    19: (__test_656467655f746573742e6d6274_19, ["remove all elements in reverse insertion order"]),
    20: (__test_656467655f746573742e6d6274_20, ["removing a missing key after draining returns None"]),
    21: (__test_656467655f746573742e6d6274_21, ["interleaved insert and remove stay consistent"]),
    22: (__test_656467655f746573742e6d6274_22, ["remove then contains is false on both directions"]),
    23: (__test_656467655f746573742e6d6274_23, ["get_index with negative index returns None"]),
    24: (__test_656467655f746573742e6d6274_24, ["get_index equal to len returns None"]),
    25: (__test_656467655f746573742e6d6274_25, ["get_index_of_left reindexes after a middle removal"]),
    26: (__test_656467655f746573742e6d6274_26, ["get_index_of_right reindexes after removal"]),
    27: (__test_656467655f746573742e6d6274_27, ["first after removing the first element advances"]),
    28: (__test_656467655f746573742e6d6274_28, ["last after removing the last element retreats"]),
    29: (__test_656467655f746573742e6d6274_29, ["get_index in the middle"]),
    30: (__test_656467655f746573742e6d6274_30, ["get_index_of_left agrees with iteration position for all keys"]),
    31: (__test_656467655f746573742e6d6274_31, ["C2 rebind leaves the index unchanged"]),
    32: (__test_656467655f746573742e6d6274_32, ["from_array on an empty array yields an empty map"]),
    33: (__test_656467655f746573742e6d6274_33, ["from_array on a single pair"]),
    34: (__test_656467655f746573742e6d6274_34, ["from_array where every pair shares the left key"]),
    35: (__test_656467655f746573742e6d6274_35, ["from_array where every pair shares the right value"]),
    36: (__test_656467655f746573742e6d6274_36, ["with_capacity(0) still works"]),
    37: (__test_656467655f746573742e6d6274_37, ["with_capacity rounds up to a power of two"]),
    38: (__test_656467655f746573742e6d6274_38, ["capacity is always at least len"]),
    39: (__test_656467655f746573742e6d6274_39, ["copy of an empty map is empty and independent"]),
    40: (__test_656467655f746573742e6d6274_40, ["mutating the original does not affect an earlier copy"]),
    41: (__test_656467655f746573742e6d6274_41, ["to_inverse of an empty map is empty"]),
    42: (__test_656467655f746573742e6d6274_42, ["to_inverse of a single pair swaps it"]),
    43: (__test_656467655f746573742e6d6274_43, ["Eq: two empty maps are equal"]),
    44: (__test_656467655f746573742e6d6274_44, ["Eq: empty is not equal to non-empty"]),
    45: (__test_656467655f746573742e6d6274_45, ["Hash: hashing the same map twice is stable"]),
    46: (__test_656467655f746573742e6d6274_46, ["Eq: same pair set reached by different operation paths is equal"]),
    47: (__test_656467655f746573742e6d6274_47, ["Show of a single pair"]),
    48: (__test_656467655f746573742e6d6274_48, ["Show reflects removal"]),
    49: (__test_656467655f746573742e6d6274_49, ["ToJson of an empty map is an empty object"]),
    50: (__test_656467655f746573742e6d6274_50, ["ToJson of a single pair"]),
    51: (__test_656467655f746573742e6d6274_51, ["Default then insert behaves like new"]),
  },
  "coverage_test.mbt": {
    0: (__test_636f7665726167655f746573742e6d6274_0, ["insert_no_overwrite: several fresh inserts all succeed"]),
    1: (__test_636f7665726167655f746573742e6d6274_1, ["insert_no_overwrite: failure leaves order intact"]),
    2: (__test_636f7665726167655f746573742e6d6274_2, ["insert_no_overwrite then insert: strict guard then forced"]),
    3: (__test_636f7665726167655f746573742e6d6274_3, ["into_array after a C2 rebind shows the new right"]),
    4: (__test_636f7665726167655f746573742e6d6274_4, ["into_array after a C3 takeover drops the old left"]),
    5: (__test_636f7665726167655f746573742e6d6274_5, ["into_array after a C4 collapse has one fewer pair"]),
    6: (__test_636f7665726167655f746573742e6d6274_6, ["lefts after removals skips removed keys"]),
    7: (__test_636f7665726167655f746573742e6d6274_7, ["rights after a C2 rebind reflects the new value"]),
    8: (__test_636f7665726167655f746573742e6d6274_8, ["iter count matches len after mixed ops"]),
    9: (__test_636f7665726167655f746573742e6d6274_9, ["get_index_of_right equals get_index_of_left of its partner"]),
    10: (__test_636f7665726167655f746573742e6d6274_10, ["first/last track insertions"]),
    11: (__test_636f7665726167655f746573742e6d6274_11, ["get_index walks the whole map in order"]),
    12: (__test_636f7665726167655f746573742e6d6274_12, ["copy independence: editing copy leaves original intact"]),
    13: (__test_636f7665726167655f746573742e6d6274_13, ["to_inverse independence: editing inverse leaves original intact"]),
    14: (__test_636f7665726167655f746573742e6d6274_14, ["to_inverse of to_inverse round-trips lookups"]),
    15: (__test_636f7665726167655f746573742e6d6274_15, ["qc: String-keyed generated maps satisfy invariants"]),
    16: (__test_636f7665726167655f746573742e6d6274_16, ["qc: removing random left keys keeps invariants"]),
    17: (__test_636f7665726167655f746573742e6d6274_17, ["qc: removing random right keys keeps invariants"]),
    18: (__test_636f7665726167655f746573742e6d6274_18, ["qc: insert_no_overwrite never breaks invariants"]),
    19: (__test_636f7665726167655f746573742e6d6274_19, ["capacity stays a power of two through growth"]),
    20: (__test_636f7665726167655f746573742e6d6274_20, ["len never exceeds the number of inserted distinct pairs"]),
    21: (__test_636f7665726167655f746573742e6d6274_21, ["reinserting all after a full drain restores content"]),
    22: (__test_636f7665726167655f746573742e6d6274_22, ["contains_left/right agree with get_by_left/right"]),
    23: (__test_636f7665726167655f746573742e6d6274_23, ["Eq and Hash agree across copy"]),
  },
  "bimap_test.mbt": {
    0: (__test_62696d61705f746573742e6d6274_0, ["C0: insert into empty map returns Neither"]),
    1: (__test_62696d61705f746573742e6d6274_1, ["C0: two fresh inserts both return Neither"]),
    2: (__test_62696d61705f746573742e6d6274_2, ["C1: exact reinsert returns Pair and is idempotent"]),
    3: (__test_62696d61705f746573742e6d6274_3, ["C2: rebinding a left key returns Left with the old right"]),
    4: (__test_62696d61705f746573742e6d6274_4, ["C3: rebinding a right value returns Right with the old left"]),
    5: (__test_62696d61705f746573742e6d6274_5, ["C4: both-sides conflict collapses two pairs into one"]),
    6: (__test_62696d61705f746573742e6d6274_6, ["C1 right after C4: reinserting the surviving pair is Pair"]),
    7: (__test_62696d61705f746573742e6d6274_7, ["reproduce the full Rust bimap golden sequence"]),
    8: (__test_62696d61705f746573742e6d6274_8, ["C2 rebinding keeps the left key's insertion position"]),
    9: (__test_62696d61705f746573742e6d6274_9, ["empty-string key behaves normally"]),
    10: (__test_62696d61705f746573742e6d6274_10, ["get_by_left miss returns None"]),
    11: (__test_62696d61705f746573742e6d6274_11, ["get_by_right miss returns None"]),
    12: (__test_62696d61705f746573742e6d6274_12, ["contains_left / contains_right"]),
    13: (__test_62696d61705f746573742e6d6274_13, ["lookup symmetry: get_by_left(l)==Some(r) iff get_by_right(r)==Some(l)"]),
    14: (__test_62696d61705f746573742e6d6274_14, ["remove_by_left removes both directions"]),
    15: (__test_62696d61705f746573742e6d6274_15, ["remove_by_left on missing key returns None and changes nothing"]),
    16: (__test_62696d61705f746573742e6d6274_16, ["remove_by_right removes both directions"]),
    17: (__test_62696d61705f746573742e6d6274_17, ["remove_by_right on missing value returns None"]),
    18: (__test_62696d61705f746573742e6d6274_18, ["removal shrinks the order, keeping remaining indices correct"]),
    19: (__test_62696d61705f746573742e6d6274_19, ["remove then reinsert reuses the tombstone path correctly"]),
    20: (__test_62696d61705f746573742e6d6274_20, ["drain to empty then is_empty"]),
    21: (__test_62696d61705f746573742e6d6274_21, ["new map is empty"]),
    22: (__test_62696d61705f746573742e6d6274_22, ["with_capacity reports at least the requested capacity"]),
    23: (__test_62696d61705f746573742e6d6274_23, ["into_array preserves insertion order"]),
    24: (__test_62696d61705f746573742e6d6274_24, ["insert_no_overwrite: fresh insert returns Ok"]),
    25: (__test_62696d61705f746573742e6d6274_25, ["insert_no_overwrite: left conflict returns Err and changes nothing"]),
    26: (__test_62696d61705f746573742e6d6274_26, ["insert_no_overwrite: right conflict returns Err and changes nothing"]),
    27: (__test_62696d61705f746573742e6d6274_27, ["insert_no_overwrite: both-sides conflict (C4 shape) returns Err, no collapse"]),
    28: (__test_62696d61705f746573742e6d6274_28, ["insert_no_overwrite: exact existing pair returns Err"]),
    29: (__test_62696d61705f746573742e6d6274_29, ["get_index: first and last by position"]),
    30: (__test_62696d61705f746573742e6d6274_30, ["get_index: out of bounds returns None"]),
    31: (__test_62696d61705f746573742e6d6274_31, ["get_index_of_left: hit and miss"]),
    32: (__test_62696d61705f746573742e6d6274_32, ["get_index_of_right: hit and miss"]),
    33: (__test_62696d61705f746573742e6d6274_33, ["first / last on non-empty and empty maps"]),
    34: (__test_62696d61705f746573742e6d6274_34, ["single element: first == last"]),
    35: (__test_62696d61705f746573742e6d6274_35, ["insertion order == iteration order == index order"]),
    36: (__test_62696d61705f746573742e6d6274_36, ["C4 collapse reindexes the survivors correctly"]),
    37: (__test_62696d61705f746573742e6d6274_37, ["from_array with no duplicates"]),
    38: (__test_62696d61705f746573742e6d6274_38, ["from_array with duplicate left keys: last wins"]),
    39: (__test_62696d61705f746573742e6d6274_39, ["from_array triggering C4 keeps the count correct"]),
    40: (__test_62696d61705f746573742e6d6274_40, ["copy is a deep, independent copy"]),
    41: (__test_62696d61705f746573742e6d6274_41, ["to_inverse swaps sides and is a copy"]),
    42: (__test_62696d61705f746573742e6d6274_42, ["to_inverse is an involution: m.to_inverse().to_inverse() == m (as pairs)"]),
    43: (__test_62696d61705f746573742e6d6274_43, ["to_inverse preserves pair order"]),
  },
  "bench_test.mbt": {
    0: (__test_62656e63685f746573742e6d6274_0, ["stress: 10k sequential inserts keep invariants and lookups hit"]),
    1: (__test_62656e63685f746573742e6d6274_1, ["stress: insert 10k then remove 5k keeps counts and survivors correct"]),
    2: (__test_62656e63685f746573742e6d6274_2, ["stress: resize cascade from 16 keeps invariants at each crossing"]),
    3: (__test_62656e63685f746573742e6d6274_3, ["stress: tombstone buildup then rehash stays correct"]),
    4: (__test_62656e63685f746573742e6d6274_4, ["stress: heavy C4 traffic keeps len consistent and non-negative"]),
    5: (__test_62656e63685f746573742e6d6274_5, ["stress: 20000 deterministic mixed operations end in a valid state"]),
  },
  "arbitrary_test.mbt": {
    0: (__test_6172626974726172795f746573742e6d6274_0, ["qc: generated BiMaps satisfy the bijection invariants"]),
    1: (__test_6172626974726172795f746573742e6d6274_1, ["qc: generated BiMaps report a consistent length"]),
    2: (__test_6172626974726172795f746573742e6d6274_2, ["qc: Eq/Hash are order-independent on random maps (reverse insertion)"]),
    3: (__test_6172626974726172795f746573742e6d6274_3, ["qc: copy() yields an equal map"]),
    4: (__test_6172626974726172795f746573742e6d6274_4, ["qc: to_inverse is an involution on random maps"]),
    5: (__test_6172626974726172795f746573742e6d6274_5, ["qc: to_inverse flips every lookup"]),
  },
}


///|
impl MoonBit_Test_Driver for MoonBit_Test_Driver_Internal_No_Args with fn run_test(
  _,
  filename,
  index,
  handle_start,
  handle_result,
  error_to_string,
) {
  if moonbit_test_driver_internal_no_args_tests.0.get(filename)
    is Some(index_map) &&
    index_map.get(index) is Some((f, attrs)) {
    let name = if attrs is [name, ..] { name } else { "" }
    if MOONBIT_TEST_DRIVER_INTERNAL_IS_NATIVE {
      for attr in attrs {
        if attr is [.. "panic", ..] {
          raise MoonBitTestDriverInternalSkipTest(name~)
        }
      }
    }
    handle_start()
    moonbit_test_driver_internal_catch_error(
      f,
      on_ok=() => handle_result(name, "", false),
      on_err=err => handle_result(name, error_to_string(err), false),
    )
    true
  } else {
    false
  }
}
///|
#cfg(any(target="native", target="llvm"))
#test_entry
fn main {
  let async_tests = []
  for arg in moonbit_test_driver_internal_native_parse_args() {
    moonbit_test_driver_internal_do_execute(async_tests, arg.0, arg.1)
  }
  MoonBit_Async_Test_Driver_Impl::run_async_tests(async_tests)
}

///|
#cfg(target="js")
#test_entry
fn main {
  let test_params = moonbit_test_driver_js_parse_args()
  moonbit_test_driver_internal_execute(test_params)
  moonbit_test_driver_finish()
}

///|
#cfg(any(target="wasm", target="wasm-gc"))
#test_entry
fn main {
  ()
}

///|
#cfg(target="js")
extern "js" fn moonbit_test_driver_js_parse_args() -> Array[
  MoonBitTestDriverInternalTestEntry,
] =
  #|() => {
  #|  try {
  #|    let testParams = []
  #|    // check if there is command line argument
  #|    if (process.argv.length > 2) {
  #|      const testArgs = JSON.parse(process.argv[2])
  #|      testParams = testArgs.file_and_index.flatMap(([file, ranges]) => {
  #|        let arr = []
  #|        for (let range of ranges) {
  #|          for (let i = range.start; i < range.end; i++) {
  #|            arr.push([file, i])
  #|          }
  #|        }
  #|        return arr
  #|      })
  #|      return testParams
  #|    }
  #|  } catch (error) {
  #|    console.error('failed to parse args: ', error.message)
  #|    process.exit(1)
  #|  }
  #|}

///|
/// Executes selected JavaScript tests from parsed test entries.
#cfg(target="js")
pub fn moonbit_test_driver_internal_execute(
  tests : Array[MoonBitTestDriverInternalTestEntry],
) -> Unit {
  let async_tests = []
  for i in 0..<tests.length() {
    let entry = tests[i]
    moonbit_test_driver_internal_do_execute(
      async_tests,
      entry.filename(),
      entry.index(),
    )
  }
  MoonBit_Async_Test_Driver_Impl::run_async_tests(async_tests)
}

///|
#cfg(target="wasm")
let moonbit_test_driver_internal_wasm_async_tests : Array[async () -> Unit] = []

///|
/// Executes one selected WebAssembly test and stores async work for finalization.
#cfg(target="wasm")
pub fn moonbit_test_driver_internal_execute(
  filename : MoonbitTestDriverInternalExternString,
  index : Int,
) -> Unit {
  let filename = moonbit_test_driver_internal_get_file_name(filename)
  moonbit_test_driver_internal_do_execute(
    moonbit_test_driver_internal_wasm_async_tests, filename, index,
  )
}

///|
/// Executes one selected WebAssembly GC test and drains async work immediately.
#cfg(target="wasm-gc")
pub fn moonbit_test_driver_internal_execute(
  filename : MoonbitTestDriverInternalExternString,
  index : Int,
) -> Unit {
  let filename = moonbit_test_driver_internal_get_file_name(filename)
  let async_tests = []
  moonbit_test_driver_internal_do_execute(async_tests, filename, index)
  MoonBit_Async_Test_Driver_Impl::run_async_tests(async_tests)
}

///|
/// Finishes pending WebAssembly async tests and coverage collection.
#cfg(target="wasm")
pub fn moonbit_test_driver_finish() -> Unit {
  MoonBit_Async_Test_Driver_Impl::run_async_tests(
    moonbit_test_driver_internal_wasm_async_tests,
  )
  
}

///|
/// Finishes coverage collection for backends without pending async work.
#cfg(any(target="js", target="wasm-gc"))
pub fn moonbit_test_driver_finish() -> Unit {
  
}

///|
fn moonbit_test_driver_internal_do_execute(
  async_tests : Array[async () -> Unit],
  filename : String,
  index : Int,
) -> Unit {
  // These two are internalized to avoid unused warnings

  fn handle_start() {
    let file_name = filename.escape()
    @moonbitlang/core/prelude.println("----- BEGIN MOON TEST RESULT -----")
    @moonbitlang/core/prelude.println(
      "{\"type\":\"start\",\"file\":\{file_name},\"index\":\{index}}",
    )
    @moonbitlang/core/prelude.println("----- END MOON TEST RESULT -----")
  }

  fn handle_result(_testname : String, message : String, skipped : Bool) {
    // In WASM, this function is called by the external test driver, but here
    // in native mode there's nothing that calls it, so we call it manually.
    if !skipped && MOONBIT_TEST_DRIVER_INTERNAL_IS_NATIVE {
      
    }
    let file_name = filename.escape()
    let message = message.escape()
    @moonbitlang/core/prelude.println("----- BEGIN MOON TEST RESULT -----")
    @moonbitlang/core/prelude.println(
      "{\"type\":\"result\",\"file\":\{file_name},\"index\":\{index},\"message\":\{message}}",
    )
    @moonbitlang/core/prelude.println("----- END MOON TEST RESULT -----")
  }

  fn error_to_string(err : Error) -> String {
    match err {
      @moonbitlang/core/prelude.Failure::Failure(e)
      | @moonbitlang/core/prelude.InspectError::InspectError(e)
      | @moonbitlang/core/prelude.SnapshotError::SnapshotError(e)
      | MoonBitTestDriverInternalJsError(e) => e
      e => moonbit_test_driver_internal_error_to_string(e)
    }
  }

  try {
    if !(MoonBit_Test_Driver_Internal_No_Args::run_test(
        async_tests, filename, index, handle_start, handle_result, error_to_string,
      ) ||
      MoonBit_Test_Driver_Internal_With_Args::run_test(
        async_tests, filename, index, handle_start, handle_result, error_to_string,
      ) ||
      MoonBit_Test_Driver_Internal_Async_No_Args::run_test(
        async_tests, filename, index, handle_start, handle_result, error_to_string,
      ) ||
      MoonBit_Test_Driver_Internal_Async_With_Args::run_test(
        async_tests, filename, index, handle_start, handle_result, error_to_string,
      ) ||
      MoonBit_Test_Driver_Internal_With_Bench_Args::run_test(
        async_tests, filename, index, handle_start, handle_result, error_to_string,
      )) {
      raise MoonBitTestDriverInternalSkipTest(name="")
    }
  } catch {
    err => {
      guard err is MoonBitTestDriverInternalSkipTest(name~)
      handle_result(name, "skipped test", true)
    }
  }
}
