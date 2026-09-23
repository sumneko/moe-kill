# Tasks

## 1. 内核：`AskCard` 加一个可覆写钩子

- [x] `settle()` 里在触发 `'卡牌-答复'` 之前调 `self:onAnswered()`（`---@async`，基类空实现）
- [x] `answer()` / 校验 / 候选筛选逻辑不动（打出与选择的形状本就一样）

## 2. 内核：`AskPlayCard`

- [x] 新增 `server/core/effect/ask-play-card.lua`（`AskPlayCard : AskCard`，`kind` = `'askPlayCard'`）
- [x] `onAnswered()`：`game:moveCard(答复的牌, self.parent:getTempZone())`；没有父结算就不动
- [x] `moe.askPlayCard.create(...)`；`core/effect/init.lua` 装载它
- [x] `game:askPlayCard(被问者, 缘由, 条件?)`（`---@async`，返回询问实例）
- [x] `env-meta.lua`：三个时机载荷类型改成 `AskCard|AskUseCard|AskPlayCard`

## 3. 内容侧：四张牌改用 `askPlayCard`，缘由换成发起者名字

- [x] `package/标准/卡牌/杀.lua`：`game:askPlayCard(target, '杀', { name = '闪' })`
- [x] `package/标准/卡牌/万箭齐发.lua`：`'万箭齐发'` + `{ name = '闪' }`
- [x] `package/标准/卡牌/南蛮入侵.lua`：`'南蛮入侵'` + `{ name = '杀' }`
- [x] `package/标准/卡牌/决斗.lua`：`'决斗'` + `{ name = '杀' }`
- [x] 删掉 `package/@基础/打出.lua`（用户已同意；职责移交 `AskPlayCard`）

## 4. 用例

- [x] 新增 `server/test/core/effect/ask-play-card.lua`（4 条：进父结算临时区 + 收尾进弃牌 / 无父结算不动 / 条件筛候选且拒收目标 / 答复不在候选里就拒收且牌不动）
- [x] `server/test/core/effect/ask-card.lua`：两条 `'打出'` 用例换成「`AskCard` 自己不处置那张牌」
- [x] `server/test.lua` 注册新套件
- [x] `server/bin/moe-kill.exe --test` 全绿（486 个用例）

## 5. 文档与验收

- [x] `moe-kill-dev`：`references/architecture.md`（§12 表格与"解答方"段落、`onAnswered`、打出口径、临时区回顾条目、测试清单）、`references/progress.md`、`references/infrastructure.md`、`references/code-style.md`、`SKILL.md`
- [x] `sanguosha-rules`：§6 已实现现状、§7 缘由与去向、§9.2【杀】示例、§9.10【南蛮入侵】/【决斗】
- [x] 问题面板清到 0（information 及以上）
- [x] `openspec validate add-ask-play-card --strict` 通过；提交并归档
