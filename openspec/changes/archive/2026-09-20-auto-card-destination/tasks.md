# Tasks

## 1. 内核：挪牌成效果（`server/core/move-card.lua` 新增）

- [x] 1.1 `MoveCard : Effect`（`kind` = `moveCard`，字段 `cards: Card[]` / `zones: string[]`）：`settle()` 先解析全部区名（有一个不属于这一局 ⇒ 失败）→ 校验每张牌都有归属 → 再沿路径逐站移动（整批校验在改状态之前）；验证：`--test core.game` 的挪牌用例全绿
- [x] 1.2 `MoveCard.API.create { game, cards, zones }`；`server/core/init.lua` 挂 `moe.moveCard`（顺序在 `core.effect` 之后）；`server/moe-kill.lua` 的 `moe` 注解补该字段
- [x] 1.3 `game:moveCard(card, zone)` 改成便利入口（造效果 + `:apply():await()`，标 `---@async`，返回效果实例；单张 / 一批、单个 / 一串区名的归一化留在这里）；`env-meta.lua` 若有用到该签名的声明则同步（上次已把非事件入口移出该文件，预期不动）

## 2. 内核：询问带缘由 + 答复时机

- [x] 2.1 `server/core/ask-card.lua`：`AskCard` 加 `reason`（不透明字符串，可为 `nil`）与创建参数；`settle()` 在 `fire('卡牌-询问', self)` 之后、返回结果之前触发 **`'卡牌-答复'`**（上下文 = 自己）；再加 `:respond()` —— 把这次给出的牌当作一次「打出」（转调 `game:respond(self.to, self.reply)`），**没给出牌时明确失败**
- [x] 2.2 `server/core/game.lua`：`game:askCard(被问者, reason, 要什么牌)`；`server/core/loader/env-meta.lua` 把 `'游戏-询问'` 的重载改名成 `'卡牌-询问'`，并补 `'卡牌-答复'`（上下文 = `AskCard`）
- [x] 2.4 全局把 `'游戏-询问'` 改名成 `'卡牌-询问'`（package / 测试 / 文档；归档目录里的历史记录不动）
- [x] 2.3 验证：`--test core.ask-card` 用例改为新签名后全绿

## 3. 内容：去向交给基础规则

- [x] 3.1 `package/@基础/牌堆.lua`：订阅 `'卡牌-答复'` —— `reason == '打出'` 且给出了牌 ⇒ `ctx:respond()`；`'卡牌-打出后'` 的订阅改成 `game:moveCard(ctx.card, { '处理', '弃牌' })`
- [x] 3.2 `package/标准/卡牌/杀.lua`：询问改为 `game:askCard(target, '打出', { name = '闪' })`，**删掉** `game:moveCard(...)`（业务层不再挪牌）
- [x] 3.3 验证：`--test rule.slash` 里「打出闪就不受伤、闪进弃牌」照旧通过，且【杀】里不再出现 `moveCard`

## 4. 测试

- [x] 4.1 `server/test/core/game.lua`：挪牌的失败断言从 `lt.assertError` 改成 `lt.assertFailed`（读效果的 `.err`）；补「挪牌在结算栈上、能被取消」「一次结算挪完一批」
- [x] 4.2 `server/test/core/ask-card.lua`：询问加缘由参数；补「结果与缘由挂在询问上」「答复后触发 `'卡牌-答复'`」「没有人应答时也触发」「把答复当作打出 / 没给出牌时不能当作打出」
- [x] 4.3 `server/test/rule/{slash,support}.lua`：应答脚本改用新签名（带 `'打出'`）；断言闪最终在 `弃牌` 且不再由测试/内容侧亲自挪牌
- [x] 4.4 全量 `server/bin/moe-kill.exe --test` 0 失败；问题面板 0（information 及以上）

## 5. 文档

- [x] 5.1 `moe-kill-dev/references/architecture.md` §12：机制表加 `MoveCard` 与 `game:moveCard`（效果、返效果实例）、`'卡牌-答复'` 时机、`askCard` 行补 `reason` 与 `:respond()`；示例删掉 `moveCard`；把上一批记的「【2026-09-20 记录，待做】」改成已落地（保留处理区停留点这条待定）
- [x] 5.2 `sanguosha-rules` §6 / §7 / §9.2：「要一张牌」改成带缘由；打出由基础规则按缘由自动完成（业务层不写 `moveCard`）；§9.2 示例同步

## 6. 验收

- [x] 6.1 `openspec validate auto-card-destination --strict` 与 `openspec validate --all --strict` 通过
- [x] 6.2 全量用例 0 失败、问题面板 0
- [x] 6.3 归档 `openspec archive auto-card-destination --yes`，确认主规格已按 delta 更新（`core-move` 挪牌成效果、`core-response` 的旧「询问」「回答者」已移除、`base-rules` 的自动去向），并检查归档后有无 `TBD` 的 Purpose 占位
