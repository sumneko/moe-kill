# Tasks

## 1. 内核：牌区可见性

- [x] 1.1 `server/core/zone.lua`：`Zone` 加 `---@field private visible boolean`（默认 `true`）与 `---@field private owner? Player`；新增 `M:bindOwner(player)`（记归属，只有玩家建区时用）、`M:setVisible(value)`、`M:isVisibleTo(viewer)`（`visible` 或 `owner == viewer`）；验证：`--test core.zone` 全绿
- [x] 1.2 `server/core/player.lua`：`addZone` 里把新建 / 传入的区 `bindOwner(self)`；验证：`--test core.player` 全绿
- [x] 1.3 `server/test/core/zone.lua` 补用例：默认对所有人可见；`setVisible(false)` 之后只有持有者看得见（别人 `false`、持有者 `true`）；没有归属的区配 `false` ⇒ 谁都不见；验证：`--test core.zone` 全绿

## 2. 内核：询问的候选可以是一批区域

- [x] 2.1 `server/core/effect/ask-card.lua`：`Condition` 加 `---@field zones? Zone[]`、`Answer` 加 `---@field zone? Zone`、`Option` 加 `---@field zone? Zone`；`collectOptions` 在给了 `zones` 时（可与 `cards` 同时给）产出区域选项并合并；`answerProblem` 支持按 `zone` 比对；`M.__getter.zone`（读 `.result.zone`）；验证：`--test core.effect.ask-card` 全绿
- [x] 2.2 `server/test/core/effect/ask-card.lua` 补用例：给了 `zones` ⇒ 选项是那几个区域；答复落在里面 ✓；答复不在里面 ⇒ 拒收（`.err` = 原因、`.zone` 不存在）；`cards` 与 `zones` 同给 ⇒ 两类选项都在；验证：同上

## 3. 内容侧：两个空区 + 两张牌

- [x] 3.1 `package/@基础/牌堆.lua`：`'游戏-开始'` 里给每名角色加 `装备` / `判定` 两个区，并把 `手牌` 标成 `setVisible(false)`；验证：`--test rule.base` / `--test rule.trick` 全绿
- [x] 3.2 `package/标准/卡牌/过河拆桥.lua`（新）：顶部写官方描述；`'获取目标'` = 其他**区域里有牌**的存活角色（局部 `hasCard`）；`'生效'` = 按可见性收集「明区逐张的牌」+「暗区整体」，一次 `game:askCard(user, '过河拆桥', { cards = …, zones = … })`，暗区随机 `game.random:pick`，最后 `game:moveCard(card, '弃牌')`；答不上就不动；验证：`--test rule.trick` 全绿
- [x] 3.3 `package/标准/卡牌/顺手牵羊.lua`（新）：顶部写官方描述；`'获取目标'` = 距离 1 以内、其他、区域里有牌；`'生效'` 同上挑一张，但 `game:moveCard(card, cardEffect.user:getZone('手牌'))`；验证：同上

## 4. 用例（规则侧）

- [x] 4.1 `server/test/rule/support.lua`：脚本化应答改成 `(Card|AskCard.Answer)[]`（直接给牌就是答复那张，给表就是整份答复 —— 于是也能答「区域」）；验证：既有套件全绿
- [x] 4.2 过河拆桥：目标只有手牌（暗区）⇒ 候选只有一个区、从那个区随机弃一张（进 `弃牌`）
- [x] 4.3 过河拆桥：目标 `装备` 区有一张明牌 ⇒ 使用者挑中它（它进 `弃牌`、手牌一张没动）
- [x] 4.4 过河拆桥：合法目标 = 「区域里有牌」的其他角色（身上一张牌都没有的不在列表里；不含自己）
- [x] 4.5 顺手牵羊：把目标装备区的明牌拿进**使用者**的 `手牌`；拿目标手牌时只能随机一张
- [x] 4.6 顺手牵羊：合法目标要同时满足「距离 ≤ 1」与「区域里有牌」（距离 2 的不算、相邻但身上没牌的不算）
- [x] 4.7 分类：把两张新牌并入既有的分类循环用例（`isKind('锦囊')` / `isKind('非延时锦囊')` / 分类列表 / 从 `手牌` 用）

## 5. 文档与验收

- [x] 5.1 `.agents/skills/sanguosha-rules/SKILL.md`：§9.10 补两张牌的官方原文与已实现口径（明区挑 / 暗区随机、区域候选、距离 1 以内、「不看牌的写法」）、§4 的牌分类表（已落地 8 张）与 §7 的「还没做」同步（普通锦囊只剩【借刀杀人】【无懈可击】）
- [x] 5.2 `.agents/skills/moe-kill-dev/references/architecture.md`：§1.1 补「可见性照一等字段落地」、`askCard` 行与「询问与应答方」补 `zones` / `.zone`、新增「牌区知道谁能看见」条、测试清单补 `rule.trick`；`.agents/skills/moe-kill-dev/references/progress.md`：内容包现状（8 张普通锦囊、玩家的三个区）与 §2 候选表
- [x] 5.3 验收：`server/bin/moe-kill.exe --test` 全量 **479 用例 0 失败**、问题面板 information 及以上 0；提交（`【AI】` 前缀）
