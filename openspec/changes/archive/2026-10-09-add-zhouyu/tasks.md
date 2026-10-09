# Tasks

## 1. 内核：可见性收成一个模块

- [x] 1.1 `server/core/visibility.lua`（新）：类型别名 `Visibility`（`boolean|Player|Player[]|fun(player): boolean`）+ `moe.visibility.normalize(值)` + `moe.visibility.isVisibleTo(值, 视角)`
- [x] 1.2 `server/core/init.lua`：`include 'core.visibility'`（排在 `core.zone` 之前）
- [x] 1.3 `server/core/zone.lua`：`Zone.visible` 字段类型收成 `Visibility`；`setVisible` / `isVisibleTo` 转调模块（行为不变）

## 2. 内核：搬动的可见性

- [x] 2.1 `server/core/zone.lua`：`Zone.Move` 加 `visible?`；`takeIn(cards, visible?)` / `accept(cards, visible?)` 记下来；两个 `notify*` 各多一参并转发给牌自己那份与区主人那份
- [x] 2.2 `server/core/effect/move-card.lua`：`CreateOptions.visible?` + 字段 + `__init` + `create` 传参；`settle` 里 `stop:accept(self.cards, self.visible)`
- [x] 2.3 `server/core/game.lua`：`game:moveCard(牌, 区, 可见性?)`（含 `runMoveCard` 内部函数）—— 默认不给 = 读的人按「源区可见 or 目标区可见」算

## 3. 类型面

- [x] 3.1 `server/core/loader/env-meta.lua`：`CardDef` / `SkillDef` / `Player` 三块的「卡牌-进入区域 / 卡牌-离开区域」载荷加 `visible?: Visibility`
- [x] 3.2 `AskChoice` 签名收窄（用户 2026-10-09 要求）：`options` 从 `any[]` 收成 **`string[]`**、结果字段声明成 **`result? string`**（`.choice` 保留为语义化读法；`game:askChoice` 的入口注解与 `checkAnswer` 参数同步）

## 4. 内容：周瑜

- [x] 4.1 `package/标准/武将/周瑜.lua`（新）：吴 · 男 · 体力上限 3；【英姿】= `auto(true)` + `'阶段-开始'`（摸牌）+ `tryCast` 里 `phase:bindGC(addAttr('摸牌数', 1))`
- [x] 4.2 同文件【反间】：`limit('出牌', 1)` + 一张手牌 + 其他角色；`askChoice` 选花色（`'${红桃}'` 格式）⇒ `game:moveCard(牌, 目标手牌, true)` ⇒ 花色不同就 `game:damage(cast.from, target, 1, 牌)`；**不选 = 总是算不同**

## 5. 用例

- [x] 5.1 `server/test/core/zone.lua`：可见性也收谓词（逐人现算）
- [x] 5.2 `server/test/core/zone.lua`：搬牌时给的可见性原样交给事件第三参（不给就是空）
- [x] 5.3 `server/test/rule/hero-skill.lua`：【英姿】2 条（默认不问摸三张 / 关掉自动同意会问且答否只摸两张）
- [x] 5.4 `server/test/rule/hero-skill.lua`：【反间】4 条（花色不同挨 1 点且牌照给 / 花色选对不挨伤害 / **不答复也算不同** / 候选只有其他角色 + 限一次）
- [x] 5.5 反向验证：改坏三处（英姿 `+1`、反间「不答复算不同」、`accept` 丢第三参）⇒ 恰好三条红；改回后全绿

## 6. 文档

- [x] 6.1 `sanguosha-rules`：§9.2 区域事件载荷补第三参；新增 §9.28 周瑜（含两个口径：花色格式与「不选算不同」）
- [x] 6.2 `moe-kill-dev/references/architecture.md`：可见性拆成「区级 / 搬动级」两条（含「牌级朝向还没有」那条）+ `game:moveCard` 行补第三参 + 区域事件载荷补第三参
- [x] 6.3 `moe-kill-dev/references/progress.md`：基线 1005、21 将、成本表周瑜行、缺口表补「牌级可见性」一行、§1 本批条目

## 7. 收尾

- [x] 7.1 `server/bin/moe-kill.exe --test` 全绿（1005 用例 0 失败）
- [x] 7.2 问题面板 information 及以上 0
