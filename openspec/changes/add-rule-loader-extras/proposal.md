# Proposal

## Why

模式 = "清单里放了哪些包"（`load { '基础', '身份场', '标准' }`），所以必须能拦住**互斥的组合**（身份场 + 国战同时进清单）。但加载是顺序执行的：等跑到冲突那一行才发现，前面已经白跑了一堆文件。因此需要**预解析** —— 枚举出文件后先试跑一次，只提取它们的依赖 / 互斥 / 条目清单，汇总成**包元信息**，这样**执行任何文件之前**就能报出冲突。

## What Changes

- `rule.depends` 支持**互斥声明**：项以 `!` 开头（`rule.depends { '!国战' }`）表示与该项互斥。项与依赖项**同一套路径解析**（含相对路径）；判定「已加载」= 本轮加载的文件里有任何一个落在该项（包目录 / 文件）之下；该项**没被加载时不报错**；冲突时报错要指出**声明者**与**被排斥的项**。
- 新增**预解析**：对每个已枚举到的文件做一次**试跑**，提取它声明的**依赖项 / 互斥项 / 条目清单**（声明过的裸名，按顺序），汇总为**包元信息**（包名、依赖、互斥、条目清单、每个文件的逻辑路径与它来自哪个来源）。试跑**不产生真实副作用**（不写规则表、不写规则数值）。
- **执行前校验冲突**：互斥冲突与**同包重复条目**都在执行任何文件之前报错；本轮加载结束时再兜一次底（试跑失败的文件可能藏着声明）。
- 新增**只读查询**：`rule:getPackageMeta(包名)` / `rule:getMetas()`。
- 试跑用 `sumneko/utility/without-check-nil`（给 `nil` 装元表，nil 上的算术 / 拼接 / 索引 / 调用都不崩）+ **stub 环境**（`rule` 只记声明，其余 API 落到 nil 也不炸）；**试跑失败只记警告并继续**（执行时校验兜底）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `rule-loading`: 「文件级依赖声明」增加互斥声明；新增「预解析与包元信息」需求（试跑、元信息内容、执行前冲突校验、只读查询）。

## Impact

- `server/rule/init.lua`：互斥解析与校验、预解析接入、元信息汇总与查询。
- 新增 `server/rule/preparse.lua`（试跑：stub 环境 + `without-check-nil` 开关）。
- `server/tools/without-check-nil.lua`：照搬 `sumneko/utility`（`server/tools/` 是"照搬不改"区，需在 `infrastructure.md` 记录来源与授权）。
- 测试：新增 `server/test/rule/meta.lua`（预解析 / 元信息 / 互斥），并挂到套件列表。
- 文档：`architecture.md` 第 9 节补「互斥声明」「预解析与包元信息」；`infrastructure.md` 补 `without-check-nil` 的来源行。
- 后续：`add-base-rules` 用这套机制拦住「身份场 + 国战」这类组合。
