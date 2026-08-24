# SPEC.md — moonbit-bimap API 规格(唯一真源)

> **这是执行会话编码的唯一 API 真源。** 签名、返回类型、语义必须与此一致。
> 若本文与 Rust `bimap` crate 行为有出入且无法判断,**以 §0 摘录的 Rust 源码为准**,
> 并在 CHANGELOG 记一笔。

---

## §0 参考实现:Rust `bimap` crate 的真实行为(已核实,照此对齐)

来自 `bimap-rs` v0.6.3(Apache-2.0/MIT)。**`insert` 返回 `Overwritten` 枚举,共 5 个变体;
精确重插返回 `Pair`,不是 `Neither`。

```rust
pub enum Overwritten<L, R> {
    Neither,          // C0:全新插入,没挤掉任何对
    Left(L, R),       // C2:左键已绑别的右值,挤掉了旧 (l, r')
    Right(L, R),      // C3:右值已被别的左键绑,挤掉了旧 (l', r)
    Both((L,R),(L,R)),// C4:两侧都冲突,两对塌缩成一对(len 净减 1)
    Pair(L, R),       // C1:精确重插这一对,幂等(返回这对本身)
}

// 真实源码节选(核心逻辑):
pub fn insert(&mut self, left: L, right: R) -> Overwritten<L, R> {
    let retval = match (self.remove_by_left(&left), self.remove_by_right(&right)) {
        (None, None) => Overwritten::Neither,
        (None, Some(r_pair)) => Overwritten::Right(r_pair.0, r_pair.1),
        (Some(l_pair), None) => {
            // remove_by_left 先行,若精确重插,右值可能已被顺手删掉
            if l_pair.1 == right { Overwritten::Pair(l_pair.0, l_pair.1) }
            else { Overwritten::Left(l_pair.0, l_pair.1) }
        }
        (Some(l_pair), Some(r_pair)) => Overwritten::Both(l_pair, r_pair),
    };
    self.insert_unchecked(left, right);
    retval
}

pub fn insert_no_overwrite(&mut self, left: L, right: R) -> Result<(), (L, R)> {
    if self.contains_left(&left) || self.contains_right(&right) {
        Err((left, right))            // 注意:把尝试插入的对原样退回
    } else {
        self.insert_unchecked(left, right);
        Ok(())
    }
}
```

**Rust 实测样例(你的测试必须复现这些行为):**
```
insert('a',1) => Neither          len 0->1
insert('b',2) => Neither          len 1->2
insert('a',4) => Left('a',1)      len 2   (a 改绑 4)
insert('c',2) => Right('b',2)     len 2   (2 改由 c 绑)
insert('a',2) => Both(('a',4),('c',2))   len 2->1  ← C4 塌缩!
insert('a',2) => Pair('a',2)      len 1   (精确重插)
```

> **本库的两个增量(超出 Rust/Guava)**:① 保持**插入顺序**(`order`);
> ② 支持**按位置索引访问**(`get_index` 等)。这是差异化卖点,`DEVPLAN.md §1` 详述。

---

## §1 定位与概念辨析(过审关键:与 indexmap 的实质区别)

| 特性 | 普通 `Map` | **BiMap** | IndexMap |
|---|---|---|---|
| 键 → 值 | ✅ | ✅ | ✅ |
| **值 → 键(反查)** | ❌ | ✅ | ❌ |
| **按位置 `get_index(i)`** | ❌ | ✅(增量) | ✅ |
| 键唯一 | ✅ | ✅ | ✅ |
| **值也唯一(双射)** | ❌ | ✅ | ❌ |
| 保持插入顺序 | 看实现 | ✅(增量) | ✅ |
| `Eq`/`Hash` 语义 | 顺序无关 | **顺序无关** | **顺序敏感** |

**BiMap = 双向 + 保序 + 可索引 + 双射。** 与 indexmap 是**正交问题**:
- BiMap 的 "Bi" = **bidirectional**(键值一一对应、可反查)。
- IndexMap 的 "Index" = **position**(按第几个访问)。
- 共享的只是底层哈希表(工程组件),如同两个库都用数组。**不是 indexmap 的拆分/改名。**

---

## §2 `Overwritten` 枚举(公开类型)

```moonbit
///|
/// `insert` 的返回值:描述本次插入挤掉了哪些旧对。
/// 对齐 Rust `bimap::Overwritten`。
pub enum Overwritten[L, R] {
  Neither              // C0:全新插入
  Left(L, R)           // C2:左键改绑,挤掉旧 (l, old_r)
  Right(L, R)          // C3:右值改由本左键绑,挤掉旧 (old_l, r)
  Both((L, R), (L, R)) // C4:两侧冲突,两对塌缩成一对
  Pair(L, R)           // C1:精确重插这一对(幂等)
} derive(Debug, Eq)
```

> `Eq`/`Debug` 用 derive 即可(L、R 自带约束时)。`Both` 第一个元组是被挤掉的左对,
> 第二个是被挤掉的右对(与 Rust 顺序一致)。

---

## §3 三套插入语义 → **收敛为两个公开方法**(已按评审决策)

> **决策(已定)**:砍掉自造的"严格 fail! 版"。Rust 也没有 fail! 严格版。
> 严格语义 = `insert()` 后检查 `Overwritten::Neither`。公开方法只有两个。

### §3.1 `insert` — 主力(= Rust `insert` = 顶替语义)

```moonbit
///|
/// 插入 (l, r)。任一侧冲突就顶替旧对,返回被挤掉信息的 `Overwritten`。
/// **C4 会使 len 净减 1**(两对塌缩成一对)。
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::insert(
  self : BiMap[L, R], l : L, r : R,
) -> Overwritten[L, R]
```

行为(对应 §0 的 C0–C4):

| 情形 | 条件 | `insert` 返回 | len 变化 |
|---|---|---|---|
| **C0** | l、r 都不存在 | `Neither` | +1 |
| **C1** | (l, r) 精确已存在 | `Pair(l, r)` | 0 |
| **C2** | l→r' 存在(r'≠r),r 不在 | `Left(l, r')` | 0 |
| **C3** | l'→r 存在(l'≠l),l 不在 | `Right(l', r)` | 0 |
| **C4** | l→r' 且 l'→r 同时存在 | `Both((l, r'), (l', r))` | **−1** |

### §3.2 `insert_no_overwrite` — 非覆盖(对齐 Rust 签名)

```moonbit
///|
/// 任一侧已存在则不改动映射,返回 `Err((l, r))`(把尝试的对原样退回);
/// 否则插入并返回 `Ok(())`。
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::insert_no_overwrite(
  self : BiMap[L, R], l : L, r : R,
) -> Result[Unit, (L, R)]
```

> **注意签名对齐 Rust**:错误值是 `Err((L, R))`(尝试插入的对),**不是**自造的
> `Conflict` 枚举。`Both`(C4)在这里不特殊——只要左或右任一存在就 `Err`。

### §3.3 (已删除)`insert` 严格 fail! 版

不提供。需要"严格"的调用方:`match m.insert(l, r) { Neither => ...; other => 处理冲突 }`,
或用 `insert_no_overwrite`。

---

## §4 核心不变量(属性测试的靶子)

任何变更后,**全部**成立:

```
∀ (l, r) ∈ forward  ⟺  backward[r] == l          // 两侧严格互逆
forward.len == backward.len == order.length()
            == positions.size() == self.len       // 五处计数一致
positions[order[i]] == i                           // 位置映射自洽
self.mask == forward.buckets.length() - 1
forward.buckets.length() 是 2 的幂
order 中无重复左键(双射 ⟹ 左键唯一)
```

**架构纪律**:用三个收口点收口——
- `put_pair(l, r) -> (R?, L?)`:插入路径**唯一**同时改 forward+backward+order+positions 的地方;
  返回被挤掉的 `(old_right?, old_left?)`,供 `insert` 映射成 `Overwritten`。
- `remove_by_left(l) -> R?` / `remove_by_right(r) -> L?`:单对删除路径——双侧清理 +
  维护 order/positions + bump version。
- `retain(f)`:**批量删除路径**(第三个收口点):快照 + 逐对三结构删除 + `order` 原地压实
  (O(n),避开逐元素头删的 O(n²));全保留时 no-op 且不 bump version。

所有公开增删方法**只走这三个收口点**,绝不自己同步两表。

### `put_pair` 的参考实现骨架(C0–C4 的正确算法)

```moonbit
// 返回 (被挤掉的旧右值?, 被挤掉的旧左键?)
fn put_pair(self, l, r) -> (R?, L?) {
  let old_r = self.forward.get(l)      // l 当前绑的右值(若有)
  let old_l = self.backward.get(r)     // r 当前绑的左键(若有)
  match (old_r, old_l) {
    (None, None) =>            // C0
      self.add_fresh(l, r)
      (None, None)
    (Some(r0), None) =>        // C2:l 改绑;r0 失去左键
      self.unbind_right(r0)    // 从 backward 删 r0、从 order/positions 删 l(或复用槽)
      self.bind(l, r)
      (Some(r0), None)
    (None, Some(l0)) =>        // C3:r 改由 l 绑;l0 失去右值
      self.unbind_left(l0)     // 从 forward 删 l0、从 order/positions 删 l0
      self.bind(l, r)
      (None, Some(l0))
    (Some(r0), Some(l0)) =>    // C4:两对塌缩成一对,len 净减 1
      // 小心:l0 可能 == l?不会(否则 old_r 不会是 Some(r0) 且 r0≠r 的普通 C2)
      // 实际 C4 中 l ≠ l0 且 r ≠ r0。需删掉 (l, r0) 和 (l0, r) 两对,再建 (l, r)。
      self.remove_two_then_bind(l, r0, l0, r)
      (Some(r0), Some(l0))
  }
}
```

> **C1(精确重插)** 在 `put_pair` 里表现为 `old_r == Some(r)` 且 `old_l == Some(l)`
> 且 `old_r==r && old_l==l` —— 此时 `insert` 应返回 `Pair(l, r)` 且不改动。
> **实现要点**:`insert` 在调 `put_pair` 前,先判断 `forward.get(l) == Some(r)`
> (即精确已存在)→ 直接 `return Pair(l, r)`,不进 `put_pair`。这样 `put_pair` 只需处理
> C0/C2/C3/C4,C1 短路。这与 Rust 用 `remove_by_left` 先行再判 `l_pair.1 == right` 等价,
> 但更清晰。**务必为 C1 写专门测试。**

> **执行会话注意**:上面是**语义骨架**,具体 `add_fresh/bind/unbind_*/remove_two_then_bind`
> 由你实现,但**必须保证 §4 不变量**。用属性测试兜底。

---

## §5 双向查找 API

```moonbit
// 正向(左→右)
pub fn get_by_left(self, l : L) -> R?
pub fn contains_left(self, l : L) -> Bool
pub fn remove_by_left(self, l : L) -> R?     // 删除并返回右值;同步清 backward+order+positions

// 反向(右→左)
pub fn get_by_right(self, r : R) -> L?
pub fn contains_right(self, r : R) -> Bool
pub fn remove_by_right(self, r : R) -> L?    // 删除并返回左键;同步清 forward+order+positions

// 批量
pub fn retain(self, f : (L, R) -> Bool) -> Unit
    // 保留满足 f 的对;O(n);保留对的相对插入序不变;
    // 全保留时 no-op 且不 bump version(迭代器不失效)
```

> **`retain` 是移植项**(Rust bimap 两类映射均有,`retain_calls_f_once` 与"谓词恰好求值一次"
> 吻合),同时是第三个 mutation 收口点(§4)。谓词内不得改 map。

> **删除双侧清理是 BiMap 第二易错点**:删任一侧,另一侧 + order + positions 必须同步,
> 并 bump `version`。只走 `remove_by_left`/`remove_by_right`。
> **复杂度**:查找 O(1) 平均;删除另需 O(len) 最坏(`order` 移位保序)。按插入序从头批量
> 删除 n 对总计 O(n²)——批量清理请逆序删或重建(README Gotcha #9、Performance 段)。

---

## §6 索引 / 构造 / 转换 API

```moonbit
// 索引红利(来自 order/positions,这是相对 Rust/Guava 的增量)
pub fn get_index(self, i : Int) -> (L, R)?          // 按插入序第 i 对;越界 None
pub fn get_index_of_left(self, l : L) -> Int?        // 左键在插入序中的下标
pub fn get_index_of_right(self, r : R) -> Int?       // = get_index_of_left(get_by_right(r));见 §6.4
pub fn first(self) -> (L, R)?                         // 最早插入的对
pub fn last(self) -> (L, R)?                          // 最晚插入的对

// 构造
pub fn new() -> BiMap[L, R]
pub fn with_capacity(cap : Int) -> BiMap[L, R]
pub fn from_array(pairs : Array[(L, R)]) -> BiMap[L, R]   // 见 §6.3
pub fn default() -> BiMap[L, R]
pub fn copy(self) -> BiMap[L, R]                        // 深拷贝

// 查询
pub fn len(self) -> Int
pub fn is_empty(self) -> Bool
pub fn capacity(self) -> Int

// 转换
pub fn to_inverse(self) -> BiMap[R, L]                  // 拷贝,非实时视图(见 §6.2)

// 迭代(fail-fast,按左键插入序)
pub fn iter(self) -> Iter[(L, R)]
pub fn lefts(self) -> Iter[L]
pub fn rights(self) -> Iter[R]
pub fn into_array(self) -> Array[(L, R)]
```

### §6.2 `to_inverse` 是拷贝
返回的 `BiMap[R, L]` 是独立副本,改它不影响原表。MoonBit 所有权模型不适合共享活视图;
这与 Rust bimap 用方法、Guava 用活视图 `inverse()` 不同——**文档务必写明是拷贝**。

### §6.3 `from_array` 遇重复对:**走 `insert`(最后赢)**
对齐 Rust `FromIterator`(后者覆盖前者)。**在文档注明**。例如
`from_array([("a",1), ("a",2)])` 结果 = `{a ↔ 2}`。

### §6.4 为什么没有"对称"的 `get_index_of_right` 存储
`order` 只存**左键**插入序(右值的序无独立意义,因为双射一一对应)。
`get_index_of_right(r)` 作为**便捷方法**提供,内部 =
`match self.get_by_right(r) { Some(l) => self.get_index_of_left(l); None => None }`。
**文档说明这一点**,避免用户误以为 API 不对称是遗漏。

### §6.5 `iter()` 的遍历顺序
按**左键插入序**产出 `(L, R)`。这是"保序"卖点的落点,**写进 README**。

### §6.6 集合视图快照 + entry 助手(v0.2.0 M2,**原创扩展**)

> 真源核验(bimap-rs 0.6.3 源码):`contains_pair`、`left_keys`、
> `get_or_insert_left/right` **不存在**——原创扩展,无真源差分,语义由测试钉死。
> `right_values` 是唯一同名项:Rust 的 `right_values()` 返回惰性迭代器
> `RightValues`(哈希序、无排序承诺);本库同名方法返回**插入序 `Array[R]` 快照**
> (不做活视图,与 `to_inverse` 同一决策)——同名不同契约,CHANGELOG Notes 已记录。
> 左侧参照:Rust 还有 `left_values()`(同款哈希序惰性迭代器),语义对应本库
> `left_keys` 一侧——`left_keys` 按名字在上游确实不存在,但与 `left_values` 是
> 近亲(名称、返回类型、顺序语义均不同),对照真源时勿误判为左侧完全没有上游参照。
> 集合视图统一决策:**不做活视图**(MoonBit 无 Set trait、无所有权基础),做快照
> 访问器 + 成员判定。

```moonbit
// 成员判定(O(1),即 C1 判定;只查 forward,故 R 只需 Eq 不需 Hash)
pub fn[L : Hash + Eq, R : Eq] BiMap::contains_pair(self, l : L, r : R) -> Bool

// 快照(插入序,拷贝;改返回数组不影响 map)
pub fn[L, R] BiMap::left_keys(self) -> Array[L]              // 零约束
pub fn[L : Hash + Eq, R] BiMap::right_values(self) -> Array[R]

// entry 风格助手(原创;无状态一次性查询-插入,走既有 insert 收口点)
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::get_or_insert_left(self, l : L, r : R) -> R
pub fn[L : Hash + Eq, R : Hash + Eq] BiMap::get_or_insert_right(self, r : R, l : L) -> L
```

### §6.7 `left_keys` 与既有 `lefts()` 的定位差异(不是重复建设)
`lefts()` 是惰性 fail-fast 迭代器,要求 `L : Hash + Eq`;`left_keys()` 的增量价值是
**零约束 + 直出 `Array[L]` 快照**——在"持有 `BiMap[L, R]` 但两侧没有任何 trait 约束"
的泛型上下文里可用。这是它存在的理由,不是重复建设。

### §6.8 `get_or_insert_*` 语义(原创,测试钉死,无真源)
- `get_or_insert_left(l, r) -> R`:若 `l` 已存在,返回其当前右值,**不改动 map**(不
  bump version,迭代器不失效);若 `l` 不存在,走完整 `insert(l, r)` 并返回 `r`。
  **惊奇面**:插入路径上若 `r` 已绑别的左键 `l'`,`(l', r)` 被 C3 驱逐——完整 insert
  语义,非"仅当空闲才插入";调用返回后 `l ↔ r` 成立。
- `get_or_insert_right(r, l) -> L`:镜像。插入路径(r 不存在)上若 `l` 已绑别的右值
  `r'`,`(l, r')` 被 C2 改绑挤掉;调用返回后 `l ↔ r` 成立。

---

## §7 Trait 实现(关键:`Eq`/`Hash` 顺序无关)

```moonbit
pub impl[L : Debug + Hash + Eq, R : Debug] Debug for BiMap[L, R]      // Repr::opaque_("BiMap", ...)
pub impl[L : Hash + Eq, R] Default for BiMap[L, R]                     // 空表
pub impl[L : Show + Hash + Eq, R : Show] Show for BiMap[L, R]         // 可选,推荐
pub impl[L : Hash + Eq, R : Eq] Eq for BiMap[L, R]                    // **顺序无关**
pub impl[L : Hash + Eq, R : Hash] Hash for BiMap[L, R]                // **可交换组合**
pub impl[L : Show + Hash + Eq, R : ToJson] ToJson for BiMap[L, R]     // 键用 l.to_string()
pub impl[L : @quickcheck.Arbitrary + Hash + Eq, R : @quickcheck.Arbitrary + Hash + Eq]
  @quickcheck.Arbitrary for BiMap[L, R]                               // from_array(arbitrary pairs)
```

### §7.1 `Eq` 顺序无关(与 indexmap 的关键差异!)
双射本质是"**对的集合**",顺序是偶然的。两个 BiMap 相等 ⟺ 它们含相同的 (l, r) 对集合
(不论插入序)。实现:先比 `len`,再对 `self` 每对 `(l, r)` 检查 `other.get_by_left(l) == Some(r)`。

### §7.2 `Hash` 顺序无关正则形(sort-fold,2026-08 加固)
因为 Eq 顺序无关,Hash 必须与顺序无关——组合方式不能依赖插入序。**实现:把"排序后的
指纹序列"作为对集合的正则形,再做顺序敏感折叠**:

```moonbit
pub impl[L : Hash + Eq, R : Hash] Hash for BiMap[L, R] with fn hash_combine(self, hasher) {
  // 1. 每对指纹(对内有序): pair_fingerprint(l, r) = Hash::hash(l) * K + Hash::hash(r)
  // 2. 排序指纹:双射不含重复对 ⟹ 排序序列是这对集合的完美正则形
  // 3. FNV-1a 风格折叠(先混入 len): acc = lxor(acc, f) * PRIME
  ...
}
```

**为什么不用可交换的加法/异或累加**:加法是线性结构,其下 `{(a,b),(c,d)}` 与
`{(a,d),(c,b)}` 对**任意**键 hash 恒等碰撞(攻击者无需任何 hash 控制)。排序+顺序折叠
破坏线性,把碰撞归约为"指纹多重集相等"——需要攻击者具备键 hash 层面的控制能力
(见 README Gotcha #2)。代价 O(n log n)(排序;FNV 常数为 64 位系,跨后端 hash 值
可不一致)。**属性测试兜底:打乱插入序后 hash 不变。**

> **Gotchas 必须写明**:① BiMap 的 `Eq`/`Hash` 顺序**无关**,与 indexmap 相反;
> ② 加固后碰撞归约为指纹多重集相等;指纹级碰撞(h(l)+t、h(r)−K·t)仍需攻击者控制
> key 的 hash——见 README Gotcha #2。

### §7.3 `ToJson` 键不要 mangle
键用 `l.to_string()`(`L : Show`),**不要**用 `@debug.to_string(l.to_json())`
(会把键变成 `String("name")`,这是 indexmap v0.3.3 修过的老坑)。
JSON 表示:对象 `{ "<l.to_string()>": <r.to_json()>, ... }`,按左键插入序输出。

---

## §8 内部数据结构(执行参考,详见 `DEVPLAN.md §3`)

```moonbit
// 私有纯引擎(无顺序)——从 indexmap 移植
struct Entry[K, V] { key : K; value : V; hash : Int; mut distance : Int } derive(Debug)
struct HashTab[K, V] {
  mut buckets : Array[Entry[K, V]?]
  mut len : Int
  mut mask : Int
  mut tombstone_count : Int
  mut max_probe_distance : Int
}

// 公开主体
struct BiMap[L, R] {
  mut forward  : HashTab[L, R]   // 左→右,承载顺序
  mut backward : HashTab[R, L]   // 右→左,仅反查,无自己的 order
  mut order    : Array[L]        // 左键插入序(唯一一份)
  mut positions : Map[L, Int]    // 左键 → order 下标
  mut len : Int
  mut version : Int              // fail-fast
}
```

常量:`MIN_CAPACITY=16`、负载因子 `3/4`、`TOMBSTONE_HASH=-1`、`NO_DISTANCE=-1`。
类型约束:**按方法最小化**(struct 本身无约束)。写路径方法(`insert`、`insert_no_overwrite`、
`remove_by_left/right`、`from_array`、`copy`、`to_inverse`、`get_index_of_right`、
`get_or_insert_left/right`)需双侧 `Hash + Eq`;单侧只读方法只约束被查询的一侧——
`new`、`with_capacity`、`get_by_left`、`contains_left`、`get_index`、
`get_index_of_left`、`first`、`last`、`iter`、`lefts`、`rights`、`into_array`、
`right_values` 为 `[L : Hash + Eq, R]`,`get_by_right`、`contains_right` 为
`[L, R : Hash + Eq]`,`contains_pair` 为 `[L : Hash + Eq, R : Eq]`,`left_keys` 为
**零约束** `[L, R]`(零约束的**键数据快照**读取方法;`len`/`is_empty`/`capacity`
虽同为 `[L, R]` 零约束,但不读取键值内容,不构成冲突)。trait impl 同理收紧:`Eq` 需 `R : Eq`(比值)、
`Hash` 需 `R : Hash`、`Default` 仅需 `L : Hash + Eq`(见 §7)。

---

## §9 完整 API 速查表

| 类别 | 方法 |
|---|---|
| 构造 | `new()`, `with_capacity(n)`, `from_array(pairs)`, `default()`, `copy()` |
| 查询 | `len()`, `is_empty()`, `capacity()` |
| 插入 | `insert(l, r) -> Overwritten`, `insert_no_overwrite(l, r) -> Result[Unit,(L,R)]` |
| 正向 | `get_by_left(l)`, `contains_left(l)`, `remove_by_left(l) -> R?` |
| 反向 | `get_by_right(r)`, `contains_right(r)`, `remove_by_right(r) -> L?` |
| 索引 | `get_index(i)`, `get_index_of_left(l)`, `get_index_of_right(r)`, `first()`, `last()` |
| 迭代 | `iter()`, `lefts()`, `rights()`, `into_array()` |
| 视图/entry | `contains_pair(l, r)`, `left_keys()`, `right_values()`, `get_or_insert_left(l, r) -> R`, `get_or_insert_right(r, l) -> L` |
| 转换 | `to_inverse() -> BiMap[R, L]` |
| Traits | `Debug`, `Default`, `Show`, `Hash`(顺序无关), `Eq`(顺序无关), `ToJson`, `Arbitrary` |

> 排序变体 `BiBTreeMap` 的完整 API 与差异表见 **§11**(插入序→左键升序,无索引,
> `first`/`last` 语义不同,`range(lo, hi)` 两端闭)。

---

## §10 不实现 / 明确排除(避免范围蔓延)

- ❌ Entry API(`OccupiedEntry`/`VacantEntry`)——indexmap 的历史 bug 聚集地,BiMap 不需要。
- ❌ `get_mut` 回调式修改——同上。
- ❌ `sort_by*`——BiMap 顺序由插入决定,不提供原地排序。
- ❌ 实时 `inverse()` 活视图——用 `to_inverse()` 拷贝替代。
- ❌ 严格 `fail!` 插入——用 `insert` + 检查 `Overwritten` 表达。
- ❌ 多线程/并发(如 DashMap)——单线程库,indexmap 同款定位。

> **裁决(v0.2.0 M2)**:`get_or_insert_left/right` **不属于**上列"Entry API"排除范围。
> 这里排除的是 entry 视图对象(`OccupiedEntry`/`VacantEntry`)、`get_mut` 与 update
> 类回调修改(indexmap 的历史 bug 聚集地:entry 缓存的索引在结构变更后失效)。
> `get_or_insert_*` 是无状态的一次性"查询-插入"组合,内部走既有 `insert` 收口点,
> 不引入任何 entry 对象或 update 回调,不产生该失效风险面。见 §6.6–§6.8。

---

## §11 BiBTreeMap — 排序双射(v0.2.0 M3)

> 定位:`BiMap` 的排序变体。数据层用两个 core `SortedMap` 互逆表(与 BiMap 的双
> HashTab 同构),**排序取代插入序**:迭代与快照按左键升序,**无插入序、无索引访问**。
> 插入 C0–C4 / `Overwritten` / 删除 / Eq / Hash / fail-fast 与 BiMap 逐项对齐,
> 差异只在与"顺序"有关之处——全部列在 §11.4 差异表。约束写 `Compare`
> (`builtin/traits.mbt` 实测 `Compare: Eq` 超类,C1 判定的 `==` 免费可用)。

### §11.1 数据布局与不变量

```
BiBTreeMap[L, R]
├── forward  : SortedMap[L, R]   // 按 L 有序
├── backward : SortedMap[R, L]   // 按 R 有序(反查)
├── len      : Int   (mut)
└── version  : Int   (mut)       // fail-fast 迭代
```

不变量:`∀ (l, r) ∈ forward ⟺ backward[r] == l`;`forward.length() == backward.length() == len`。
**纪律照搬 BiMap**:三个 mutation 收口点——`put_pair`(插入)、`remove_by_left/right`
(单对删除)、`retain`(批量删除)。core `SortedMap::set` 返回 Unit(不还旧值),插入
语义必须"**get 预判 + set**"(两侧旧值先读,再做 set/remove)——这是实现上的唯一正路。
`copy`/`to_inverse` 构造新表、不改源表:`to_inverse` 直接交换两侧 SortedMap 的
拷贝(新 forward = 旧 backward 拷贝,已按新左键有序),零重插、零约束。

### §11.2 API(约束按方法最小化)

```moonbit
// 构造/转换
pub fn[L : Compare, R : Compare] BiBTreeMap::new() -> BiBTreeMap[L, R]
pub fn[L : Compare, R : Compare] BiBTreeMap::from_array(pairs : Array[(L, R)])  // 后赢
pub fn[L, R] BiBTreeMap::copy(self) -> BiBTreeMap[L, R]          // 零约束
pub fn[L, R] BiBTreeMap::to_inverse(self) -> BiBTreeMap[R, L]    // 零约束

// 插入(复用 lib.mbt 的 Overwritten 枚举)
pub fn[L : Compare, R : Compare] BiBTreeMap::insert(self, l, r) -> Overwritten[L, R]
pub fn[L : Compare, R : Compare] BiBTreeMap::insert_no_overwrite(...) -> Result[Unit, (L, R)]

// 查找/删除
pub fn[L : Compare, R] BiBTreeMap::get_by_left(self, l) -> R?
pub fn[L, R : Compare] BiBTreeMap::get_by_right(self, r) -> L?
pub fn[L : Compare, R] BiBTreeMap::contains_left(self, l) -> Bool
pub fn[L, R : Compare] BiBTreeMap::contains_right(self, r) -> Bool
pub fn[L : Compare, R : Compare] BiBTreeMap::remove_by_left(self, l) -> R?
pub fn[L : Compare, R : Compare] BiBTreeMap::remove_by_right(self, r) -> L?

// 查询 / 排序红利
pub fn[L, R] BiBTreeMap::len(self) -> Int
pub fn[L, R] BiBTreeMap::is_empty(self) -> Bool
pub fn[L, R] BiBTreeMap::first(self) -> (L, R)?   // 最小左键(O(log n) 走向最左)
pub fn[L, R] BiBTreeMap::last(self) -> (L, R)?    // 最大左键(O(n) 走到迭代器尾)
pub fn[L : Compare, R] BiBTreeMap::range(self, lo, hi) -> Iter[(L, R)]  // [lo, hi] 两端闭

// v0.2.0 并行 API
pub fn[L : Compare, R : Compare] BiBTreeMap::retain(self, f) -> Unit   // 真源 btree.rs:378 同款
pub fn[L : Compare, R : Compare] BiBTreeMap::contains_pair(self, l, r) -> Bool
pub fn[L, R] BiBTreeMap::left_keys(self) -> Array[L]          // 升序,零约束
pub fn[L, R] BiBTreeMap::right_values(self) -> Array[R]       // 按左键升序,零约束
pub fn[L : Compare, R : Compare] BiBTreeMap::get_or_insert_left(self, l, r) -> R
pub fn[L : Compare, R : Compare] BiBTreeMap::get_or_insert_right(self, r, l) -> L

// 迭代
pub fn[L, R] BiBTreeMap::iter(self) -> Iter[(L, R)]            // 按 L 升序,fail-fast
pub fn[L, R] BiBTreeMap::into_array(self) -> Array[(L, R)]     // 按 L 升序

// traits(约束逐个最小化,0053 门禁过)
Eq [L : Compare, R : Eq]    Hash [L : Hash, R : Hash]
Debug [L : Debug, R : Debug]  Show [L : Show, R : Show]
ToJson [L : Show, R : ToJson]  Default [L : Compare, R : Compare]
Arbitrary [L : @quickcheck.Arbitrary + Compare, R : @quickcheck.Arbitrary + Compare]
```

**零约束快照红利**:`into_array/iter/first/last/copy/to_inverse/left_keys/right_values/len/is_empty`
全部零约束(不像 BiMap 的对应物需要 `L : Hash + Eq`),所以 Hash/Debug/Show/ToJson 的
impl 也无需 Compare——比 BiMap 更宽松,已由 mbti 与 0053 门禁逐条验证。

### §11.3 排序红利与显式决策

- `first()`/`last()` = **最小/最大左键**(与 BiMap 的最早/最晚插入不同,§11.4 差异表)。
  `last` 为 O(n)(无 O(1) 最大值游标;走到迭代器尾)。
- **`range(lo, hi)` 两端闭区间 `[lo, hi]`**——边界语义以 core `SortedMap::range`
  实测为准(源码: `low <= key <= high` 才产出),测试钉死。注意与 Rust
  `left_range(a..b)`(右开)的习惯不同:本库等价于 `a..=b`;lo > hi 得空迭代器。
- **defer:反向区间(右 range)不做**。Rust `right_range`(btree.rs:558)显式留 v0.2.x:
  反向查找已有 `get_by_right` 覆盖主需求;无真源差分以外的紧迫场景。此 defer 是
  已批准的显式决策,不是遗漏。
- **`clear()` 不提供**(真源 btree.rs:101 有):计划范围外,retain-none 可达空表;
  需要时 v0.2.x 按反馈增补。

### §11.4 BiMap vs BiBTreeMap 差异表(防迁移误用)

| 方面 | BiMap | BiBTreeMap |
|---|---|---|
| 顺序 | 插入序(左键) | **左键升序** |
| 引擎 | 双 Robin Hood HashTab | 双 core SortedMap |
| 索引访问 | `get_index` / `get_index_of_*` | ❌ 不提供(排序取代插入序) |
| `first()`/`last()` | 最早 / 最晚插入 | **最小 / 最大左键** |
| 容量 | `capacity()` / `with_capacity` | 无容量概念 |
| `left_keys()` | 插入序 | 升序 |
| `right_values()` | 插入序(左键序) | 按左键升序(与 Rust 同名方法相反,见 §11.5) |
| range | ❌ | `range(lo, hi)` 两端闭 |
| 键约束 | `Hash + Eq` | `Compare`(可用无 Hash 类型) |
| 快照/迭代约束 | 多需 `L : Hash + Eq` | **零约束** |
| 删除复杂度 | O(len) 保序移位 | O(log n),无位移 |

### §11.5 真源对照(bimap-rs 0.6.3 btree.rs,已逐项核对)

- `insert`(btree.rs:442)与 `insert_no_overwrite`(479):与 BiHashMap 同款语义,
  返回同一个 `Overwritten` 枚举(已复用 §2)。
- `retain`(378):`BTreeMap::retain` 按左键升序逐对求值谓词、恰好一次——本库实现
  吻合(快照 + 逐对双表删除,全保留 no-op 不 bump version)。
- 迭代升序(125);`remove_by_left/right` 返回整对(303/341),本库拆成单侧返回值,
  与 BiMap 同一"信息等价"决策。
- `left_range`(521):RangeBounds 参数(`a..b` 右开);本库 `range` 固定两端闭(§11.3)。
- `right_values()`(175):按**右值**升序(遍历 right2left);本库同名方法返回**按左键
  升序**的急求值快照——**同名不同序**(且迭代器 vs 快照),测试钉死。
- `left_values()`(150):按左键升序迭代器,是本库 `left_keys()` 的近亲参照(名称、
  返回类型不同)。

### §11.6 差分覆盖(比 BiMap 更强)

`tools/diffgen` 第二份夹具:同一 5-op LCG 流(6000 步,retain 谓词 `(l + r) % 3 != 0`
与 model_test 逐字一致)+ 黄金 C0–C4 序列 + **排序终态全量比对**(最终对列按迭代序与
Rust 端逐元素相等——BiMap 侧只做成员判定,这里是序+内容双重)。MoonBit 侧:
`src/bbtreemap_diff_test.mbt`。range/left_keys/right_values/first/last/get_or_insert_*
是本库自身表面(边界语义由 `bbtreemap_test.mbt` 钉死),不进差分。

### §11.7 Eq / Hash / fail-fast

- Eq:集合相等(与 BiMap 同语义;排序表下与排序序列相等重合)。Hash:复用
  `pair_fingerprint` + sort-fold 组合器(同算法同常数;与 BiMap 相同对集哈希同值
  不作跨类型承诺)。Gotcha #2 的加固说明照搬。
- fail-fast:迭代器快照 `version`,中途 mutation 即 abort——与 BiMap 同构;
  **进程内不可测**,文档化(README Known Issues 同款)。
- trait 约束最小化清单见 §11.2 尾部;Default/Arbitrary 需双侧 Compare(构造空双表)。
