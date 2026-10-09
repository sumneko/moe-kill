# Tasks

## 1. 内核：并进 `AskPlayCard`

- [x] 1.1 `server/core/effect/ask-play-card.lua`：加 `settle()` —— 带 `responseTo` 时「没答上 ⇒ `reject('没有打出')`」「答复到手且没被驳回 ⇒ 发 `'效果-被响应'` + `'效果-来源-被响应'`」；不带 `responseTo` 照旧（空答复、不发时机）
- [x] 1.2 删 `server/core/effect/ask-offset-card.lua`（含 `moe.askOffsetCard` 门面）与 `core/effect/init.lua` 里那行 `include`
- [x] 1.3 `server/core/game.lua`：删 `game:askOffsetCard`；`askPlayCard` 的说明补「一次响应」语义

## 2. 内核：事件改名

- [x] 2.1 `server/core/loader/env-meta.lua`：`'效果-被抵消'` → `'效果-被响应'`、`'效果-来源-被抵消'` → `'效果-来源-被响应'`（`CardDef` / `SkillDef` / `Game` / `Player` 四处订阅面 + 载荷类型 `AskOffsetCard` → `AskPlayCard`）
- [x] 2.2 询问族联合类型去掉 `AskOffsetCard`

## 3. 内容

- [x] 3.1 `package/标准/卡牌/杀.lua`：`game:askOffsetCard(…)` → `game:askPlayCard(…)`（仍读 `.success`）
- [x] 3.2 `package/标准/卡牌/青龙偃月刀.lua` / `贯石斧.lua`：订 `'效果-来源-被响应'`（判据不变；顶部官方牌面照抄不动）

## 4. 用例

- [x] 4.1 `server/test/core/effect/ask-offset-card.lua` **9 条**并进 `ask-play-card.lua`：用例名「抵消：…」→「响应：…」、措辞改「响应」、`askOffsetCard` → `askPlayCard(…, { responseTo = … })`（没答上那条要带 `responseTo` 才拒收）、**新增一条**「答复之后被驳回 ⇒ 不发时机」；删原文件（连带 `server/test.lua` 里那行 `test.require`）
- [x] 4.2 `equip.lua` / `hero-skill.lua` / `slash.lua`：应答脚本里 `ask.kind == 'askOffsetCard'` → 按 `ask.reason == '杀'` 筛；`slash.lua` 那条事件名用例改名；`hero-skill.lua` 护驾那条改成「只有【杀】那一次 `askPlayCard`」；龙胆 / 倾国 / 铁骑 / 仁王盾的用例名与断言措辞改「响应」
- [x] 4.3 `ask-use-card-to-card.lua` / `use-card-to-card.lua`：夹具牌名 `'抵消牌'` → `'可用牌'`；`hero-skill.lua` / `equip.lua` 里我们自己的「抵消」措辞改「响应 / 挡下」

## 5. 收尾

- [x] 5.1 `server/bin/moe-kill.exe --test` 全绿（**1044 → 1045**）
- [x] 5.2 问题面板 information 及以上 0
- [x] 5.3 反向验证（实测三条）：去掉 reject ⇒ **58 条红**；无条件发时机 ⇒ **1 条红**（用例已补强成「有答复也算不上响应」）；去掉来源段 ⇒ **9 条红**；另实测 `and self.success` **不可达**（0 红）⇒ 已删，见 design D1/D6

## 6. 文档

- [x] 6.1 `moe-kill-dev/references/architecture.md`：`askPlayCard` 行补响应语义、删 `askOffsetCard` 行、`'效果-被响应'` 两处行、`AskCard.ResponseOptions` 那行
- [x] 6.2 `sanguosha-rules` §7 / §9.2 / §9.10：引擎措辞改「响应」，官方引文保留
- [x] 6.3 `moe-kill-dev/references/progress.md`：基线、本批条目

