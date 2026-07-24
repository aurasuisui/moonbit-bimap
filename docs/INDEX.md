# moonbit-bimap 文档体系 · 导航 (INDEX)

> **这份文档是给"冷启动、无人值守、约 6 小时独立开发"的执行会话看的。**
> 你(执行会话)之前没有任何上下文。按下面的顺序读完,你就能独立、正确地
> 从零构建出 `moonbit-bimap` 并通过 MoonBit 8 月黑客松验收。**不要跳过任何一份。**

---

## 0. 你是谁,你要做什么

- **目标**:从零实现 `moonbit-bimap`——MoonBit 版双向映射(BiMap),移植自 Rust
  [`bimap`](https://crates.io/crates/bimap) crate / Guava `BiMap` 的概念,
  并额外提供 **保序 + 可索引**(Rust/Guava 都没有)作为差异化卖点。
- **这是 2026 MoonBit 8 月黑客松的参赛项目**,作者已有同生态项目
  `aurasuisui/indexmap`(保序哈希表)。两者组成"有序集合家族"。
- **硬约束**:必须与 `indexmap` 有**实质性区别**(黑客松规则)。BiMap 解决的是
  **正交问题**(双向一一对应),不是 indexmap 的拆分或改名。详见 `SPEC.md §1` 与 `申报书.md`。
- **你的工作方式**:无人值守约 6 小时。**遇到不确定的设计问题,先查这套文档;
  文档没写的,按 `EXECUTION.md §决策规则` 处理,绝不停下来等人。**

---

## 1. 阅读顺序(必读)

| 顺序 | 文件 | 作用 | 何时读 |
|---|---|---|---|
| 1 | **本文件 `INDEX.md`** | 总导航 + 全局纪律 | 现在 |
| 2 | **`EXECUTION.md`** | **6 小时执行剧本**:时间预算、里程碑门禁、卡住时怎么办、完成定义 | 读完本文件立刻读 |
| 3 | **`SPEC.md`** | **唯一 API 真源**:每个类型/方法签名、`Overwritten` 枚举、C0–C4 语义、不变量、Eq/Hash 语义 | 写任何代码前读 |
| 4 | **`MOONBIT_REF.md`** | MoonBit 语法/惯用法速查(均来自 indexmap 的可用代码,非臆测) | 写代码时随手查 |
| 5 | **`TESTS.md`** | 测试矩阵:属性测试、语义×情形矩阵、压力测试清单 | 进入测试阶段读 |
| 6 | **`DEVPLAN.md`** | 架构设计稿:为什么这么设计、内化 indexmap 什么、BiMap 特有的坑 | 想理解"为什么"时读 |
| 7 | **`申报书.md`** | 一页申报书内容(过审用,也是你的"需求规格"复核) | 收尾发布前读 |
| 8 | **`drafts/README.md` / `drafts/CONTRIBUTING.md` / `drafts/CHANGELOG.md`** | 文档草稿,直接拷进项目根目录再按实际微调 | 收尾阶段 |
| 9 | **`START_PROMPT.md` + `WATCHDOG.md`** | 作者用:启动执行会话的开场 prompt + 无人看守的自动自检/续跑看门狗 | 启动时 |

> **作者(不是执行会话)启动执行会话时**:把 `START_PROMPT.md` 里 `---` 之间的内容粘给新会话即可。

---

## 2. 全局纪律(任何阶段都适用)

1. **`SPEC.md` 是 API 的唯一真源。** 代码签名、返回类型、语义必须与之一字不差。
   若你发现 SPEC 有矛盾或不可实现,**优先遵循 Rust `bimap` crate 的真实行为**
   (参考 `SPEC.md §0` 的源码摘录),并在 `CHANGELOG.md` 记一笔偏差。
2. **不依赖 `aurasuisui/indexmap` 包**(独立成包,零依赖),但**内化**它验证过的
   设计:Robin Hood 开放寻址、order+positions、fail-fast 迭代器、测试/文档范式。
   详见 `DEVPLAN.md §2、§7`。
3. **所有公开 API 都要有 `///|` 文档注释**;测试全部黑盒 `@aurasuisui/bimap.` 前缀。
4. **收口不变量**:任何变更只通过私有 helper `put_pair` / `remove_pair` 维护
   "两表互逆 + 五处计数一致"。绝不在多个公开方法里各写一遍同步逻辑。(`SPEC.md §4`)
5. **每一步都要能 `moon check` 通过再往下走**;每个里程碑结束跑 `moon test`。
   不要积攒一大堆未编译代码。
6. **保留清晰 git 提交记录**(Conventional Commits),每个里程碑一个或多个提交。
   黑客松验收要求"开发过程可追踪"。

---

## 3. 项目目录约定

执行会话应在一个**新目录** `moonbit-bimap/` 下工作(不要污染 `moonbit-indexmap/`)。
最终结构见 `DEVPLAN.md §11`。文档本身(`INDEX/EXECUTION/SPEC/...`)放在项目根的
`docs/` 子目录里,`README/CONTRIBUTING/CHANGELOG` 从 `drafts/` 拷到项目根。

---

## 4. "完成"意味着什么(速览,详见 `EXECUTION.md §完成定义`)

- `moon fmt --check` / `moon check` / `moon info && git diff --exit-code` /
  `moon test` / `moon build` **五步全绿**(CI 同款)。
- 核心不变量有 QuickCheck 属性测试守护;C0–C4 语义矩阵全覆盖。
- README / CONTRIBUTING / CHANGELOG / LICENSE(Apache-2.0)/ CI 齐全。
- 有可运行示例(`cmd/`)。
- 已 `moon publish` 到 mooncakes.io(若环境允许;否则留好发布说明)。
- 测试数量级:目标 **≥ 200**(对标 indexmap 的 277)。
