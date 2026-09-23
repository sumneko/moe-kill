# Design

## Context

- **`Card` 现在的形状**：`---@field private id integer` / `---@field private label? any` / `---@field private zone? Zone` —— 读用 `getId()` / `getLabel()`，改只有一个 `setLabel()`；`moe.card.create(label, id)`，`game:createCard(name)` 负责发号。
- **既有口径与它的用例**：`AGENTS.md` 与归档规格写着「**内核不预设牌的定义内容（名称 / 花色 / 点数 / 效果）**」，`server/test/core/card.lua` 有一条用例钉着它（遍历 `pairs(card)` 断言只有 `id,label`，并逐项断言没有 `'花色'` / `'点数'` / `'效果'` 字段）。
- **牌表**：`标准/牌表.lua` 是 `{ name = '杀', count = 30 }` 这种「每种牌的张数」，共 102 张（缺延时锦囊【乐不思蜀】【闪电】，那是后续批次）；有 3 处**测试帮助函数**按 `entry.count` 求和算总张数（`server/test/rule/base.lua` / `setup.lua` / `turn.lua`）。
- **判定的现状**：`game:judge` 的「结果」是那张判定牌（`judge.card`），但**没人能解释它**（没有花色点数）。

## Goals / Non-Goals

**Goals:**

- 牌自己带着**花色与点数**（内核只存不解释，与 `label` 同一性质），判定 / 拼点 / 将来的技能都能直接读。
- 牌表按**逐张**给出牌面（真实牌堆本来就是逐张的：同名的 30 张【杀】各有各的花色点数）。
- 老调用点与老用例尽量少动：`game:createCard(名字)` 照旧可用（牌面是可选参数）。

**Non-Goals:**

- 颜色（红 / 黑）与拼点 API —— 颜色是花色的派生（内容侧一个映射就够），拼点是另一个功能点。
- 判定阶段的结算、延时锦囊、判定区（另开变更）。
- 牌面的改写接口（`setSuit` / `setPoint`）：牌面在建牌时定下，真要「改判牌面」类的效果再单独提。
- **官方牌表数据的核对**：本批交付机制与结构；`标准/牌表.lua` 的牌面与张数一样是**草稿**（文件顶部继续标待核对，用例只断结构性事实，不断言官方牌面）。

## Decisions

### D1 牌面做成 `Card` 的两个字段，**读的时候直接用字段**（用户 2026-09-23 定）

```lua
---@class Card
---@field private id integer
---@field private label? any
---@field suit? string # 花色（内容给的值，内核不解释：黑桃 / 红桃 / 梅花 / 方块）
---@field point? integer # 点数（1..13）
---@field private zone? Zone
```

- **不加 getter**：牌面是**数据**，不是派生属性 —— `card.suit` / `card.point` 直接读最省事。将来真出现「需要换算或派生」的读法（如颜色、官方记法的点数），再按项目既有手法用 **`__getter`**（参考 `desk.players` / `desk.alivePlayers` / `player.acting`）——对外仍是 `card.xxx`，调用点不用改。这条已写成项目规则：`moe-kill-dev` 的 `references/code-style.md` 第 11 节（用户 2026-09-23 定）。
- **也不加 setter**（见 Non-Goals）：牌面在建牌时定下；真要有「改判牌面」类的效果再单独提。
- **为什么不做通用数据袋**（备选，否）：判定 / 拼点 / 技能的读牌面会很频繁，做成字段比 `card:getParam('点数')` 直接；牌面也是**每张牌都有**的东西，不是某类区域才有的附加数据 —— 这与 `Zone` 的 params 分工不同。
- **口径变化**（明确记账）：原来那句「内核不预设名称 / 花色 / 点数 / 效果」要改成「**内核不解释牌名与牌面**，只搬运内容给的取值」—— `label` 早就是这个性质（牌名也是内容给的），花色与点数只是同一性质的第二、第三个字段。相应地：
  - `server/test/core/card.lua` 那条用例改成断言**新形状**：没传牌面时**表里就没有 `suit` / `point` 两个键**（`pairs` 仍只有 `id,label`），传了则多两个键；仍然没有 `'名称'` / `'效果'` 这类字段；
  - `AGENTS.md` / 归档规格里的旧措辞不动（归档是历史），新措辞写进 `sanguosha-rules` 与 `architecture.md`（本题材的现状）。

### D2 取值口径：花色用官方名词，点数用 1..13

- 花色：`'黑桃' / '红桃' / '梅花' / '方块'` —— **数据取值用中文**是项目既有口径（`'杀'` / `'主公'` / `'体力'` 都这样）。
- 点数：**数字 `1..13`**（A=1 … K=13）。理由：判定要判区间（如「黑桃 2~9」）、拼点要比大小，数字最省事；官方记法（A / J / Q / K）只是展示层的事。
- **颜色不存**：红 / 黑由花色推得（内容侧将来一个映射就行），存两份会有一致性负担。

### D3 `game:createCard(name, suit, point)` 追加两个可选参数

```lua
---@param name string
---@param suit? string # 花色（内容侧给，内核不解释）
---@param point? integer # 点数（1..13）
---@return Card
function M:createCard(name, suit, point) ... end
```

- 可选 ⇒ 老调用点（用例、`牌堆.lua` 之外的地方）一行不改。
- 与 `Card:__init` / `moe.card.create(label, id, suit, point)` 一条线传下去（号仍然由局发）—— 字段在构造里一次性定下，后续只读（不改写接口）。

### D4 牌表改成逐张，牌面是草稿

```lua
game:setValue('牌表', {
    { name = '杀', suit = '黑桃', point = 7 },
    ...
})
```

- 逐张才装得下真实的牌堆（同名多张各有牌面）；`@基础/牌堆.lua` 的建牌循环从「按 count 重复」变成「一条一张」：
  ```lua
  for _, entry in ipairs(cardTable) do
      cards[#cards + 1] = game:createCard(entry.name, entry.suit, entry.point)
  end
  ```
- **张数构成不变**（仍是现有草稿的 102 张：杀 30 / 闪 15 / 桃 8 / 锦囊 31 / 装备 18），只是补上牌面 ⇒ 既有「张数与构成」用例（杀 30 张、闪 15 张…）继续有效。
- **牌面取值是草稿**：本批只保证结构与机制，用例**不断言**某张【杀】具体是黑桃 7 还是梅花 3（那种断言把「数据核对」和「机制验收」绑在一起，核对一改就红一片）。核对列为该文件上的遗留事项（与「张数待核对」同一状态）。

### D5 与判定的衔接

判定不用改一行：`judge.card` 现在带着牌面，调用方 `judge.card.suit` / `judge.card.point` 就能结算【乐不思蜀】【闪电】【八卦阵】（那些是下一批的事）。
