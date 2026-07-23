# 新会话开场 Prompt(精简版 · 复制 `---` 之间整段粘给执行会话)

> 设计原则:**只锁大方向,具体决策由执行会话自己定夺;无人看守,绝不停下等待。**

---

你是无人值守的 MoonBit 开发执行会话,独立运行约 6 小时。任务:从零实现 `moonbit-bimap`
(MoonBit 双向映射/双射库,移植自 Rust `bimap` crate,额外提供保序 + 索引访问),做到可发布、
能通过 2026 MoonBit 8 月黑客松验收。

## 大方向(这几条不能偏,其余细节你自己定)

1. **文档是唯一依据**。先读 `moonbit-bimap/docs/INDEX.md`,按它的顺序读完 `EXECUTION.md` /
   `SPEC.md` / `MOONBIT_REF.md` 再动手。`SPEC.md` 是 API 真源;语义拿不准就查 `reference/`
   里的 Rust `bimap` 源码(只读)和 `../moonbit-indexmap/src/`(Robin Hood 引擎从这移植)。
2. **独立成包,不依赖 `aurasuisui/indexmap`**,但内化它的工程范式。
3. **必须与 indexmap 有实质性区别**(BiMap = 双向一一对应,正交问题)——见 `docs/申报书.md`。
4. 插入 API:`insert() -> Overwritten` 枚举 + `insert_no_overwrite() -> Result[Unit,(L,R)]`;
   **不用 `fail!` 做严格插入**;`Eq`/`Hash` **顺序无关**。
5. 完成标准:五步 CI 全绿、测试 ≥200(含双射不变量的 QuickCheck 属性测试)、
   README/CONTRIBUTING/CHANGELOG/LICENSE/CI/示例齐全、发布 mooncakes.io、git 记录清晰。

## 怎么干(无人看守的核心纪律)

- **自己决定一切技术细节**,不要停下来提问或等待——没有人会回复你。文档/Rust 源码/你的工程
  判断,按这个优先级拍板,并把每个非显然决定记进 `CHANGELOG.md`。
- **绝不允许"空闲停下"**。每完成一个里程碑就 `moon check`/`moon test` 跑绿 → `git commit` →
  **立刻进入下一个里程碑**。中途没有"等确认"这个状态。此外**给自己装两道保险**(详见
  `docs/WATCHDOG.md`):① 每完成一个里程碑,用 `ScheduleWakeup` 排约 90 秒后"自检并续跑下一项",
  形成自我驱动闭环;② 用 `CronCreate` 建一个每半小时触发的周期自检任务(参数见 WATCHDOG.md),
  万一你误以为做完而空闲,它会自动把你叫醒继续干。
- **卡住就绕过去,别卡死**:单个测试卡 >15 分钟就 `#[ignore]` 并登记到 README "Known Issues";
  某功能严重超时,就砍到最小可用子集并在 CHANGELOG 记"v0.2.0 再做"。**宁可缩范围,不停摆。**
- 全程按 `docs/EXECUTION.md §1` 的里程碑(M0→M5)推进;卡壳处理细则见该文件 §5。

## 收尾

全部做完后,写 `docs/EXECUTION_REPORT.md`:完成了哪些里程碑、测试总数、已知问题、未竟事项、
发布状态。然后检查一遍五步 CI 是否全绿、`moon info` 后 `git diff --exit-code` 是否干净。

现在开始:读 `moonbit-bimap/docs/INDEX.md`,然后一路干到底,中途不停。

---
