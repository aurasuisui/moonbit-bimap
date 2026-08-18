# MOONBIT_REF.md — MoonBit 语法/惯用法速查(均来自 indexmap 可用代码)

> **本文件每一段代码都摘自 `aurasuisui/indexmap` v0.3.3 的真实可运行源码**(路径见各节),
> 不是臆测。写 bimap 时直接照搬这些模式,只改类型名/删顺序耦合。
> 若与最新工具链有出入,以 `moon check` 报错为准微调。

---

## §1 项目配置文件(照抄改名)

### `moon.mod`(项目根)——源自 `moonbit-indexmap/moon.mod`
```toml
name = "aurasuisui/bimap"

version = "0.1.1"

readme = "README.md"

repository = "https://github.com/aurasuisui/moonbit-bimap"

license = "Apache-2.0"

keywords = [ "bimap", "bidirectional", "bijection", "data-structure", "ordered" ]

description = "A bidirectional map (bijection) with reverse lookup, insertion order, and index access - MoonBit port of Rust's bimap"

source = "src"
```

### `src/moon.pkg`——源自 `moonbit-indexmap/src/moon.pkg`
```
import {
  "moonbitlang/core/test",
  "moonbitlang/core/quickcheck",
  "moonbitlang/core/debug",
}
```
> 测试文件与源码同目录即可被 `moon test` 发现。`test`/`debug` 只在测试用,
> 但放 `moon.pkg` 的 import 里没问题(indexmap 就是这么做的)。

### `.github/workflows/ci.yml`——**五步**,照抄 `moonbit-indexmap/.github/workflows/ci.yml`
```yaml
name: CI

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  check-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup MoonBit
        uses: hustcer/setup-moonbit@v1
        with:
          version: latest
      - name: Format check
        run: moon fmt --check
      - name: Type check
        run: moon check
      - name: Interface check (mbti up-to-date)
        run: |
          moon info
          git diff --exit-code
      - name: Run tests
        run: moon test
      - name: Build
        run: moon build
```
> **关键**:`moon info` 会重新生成 `src/pkg.generated.mbti`,`git diff --exit-code`
> 检查它是否已提交。所以每次改完公开 API 都要 `moon info` 并提交 mbti,否则 CI 挂。

### `.gitignore`
```
target/
.moon/
```

---

## §2 常用命令

```bash
moon check                        # 类型检查
moon test                         # 跑全部测试
moon test --test-filter "pat"     # 过滤(**用 --test-filter,不是 -f**)
moon test -u                      # 更新 expect-test 快照(只对稳定单值快照用)
moon fmt                          # 格式化
moon fmt --check                  # 格式检查(CI 门禁)
moon info                         # 重新生成 src/pkg.generated.mbti
moon build                        # 构建
moon publish                      # 发布到 mooncakes.io(需登录)
```

---

## §3 Robin Hood 引擎(从 indexmap 移植,删顺序耦合)

> 下面函数全部来自 `moonbit-indexmap/src/map.mbt`。**移植到 `src/hashtable.mbt` 时,
> 把 `IndexMap` 换成 `HashTab`,删掉一切 `order`/`positions`/`version`/`remove_from_order`
> 相关代码**——HashTab 是纯哈希表,无顺序。

### 常量与 Entry(`map.mbt:7-28`)
```moonbit
const MIN_CAPACITY : Int = 16
const NO_DISTANCE : Int = -1
const TOMBSTONE_HASH : Int = -1

struct Entry[K, V] {
  key : K
  value : V
  hash : Int
  mut distance : Int
} derive(Debug)
```

### 负载因子判断(`map.mbt:79-81`)
```moonbit
fn should_resize_impl(len : Int, capacity : Int) -> Bool {
  len * LOAD_FACTOR_DENOMINATOR >= capacity * LOAD_FACTOR_NUMERATOR
}
// 其中 LOAD_FACTOR_NUMERATOR=3, LOAD_FACTOR_DENOMINATOR=4(见 hash.mbt)
```

### 下一 2 的幂(`map.mbt:85-94`)
```moonbit
fn next_power_of_two_impl(n : Int) -> Int {
  if n <= 1 { return 1 }
  let mut p = 1
  while p < n { p = p << 1 }
  p
}
```

### `probe_find`(简单线性探测,用于 get/remove/contains)(`map.mbt:98-121`)
```moonbit
fn[K : Eq, V] HashTab::probe_find(self, key : K, hash : Int) -> (Int, Bool) {
  let start = hash & self.mask
  let mut i = start
  while true {
    match self.buckets[i] {
      None => return (i, false)
      Some(entry) =>
        if entry.hash != TOMBSTONE_HASH && entry.hash == hash && entry.key == key {
          return (i, true)
        }
    }
    i = (i + 1) & self.mask
    if i == start { return (i, false) }
  }
  (0, false)
}
```

### `robin_hood_find`(带墓碑复用,用于 insert)(`map.mbt:125-162`)
```moonbit
fn[K : Eq, V] HashTab::robin_hood_find(self, key : K, hash : Int) -> (Int, Bool) {
  let start = hash & self.mask
  let mut i = start
  let mut dist = 0
  let mut first_tombstone : Int = -1
  while true {
    match self.buckets[i] {
      None => {
        let insert_at = if first_tombstone >= 0 { first_tombstone } else { i }
        return (insert_at, false)
      }
      Some(entry) => {
        if entry.hash == TOMBSTONE_HASH {
          if first_tombstone < 0 { first_tombstone = i }
        } else if entry.hash == hash && entry.key == key {
          return (i, true)
        }
        if entry.distance >= 0 && entry.distance < dist {
          let insert_at = if first_tombstone >= 0 { first_tombstone } else { i }
          return (insert_at, false)
        }
      }
    }
    i = (i + 1) & self.mask
    dist = dist + 1
    if i == start { return (i, false) }
  }
  (0, false)
}
```

### `robin_hood_insert_at`(Robin Hood 位移插入)(`map.mbt:166-224`)
```moonbit
fn[K, V] HashTab::robin_hood_insert_at(self, entry_param : Entry[K, V], start_idx : Int, hash : Int) -> Unit {
  let mut entry = entry_param
  let mut i = start_idx
  let mut dist = if start_idx == (hash & self.mask) {
    0
  } else {
    (start_idx - (hash & self.mask)) & self.mask
  }
  let cap = self.buckets.length()
  let mut steps = 0
  while true {
    if steps > cap { abort("HashTab: robin_hood_insert_at found no free slot (table full)") }
    steps = steps + 1
    match self.buckets[i] {
      None => {
        entry.distance = dist
        self.buckets[i] = Some(entry)
        if dist > self.max_probe_distance { self.max_probe_distance = dist }
        return
      }
      Some(existing) => {
        if existing.hash == TOMBSTONE_HASH {
          entry.distance = dist
          self.buckets[i] = Some(entry)
          self.tombstone_count = self.tombstone_count - 1
          if dist > self.max_probe_distance { self.max_probe_distance = dist }
          return
        }
        if existing.distance >= 0 && existing.distance < dist {
          entry.distance = dist
          self.buckets[i] = Some(entry)
          if dist > self.max_probe_distance { self.max_probe_distance = dist }
          entry = existing
          dist = existing.distance + 1
        } else {
          dist = dist + 1
        }
      }
    }
    i = (i + 1) & self.mask
  }
}
```

### `rehash`(重建,清墓碑)(`map.mbt:262-327`)
> 移植时把"遍历 `self.order`"改成"遍历 `self.buckets` 中的活条目"(因为 HashTab 没有 order)。
> 即:扫描旧 buckets,跳过 `None` 和墓碑,把每个活 entry 用上面的位移逻辑插进 new_buckets。
```moonbit
fn[K : Hash + Eq, V] HashTab::rehash(self, new_cap : Int) -> Unit {
  let cap = if new_cap > 0 { new_cap } else { self.buckets.length() }
  let new_buckets : Array[Entry[K, V]?] = Array::make(cap, None)
  let new_mask = cap - 1
  let mut new_len = 0
  let mut new_max_probe = 0
  // 遍历旧 buckets(非 order!)
  let mut pos = 0
  while pos < self.buckets.length() {
    match self.buckets[pos] {
      Some(entry) if entry.hash != TOMBSTONE_HASH => {
        let mut dist = 0
        let mut i = entry.hash & new_mask
        let mut to_insert = { key: entry.key, value: entry.value, hash: entry.hash, distance: 0 }
        while true {
          match new_buckets[i] {
            None => {
              to_insert.distance = dist
              new_buckets[i] = Some(to_insert)
              new_len = new_len + 1
              if dist > new_max_probe { new_max_probe = dist }
              break
            }
            Some(existing) => {
              if existing.distance >= 0 && existing.distance < dist {
                to_insert.distance = dist
                new_buckets[i] = Some(to_insert)
                if dist > new_max_probe { new_max_probe = dist }
                to_insert = existing
                dist = existing.distance + 1
              } else {
                dist = dist + 1
              }
            }
          }
          i = (i + 1) & new_mask
        }
      }
      _ => ()
    }
    pos = pos + 1
  }
  self.buckets = new_buckets
  self.mask = new_mask
  self.len = new_len
  self.tombstone_count = 0
  self.max_probe_distance = new_max_probe
}
```
> ⚠️ MoonBit 的 `match ... { Some(x) if cond => }` 守卫语法若工具链不支持,
> 改写成嵌套 `match`/`if`(indexmap 用的是嵌套写法,稳妥起见照嵌套写)。

### HashTab 的 `insert`/`get`/`remove`/`contains` 参考逻辑
- `insert(k, v)`:先 `probe_find` 看是否存在 → 存在则更新 value 返回旧值;
  否则 `robin_hood_find` 找插入点 → `robin_hood_insert_at`;`len+1`;
  若 `should_resize_impl` 则 `rehash(cap*2)`;墓碑率 >25% 也 rehash。
- `get(k)`:`probe_find` → 找到返回 `Some(value)` 否则 `None`。
- `remove(k)`:`probe_find` 找到 → 该槽设为墓碑(`entry.hash = TOMBSTONE_HASH`,`tombstone_count+1`,`len-1`),返回旧值。
- `contains(k)`:`probe_find` 的 found。

> **indexmap 的删除是"墓碑 + order shift-remove"。HashTab 只要墓碑,不要 order 部分。**
> 删除后的"order shift"是 BiMap 层 `remove_pair_*` 的职责。

---

## §4 迭代器(`Iter::new` + fail-fast)——源自 `map.mbt:814-884`

```moonbit
pub fn[L : Hash + Eq, R] BiMap::iter(self : BiMap[L, R]) -> Iter[(L, R)] {
  let mut pos = 0
  let len = self.order.length()
  let version = self.version
  Iter::new(
    fn() -> (L, R)? {
      if self.version != version {
        abort("BiMap: map mutated during iteration")
      }
      while pos < len {
        let left = self.order[pos]
        pos = pos + 1
        match self.get_by_left(left) {
          Some(r) => return Some((left, r))
          None => continue
        }
      }
      None
    },
    size_hint=len,
  )
}
```
> `Iter::new(fn () -> T?, size_hint=Int)` 构造惰性迭代器,支持 `for x in it`。
> `lefts()`/`rights()` 同理,分别 yield `L` / `R`。`version` 快照实现 fail-fast。

---

## §5 Trait 实现模式——源自 `map.mbt:1097-1181`

### Debug(`map.mbt:1097`)
```moonbit
pub impl[L : Debug + Hash + Eq, R : Debug] Debug for BiMap[L, R] with fn to_repr(self) {
  let entries : Array[(Repr, Repr)] = []
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((l, r)) => entries.push((Debug::to_repr(l), Debug::to_repr(r)))
      None => break
    }
  }
  Repr::opaque_("BiMap", Repr::map(entries))
}
```

### Hash(indexmap 版是顺序相关;**bimap 要顺序无关,见 SPEC §7.2**)
indexmap 原版(顺序相关,**不要照抄**):
```moonbit
pub impl[K : Hash + Eq, V : Hash] Hash for IndexMap[K, V] with fn hash_combine(self, hasher) {
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((k, v)) => { k.hash_combine(hasher); v.hash_combine(hasher) }
      None => break
    }
  }
}
```
**bimap 正确做法(可交换累加)**——核心思路:
```moonbit
pub impl[L : Hash + Eq, R : Hash] Hash for BiMap[L, R] with fn hash_combine(self, hasher) {
  // 对每对 (l, r) 计算一个 hash 值,用可交换运算(加法)累加,最后喂给 hasher
  let mut acc : Int = 0
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((l, r)) => acc = acc + combine_pair_hash(l, r)  // combine_pair_hash 自实现
      None => break
    }
  }
  acc.hash_combine(hasher)
}
```
> **如何实现 `combine_pair_hash(l, r)`**:用一个局部 hasher 把 l、r 依次 hash 进去取结果。
> MoonBit 的 `Hasher` 用法:实现/使用 `Hash::hash_combine(value, hasher)`。最稳妥:
> 借助标准库提供的 hasher 累积。若 API 拿不准,**退而求其次**:
> `acc = acc + (l.hash_value_xored_with_r)` 之类——但**必须保证同一对在任意 BiMap 里算出同一个数,
> 且累加用加法/异或(可交换)**。**用属性测试验证:打乱插入序后 hash 不变。**

### Eq(**顺序无关**,与 indexmap 不同)——`map.mbt:1131` 是顺序相关版,**bimap 改写**:
```moonbit
pub impl[L : Hash + Eq, R : Eq] Eq for BiMap[L, R] with fn equal(self, other) {
  if self.len() != other.len() { return false }
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((l, r)) =>
        match other.get_by_left(l) {
          Some(r2) => if r != r2 { return false }
          None => return false
        }
      None => return true
    }
  }
  false
}
```

### ToJson(键用 `l.to_string()`,**别 mangle**)——`map.mbt:1155`
```moonbit
pub impl[L : Show + Hash + Eq, R : ToJson] ToJson for BiMap[L, R] with fn to_json(self) {
  let obj : Map[String, Json] = Map([])
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((l, r)) => obj[l.to_string()] = r.to_json()
      None => break
    }
  }
  Json::object(obj)
}
```

### Arbitrary(QuickCheck 生成)——`map.mbt:1175`
```moonbit
pub impl[L : @quickcheck.Arbitrary + Hash + Eq, R : @quickcheck.Arbitrary] @quickcheck.Arbitrary for BiMap[
  L,
  R,
] with fn arbitrary(size, r0) {
  let pairs : Array[(L, R)] = @quickcheck.Arbitrary::arbitrary(size, r0)
  BiMap::from_array(pairs)
}
```

---

## §6 测试惯用法——源自 `map_test.mbt` / `arbitrary_test.mbt`

```moonbit
// expect-test 快照(稳定单值)
test "get returns inserted value" {
  let m = @aurasuisui/bimap.new()
  m.insert("a", 1) |> ignore
  debug_inspect(m.get_by_left("a"), content="Some(1)")
}

// 循环内变值断言 —— 用 @test.assert_eq / @test.fail(别用 debug_inspect)
test "all pairs roundtrip" {
  let m = @aurasuisui/bimap.from_array([("a", 1), ("b", 2)])
  let iter = m.iter()
  while true {
    match iter.next() {
      Some((l, r)) =>
        match m.get_by_left(l) {
          Some(got) => @test.assert_eq(got, r)
          None => @test.fail("missing")
        }
      None => break
    }
  }
}

// QuickCheck 生成
test "qc: bijection invariant holds after random ops" {
  let maps : Array[@aurasuisui/bimap.BiMap[Int, Int]] = @quickcheck.samples(20)
  let mut i = 0
  while i < maps.length() {
    let m = maps[i]
    // 断言:对每对 (l, r),get_by_right(r) == Some(l)
    let iter = m.iter()
    while true {
      match iter.next() {
        Some((l, r)) =>
          match m.get_by_right(r) {
            Some(l2) => @test.assert_eq(l2, l)
            None => @test.fail("inverse broken")
          }
        None => break
      }
    }
    i = i + 1
  }
}
```
> `@quickcheck.samples(n)` 生成 n 个随机值(需 `Arbitrary` impl);`@quickcheck.gen()` 生成单个。
> `@test.assert_eq(a, b)` 要求 `a`、`b` 可比较(`Eq`/`Debug`)。

---

## §7 常见编译错误对照(执行会话急救)

| 报错 | 多半原因 | 修法 |
|---|---|---|
| trait bound 不满足 | 公开方法缺约束 | 进哈希表/比较的**那一侧**加约束:写路径双侧 `Hash + Eq`,只读方法只加被查询侧(见 SPEC §8) |
| 不能修改 `self.xxx` | `self` 参数没标 `mut` 或 struct 字段没 `mut` | struct 字段加 `mut`;方法 `self : BiMap[L,R]`(MoonBit 引用语义,字段 mut 即可改) |
| `Iter::new` 类型错 | 闭包返回类型不是 `T?` 或缺 `size_hint` | 照 §4 模板 |
| `debug_inspect` 快照不稳 | 循环里用 debug_inspect 多变值 | 改 `@test.assert_eq` |
| `moon info` 后 CI diff 挂 | mbti 没提交 | `moon info && git add src/pkg.generated.mbti && git commit` |
| `[0083]` 弃用警告(多约束点调用) | `key.hash()` 这类 | indexmap 选择不修(CI 不 --deny-warn);bimap 可同样容忍,或改 `Hash::hash_combine(key, hasher)` |
| enum 带泛型 derive 失败 | `Overwritten[L,R]` derive | 手写 `Debug`/`Eq` impl 代替 derive |

---

## §8 关于 `[0083]` 弃用警告

indexmap 在 `moon check` 下有 14 个 `[0083]` 警告(对多 trait 约束的类型参数做点调用,
如 `key.hash()`),**选择不修**,因为 CI 不带 `--deny-warn`。bimap 起初沿用同样策略,
**2026-08 的 zero-warnings 任务后改为全部清零**:`moon check` / `moon test` 均 0 警告,
本地按 `--deny-warn` 验收(CI 仍不带,因其跟踪 `version: latest`,见 CHANGELOG
[Unreleased])。若想干净,把 `x.hash()` 改成 `Hash::hash_combine(x, hasher)` 形式。
