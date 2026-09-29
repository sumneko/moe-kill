# Proposal

## Why

一条早被记为「还没做」的官方口径：**目标数量**（`sanguosha-rules` §9.2 的批次边界里就列着「目标数量（至多 / 至少 N 个）」）——「额外指定目标」类装备技能与多目标锦囊都要它，顺带把已有的「无目标开关」并成同一个概念。

| 现状 | 影响 |
| --- | --- |
| **【杀】没实现「至多一名目标」**：官方是「对你攻击范围内的一名角色使用」，而 `canUse` 只校验「给的目标是合法集合的非空子集」、不查个数 | 多目标【杀】现在随便用（`rule.slash` 的「多目标依次结算」就是靠这个超集行为跑的） |
| 「额外指定目标」类技能需要**放宽**数量上限的通道 | 纯否决式的 `'卡牌-能否使用'` 表达不了「放宽」（它只能拒绝、不能放行） |
| `noTarget()` 与「目标数量」是同一个概念的两半 | 装备的「不指定目标」就是「最少 0、最多 0」—— 拆成两个开关不如合成一份配置 |

口径（用户定）：**卡牌（与将来的技能）默认「最少 1、最多 1」**，定义时用一份配置改；上限用**数字**表示（事实不限就写 `1000`）；**最终上限 = min(定义上限 + Σ修正, 『获取目标』的返回值数量)**。

## What Changes

- **内核新增「目标数量」**：`CardDef:targetCount(min, max)`（两个数字必给；**不调用 = 默认 `1, 1`**；事实不限写 `1000`；`extends` 会抄）。校验只在**给了目标**时做：`min ≤ 个数 ≤ min(max + Σ修正, 合法目标数量)`，超出 ⇒ 明确失败、牌留在原处。
- **`noTarget()` / `isNoTarget()` 退役**：等价于 `targetCount(0, 0)` —— 给了目标即拒、零目标成立、不要求声明『获取目标』（判据从「非 noTarget」改成「上限 > 0」才收集合法目标）。
- **内核新增收集式触发**：`Event:collect` / `game:collect`（跑全部回调、收集非 nil 返回值；报错隔离与 `fire` 一致）——「快速返回」的 `fire` 收集不了多个修正（第一个说话者就截断了）。
- **内核新增时机 `'卡牌-目标数修正'`**（载荷 `{ user, card, targets }`，与 `'卡牌-能否使用'` 同形）：在**给了目标**的校验里收集；每个订阅者 MAY 返回一个整数增量（可正可负），内核**全部累加**到上限上（最终再与合法目标数量取较小值）。
- **【杀】不用声明**（默认 `1, 1` 正是它要的；**BREAKING**：多目标【杀】从「随便用」变为「要效果放宽才能用」—— `rule/slash` 原来靠它跑的多目标用例改成负例；逐目标机制本身由 `core.effect.play` 的探针用例继续覆盖）。
- **多目标锦囊补齐声明**（行为不变）：南蛮 / 万箭 / 五谷 / 桃园 `: targetCount(1, 1000)`；**装备模板**把 `noTarget()` 换成 `: targetCount(0, 0)`。其余单目标牌一律默认、不用动。
- 用例：`core.*`（目标数量 / 修正 / 收集原语 / `(0,0)`）、`rule/slash`（默认 1..1 ⇒ 多目标被拒）+ 各探针适配（多目标探针补声明、`noTarget()` 换写法）；文档同步（`architecture.md` / `infrastructure.md`（照搬件 `simple-event` 的改动记账）/ `progress.md` / `sanguosha-rules`）。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `core-play`: 新增「目标数量（最少 / 最多）与目标数修正」—— 默认 `1,1`、定义可改、收集式修正、超出即拒绝、`(0,0)` 即「无目标」。

## Impact

- `server/core/game.lua`（`CardDef:targetCount` + 删 `noTarget` + `canUse` 区间校验 + `game:collect`）、`server/core/event.lua`、`server/tools/simple-event.lua`（照搬件：加 `collect`，改动记账）、`server/core/loader/env-meta.lua`（时机声明与兜底签名）
- `package/标准/卡牌/{南蛮入侵,万箭齐发,五谷丰登,桃园结义}.lua`（声明上限）、`package/@基础/卡牌/装备牌.lua`（`(0,0)`）
- 用例：`server/test/core/{event,card-def,can-use}.lua`、`server/test/core/effect/{play,ask-use-card}.lua`（探针适配）、`server/test/rule/slash.lua`
- 文档：`moe-kill-dev` 的 `references/{architecture,infrastructure,progress}.md`、`sanguosha-rules` 的 §9.2 与 §9.11
- 行为：多目标【杀】由「默认可用」改为「默认被拒」（**BREAKING**；现存用法在测试里）；`noTarget` 的调用面（内容侧 1 处、内核 2 处判读、测试若干）全部换成 `(0, 0)`

## Non-goals

- **装备技能的落地**（含【方天画戟】的「最后手牌额外指定目标」—— 本批只备机制，它待专门规划）与其余 9 张（诸葛连弩 / 雌雄双股剑 / 青釭剑 / 青龙偃月刀 / 丈八蛇矛 / 贯石斧 / 麒麟弓 / 八卦阵 / 仁王盾）—— 各是一个功能点，依次推进。
- 更复杂的替换式效果（官方「额定摸牌数」那套里还有「改为 0 / 改为某值」式的作用）—— 本批只做「区间 + 增量」，要用时再开。
- 询问选项里带「至多几个」的协议表达（`ask.options` 不减 —— 留给会话 / 协议批次）。
