//! Differential-test fixture generator for moonbit-bimap.
//!
//! Runs the reference implementation — the Rust `bimap` crate v0.6.3, the
//! porting source documented in `docs/SPEC.md` §0 — over the operation
//! streams shared with the MoonBit tests:
//!
//!   1. the hand-crafted golden C0–C4 sequence (shared with `bimap_test.mbt`
//!      and `model_test.mbt`), and
//!   2. the 6000-step deterministic LCG stream (same seed, moduli, and op
//!      mapping as `model_test.mbt`, including retain with the shared
//!      deterministic predicate).
//!
//! It emits TWO fixtures, one per map type:
//!   - `src/differential_fixture_test.mbt` (BiHashMap): per-step
//!     `Overwritten` / `Option` / `Result` observations + len, then the
//!     final pair SET (sorted by left key).
//!   - `src/bbtreemap_diff_fixture_test.mbt` (BiBTreeMap): the same streams
//!     plus the final pair list IN ITERATION ORDER (ascending by left key) —
//!     the sorted-terminal-state check, stronger than the BiMap side's
//!     membership-only comparison.
//!
//! The MoonBit side replays the same streams through the real `BiMap` /
//! `BiBTreeMap` and must reproduce every observation exactly.
//!
//! Usage:
//!   cargo run --release -- ../../src/differential_fixture_test.mbt ../../src/bbtreemap_diff_fixture_test.mbt

use bimap::{BiBTreeMap, BiMap, Overwritten};
use std::env;
use std::fmt::Write as _;
use std::fs;

const STEPS: u64 = 6000;

/// Same LCG as `src/model_test.mbt`: seed 0x1234_5678, mask to 31 bits.
fn next_state(state: u64) -> u64 {
    (state.wrapping_mul(1_103_515_245).wrapping_add(12_345)) & 0x7FFF_FFFF
}

/// Encode an `insert` result into the fixture's string format.
fn classify(o: Overwritten<i32, i32>) -> String {
    match o {
        Overwritten::Neither => "Neither".to_string(),
        Overwritten::Left(l, r) => format!("Left({},{})", l, r),
        Overwritten::Right(l, r) => format!("Right({},{})", l, r),
        Overwritten::Both((l1, r1), (l2, r2)) => {
            format!("Both(({},{}),({},{}))", l1, r1, l2, r2)
        }
        Overwritten::Pair(l, r) => format!("Pair({},{})", l, r),
    }
}

/// One LCG step: state advance plus op/key derivation (shared VERBATIM with
/// src/model_test.mbt and the MoonBit replay files).
fn lcg_step(state: &mut u64) -> (u64, i32, i32) {
    *state = next_state(*state);
    let op = *state % 5;
    let l = ((*state >> 6) % 15) as i32;
    let r = ((*state >> 14) % 15) as i32;
    (op, l, r)
}

/// Encode one stream step against a BiHashMap into the fixture string format.
fn step_bihashmap(map: &mut BiMap<i32, i32>, op: u64, l: i32, r: i32) -> String {
    let obs = match op {
        0 => classify(map.insert(l, r)),
        // Rust bimap's remove_by_left/right returns the whole removed
        // (L, R) pair; the observable counterpart of MoonBit's
        // `remove_by_left(l) -> R?` is the pair's RIGHT value.
        1 => match map.remove_by_left(&l) {
            Some((l0, r0)) => {
                assert_eq!(l0, l, "remove_by_left returned a mismatched left key");
                format!("Some({})", r0)
            }
            None => "None".to_string(),
        },
        // ...and of `remove_by_right(r) -> L?` the pair's LEFT key.
        2 => match map.remove_by_right(&r) {
            Some((l0, r0)) => {
                assert_eq!(r0, r, "remove_by_right returned a mismatched right value");
                format!("Some({})", l0)
            }
            None => "None".to_string(),
        },
        3 => match map.insert_no_overwrite(l, r) {
            Ok(()) => "Ok".to_string(),
            Err(_) => "Err".to_string(),
        },
        // retain returns (); the observable is the post-retain length
        // (appended by the common "|len" suffix below).
        _ => {
            map.retain(|l, r| (l + r) % 3 != 0);
            "Retain".to_string()
        }
    };
    format!("{}|{}", obs, map.len())
}

/// Encode one stream step against a BiBTreeMap (same op mapping and the same
/// deterministic retain predicate, shared verbatim).
fn step_bibtree(map: &mut BiBTreeMap<i32, i32>, op: u64, l: i32, r: i32) -> String {
    let obs = match op {
        0 => classify(map.insert(l, r)),
        1 => match map.remove_by_left(&l) {
            Some((l0, r0)) => {
                assert_eq!(l0, l, "remove_by_left returned a mismatched left key");
                format!("Some({})", r0)
            }
            None => "None".to_string(),
        },
        2 => match map.remove_by_right(&r) {
            Some((l0, r0)) => {
                assert_eq!(r0, r, "remove_by_right returned a mismatched right value");
                format!("Some({})", l0)
            }
            None => "None".to_string(),
        },
        3 => match map.insert_no_overwrite(l, r) {
            Ok(()) => "Ok".to_string(),
            Err(_) => "Err".to_string(),
        },
        _ => {
            map.retain(|l, r| (l + r) % 3 != 0);
            "Retain".to_string()
        }
    };
    format!("{}|{}", obs, map.len())
}

fn main() {
    let mut args = env::args();
    let _prog = args.next();
    let bimap_out_path = args
        .next()
        .expect("usage: diffgen <differential_fixture_test.mbt> <bbtreemap_diff_fixture_test.mbt>");
    let bbtree_out_path = args
        .next()
        .expect("usage: diffgen <differential_fixture_test.mbt> <bbtreemap_diff_fixture_test.mbt>");

    // ---------------------------------------------------------------------
    // 1. BiHashMap fixture (unchanged format; must stay byte-identical when
    //    regenerated).
    // ---------------------------------------------------------------------
    let mut out = String::new();
    writeln!(
        out,
        "// GENERATED by `tools/diffgen` (reference: Rust `bimap` crate v0.6.3, the porting source)."
    )
    .unwrap();
    writeln!(
        out,
        "// Regenerate: cd tools/diffgen && cargo run --release -- ../../src/differential_fixture_test.mbt ../../src/bbtreemap_diff_fixture_test.mbt"
    )
    .unwrap();
    writeln!(
        out,
        "// then run `moon fmt`. Do not edit by hand; see tools/diffgen/README.md."
    )
    .unwrap();
    writeln!(out).unwrap();

    let golden: [(i32, i32); 6] = [(1, 10), (2, 20), (1, 40), (3, 20), (1, 20), (1, 20)];
    let mut map: BiMap<i32, i32> = BiMap::new();
    writeln!(out, "let diff_golden_observations : Array[String] = [").unwrap();
    for (l, r) in golden {
        let o = map.insert(l, r);
        writeln!(out, "  \"{}|{}\",", classify(o), map.len()).unwrap();
    }
    writeln!(out, "]").unwrap();
    writeln!(out).unwrap();

    let mut map: BiMap<i32, i32> = BiMap::new();
    let mut state: u64 = 0x1234_5678;
    writeln!(out, "let diff_observations : Array[String] = [").unwrap();
    for _ in 0..STEPS {
        let (op, l, r) = lcg_step(&mut state);
        writeln!(out, "  \"{}\",", step_bihashmap(&mut map, op, l, r)).unwrap();
    }
    writeln!(out, "]").unwrap();
    writeln!(out).unwrap();

    // Final pair set, sorted by left key (left keys are unique in a bijection).
    let mut pairs: Vec<(i32, i32)> = map.iter().map(|(l, r)| (*l, *r)).collect();
    pairs.sort();
    writeln!(out, "let diff_final_pairs : Array[(Int, Int)] = [").unwrap();
    for (l, r) in pairs {
        writeln!(out, "  ({}, {}),", l, r).unwrap();
    }
    writeln!(out, "]").unwrap();

    fs::write(&bimap_out_path, out).expect("failed to write bimap fixture");
    println!("wrote {}", bimap_out_path);

    // ---------------------------------------------------------------------
    // 2. BiBTreeMap fixture: same golden + LCG streams, plus the final pair
    //    list IN ITERATION ORDER (ascending by left key) — the
    //    sorted-terminal-state check.
    // ---------------------------------------------------------------------
    let mut out = String::new();
    writeln!(
        out,
        "// GENERATED by `tools/diffgen` (reference: Rust `bimap` crate v0.6.3 BiBTreeMap, the porting source)."
    )
    .unwrap();
    writeln!(
        out,
        "// Regenerate: cd tools/diffgen && cargo run --release -- ../../src/differential_fixture_test.mbt ../../src/bbtreemap_diff_fixture_test.mbt"
    )
    .unwrap();
    writeln!(
        out,
        "// then run `moon fmt`. Do not edit by hand; see tools/diffgen/README.md."
    )
    .unwrap();
    writeln!(out).unwrap();

    let mut map: BiBTreeMap<i32, i32> = BiBTreeMap::new();
    writeln!(out, "let bbtree_diff_golden_observations : Array[String] = [").unwrap();
    for (l, r) in golden {
        let o = map.insert(l, r);
        writeln!(out, "  \"{}|{}\",", classify(o), map.len()).unwrap();
    }
    writeln!(out, "]").unwrap();
    writeln!(out).unwrap();

    let mut map: BiBTreeMap<i32, i32> = BiBTreeMap::new();
    let mut state: u64 = 0x1234_5678;
    writeln!(out, "let bbtree_diff_observations : Array[String] = [").unwrap();
    for _ in 0..STEPS {
        let (op, l, r) = lcg_step(&mut state);
        writeln!(out, "  \"{}\",", step_bibtree(&mut map, op, l, r)).unwrap();
    }
    writeln!(out, "]").unwrap();
    writeln!(out).unwrap();

    // BiBTreeMap iterates ascending by left key, so this is already the
    // sorted terminal state (no sort needed — the ORDER is the assertion).
    let pairs: Vec<(i32, i32)> = map.iter().map(|(l, r)| (*l, *r)).collect();
    writeln!(out, "let bbtree_diff_final_pairs : Array[(Int, Int)] = [").unwrap();
    for (l, r) in pairs {
        writeln!(out, "  ({}, {}),", l, r).unwrap();
    }
    writeln!(out, "]").unwrap();

    fs::write(&bbtree_out_path, out).expect("failed to write bbtreemap fixture");
    println!("wrote {}", bbtree_out_path);
}
