# Proposal

## Why

工具集（`filter` / `map` / `contains`）上一批刚从内核挪到默认包 `@tools`，落在**共享环境里一个自造的全局 `Table`** 上（用户 2026-09-21 定）。挪是挪对了，但名字成了负担：`Table` 与 Lua 的 `table` 只差一个大小写，**读代码的人会以为它是标准库**，而它又不是 —— 于是要么继续纠结工具集该叫什么（`util` / `Table` / `list` / `工具`），要么承认「它就是对标准库的扩充」把名字直接定成 `table`。

用户 2026-09-21 定：**走后者** —— `table.filter(列表, 判定)` 语义自明，「扩充」这层意思写在名字里，也不用再为工具集单开一个全局。

挡路的是沙箱口径：白名单里的 `table` / `string` / `math` / `utf8` 现在**直接指向内核那几张表** ⇒ 内容侧一挂 `table.filter`，内核的标准库就被改了（跨局、跨重载、连测试与内核代码一起受影响）。

## What Changes

- **白名单里表值的项改成「内容侧的副本」**：`server/core/loader/init.lua` 的 `makeEnv` 里，`type(value) == 'table'` 的项**浅拷贝**一份再放进环境（一层，够用 —— 扩充都是往表上挂新函数）。于是内容侧改 `table` / `string` / `math` / `utf8` **只影响内容侧**，内核的标准库一点不动；**重装换新副本**（与共享环境同一生命周期）。**不做元表代理**（用户提案时以为要做，实测不必）。
- **`package/@tools/table.lua` 取代 `package/@tools/工具.lua` + `package/@tools/meta.lua`**（文件由用户改名/删除）：直接给内容侧的 `table` 加 `filter` / `map` / `contains`，**泛型标在实体函数上**（`---@generic T` + `function table.filter(…)`）—— 类型就写在赋值处，不再需要 `meta.lua`。
- **`package/标准/卡牌/杀.lua`** 的「获取目标」改用 `table.filter`。
- **用例**：`server/test/rule/init.lua` 里那两条工具集用例改成 `table.*`；**新增一条**「内容侧的标准库是副本，改了不影响内核」（内容侧加 `table.乱来`，断言内核侧仍是 `nil`）。
- **文档**：`architecture.md`（§9.6 白名单段 + 工具集段 + 泛型段 + 类型面段 + 示例）、`sanguosha-rules/SKILL.md`（§9.1 三条 + 示例）、`moe-kill-dev/SKILL.md`（`package/` 行）全部从 `Table` 口径改成「内容侧标准库的扩充」。

**明确不做**：不新增工具函数（要加先过「纯函数」这条线）；不给 `@tools` 加保护（覆盖了由那个包负全责 —— 与别的内容全局同口径）；`` `@tools` 的未来文件（`string.lua` / `math.lua`）**本批不建**，只把套路写清。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设 `skip_specs: true`）：契约由用例承担 —— `--test rule`（工具集两条 + 副本一条）。

## Impact

- 改动：`server/core/loader/init.lua`（`makeEnv` 浅拷贝）、`package/@tools/table.lua`（新，取代 `工具.lua`）、`package/标准/卡牌/杀.lua`（`table.filter`）、`server/test/rule/init.lua`（两条改写 + 一条新增）
- 删除：`package/@tools/工具.lua`、`package/@tools/meta.lua`（用户删的；类型改标在实体函数上）
- 文档：`architecture.md`、`sanguosha-rules/SKILL.md`、`moe-kill-dev/SKILL.md`
- **行为变化**：① 内容侧改标准库**不再影响内核**（这是本批的全部意义）；② 没装 `@tools` 的局**仍然有 `table`**，只是没有 `filter` / `map` / `contains`（上一批的代价是「没有 `Table` 这个全局」，这条比它轻）
- **推翻的历史决策**：`2026-09-19-package-surface` 明确「不做『增强标准库』（往注入的 `table` 上挂私货）—— 读包的人会误以为它是 Lua 自带的，将来把包挪到别的引擎也会踩坑」。本批反悔，理由见 `design.md` D1。
