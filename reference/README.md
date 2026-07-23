# reference/ — Rust `bimap` crate 参考源码(只读对照)

> **这是移植的原始参考实现**,供执行会话在语义不确定时查阅。**只读,不要修改。**
> **API/语义的最终仲裁顺序**:`docs/SPEC.md` → 本目录 `bimap_hash.rs` 的真实行为 → 你的判断。

## 来源
- **crate**:`bimap` v0.6.3 — https://github.com/billyrieger/bimap-rs
- **许可证**:`Apache-2.0/MIT`(见 `bimap_LICENSE_APACHE` / `bimap_LICENSE_MIT`)。
  本项目(moonbit-bimap)采用 Apache-2.0,与之兼容;README/申报书须保留来源与许可说明。

## 各文件作用

| 文件 | 作用 | 重点看什么 |
|---|---|---|
| **`bimap_hash.rs`** | **最重要**——`BiHashMap` 的方法实现(基于 HashMap 的双向映射) | `insert`(L558)、`insert_no_overwrite`(L595)、`remove_by_left`(L456)/`remove_by_right`(L493)、`get_by_left`(L355)/`get_by_right`(L379)、`contains_left`(L403)/`contains_right`(L427)、`len`/`iter`/`left_values`/`right_values`。**你的 C0–C4 / 插入语义必须与这些方法逐条一致。** |
| **`bimap_lib.rs`** | crate 顶层:**`Overwritten` 枚举定义在此**(L228)+ 公共 re-export | **`pub enum Overwritten<L, R>` 的 5 个变体定义**(Neither/Left/Right/Both/Pair)与文档注释——你的 MoonBit `enum Overwritten[L, R]` 照此定义 |
| `bimap_btree.rs` | `BiBTreeMap`(基于 BTreeMap 的有序变体) | **本次不移植**(v0.2.0 范围),但可参考其有序语义;你的"保序"用的是插入序,不是键序,与之不同 |
| `bimap_mem.rs` | 内部内存布局小工具 | 一般不需要 |
| `bimap_README.md` | crate 说明 | 用法示例,可改写进你的 README |
| `bimap_Cargo.toml` | 版本/许可证元数据 | 确认版本与许可 |

## `bimap_hash.rs` 里的黄金基准(`insert` 的实测行为)

`SPEC.md §0` 已摘录。核心再强调一次——`insert` 返回 5 种 `Overwritten`:

```
insert('a',1) => Neither                 len 0->1   (C0)
insert('b',2) => Neither                 len 1->2   (C0)
insert('a',4) => Left('a',1)             len 2      (C2: a 改绑)
insert('c',2) => Right('b',2)            len 2      (C3: 2 改由 c 绑)
insert('a',2) => Both(('a',4),('c',2))   len 2->1   (C4: 两对塌缩!)
insert('a',2) => Pair('a',2)             len 1      (C1: 精确重插)
```

实现 `insert` 的关键(≈L558):先 `remove_by_left(&left)` 再 `remove_by_right(&right)`,
按两个 `Option` 的组合决定返回哪个变体;若左删出的对的右值 == 新右值,则是 `Pair`(C1)。
**你在 MoonBit 里用 `put_pair` 收口实现,语义照此,但结构是"两张 Robin Hood 表 + 一份 order"。**

## 注意:bimap-rs 没有的,你要自己设计(增量)

bimap-rs 的 `BiHashMap` **不保序、不可索引**(基于无序 HashMap)。你的 moonbit-bimap 额外提供:
- `order: Array[L]` + `positions: Map[L, Int]` → 保序 + `get_index`/`get_index_of_*`/`first`/`last`。
- `Eq`/`Hash` **顺序无关**(bimap-rs 的 `PartialEq` 也是按对集合比较,与之**一致**——放心照此实现)。
- `to_inverse()` 拷贝(bimap-rs 没有直接的 inverse 方法;Guava 有活视图,你选择拷贝)。

这些增量的设计见 `docs/SPEC.md §6-§7` 与 `docs/DEVPLAN.md`。
