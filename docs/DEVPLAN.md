# DEVPLAN.md — moonbit-bimap 架构设计稿(已按评审修订)

> **状态:** 立项设计稿(已定稿,执行以此为准)
> **定位:** MoonBit 版双向映射(BiMap),移植自 Rust [`bimap`](https://crates.io/crates/bimap) crate / Guava `BiMap` 概念
> **目标:** 2026 MoonBit 8 月黑客松
> **API 细节以 `SPEC.md` 为准;本文讲"为什么这么设计"。**

### 本版相对初稿的关键修订(评审决策)

| # | 修订 | 理由 |
|---|---|---|
| 1 | 主插入 API 从 `(R?, L?)` 元组 + 自造三语义,改为**对齐 Rust 的 `insert() -> Overwritten` 枚举 + `insert_no_overwrite() -> Result`** | 对标更一致、`Overwritten::Pair` 区分"精确重插"与"全新"、枚举自解释、降低迁移成本 |
| 2 | **砍掉 `fail!` 严格版插入** | Rust 也没有;严格语义 = `insert` 后检查 `Overwritten::Neither`;少一个 API = 少一组测试与维护面 |
| 3 | `insert_no_overwrite` 错误类型用 `Result[Unit, (L, R)]`(对齐 Rust),**不用自造 `Conflict` 枚举** | 与参考实现签名一致 |
| 4 | 明确 `Eq`/`Hash` **顺序无关**,并加与 indexmap 的对比表 | 双射=对的集合;且同作者两库 Eq 语义相反,必须讲清 |
| 5 | 补 `get_index_of_right`、`iter()` 顺序、`from_array` 重复对处理 三个 API 决策 | 完备性,避免被误读为遗漏 |
| 6 | CI 统一为**五步**(原稿"四步"笔误) | 与实际 ci.yml 一致 |

### 关键决策(已定,不可再议)

1. **独立成包,不依赖 `aurasuisui/indexmap`**——但内化其验证过的好设计(Robin Hood、order+positions、fail-fast、测试与文档范式)。
2. **两套插入语义**(对齐 Rust):`insert`(顶替,返回 `Overwritten`)+ `insert_no_overwrite`(非覆盖,返回 `Result`)。
3. **反向访问用方法 + `to_inverse()` 拷贝**,不用实时活视图。
4. **`Eq`/`Hash` 顺序无关**(与 indexmap 的顺序敏感相反)。

---

## 一、概念辨析:BiMap vs IndexMap(过审核心)

两个名字都带 map、都加了修饰词,但解决的是**正交**的问题:

- **BiMap** 的 "Bi" = **bidirectional(双向查找)**——键和值都唯一,可正向(键→值)也可反向(值→键)。
- **IndexMap** 的 "Index" = **position(位置/下标)**——保持插入顺序,且能按"第几个"访问。

| 特性 | 普通 Map | **BiMap** | IndexMap |
|---|---|---|---|
| 键 → 值 | ✅ | ✅ | ✅ |
| **值 → 键(反查)** | ❌ | ✅ | ❌ |
| **按位置 `get_index(i)`** | ❌ | ✅(增量) | ✅ |
| 键唯一 | ✅ | ✅ | ✅ |
| **值也唯一(双射)** | ❌ | ✅ | ❌ |
| 保持插入顺序 | 看实现 | ✅(增量) | ✅ |
| `Eq`/`Hash` 语义 | 顺序无关 | **顺序无关** | **顺序敏感** |

**本项目 = 双向 + 保序 + 可索引 + 双射。** 保序与可索引是 Rust bimap(内部两个无序 HashMap)和 Guava BiMap 都给不了的差异化卖点。

同一例子的行为差异——存 `{"alice": "admin", "bob": "admin"}`(两人都是 admin):
- **普通 Map**:能存;能查"alice 是什么角色",但"谁是 admin?"查不了。
- **BiMap**:存不进——值 `admin` 重复,违反一一对应(双射)。
- **IndexMap**:能存(值可重复);"谁是 admin"也不行,但能问"第一个用户是谁""alice 排第几"。

> **共享的只是底层哈希表**(工程组件),如同两个库都用数组。BiMap 的核心不变量
> (双射互逆)、插入语义(C0–C4)、Eq/Hash 语义都与 indexmap 不同——**这是实质性区别,不是拆分/改名。**

---

## 二、架构定调:为什么"不引用"反而更内聚

IndexMap 里,哈希桶、order 数组、positions 是糊在同一个 struct 里的。BiMap 因为需要**两张表但只有一份顺序**,天然必须把"纯哈希表"与"顺序逻辑"拆开:

- **`HashTab[K,V]`**(内部、私有)= 纯 Robin Hood 哈希表,只管 `insert/get/remove/contains/iter/rehash`,**不含顺序**。这是从 IndexMap 内化来的核心引擎。
- **`BiMap[L,R]`** = 两张 `HashTab` + **一份** order/positions + 互逆不变量 + 两套插入语义。顺序逻辑是 BiMap 这一层的职责。

| 原则 | 收益 |
|---|---|
| **高内聚** | `HashTab` 单一职责(就是张哈希表);`BiMap` 单一职责(双向一一对应)。比 IndexMap 把表与顺序耦合在一起更纯 |
| **低耦合** | 对 `aurasuisui/indexmap` **零依赖边**,完全规避"地基缺陷传染"与"发布周期绑定" |

### 代价(必须正视)

你现在自己拥有这张哈希表的维护权,拿不到 IndexMap 未来的修复。缓解:
1. 只内化**最小纯 `HashTab`**,不搬 IndexMap 的整套公开 API;
2. `HashTab` 保持私有/内部;
3. 把 IndexMap 0.3.3 的回归测试(扩容级联、墓碑、再散列)一并移植;
4. 因为不用 `get_mut`/Entry API(历史 bug 聚集地),只移植 resize/tombstone 正确性测试,内化引擎风险很低;
5. 同一作者、同为 Apache-2.0,README 注明"哈希表设计改编自本人 indexmap"。

### 关于"地基缺陷"的背景结论

IndexMap 独立测试报告发现的正确性 bug(Entry 扩容挂死、`get_mut` 损坏、`ToJson` 键 mangle、假 fail-fast)已在 0.3.3 全部修复并有回归测试;剩下的 `Eq`/`Hash` 顺序敏感、`swap_remove_index` 实为 O(n) 等是设计取舍,且都落在 BiMap 不会去用的 API 上。本方案选择独立成包,地基稳定性担忧被彻底绕开。

---

## 三、内部数据结构(详见 `SPEC.md §8`)

```moonbit
// 私有引擎:纯 Robin Hood 表,无顺序
struct HashTab[K, V] {
  mut buckets : Array[Entry[K, V]?]  // None=空, hash==TOMBSTONE_HASH=墓碑
  mut len : Int
  mut mask : Int                      // capacity - 1(capacity 恒为 2 的幂)
  mut max_probe_distance : Int
  mut tombstone_count : Int           // 墓碑数,超 25% 触发再散列
}

// 公开主体
struct BiMap[L, R] {
  mut forward  : HashTab[L, R]   // 左→右(承载顺序)
  mut backward : HashTab[R, L]   // 右→左(仅反查,无需顺序)
  mut order    : Array[L]        // 左键的插入顺序(唯一一份)
  mut positions : Map[L, Int]    // 左键 → order 下标,O(1) get_index_of_left
  mut len : Int
  mut version : Int              // fail-fast 变更计数
}
```

**要点:**
- `backward` **不需要自己的 order**——反查是按值哈希查找,顺序无意义。比"两个完整 IndexMap"省一半顺序开销。
- 关键常量(沿用 IndexMap):`MIN_CAPACITY = 16`,负载因子 `3/4`,`TOMBSTONE_HASH = -1`,`NO_DISTANCE = -1`。
- 类型约束:`BiMap[L : Hash + Eq, R : Hash + Eq]`。

---

## 四、核心不变量(测试火力焦点,详见 `SPEC.md §4`)

任何一次变更后,全部成立:
```
∀ (l, r) ∈ forward  ⟺  backward[r] == l        // 两侧严格互逆
forward.len == backward.len == order.length()
            == positions.size() == self.len     // 五处计数一致
positions[order[i]] == i                         // 位置映射自洽
self.mask == forward.buckets.length() - 1
forward.buckets.length() 是 2 的幂
```

**架构纪律:** 用少数私有 helper(`put_pair` / `remove_pair_by_left` / `remove_pair_by_right`)**统一**维护不变量。所有公开增删都走这些 helper,绝不在多处各写一遍"同步两张表"。

---

## 五、插入语义(C0–C4,详见 `SPEC.md §2-§3`)

插入 `(l, r)` 的五种子情形(BiMap 最易错之处):

| 情形 | 条件 | `insert` 返回 | len |
|---|---|---|---|
| **C0** | l、r 都不存在 | `Neither` | +1 |
| **C1** | (l, r) 精确已存在 | `Pair(l, r)` | 0 |
| **C2** | l→r' 存在(r'≠r),r 不在 | `Left(l, r')` | 0 |
| **C3** | l'→r 存在(l'≠l),l 不在 | `Right(l', r)` | 0 |
| **C4** | l→r' 且 l'→r 同时存在 | `Both((l,r'),(l',r))` | **−1** |

> **C4 是经典陷阱**:两对塌缩成一对,`len` 净减 1,bookkeeping 最易算错,必须是 property test 靶子。
> **C1 实现要点**:`insert` 在调 `put_pair` 前先判 `forward.get(l) == Some(r)` → 直接返回 `Pair(l, r)`(幂等短路),`put_pair` 只处理 C0/C2/C3/C4。

`insert_no_overwrite`:任一侧已存在 → `Err((l, r))` 且映射不动;否则插入返回 `Ok(())`。

---

## 六、反向访问与索引 API(详见 `SPEC.md §5-§6`)

```moonbit
// 双向查找
get_by_left(l) -> R?      contains_left(l) -> Bool    remove_by_left(l) -> R?
get_by_right(r) -> L?     contains_right(r) -> Bool   remove_by_right(r) -> L?

// 索引红利(来自 order/positions)
get_index(i) -> (L, R)?   get_index_of_left(l) -> Int?   get_index_of_right(r) -> Int?
first() -> (L, R)?        last() -> (L, R)?

// 反向副本(拷贝,非实时视图)
to_inverse() -> BiMap[R, L]
```

- `to_inverse()` 是**拷贝**,改它不影响原表(MoonBit 所有权模型不适合共享活视图;区别于 Guava `inverse()` 活视图,与 Rust bimap 用方法一致)。
- `get_index_of_right(r)` 是便捷方法,内部走 `get_by_right` 再 `get_index_of_left`(因为 order 只存左键)。
- `iter()` 按**左键插入序**产出 `(L, R)`——保序卖点的落点。
- `from_array` 遇重复对走 `insert`(**最后赢**),对齐 Rust `FromIterator`。

---

## 七、从 IndexMap 内化什么 / 不内化什么

### ✅ 内化(优点)
- Robin Hood 开放寻址 + 墓碑删除 + 25% 墓碑率自动 rehash
- order 数组 + positions 映射(顺序 + O(1) 下标)
- `version` fail-fast 迭代器(0.3.3 的真 fail-fast)
- 测试范式:黑盒 `@pkg.` 前缀、`debug_inspect` expect-test、QuickCheck 属性测试、独立测试套件
- 文档结构:README Gotchas / CONTRIBUTING / CHANGELOG / CI 五步流水线

### ❌ 不内化(历史 bug 聚集地 / BiMap 用不上)
- `get_mut`(0.3.2/0.3.3 反复修过,BiMap 不需要)
- Entry API(`OccupiedEntry`/`VacantEntry`,0.3.3 扩容挂死就在这,BiMap 不需要)
- `sort_by*`、`swap_remove_index`(那俩设计取舍都在这些面上)

只内化最小纯 `HashTab`,正好绕开所有历史雷区。

---

## 八、BiMap 特有的坑

1. **双表同步**——每次变更要同时改 forward、backward、order、positions、len、version 六处。用 `put_pair`/`remove_pair_*` 收口。
2. **C4 合并**——两对塌缩成一对,`len` 减 1,极易算错计数。
3. **删除双侧清理**——`remove_by_left(l)` 必须顺带删 `backward[r]`,反之亦然;漏一侧即破坏互逆。
4. **先检查后变更**——`insert_no_overwrite` 必须在动任何表**之前**完成两侧冲突检查。
5. **两表独立扩容**——一次 insert 可能触发一侧或两侧 resize;移植 IndexMap 的 16→256 扩容级联测试。
6. **Eq/Hash 顺序无关**——BiMap 用顺序无关 Eq(双射本质是"对的集合"),Hash 用可交换组合(对每对 hash 求和)。这顺手避开 IndexMap"Eq 顺序敏感"gotcha。**与 indexmap 对比表见第一节;务必写进 README。**
7. **ToJson 键**——用 `l.to_string()`(`L : Show`),别踩 `@debug.to_string(k.to_json())` 把键 mangle 成 `String("name")` 的老坑。

---

## 九、完整 API 面(详见 `SPEC.md §9`)

| 类别 | 方法 |
|---|---|
| 构造 | `new()`, `with_capacity(n)`, `from_array(pairs)`, `default()`, `copy()` |
| 查询 | `len()`, `is_empty()`, `capacity()` |
| 插入 | `insert(l, r) -> Overwritten`, `insert_no_overwrite(l, r) -> Result[Unit,(L,R)]` |
| 正向 | `get_by_left(l)`, `contains_left(l)`, `remove_by_left(l) -> R?` |
| 反向 | `get_by_right(r)`, `contains_right(r)`, `remove_by_right(r) -> L?` |
| 索引 | `get_index(i)`, `get_index_of_left(l)`, `get_index_of_right(r)`, `first()`, `last()` |
| 迭代 | `iter()`, `lefts()`, `rights()`, `into_array()` |
| 转换 | `to_inverse() -> BiMap[R, L]` |
| Traits | `Debug`, `Default`, `Show`, `Hash`(顺序无关), `Eq`(顺序无关), `ToJson`, `Arbitrary` |

---

## 十、测试策略(详见 `TESTS.md`)

- **属性测试打核心不变量**(QuickCheck):随机操作序列后断言"两侧互逆 + 五处计数一致"。最高价值。
- **两语义 × 五情形(C0–C4)矩阵**全覆盖,重点 C4。
- 删左/删右对称性、fail-fast、扩容级联、50% 批量删除、边界键——参照 IndexMap 的 `map_test`/`property_test`/`bench_test` 改写。
- 压力测试:10k+ 混合 insert/remove。
- 独立测试套件:indexmap 的制胜公式,bimap 照搬流程(M5 之后)。
- 目标总数 **≥ 200**(对标 indexmap 277)。

---

## 十一、文件结构与里程碑

```
moonbit-bimap/
  moon.mod
  docs/                  # 本文档体系(INDEX/EXECUTION/SPEC/MOONBIT_REF/TESTS/DEVPLAN/申报书)
  src/
    hashtable.mbt        # 私有纯 Robin Hood 引擎(内化自 indexmap,去顺序耦合)
    bimap.mbt            # BiMap 主体:两表 + order + positions + put_pair/remove_pair + 两语义
    lib.mbt              # 公开 re-export(new/with_capacity) + VERSION + Overwritten 枚举
    bimap_test.mbt       # 黑盒单元测试
    property_test.mbt    # QuickCheck 不变量
    bench_test.mbt       # 压力测试
    arbitrary_test.mbt   # QuickCheck 生成测试
    pkg.generated.mbti   # moon info 生成,CI 跟踪
  cmd/                   # 示例(username↔email、国家名↔国家码)
  README.md / CONTRIBUTING.md / CHANGELOG.md / LICENSE(Apache-2.0)
  .github/workflows/ci.yml
```

里程碑(详见 `EXECUTION.md §1`):M0 骨架 → M1 HashTab 引擎 → M2 BiMap 骨架+不变量 →
M3 完整 API → M4 traits+迭代 → M5 压力+示例+文档+发布。

### 开发命令(沿用 indexmap)
```bash
moon check                    # 类型检查
moon test                     # 跑全部测试
moon test --test-filter "pat" # 过滤(--test-filter,不是 -f)
moon fmt --check              # 格式检查(CI 门禁)
moon info                     # 重新生成 pkg.generated.mbti
moon build                    # 构建
```

CI **五步**:`moon fmt --check` → `moon check` → `moon info && git diff --exit-code` → `moon test` → `moon build`。

---

## License

Apache 2.0(与 indexmap 一致)。哈希表核心设计改编自本人 `aurasuisui/indexmap`,于 README 致谢。
移植对标:Rust `bimap` crate(MIT/Apache-2.0)与 Guava `BiMap`(Apache-2.0),范围与适配见 `申报书.md`。
