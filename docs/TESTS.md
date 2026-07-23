# TESTS.md — 测试矩阵(可勾选清单 + 验收证据)

> 执行会话按本清单实现测试。**每条都是一个具体可写的 `test`。** 打勾表示已实现且通过。
> 目标总数 **≥ 200**。属性测试(§2)是重中之重——它们是双射不变量的守护神。

测试约定(同 indexmap):
- 黑盒前缀 `@aurasuisui/bimap.`;`test "英文描述名"`。
- 稳定单值用 `debug_inspect(x, content="...")`;循环内变值用 `@test.assert_eq`/`@test.fail`。
- 文件:`bimap_test.mbt`(单元)/ `property_test.mbt`(不变量)/ `bench_test.mbt`(压力)/ `arbitrary_test.mbt`(QuickCheck 生成)。

---

## §1 C0–C4 × 插入语义 矩阵(核心,必全覆盖)

> 用 §0(Rust 实测样例)作为黄金基准,逐条复现。

### `insert() -> Overwritten`(12+ 条)
- [ ] **C0** 空表 `insert("a",1)` → `Neither`,`len==1`,`get_by_left("a")==Some(1)`
- [ ] **C0** 再 `insert("b",2)` → `Neither`,`len==2`
- [ ] **C1** 精确重插 `insert("a",1)`(已存在 a↔1)→ `Pair("a",1)`,`len` 不变
- [ ] **C2** `insert("a",4)`(a 已绑 1)→ `Left("a",1)`;`get_by_left("a")==Some(4)`;`get_by_right(1)==None`;`len` 不变
- [ ] **C3** `insert("c",2)`(2 已被 b 绑)→ `Right("b",2)`;`get_by_left("b")==None`;`get_by_right(2)==Some("c")`;`len` 不变
- [ ] **C4** 构造 `{a↔4, c↔2}` 后 `insert("a",2)` → `Both(("a",4),("c",2))`;**`len` 从 2 → 1**;最终只剩 `a↔2`
- [ ] **C4** 后 `get_by_right(4)==None`、`get_by_left("c")==None`(两旧对彻底清除)
- [ ] **C1 紧跟 C4**:接上例再 `insert("a",2)` → `Pair("a",2)`,`len==1`
- [ ] **复现 Rust 完整序列**(SPEC §0 的 6 步),逐步断言 `Overwritten` 与 `len`
- [ ] C4 后 `order` 只剩一个左键,`positions` 自洽
- [ ] C2 后 `order` 中左键位置正确(改绑不改变左键的插入序位置——见 §6 决策)
- [ ] 空键/空串:`insert("", 0)` 正常;`("", 0)` 的 C1/C2 行为正确

### `insert_no_overwrite() -> Result[Unit,(L,R)]`(6 条)
- [ ] 空表插入 → `Ok(())`
- [ ] 左键冲突(右值新)→ `Err((l, r))`,映射不变
- [ ] 右值冲突(左键新)→ `Err((l, r))`,映射不变
- [ ] 双侧冲突(C4 情形)→ `Err((l, r))`,映射不变(**不塌缩**)
- [ ] 精确重插已存在对 → `Err((l, r))`(因为左、右都已存在)
- [ ] 失败后 `len` 与原表完全一致(无任何副作用)

---

## §2 属性测试 / 不变量(property_test.mbt,最高价值)

> 模式:对随机 BiMap(`@quickcheck.samples`)或随机操作序列后,断言不变量。
> **每条都应能抓出"两表失同步"的 bug。**

- [ ] **互逆性**:∀(l,r)∈iter ⟹ `get_by_right(r)==Some(l)` 且 `get_by_left(l)==Some(r)`
- [ ] **五处计数一致**:`forward.len == backward.len == order.length() == positions.size() == len()`
  (注:forward/backward 是私有,可通过 `len()` 与 `iter().collect().length()` 间接验证)
- [ ] **positions 自洽**:对 iter 第 i 个左键 l,`get_index_of_left(l)==Some(i)`
- [ ] **左键唯一**:iter 产出的左键无重复
- [ ] **右值唯一**:iter 产出的右值无重复
- [ ] **insert 后互逆仍成立**:随机插一批 → 验证互逆
- [ ] **remove 后互逆仍成立**:随机删一半 → 验证互逆 + 计数
- [ ] **随机操作序列**(insert/remove 混合 N 步)→ 终态互逆 + 计数
- [ ] **C4 塌缩后计数仍一致**:专门生成会触发 C4 的序列
- [ ] **Eq 顺序无关**:同一组对、不同插入序 → 两 BiMap `==`
- [ ] **Hash 顺序无关**:同一组对、不同插入序 → hash 相等
- [ ] **Eq 反对称/自反**:`a==a`;`a==b ⟹ b==a`
- [ ] **copy 保真**:`copy()` 后与原表 `==` 且互逆
- [ ] **to_inverse 是对合**:`m.to_inverse().to_inverse() == m`
- [ ] **to_inverse 互逆正确**:`m.to_inverse().get_by_left(r) == m.get_by_right(r)`

---

## §3 删除 API(remove_by_left / remove_by_right)

- [ ] `remove_by_left` 存在键 → 返回 `Some(r)`,且 `get_by_right(r)==None`(双侧清)
- [ ] `remove_by_left` 不存在键 → `None`,映射不变
- [ ] `remove_by_right` 对称测试
- [ ] 删除后 `order`/`positions` 正确收缩,剩余左键的 `get_index_of_left` 仍正确
- [ ] 删除中间元素后,后续元素的索引 −1(顺序保持)
- [ ] 删空后 `is_empty()`、`len()==0`、iter 产出空
- [ ] 删除触发 fail-fast(见 §5)
- [ ] 删一个再插同一个 → 行为正确(墓碑复用路径)

---

## §4 查找 API(get/contains × 双向)

- [ ] `get_by_left` 命中/未命中
- [ ] `get_by_right` 命中/未命中
- [ ] `contains_left` / `contains_right` 真假
- [ ] 对称性:`get_by_left(l)==Some(r) ⟺ get_by_right(r)==Some(l)`
- [ ] 大量查找(扩容后)仍命中

---

## §5 索引访问(get_index / get_index_of_* / first / last)

- [ ] `get_index(0)` = 最早插入的对;`get_index(len-1)` = 最晚
- [ ] `get_index` 越界(负数 / ≥len)→ `None`
- [ ] `get_index_of_left` 命中/未命中
- [ ] `get_index_of_right` 命中/未命中(走 `get_by_right`+`get_index_of_left`)
- [ ] `first()`/`last()` 空表 → `None`;非空正确
- [ ] 插入顺序 = 迭代顺序 = 索引顺序(三者一致)
- [ ] C2(改绑)不改变左键的索引位置;C4(塌缩)后索引重排正确

---

## §6 构造 / 转换

- [ ] `new()` 空表;`with_capacity(n)` 容量 ≥ n(实际是 ≥n 的 2 的幂)
- [ ] `from_array` 无重复 → 正确
- [ ] `from_array` 有重复左键 → **最后赢**(`[("a",1),("a",2)]` → a↔2)
- [ ] `from_array` 触发 C4 → len 正确(塌缩)
- [ ] `copy()` 深拷贝:改副本不影响原表
- [ ] `to_inverse()` 拷贝:改逆表不影响原表
- [ ] `to_inverse()` 后类型是 `BiMap[R, L]`,内容互换
- [ ] `default()` == `new()`
- [ ] `len/is_empty/capacity` 基础

---

## §7 迭代(fail-fast)

- [ ] `iter()` 按左键插入序产出 `(L,R)`
- [ ] `lefts()` 只产出左键,顺序正确
- [ ] `rights()` 只产出右值,顺序正确
- [ ] `into_array()` 消费全部,顺序正确
- [ ] **fail-fast**:创建 iter 后 `insert` → 下次 `next()` abort(用 `try`/`catch` 或单独验证 abort 消息)
  (注:abort 测试若难写,可改为"文档声明 + 手动验证",在 Known Issues 注明)
- [ ] iter 中途删除 → abort
- [ ] 两次 iter 产出相同顺序(幂等)

---

## §8 Traits

- [ ] `Debug`:`Repr` 含 "BiMap" 与所有对
- [ ] `Eq` 顺序无关(§2 已含,此处再单测几个手工例子)
- [ ] `Hash` 顺序无关:打乱插入序 hash 相等
- [ ] `Eq` 不等:不同对集合 → `!=`
- [ ] `ToJson`:对象键是 `l.to_string()` 原样(**不是** `String("...")` mangle),值正确,按键序
- [ ] `ToJson` 嵌套值(R 是复合类型)正确
- [ ] `Default` 产出空表
- [ ] `Arbitrary`:能生成,生成后满足互逆(§2 已含)

---

## §9 压力 / 扩容(bench_test.mbt)

- [ ] 顺序插入 10000 对 → len 正确、互逆成立、查找全命中
- [ ] 插入 10000 后删 5000 → 计数一致、剩余正确
- [ ] 扩容级联:从 16 一路扩到 256+(插入触发多次 rehash),每步互逆成立
  (移植 indexmap `bench_test` 的 16→256 思路)
- [ ] 墓碑堆积:插 5000 删 4000 再查 → 正确(墓碑率触发 rehash)
- [ ] 反复 C4 塌缩:构造大量塌缩 → len 从不为负、计数一致
- [ ] 混合随机操作 20000 步 → 终态互逆 + 计数

---

## §10 边界键 / 值类型

- [ ] `BiMap[String, Int]`、`BiMap[Int, Int]`、`BiMap[Int, String]`、`BiMap[Bool, Int]`、`BiMap[Char, Int]` 各跑一遍基础增删查
- [ ] 空串键 `""`
- [ ] 负数键 / 零
- [ ] 单元素表的 first==last
- [ ] 极大键值(hash 碰撞路径)

---

## 验收映射(给作者看)

| 黑客松要求 | 本测试体系覆盖 |
|---|---|
| 测试可运行 | §1–§10 全部 `moon test` 跑过 |
| 功能边界清晰 | §1 语义矩阵 + SPEC §10 排除清单 |
| 真实可用 | §9 压力 + §3/§4/§5 全 API |
| 长期维护价值 | §2 属性测试守护不变量 + §8 trait 测试 |
