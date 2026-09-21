# Proposal

## Why

体力降到 0 以下现在**没有任何后果**：`package/` 里没有一处调 `setAlive(false)`，伤害可以把人打到 -5 还照常摸牌出牌，于是回合流程的结束条件（「只剩一个存活角色」）永远不成立 —— **一局打不完**。濒死是把这条链接起来的那一环。

## What Changes

**内核（`server/core/`）**

- 新增 `Dying` 效果（`dying.lua`，`kind` = `dying`）：持**局**与**濒死者**，外加一个「哪个属性是生命值」的参数（内核不预设属性名，与区域名同理）。`settle()` = 触发 `'濒死'` 时机（规则侧在这里求桃）→ 返回后判**体力 ≥ 1**：不够就 `player:setAlive(false)`（触发既有的 `'玩家-死亡'`）。
- 新增**起濒死的入口** `game:enterDying(player, attribute)`：它只**记账**，真正的濒死结算等**当前这次效果结算收尾**时统一开始 —— 于是「受到伤害后」这类时机（郭嘉遗计 / 曹操奸雄）先跑完，濒死紧随其后。已经不在任何效果里时（例如工具 / 测试直接改属性）当场开始。
- 新增**回复入口** `Heal : Effect`（`heal.lua`，`kind` = `heal`）+ `game:heal(player, amount)`：与 `game:damage` 对称，供【桃】与将来一切回血用。

**规则包（`package/`）**

- 新增 `@基础/濒死.lua`：订阅每个玩家的 `体力` 变化（`attrs:onChange`），**从 >0 跨到 ≤0** 时 `game:enterDying(player, '体力')`；订阅 `'濒死'` 时机，**从濒死者开始按行动顺序**问一圈要不要给桃（`askCard` + `useCard`），体力回到 ≥1 就停。
- 新增 `标准/卡牌/桃.lua`：【桃】两种用法 —— 出牌阶段对**已受伤的自己**、濒死时对**处于濒死的角色**；『生效』= `game:heal(目标, 1)`。

**明确不做**（各自另开变更）：死亡奖惩与胜负判定、武将技能（遗计 / 奸雄）、判定与装备、濒死中的连锁（同一玩家在濒死结算里再次掉血）不做特殊处理（自然嵌套）、「离开濒死」的独立时机（规则侧读体力即可）。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（见 `.openspec.yaml` 的 `skip_specs: true`）：这里的契约由**用例**承担 —— `--test core.dying` / `core.heal` / `rule.dying`，以及既有的 `--test rule.slash` 等。

## Impact

- **新增**：`server/core/dying.lua`、`server/core/heal.lua`、`package/@基础/濒死.lua`、`package/标准/卡牌/桃.lua`
- **改动**：`server/core/game.lua`（`enterDying` / `heal` / 结算收尾时处理待办）、`server/core/effect.lua`（结算收尾挂一次检查）、`server/core/init.lua`（挂 `moe.dying` / `moe.heal`）、`server/core/loader/env-meta.lua`（`'濒死'` 时机的上下文类型）、`server/test.lua`（登记新套件）
- **不改**：回合流程、用牌 / 伤害 / 挪牌 / 询问这些既有机制（濒死挂在它们的收尾点上，不改它们的形状）
- 影响面：从这一批起，一局**可以真的死人**，于是「只剩一个存活角色」真的会出现 —— 胜负判定仍留给下一批（现在流程会直接返回）
