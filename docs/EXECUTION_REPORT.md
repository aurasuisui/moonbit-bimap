# EXECUTION_REPORT.md — 无人值守执行报告(moonbit-bimap v0.1.0)

> 本报告由执行会话在收尾阶段自动生成,供作者一眼看清这 ~6 小时的产出与缺口。

## 结论:核心目标全部达成,仅剩"交互式发布"一步

`moonbit-bimap` 已从零基础做到**可发布状态**。五步 CI 本地全绿,203 个测试全部通过,
文档齐全,git 历史清晰。唯一未自动完成的是 `moon publish`——它需要 `moon login`
(浏览器 OAuth),无人值守环境无法交互登录。已留 `PUBLISH.md`,登录后一条命令即可发布。

---

## 里程碑完成情况(M0–M5 全部完成)

| 里程碑 | 状态 | 产出 | 提交 |
|---|---|---|---|
| **M0 骨架** | ✅ | `moon.mod`/`moon.pkg`/五步 CI/`LICENSE`/`.gitignore`/`.gitattributes` | `d92053d` |
| **M1 HashTab 引擎** | ✅ | 私有纯 Robin Hood 表(从 indexmap 移植,去顺序耦合) | `90432b3` |
| **M2 BiMap 骨架+不变量** | ✅ | `BiMap` 主体 + `put_pair` 收口 + `insert -> Overwritten` + 属性测试锁死互逆/五处计数 | `cd40cf9` |
| **M3 完整 API** | ✅ | `insert_no_overwrite` + 正反向 get/contains/remove + 索引访问 + `from_array`/`copy`/`to_inverse` | `eeba663` |
| **M4 traits + 迭代** | ✅ | `Debug/Default/Show/Eq(顺序无关)/Hash(可交换)/ToJson/Arbitrary` + fail-fast `iter/lefts/rights` | `0a6f38c` |
| **M5 压力+示例+文档+发布** | ✅(发布留 PUBLISH.md) | 压力测试、`cmd/` 示例 ×2、README/CONTRIBUTING/CHANGELOG 定稿、`moon info` mbti | 多个提交 |

## 测试

- **总数:203**(目标 ≥200,达成),`moon test` < 1 秒跑完,全绿。
- 分布:
  - `bimap_test.mbt`:C0–C4 语义矩阵(含 Rust 黄金序列)、双向查找、删除、索引。
  - `property_test.mbt`:QuickCheck 不变量(互逆 + 五处计数一致 + 左右唯一),随机 insert/remove/碰撞序列。
  - `bench_test.mbt`:10k 增删、扩容级联(16→大)、墓碑堆积再散列、C4 高频塌缩、2 万步确定性混合 fuzz。
  - `arbitrary_test.mbt` / `traits_test.mbt` / `edge_test.mbt` / `types_test.mbt` /
    `coverage_test.mbt` / `more_test.mbt`:生成测试、trait/迭代、边界键值类型、海量边界用例。
- **核心不变量有 QuickCheck 守护**;C0–C4 × {insert, insert_no_overwrite} 矩阵全覆盖。

## 五步 CI(本地全绿)

```
moon fmt --check        ✅ PASS
moon check              ✅ PASS (0 error)
moon info && git diff   ✅ PASS (mbti 已提交,无漂移)
moon test               ✅ PASS (203/203)
moon build              ✅ PASS (0 error)
```

## 已知问题(Known Issues,已写进 README)

1. **fail-fast 的 `abort` 无法进程内测试。** 迭代中途改表会 `abort`,但 MoonBit 测试框架
   无法把"预期的 panic"断言为通过(panic 的测试被判 failed)。`src/bimap_iter.mbt` 的
   version 快照 + abort 逻辑经**人工复现验证**(确实触发 abort)与代码审查确认;其余迭代
   行为均有测试覆盖。

## 未竟事项

1. **`moon publish` 未执行**——需 `moon login`(交互式浏览器 OAuth)。包已完全发布就绪,
   见 `PUBLISH.md`(含逐步命令与发布前清单,全部已满足)。
2. **`cmd/` 示例**为独立 module,引用**已发布**的 `aurasuisui/bimap@0.1.0`,故在发布前
   不参与根 workspace 构建(与 indexmap 同款做法)。发布后可 `moon run cmd/<name>` 运行。

## 关键技术决策(均已记入 CHANGELOG「Notes / Deviations」)

1. **C2/C4 保序**(刻意扩展):改绑(C2)与塌缩(C4)保持存活左键的原插入位置,只有 C3
   接管时把新左键追加到末尾。Rust `bimap` 的 remove-then-reinsert 会把改绑键移到末尾;
   本库以"保序"为卖点,选了位置稳定版,返回的 `Overwritten` 与 `len` 变化与 Rust 完全一致。
2. **C1 短路**:`insert` 先判 `forward.get(l) == Some(r)` 直接返回 `Pair`(SPEC §4 推荐),
   避免 `(Some(r), Some(l))` 被误判成 C4 塌缩。
3. **`Arbitrary` 需 `R : Hash + Eq`**:生成走 `from_array`,而 backward 表要对右值哈希,
   故 R 必须可哈希/可比较(indexmap 只哈希键所以不需要)。
4. **`into_array` 放宽 R 约束**为 `[L : Hash + Eq, R]`(只经 `forward.get` 读),使
   Debug/Show/ToJson(R 仅约束 Debug/Show/ToJson)能枚举对。
5. **工具链适配**:`positions.length()`(弃用 `size()`)、限定式 trait 调用
   (`Hash::hash`/`Show::to_string` 等,弃用多约束点调用)、`raise` 效果注解(弃用 `!`)。

## 与 indexmap 的实质区别(过审关键,README/申报书已写明)

- BiMap = **双向一一对应(双射)+ 反查**,值也唯一;indexmap 值可重复、无反查。
- **Eq/Hash 语义相反**:BiMap 顺序无关(双射=对的集合),indexmap 顺序敏感。
- 仅共享底层哈希表(工程组件),非 indexmap 的拆分/改名;独立成包零依赖。

## 收尾自检

- [x] 五步 CI 全绿
- [x] `moon info` 后 `git diff --exit-code` 干净(mbti 已提交)
- [x] 工作区干净(`git status` 空)
- [x] 测试 ≥200(实际 203)
- [x] README/CONTRIBUTING/CHANGELOG/LICENSE/CI/示例齐全
- [ ] 已发布 mooncakes.io —— **留 `PUBLISH.md`**(待交互式登录)
- [x] git 记录清晰(Conventional Commits,每里程碑有提交)
