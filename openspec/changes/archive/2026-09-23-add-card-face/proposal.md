# Proposal

## Why

判定动作已经落地（`game:judge` 能翻出一张牌），但**翻出来的牌没有牌面**：

- 内核的 `Card` 只有 `id` + `label`（牌名）—— 花色与点数**无处可放**；判定「结果」现在是「那张牌」，可谁也没法解释它（【乐不思蜀】要判是不是红桃、【闪电】要判是不是黑桃 2~9、拼点要比点数大小）。
- `标准/牌表.lua` 也只有**每种牌的张数**（当初就写明「花色点数留到需要判定 / 拼点时再加」，见 `openspec/changes/archive/2026-09-19-add-base-rules/`）。
- 于是判定的第一个真正消费者（延时锦囊 / 八卦阵）没法开工 —— 它们要的正是一张牌的**花色与点数**。

现在做的理由：判定的动作层已经就位（翻牌 → 改判 → 收牌），牌面是它唯一的缺件；再往后拖，每个消费者都会各自想办法表达牌面（各写一张表），先把它落到牌自己身上最省事。

## What Changes

- **内核：`Card` 多两个字段 `suit` / `point`（花色 / 点数）**（用户 2026-09-23 定）
  - `moe.card.create(label, id, suit, point)` / `game:createCard(名字, 花色, 点数)`（后两个参数可选，老调用点不受影响）；读的时候**直接用字段**：`card.suit` / `card.point` —— **不另给 getter**（将来真有派生或换算需求再用 `__getter`，与 `desk.players` / `player.acting` 同一手法）。
  - **内核只存不解释**（与 `label` 同一性质）：不校验、不换算、不认识「红桃」也不认识 13 种点数；牌面由内容侧给。
  - 连带把 `server/test/core/card.lua` 里「内核不预设名称 / 花色 / 点数 / 效果」那条用例按新契约改写（那是旧口径，不是现在的事实）。
- **内容：`标准/牌表.lua` 从「每种牌的张数」改成逐张**（`{ name = '杀', suit = '黑桃', point = 7 }`，仍是 **102 张草稿**：延时锦囊还不在表里）；`@基础/牌堆.lua` 建牌时把牌面传下去。
- **取值口径**：花色用官方名 `'黑桃' / '红桃' / '梅花' / '方块'`；点数用数字 `1..13`（A=1 … K=13，便于判定区间与拼点比大小）。
- **明确不做**：颜色（红 / 黑）与拼点 API（都是派生或后续批次的事）、判定阶段的结算与延时锦囊、牌面的改写接口（建立时定下，只读）、牌面数据的官方核对（本批只管机制与结构）。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」，本变更在 `.openspec.yaml` 里设 `skip_specs: true`，契约以用例为准）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/card.lua`（`suit` / `point` 两个字段，构造函数多两个可选参数）、`server/core/game.lua`（`createCard` 追加两个可选参数）。
- 内容：`package/标准/牌表.lua`（改成逐张 102 行，带牌面）、`package/@基础/牌堆.lua`（建牌时传牌面）。
- 用例：`server/test/core/card.lua`（旧口径那条按新契约改写 + 牌面读写的用例）、`server/test/core/game.lua`（`createCard` 带牌面）、`server/test/rule/base.lua` / `setup.lua` / `turn.lua`（三处 `totalCards` 帮助函数从「按 `count` 求和」改成「数表长」，另加「每张牌都有合法花色与点数」的自检）。
- 文档：`.agents/skills/sanguosha-rules/SKILL.md`（牌面口径：花色四种 / 点数 1..13 / 颜色派生 / 判定与拼点怎么读）、`moe-kill-dev` 的 `references/architecture.md`（§12 的 `Card` 与 `game:createCard` 两行）、`references/progress.md`。
