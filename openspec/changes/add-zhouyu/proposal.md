# Proposal

## Why

标准包余下 5 将里，周瑜是**只差一条可见性边界**的一个：

- **【英姿】零新机制** —— 「摸牌数」属性 + `phase:bindGC` 是 2026-10-09 那批产出的（【裸衣】已用），这里只是 `+1`。
- **【反间】的「正面朝上获得」** —— 官方「展示 / 朝向」还没落地，但这条**不需要**牌的朝向：它是「**这张牌被公开地交出去**」这件事 ⇒ 需要的是「**移动过程**的可见性」。区级可见性（`Zone.visible`）已经在了，缺的是「这次搬动对谁可见」这一维。

## What Changes

- **内核：可见性收成一个模块**（`server/core/visibility.lua`，门面 `moe.visibility`）
  - 类型别名 **`Visibility` = `boolean|Player|Player[]|fun(player: Player): boolean`**（比区级那套**多一个谓词形态**，逐人现算）
  - `moe.visibility.normalize(值)`（单值包成一批，其余原样）+ `moe.visibility.isVisibleTo(值, 视角)`
  - `Zone:setVisible` / `Zone:isVisibleTo` 转调它 ⇒ 判定只此一处（行为不变）
- **内核：搬动的可见性**（与区的可见性**正交**）
  - `Zone:accept(牌, 可见性?)` → 每条 `Zone.Move` 带 `visible?` → 作为**第三参**交给「卡牌-离开区域」/「卡牌-进入区域」的订阅者（`(card, zone, visible?)`）
  - `game:moveCard(牌, 区, 可见性?)` / `MoveCard` 效果的字段一路传下来
  - **不给就是空**：读的人自己按「源区可见 or 目标区可见」算 —— 「可见」是相对视角的，存不了单一值
- **类型面**（`server/core/loader/env-meta.lua`）：`CardDef` / `SkillDef` / `Player` 三块的两条区域事件载荷加 `visible?`
- **内容：新武将 `package/标准/武将/周瑜.lua`**（吴 · 男 · 体力上限 3）
  - **【英姿】** = `auto(true)` + `event('阶段-开始')`（摸牌）+ `tryCast` 里 `phase:bindGC(owner:addAttr('摸牌数', 1))` —— 与【裸衣】逐字同款
  - **【反间】** = `limit('出牌', 1)` + `cards { zone = '手牌', min = 1, max = 1 }` + `targets { filter = 其他角色 }`；`'使用'` 里 `askChoice(target, '反间', { '${红桃}', '${方块}', '${黑桃}', '${梅花}' })` → `game:moveCard(牌, target:getZone('手牌'), true)` → 花色不同 ⇒ `game:damage(cast.from, target, 1, 牌)`
  - **不选 = 总是算「花色不同」**（用户定：「不能作废，否则相当于对方逃避技能效果」；**没有「无色」这个选项**）
  - **花色选项格式 `${红桃}`**：内容侧拼、协议层认，**内核不解释**；判定用同一格式拼期望串 ⇒ 不需要解析

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改。（⚠️「可见性参数的形状」与「区域事件带搬动可见性」是**对外契约**：协议层要读 —— 已同步进 `architecture.md` 与 `sanguosha-rules` §9.2。）

## Impact

- **内核**：`server/core/visibility.lua`（新）、`server/core/zone.lua`（转调 + `accept` / `takeIn` / `Zone.Move` / 两个 `notify*` 带可见性）、`server/core/effect/move-card.lua`、`server/core/game.lua`（`moveCard` 第三参）、`server/core/loader/env-meta.lua`（类型面）、`server/core/init.lua`（挂新模块）
- **内容侧**：`package/标准/武将/周瑜.lua`（新）
- **用例**：`server/test/core/zone.lua`（+2）、`server/test/rule/hero-skill.lua`（+6）
- **文档**：`sanguosha-rules`（§9.2 载荷补第三参、新增 §9.28 周瑜）、`moe-kill-dev/references/architecture.md`（可见性分成「区 / 搬动」两层 + `moveCard` 行）、`progress.md`（基线 / 21 将 / 缺口表补「牌级可见性」一行）
- **明确不做**：**牌级可见性**（`Card:setVisible` / 牌上的朝向状态）—— 用户 2026-10-09 定「card 目前用不到 setVisible，先不做」；真要做先定「牌级可见性是**牌的状态**还是**它在当前区里**的状态」，留给协议层那批
