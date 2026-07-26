# docs/ — 文档枢纽(全量地图)

> **这是整个仓库文档的唯一入口与目录。** 每份文档都在这里登记了**角色**和**存活状态**。
> **新增或删除任何文档,必须同步更新本表**——这是防"零碎死文件"的第一道闸(配合
> `CONTRIBUTING.md` 的文档同步约定)。

## 单一真源(SSOT)纪律

每条事实**只住一个文件**,别处只链接、不复制。复制是文档漂移和死文件的根源。

| 这条信息 | 唯一的家 |
|---|---|
| 是什么 / 为什么 / 用法 / API 概览 / Gotchas | [`README.md`](../README.md) |
| 架构深挖 / 开发流程 / 测试约定 / **文档同步约定** | [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| 每次改动与关键决策 | [`CHANGELOG.md`](../CHANGELOG.md) |
| API 契约(每个签名、C0–C4、不变量、Eq/Hash 语义) | [`SPEC.md`](SPEC.md) |
| 会话入口(命令 + 架构速览 + 阅读顺序) | [`CLAUDE.md`](../CLAUDE.md) |

## 文档地图

### 活文档(长期维护)

| 文件 | 角色 | 何时读 |
|---|---|---|
| [`../README.md`](../README.md) | 产品门面:用途、与 indexmap 区别、API 表、Gotchas、致谢 | 想了解项目 |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | 开发圣经:架构深挖、加功能清单、测试约定、**文档同步约定** | 要改代码 |
| [`../CHANGELOG.md`](../CHANGELOG.md) | 发布历史 + 每次决策的 Notes/Deviations | 想知道改过什么 |
| [`../CLAUDE.md`](../CLAUDE.md) | Claude 会话自动加载的入口 | 每个会话开头 |
| [`SPEC.md`](SPEC.md) | **API 唯一真源**:签名/返回类型/语义,行为拿不准时以此为准 | 动公开 API |
| [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) | **发布门禁**:每次 bump 版本前必须逐项全绿的 Tier 0–4 + 发布前必检门禁 | 准备发版 |
| [`MOONBIT_REF.md`](MOONBIT_REF.md) | MoonBit 语法/惯用法速查(来自 indexmap,非 bimap 专属) | 写 MoonBit 卡壳 |
| [`SESSION_PLAYBOOK.md`](SESSION_PLAYBOOK.md) | **任务会话手册**:讨论方案→执行→卡住决策→看门狗→知识回写 | 开新任务会话 |
| `README.md`(本文件) | 文档枢纽/全量地图 | 不知道读哪份 |

### 一次性 / 归档(只读,不再维护)

| 文件 | 角色 |
|---|---|
| [`DEVPLAN.md`](DEVPLAN.md) | 立项架构设计稿——"为什么这么设计"的决策史(含 BiMap vs IndexMap 辨析) |
| [`申报书.md`](申报书.md) | 2026 MoonBit 8 月黑客松项目申报书(过审材料) |

## 阅读顺序

**新会话快速上手**(约 5 分钟):
`CLAUDE.md`(自动加载:命令+架构) → `README.md`(产品) → `CONTRIBUTING.md`(怎么开发)
→ 动 API 才读 `SPEC.md`。

**开任务会话**(测试 / 改进 / 新功能):
`CLAUDE.md` → `SESSION_PLAYBOOK.md`(整套流程) → 按任务读 `SPEC.md` / `CONTRIBUTING.md`。

**准备发版**(bump `moon.mod` 版本):
`CLAUDE.md` → [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md)(逐项全绿 + 发布前必检门禁 + 缺口登记)
→ 勾选结果记一行进 `CHANGELOG.md`。
