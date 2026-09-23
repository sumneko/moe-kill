# Tasks

## 1. 内核：牌自己的两个钩子

- [x] 1.1 `server/core/loader/env-meta.lua`：`CardDef.on` 加 `'结算前'` / `'结算后'` 两条重载（ctx = `UseCard`）；验证：问题面板 information 及以上 0
- [x] 1.2 `server/core/effect/use-card.lua`：`UseCard:settle()` 在逐目标之前跑一次 `def:getHandlers('结算前')`、全部生效之后跑一次 `'结算后'`（都夹在全局 `'卡牌-结算前'` / `'卡牌-结算后'` 内侧）；验证：`--test core.effect.play` 新增一条「结算前 → 逐个生效 → 结算后」顺序用例

## 2. 内核：询问的候选来源 + 效果标签袋

- [x] 2.1 `server/core/effect/ask-card.lua`：`AskCard.Condition` 加 `cards?: Card[]` —— 给了就以这批牌为候选（复用 `optionOf` 的 name / targets 语义），不再遍历被问者的牌区；验证：`--test core.effect.ask-card` 新增两条（给的那批算数 / 手牌里的不算数、拒收记 `.err`）
- [x] 2.2 `server/core/effect/init.lua`：`Effect` 加标签袋（`setTag` / `getTag` / `removeTag`，与 `Phase` / `Player` 同形）；验证：`--test core.effect` 新增一条（读写 + 移除 + 空键报错）

## 3. 内容侧：【五谷丰登】

- [x] 3.1 `package/标准/卡牌/五谷丰登.lua`（新）：顶部写官方描述；`extends '锦囊牌'`；`'获取目标'` 给 `game.desk.alivePlayers`；`'结算前'` 亮出 `game:getZone('抽牌'):draw(#ctx.targets)` 并 `ctx:setTag('剩余', …)`；`'生效'` 里 `game:askCard(ctx.target, '五谷丰登', { cards = 剩余 })` ⇒ `game:moveCard(选中, 目标的手牌区对象)`；`'结算后'` 把剩余 `moveCard(…, '弃牌')`；不声明 `limit`；验证：`--test rule.trick` 全绿

## 4. 规则侧用例（`server/test/rule/trick.lua`）

- [x] 4.1 亮出张数 = 目标数（抽牌堆相应减少）、老少各拿一张进手牌、剩余为空时弃牌里只有那张用过的锦囊
- [x] 4.2 没人答的那一轮不获得（剩下的一起进 `弃牌`）
- [x] 4.3 顺序：使用者在 1 号位 ⇒ 被问顺序 `1,2,3,4`；使用者在 3 号位而锚点在 1 号位 ⇒ 被问顺序 `1,2,3`（起点是锚点，不是使用者）
- [x] 4.4 分类：把【五谷丰登】并入既有的分类循环用例

## 5. 文档与验收

- [x] 5.1 `.agents/skills/sanguosha-rules/SKILL.md`：§9.10 补【五谷丰登】的官方原文与实现口径（亮牌时机、剩余进弃牌、拿牌用目标自己的牌区）、§4 分类表与 §7 的「还没做」同步（剩 4 张）
- [x] 5.2 `.agents/skills/moe-kill-dev/references/{architecture,progress}.md`：牌钩子清单（加 `'结算前'` / `'结算后'`）、`AskCard.Condition` 的 `cards`、`Effect` 标签袋、内容包现状（6 张锦囊）、候选表
- [x] 5.3 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）
