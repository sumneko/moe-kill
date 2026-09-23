# Tasks

## 1. 内容侧：锦囊模板 + 第一张锦囊

- [x] 1.1 `package/@基础/锦囊牌.lua`（新，模板）：`Card '锦囊牌' : kind { '锦囊', '非延时锦囊' } : zone '手牌'`（与 `基本牌.lua` 同形；不在牌表里、不会被造出来）；验证：`--test rule.trick` 能继承到分类与牌区
- [x] 1.2 `package/标准/卡牌/无中生有.lua`（新）：顶部写官方描述；`Card '无中生有' : extends '锦囊牌'`；`'获取目标'` 返回 `{ ctx.user }`；`'生效'` 里 `game:draw(ctx.target, 2)`；**不声明 `limit`**；验证：`--test rule.trick` 全绿

## 2. 用例

- [x] 2.1 `server/test/rule/trick.lua`（新，装 `标准`）+ 在 `server/test.lua` 里注册：① **用出去就摸两张**（手牌那张锦囊用掉 + 摸 2 张 ⇒ 手牌净 +1、抽牌堆 -2、牌进了 `弃牌`）；② **只能以自己为目标**（`canUse(user, card, { 别人 })` 失败、`canUse(user, card, { user })` 通过）；③ **分类两类都在**（`isKind('锦囊')` / `isKind('非延时锦囊')`）；验证：`--test rule.trick` 全绿

## 3. 文档与验收

- [x] 3.1 `.agents/skills/sanguosha-rules/SKILL.md`：新增「锦囊（普通 / 非延时）」小节 —— 形状（模型 = 一张牌 + 获取目标 + 生效，与基本牌共用同一套用牌链）、模板与写法、【无中生有】已落地；§4 的牌分类表与 §7 的「还没做」同步
- [x] 3.2 `moe-kill-dev/references/progress.md`：内容包现状（可用的牌：杀 / 闪 / 桃 + 第一张锦囊【无中生有】）、§2 候选表（「即时锦囊 + 无懈可击」那条改成「其它 9 种普通锦囊 / 无懈可击」）
- [x] 3.3 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）
