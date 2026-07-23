# EXECUTION.md — 无人值守 6 小时执行剧本

> **读者**:冷启动、无人值守、约 6 小时的执行会话。
> **使命**:按本剧本把 `moonbit-bimap` 从零做到可发布,中途**不停下来等人**。
> 设计/API 以 `SPEC.md` 为准;MoonBit 语法以 `MOONBIT_REF.md` 为准。

---

## 0. 开工前 5 分钟(必做)

1. 读完 `INDEX.md` → `EXECUTION.md`(本文件)→ `SPEC.md`。
2. 确认 MoonBit 工具链可用:
   ```bash
   moon version        # 能打印版本即可
   ```
   若 `moon` 不存在:按 https://www.moonbitlang.com/download/ 安装,或用
   `curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash`(Linux/mac)。
   若装不上,**不要卡死**——继续把代码/文档/测试写完,发布相关步骤改为
   "留说明、标 TODO"(见 §5 降级策略)。
3. 建目录并初始化:
   ```bash
   mkdir -p moonbit-bimap/src moonbit-bimap/docs
   cd moonbit-bimap
   git init
   # 把 ../moonbit-bimap/docs/*.md 复制到 moonbit-bimap/docs/(若尚未在内)
   ```
4. 建好骨架文件(内容见 `MOONBIT_REF.md §1`):`moon.mod`、`src/moon.pkg`、
   `.gitignore`、`LICENSE`(Apache-2.0 全文)、`.github/workflows/ci.yml`。
5. `git add -A && git commit -m "chore: scaffold moonbit-bimap project"`。

---

## 1. 时间预算与里程碑(总计 ≈ 6 小时)

> **纪律**:每个里程碑都有**门禁**(必须满足才进入下一阶段)。每完成一个里程碑
> 就 `git commit`。**若某阶段超时,按 §5 降级,绝不恋战。**

| 里程碑 | 预算 | 内容 | 门禁(必须全绿才过关) |
|---|---|---|---|
| **M0 骨架** | 20 min | 项目脚手架、`moon.mod`/`moon.pkg`/CI/LICENSE/README 占位 | `moon check` 通过(空库) |
| **M1 HashTab 引擎** | 70 min | 私有纯 Robin Hood 表(无顺序):`insert/get/remove/contains/iter/rehash`;移植 indexmap 的 resize/tombstone 逻辑 | `moon check` + 引擎自测通过 |
| **M2 BiMap 骨架** | 60 min | `BiMap` 主体 + `put_pair`/`remove_pair` 收口 + `insert() -> Overwritten` | **属性测试锁死"两表互逆 + 五处计数一致"** |
| **M3 完整 API** | 70 min | `insert_no_overwrite` + 正反向 get/contains/remove + 索引访问 + `from_array` + `copy` + `to_inverse` | C0–C4 × 语义矩阵全绿(见 `TESTS.md`) |
| **M4 traits + 迭代** | 60 min | `Debug/Default/Show/Hash/Eq(顺序无关)/ToJson` + fail-fast `iter/lefts/rights/into_array` | trait 测试 + fail-fast 测试全绿 |
| **M5 压力 + 示例 + 文档 + 发布** | 60 min | 10k 压力测试、`cmd/` 示例、README/CONTRIBUTING/CHANGELOG 定稿、`moon publish` | `moon test` 全绿 + 五步 CI 本地跑通 |
| **缓冲** | 40 min | 修 bug、补测试、写提交信息 | — |

**合计 ≈ 380 min ≈ 6.3 h**(含缓冲)。

### 关键节奏建议
- **M1 是最容易超时的**(Robin Hood 细节多)。**对策**:直接从 indexmap
  `src/map.mbt` 的 `probe_find`/`robin_hood_find`/`robin_hood_insert_at`/`rehash`
  移植(见 `MOONBIT_REF.md §3`),**不要从零手写**。去掉顺序/positions 部分即可。
- 每写完一个方法,立刻写它的最小测试并 `moon test --test-filter "xxx"` 单跑。
  **不要攒到里程碑末才测。**

---

## 2. 每个里程碑的具体动作

### M0 骨架
- 写 `moon.mod`(`name = "aurasuisui/bimap"`,`version = "0.1.0"`,source = "src",
  keywords、repository、license = "Apache-2.0")。
- 写 `src/moon.pkg`(import test / quickcheck / debug,见 `MOONBIT_REF.md §1`)。
- 写 `.github/workflows/ci.yml`(**五步**,照抄 indexmap 的,见 `MOONBIT_REF.md §1`)。
- 写 `src/lib.mbt` 占位:`pub const VERSION : String = "0.1.0"` + 一个空 `new()` 雏形。
- `moon check` 通过 → commit。

### M1 HashTab 引擎(`src/hashtable.mbt`)
- `struct Entry[K,V] { key; value; hash; mut distance } derive(Debug)`
- `struct HashTab[K,V] { mut buckets; mut len; mut mask; mut tombstone_count; mut max_probe_distance }`
  (**注意:无 order、无 positions、无 version**——那是 BiMap 层的职责。)
- 常量:`MIN_CAPACITY=16`、`TOMBSTONE_HASH=-1`、`NO_DISTANCE=-1`、负载因子 `3/4`。
- 方法:`new/with_capacity`、`insert(k,v)->V?`、`get(k)->V?`、`remove(k)->V?`、
  `contains(k)->Bool`、`iter()`、内部 `rehash`、`probe_find`/`robin_hood_find`/
  `robin_hood_insert_at`。
- **从 indexmap 移植**这五个内部函数,逐字搬运再删顺序耦合。
- 自测:基础增删查、扩容(插 100 个)、墓碑删除后再查、50% 删除后仍正确。
- 门禁:`moon check` + 引擎测试绿 → commit `feat: internal Robin Hood HashTab engine`。

### M2 BiMap 骨架(`src/bimap.mbt`)
- `struct BiMap[L,R] { mut forward: HashTab[L,R]; mut backward: HashTab[R,L]; mut order: Array[L]; mut positions: Map[L,Int]; mut len; mut version }`。
- **`put_pair(l, r) -> (R?, L?)`**(私有):按 `SPEC.md §3` 的 C0–C4 实现,
  **这是全库唯一会同时改 forward+backward+order+positions 的地方**。
  返回被挤掉的 `(old_right?, old_left?)`。
- **`remove_pair_by_left(l) -> R?` / `remove_pair_by_right(r) -> L?`**(私有):
  双侧清理 + 维护 order/positions + bump version。
- `pub fn insert(l, r) -> Overwritten`(公开):薄封装 `put_pair`,把返回值映射成
  `Overwritten` 枚举(`SPEC.md §2`)。
- **立刻写属性测试**(`property_test.mbt`):随机操作序列后断言
  `∀(l,r)∈forward ⟺ backward[r]==l` 且五处计数一致(`SPEC.md §4`)。
- 门禁:属性测试绿 → commit `feat: BiMap core with bijection invariants`。

### M3 完整 API
- `insert_no_overwrite(l, r) -> Result[Unit, (L, R)]`(对齐 Rust,见 `SPEC.md §3.2`)。
- 正向:`get_by_left/contains_left/remove_by_left`;反向:`get_by_right/contains_right/remove_by_right`。
- 索引:`get_index(i)->(L,R)?`、`get_index_of_left(l)->Int?`、`first()、last()`。
  (`get_index_of_right` 走 `get_by_right` 再 `get_index_of_left`,见 `SPEC.md §6.4`。)
- `from_array(pairs)`(走 `insert`,最后赢,见 `SPEC.md §6.3`)、`copy()`、
  `to_inverse() -> BiMap[R,L]`(拷贝)、`len/is_empty/capacity`。
- 门禁:`TESTS.md` 的 **C0–C4 × 2 语义矩阵**全绿 → commit。

### M4 traits + 迭代
- `Debug`(`Repr::opaque_("BiMap", ...)`)、`Default`、`Show`、
  **`Eq`(顺序无关)**、**`Hash`(可交换组合,见 `SPEC.md §7`)**、
  `ToJson`(键用 `l.to_string()`,`L : Show`)。
- `iter()/lefts()/rights()` 用 `Iter::new` + fail-fast(`version` 快照),
  `into_array()` 消费式。
- **Eq/Hash 顺序无关是本库与 indexmap 的关键差异**,务必写对(对每对 hash 求和;
  Eq 用"对的集合相等")。
- 门禁:trait 测试 + fail-fast 测试绿 → commit。

### M5 压力 + 示例 + 文档 + 发布
- 压力测试:10k 混合 insert/remove 后不变量仍成立(移植 indexmap `bench_test` 思路)。
- `cmd/` 示例 2 个(放 `moon.work` 之外或独立 module,见 indexmap 的做法):
  - `username ↔ email` 双向查找
  - 国家名 ↔ 国家码(如 `"China" ↔ "CN"`)
- 把 `drafts/README.md`、`drafts/CONTRIBUTING.md`、`drafts/CHANGELOG.md` 拷到项目根,
  按实际 API/测试数微调。
- `moon fmt && moon check && moon info && moon test && moon build` 全绿。
- 发布:`moon publish`(需 mooncakes.io 账号)。失败则写 `PUBLISH.md` 留步骤。
- commit `release: v0.1.0` + `git tag v0.1.0`。

---

## 3. 验收清单(Definition of Done)

发布前逐条打勾(对应黑客松验收要求):

- [ ] 以 MoonBit 为主要实现语言(核心全 `.mbt`)
- [ ] 五步 CI 本地全绿:`moon fmt --check` → `moon check` → `moon info && git diff --exit-code` → `moon test` → `moon build`
- [ ] `pkg.generated.mbti` 已 `moon info` 生成并提交(否则 CI 的 diff 检查会挂)
- [ ] README 清晰完整(用途/功能/用法/与 indexmap 区别/Gotchas)
- [ ] 可运行示例(`cmd/`)
- [ ] CI 已配置(`.github/workflows/ci.yml`)
- [ ] 测试可运行,目标 ≥ 200 个
- [ ] CHANGELOG 记录完整
- [ ] LICENSE = Apache-2.0;README 致谢"哈希表设计改编自本人 indexmap"
- [ ] 移植说明:原项目 `bimap` crate / Guava `BiMap`、链接、许可证(MIT/Apache-2.0)、移植范围(`SPEC.md §0` + `申报书.md`)
- [ ] 已发布到 mooncakes.io(或留 `PUBLISH.md`)
- [ ] git 提交记录清晰可追踪(Conventional Commits,每里程碑有提交)

---

## 4. 测试数量与命名目标

- 文件:`bimap_test.mbt`(单元,目标 ~120)、`property_test.mbt`(不变量,~30)、
  `bench_test.mbt`(压力,~20)、`arbitrary_test.mbt`(QuickCheck 生成,~15)。
- 命名:`test "英文描述性名字"`;黑盒前缀 `@aurasuisui/bimap.`。
- expect-test 用 `debug_inspect(..., content="...")`;**循环内变值断言用
  `@test.assert_eq`/`@test.fail`**(避免 `moon test -u` 生成不稳定快照)。
- 更新快照用 `moon test -u`,但**只对稳定的单值快照用**。

---

## 5. 卡住时的决策规则(无人值守核心)

> **总原则:保持前进,产出可交付物。宁可缩小范围,不要停摆或自造一套偏离 SPEC 的设计。**

按优先级尝试:

1. **编译错误** → 查 `MOONBIT_REF.md`;90% 是 trait 约束、`Iter::new` 签名、
   `mut`/所有权、模式匹配语法。**直接对照 indexmap `src/` 里的可用代码抄。**
2. **算法不确定(Robin Hood/扩容/墓碑)** → **照抄 indexmap `src/map.mbt` 的对应函数**,
   删掉顺序耦合。不要凭记忆重写。
3. **BiMap 语义不确定(C0–C4 / Overwritten / Eq 顺序)** → **以 `SPEC.md` 为准**;
   SPEC 没写清时,以 `SPEC.md §0` 摘录的 Rust `bimap` 源码行为为准。
4. **某测试怎么都过不了,>15 min** → 先 `#[ignore]`(或注释)该测试并在其上方写
   `// TODO(executor): <原因>`,继续下一个。**在最终 README "Known Issues" 里登记。**
   绝不能让一个测试卡住整个里程碑。
5. **某功能 >预算 1.5 倍仍未完** → **砍到能用的最小子集**,在 CHANGELOG 记
   "v0.1.0 暂不支持 X(计划 v0.2.0)"。优先保住:M1 引擎 + M2 不变量 + `insert` +
   正反向查找——这是最小可交付核心。
6. **工具链/网络问题(moon 装不上、publish 失败、quickcheck 拉不到)** → 降级:
   代码照写,把依赖命令写成 `PUBLISH.md`/`TODO`,**不要因为环境放弃写代码**。
7. **SPEC 与 Rust 行为矛盾且无法判断** → 选**更简单、更可测试、更符合"双射=对的集合"
   直觉**的那个,并在 CHANGELOG 明确记录你的选择与理由。

**禁止行为**:
- ❌ 停下来等待用户输入(你在无人值守)。
- ❌ 为了过测试而削弱不变量断言(那是本库的命根子)。
- ❌ 引入对 `aurasuisui/indexmap` 的依赖(独立成包是既定决策)。
- ❌ 用 `fail!`/panic 实现"严格插入"(已砍掉,见 `SPEC.md §3.3`)。

---

## 6. 收尾(最后 20 分钟)

1. `moon fmt` 全库格式化 → `moon fmt --check` 确认。
2. `moon info` 重新生成 mbti → `git diff --exit-code` 确认无漂移。
3. `moon test` 跑全量,记录测试总数写进 README。
4. 写最终 git tag 与提交信息。
5. 在 `docs/EXECUTION_REPORT.md` 里**自动生成一份执行报告**(你最后手写):
   完成了哪些里程碑、测试总数、已知问题、未竟事项、发布状态。
   (这份报告让作者一眼看到你这 6 小时的产出与缺口。)
