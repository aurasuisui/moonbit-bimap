# 发布前测试清单(Release Checklist)

> **本文件是 `aurasuisui/bimap` 每次 bump `moon.mod` 版本号前的唯一发布门禁清单。**
> 约定:**任何 `moon publish` 之前,本清单必须逐项全绿,并在 [`CHANGELOG.md`](../CHANGELOG.md) 记一行
> 发布检查的勾选结果。** 这条约定替代 CI 脚本强制——靠每个会话自觉执行(与 `CONTRIBUTING.md` 的
> 文档同步约定互锁,见 `docs/SESSION_PLAYBOOK.md §5`)。
>
> 通用 Tier 0–4 框架取自 moonbit-dev 父目录的 `RELEASE_TEST_CHECKLIST.md`(通用模板,两个库共用);
> **本文件只记 bimap 的逐项现状**,不复制通用定义,只链接——单一真源(SSOT)。

---

## Tier 0 — 正确性地基(阻断级)

| 项 | 现状 | 出处 |
|---|---|---|
| API / 单元测试:每个公开方法按文档契约逐一验证 | ✅ | `bimap_test.mbt`(44)、`edge_test.mbt`/`coverage_test.mbt`/`more_test.mbt` |
| 边界 / 异常:空 / 单元素 / 边界值(0 / -1 / 32 位极值 / 空串)/ 重复键 / 越界下标 | ✅ | `bimap_test.mbt`(get_index 越界 → None)、`types_test.mbt`、`generics_test.mbt`(可移植 Int 极值) |
| 不变量:两侧互逆 + 五处计数 + `positions[order[i]]==i` + mask / 2 的幂 | ✅ | `bimap_wbtest.mbt`(白盒强不变量)、`property_test.mbt`(`check_bijection` 黑盒守护) |

> **MoonBit 限制**:迭代中变更触发 `abort`,恐慌不可被测试框架捕获——见 README "Known Issues"
> 与 `bimap_iter.mbt` 注释;逻辑经逐代码审查 + 手工复现验证,**非测试可达**(⊘)。

## Tier 1 — 系统化正确性(标准库分水岭)

| 项 | 现状 | 出处 |
|---|---|---|
| 模型 / 状态化属性测试 ⭐:同操作流 vs 朴素 `Array` oracle,逐步比对 | ✅ | `model_test.mbt`(差分,精确内容+顺序,5 测试含 6000 LCG + QuickCheck) |
| 差分测试:对同一操作流与可信参考实现比对 | ✅ | `model_test.mbt`(朴素 oracle)+ `differential_test.mbt` **对 Rust 原版 `bimap` crate v0.6.3 的真实差分**(夹具由 `tools/diffgen` 生成并入库:黄金 C0–C4 + 6000 步 LCG,逐步比对 Overwritten/len + 终态对集;2026-08-19 闭环) |
| 随机不变量:随机操作序列下双射恒成立 | ✅ | `property_test.mbt`(7)、`bench_test.mbt`(C4 洪流) |
| QuickCheck `Arbitrary`:生成的双射恒满足不变量 / 顺序无关 Eq/Hash / `to_inverse` 对合 | ✅ | `arbitrary_test.mbt`(6) |
| 模糊测试 fuzzing:字节流/操作流 fuzz 变更路径 | ⚠️ | 受限:MoonBit 暂无标准 fuzz 框架;`model_test.mbt` 的 6000-op LCG + QuickCheck 是"受限 fuzz"替身——见 `bimap_test.mbt` 与 `model_test.mbt` 顶部注释。真实字节流 fuzz 列为未来工作 |

## Tier 2 — 现实边缘的健壮性

| 项 | 现状 | 出处 |
|---|---|---|
| 压力 / 规模:大 N、扩容级联、墓碑累积、fill→drain→refill | ✅ | `bench_test.mbt`(10k/20k)、`generics_test.mbt`(fill→drain→refill 容量不膨胀、三轮) |
| 对抗性输入:HashDoS 碰撞洪水,无超线性退化,探测距离有界 | ✅ | `bimap_wbtest.mbt`:常哈希键洪流下表仍正确、删除可用,量化 `max_probe_distance` 线性退化(对应 README Gotcha #2 的可交换哈希弱点) |
| 迭代器 / 别名契约:fail-fast、多迭代器独立、迭代中变更行为明确 | ✅ | `iter_test.mbt`(多迭代器独立、`collect()`/size_hint 可观测效果)、`traits_test.mbt`(顺序+计数+for-in)。Fail-fast 的 abort 路径:⊘ 不可在进程内断言,已文档化 |
| 序列化往返 + golden-file 快照 | ⊘ | 本库仅单向 `ToJson`,无 `FromJson`(设计如此,见 `docs/DEVPLAN.md`),无往返可测。Debug 快照散见 `traits_test.mbt` |

## Tier 3 — 非功能 / 生产卫生

| 项 | 现状 | 出处 / 约定 |
|---|---|---|
| 性能基准 + 回归门禁(CI 上回归即 fail) | ⚠️ 本地基准 ✅ / CI 门禁 ❌ | `bench/` 模块:官方 `@bench` 框架、native + release、基准对象为已发布包,含内置 `Map` 基线(见 `bench/README.md`);CI 回归门禁仍未做(记入 CHANGELOG 未来工作) |
| **跨后端 / 跨配置矩阵**(wasm-gc / wasm / native × debug/release) | ⚠️ **文档约定,不进 CI** | 库为纯 MoonBit 无后端相关代码。**约定:发版前手动至少在 native + wasm-gc 两个后端跑一遍 `moon test --target <t>` 确认通过**;不自动化进 `ci.yml`(见下"手动约定")。当前 CI 单后端(ubuntu + `latest`) |
| 并发语义:断言/声明线程安全性 | ✅ 声明 | README Gotcha #8:**非线程安全**。`BiMap` 可变 + 迭代器 fail-fast;并发读写未定义;一线程一个 `BiMap` 或外部同步 |
| 内存:验证容量/缩容策略 | ✅ | `generics_test.mbt`(fill→drain→refill 容量不膨胀)、`bimap_wbtest.mbt`(扩容到 3/4 负载穿越、25% 墓碑再散列) |
| Trait 契约一致性:`Eq 相等 ⇒ Hash 相等`;Show/Debug/ToJson 正确 | ✅ | `traits_test.mbt`(顺序无关 Eq/Hash 即此契约)、`arbitrary_test.mbt`(Hash 同则 Eq 同) |

## Tier 4 — 元层(检验测试本身 + 流程)

| 项 | 现状 | 出处 |
|---|---|---|
| 变异测试:注入故障看测试能否抓住 | ❌ 工具所限 | MoonBit 暂无标准变异测试工具,记入 CHANGELOG 未来工作 |
| CI 流水线门禁:`moon fmt --check` → `moon check` → `moon info && git diff --exit-code` → `moon test` → `moon build` | ✅ | `.github/workflows/ci.yml`(五步全绿) |
| API / ABI 稳定:公开签名快照(`pkg.generated.mbti` diff 门禁)+ semver | ✅ | `moon info && git diff --exit-code` 步骤;`moon.mod` 坚持 semver(见下"发布前必检门禁") |
| 文档 / 示例可运行:README 代码、`cmd/` 示例编译并跑通 | ✅ 约定 | README 代码块为片段;`cmd/username_email`、`cmd/country_code` 为独立模块且**已排除出 workspace**,发版前手动 `moon run cmd/<name>` 验证可跑(需已 `moon publish`) |

---

## 发布前必检门禁(每次 bump 版本号前逐项勾选)

> 这一节是两份原清单都缺、但每次发版必须过的**非测试类门禁**。> 历史:`indexmap` 出过 VERSION 不一致(Known Issue #1),bimap 须避免重蹈。

- [x] **版本号三处一致**:`moon.mod` 里的 `version` == `src/lib.mbt` 的 `VERSION` 常量 == `README.md`
      徽章/安装说明里的 `@aurasuisui/bimap@<x.y.z>` == `CHANGELOG.md` 顶部的版本段标题。
- [x] **零依赖声明确实成立**:`moon.mod` 无 `deps` 段;"纯 MoonBit、零依赖"(不依赖 `aurasuisui/indexmap`,
      Robin Hood 引擎是就地适配,非 import)——README/CONTRIBUTING/CLAUDE 三处口径一致。
- [x] **接口快照已刷新并提交**:`moon info` 后 `git diff --exit-code` 干净(`pkg.generated.mbti`
      无未提交改动)。改过任何公开签名就必须同步提交。
- [x] **`moon publish --dry-run` 通过**:确认 mooncakes 能打包、README 描述能解析、无缺失字段。
- [x] **`cmd/*` 示例对已发布版本可跑**:`moon run cmd/username_email` 与 `moon run cmd/country_code`
      手动跑通(它们 import 的是**已发布**的 `aurasuisui/bimap@<x.y.z>`,故须先 publish 再验,或本地
      软链核对)。**勿把 `cmd/*` 加进 `moon.work` 的 members**(见 CLAUDE.md "cmd/ examples" 节)。
- [ ] **Rust 构建产物不进包**(0.1.2 起适用,因 `tools/` 入库):`moon publish` 按目录打包,
      `tools/diffgen/target/` 虽已 gitignore,但**不保证**被发布打包排除(`moon.mod` 无 files
      白名单)。发布前在 `tools/diffgen/` 跑 `cargo clean`,或发布后检查 zip 清单确认无
      `target/`(沿用 0.1.1 的发布后包内容抽查)。
- [x] **SPDX 头与署名留存**:源文件 Apache-2.0 SPDX 头在;README/CONTRIBUTING/CLAUDE 的"Acknowledgements"
      段保留三处署名——Robin Hood 引擎源自 `aurasuisui/indexmap`(Apache-2.0)、BiMap 语义源自 Rust
      `bimap`(MIT/Apache-2.0)、概念参考 Guava `BiMap`(Apache-2.0)。改这些文件时勿删署名。
- [x] **文档同步(按 `CONTRIBUTING.md` 文档同步约定)**:有公开 API 变更 → 同步 `docs/SPEC.md` +
      `README.md` API 表;有关键决策/行为变更 → 同步 `CHANGELOG.md` Notes/Deviations;架构/流程变更 →
      同步 `CONTRIBUTING.md`;命令/工具链 → `CLAUDE.md`;增删任一文档 → `docs/README.md` 枢纽表。
- [x] **五步 CI 全绿**:本节勾选时,主分支 `main` 的 GitHub Actions 跑过的五步(`moon fmt --check`
      → `moon check` → `moon info && git diff --exit-code` → `moon test` → `moon build`)全绿。
- [x] **CHANGELOG 记一行**:在本版本段加一行"发布前检查:RELEASE_CHECKLIST 全绿 @ <commit>"。

### 手动约定(不进 CI,发版前人工执行)

跨后端矩阵:`moon test --target native` 与 `moon test --target wasm-gc`(及可选 `--target js`)至少各跑一遍
确认通过。库为纯 MoonBit,预期通过;若某后端失败,该后端记入 README "Known Issues" 并考虑是否阻断发版。
**此条不自动化进 `ci.yml`**——保持 CI 单后端以控制 CI 时长,跨后端由发版前手动把关。

---

## 缺口登记(真实未达标,记为 v0.1.x 增强项)

| 项 | 性质 | 处置 |
|---|---|---|
| ~~**对 Rust 原版 `bimap` crate 的真实差分测试**~~ | ✅ **已闭环(2026-08-19)** | `tools/diffgen`(Rust,钉死 `bimap = "=0.6.3"`)生成夹具 `src/differential_fixture_test.mbt`,`src/differential_test.mbt` 逐步比对;`moon test` 无需 Rust 工具链,仅重生成夹具时需要。见 CHANGELOG [0.1.2] |
| **真实字节流 fuzzing**(非受限替身) | 工具所限 | 等 MoonBit 官方 fuzz 框架;`model_test.mbt` 的 6000-op LCG + QuickCheck 暂代 |
| **性能回归门禁**(本地基准已有,CI 门禁未做) | ⚠️ 本地 ✅ / CI ❌ | 本地计时基准已就位:`bench/`(官方 `@bench` 框架,`moon run --release bench/main.mbt`);仍缺 CI 上的回归即 fail 门禁(需稳定计时设施)。见 CHANGELOG [0.1.2] |
| **变异测试** | 工具所限 | MoonBit 暂无标准 mutator 工具 |
| **跨后端 CI 自动矩阵** | 主动选择手动 | 见上"手动约定"——不在 CI 自动化,发版前人工跑 |

> 以上四项"工具所限 + 主动选择"均已记入 `CHANGELOG.md` 的 Unreleased / 未来工作段,非遗漏,也非
> "假装做过"。诚实分级是这份清单的纪律之一:✅ 才算、⚠️ 须备注限制、❌ 工具所限须登记、⊘ 已消解须说明。

---

## 历史

- **2026-07-25**:清单初版。整合自 moonbit-dev 父目录的 `RELEASE_TEST_CHECKLIST.md`(通用 Tier 框架,
  另一会话维护)与 `TEST_CHECKLIST.md`(bimap 早期逐项审计,已被本文件取代)。
- 父目录的 `RELEASE_TEST_CHECKLIST.md` 通用模板保留;其"各库现状速览"表 bimap 列改为指向本文件的指针。
- **2026-08-18**:0.1.1 发布,门禁逐项全绿(勾选结果见上方复选框,执行记录见 CHANGELOG
  `[0.1.1]` Process)。注:`moon publish --dry-run` 在 0.10.8 工具链已无该旗标,以直接发布 +
  `cmd/*` 对已发布包的解析验证替代。