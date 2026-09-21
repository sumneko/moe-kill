# Tasks

## 1. 内核：决策询问（`Ask`）

- [x] 1.1 `server/core/ask.lua`（新）：`Ask : Effect`（`kind` = `ask`，字段 `to` / `reason` / `question` / `reply`）：`:answer(答复)` 当场定下结果（先给出的算数，重复只记 `info`）；`settle()` 触发 `'决策-询问'`，有答复时再触发 `'决策-答复'`；门面 `moe.ask.create { game, to, reason, question }`
- [x] 1.2 `server/core/game.lua`：`game:ask(被问者, 缘由, 问题)`（`---@async`，自动「驱动 + 等」，返回询问实例）；`server/core/init.lua` 挂 `include 'core.ask'`
- [x] 1.3 `server/core/loader/env-meta.lua`：补 `'决策-询问'` / `'决策-答复'` 两个时机的 `on` / `fire`（上下文 = `Ask`）
- [x] 1.4 用例 `server/test/core/ask.lua`（新）：答复往返 / 没人应答不算失败（`reply` 为空）/ 重复应答先给出的算数 / 询问不动状态 / 有答复才触发「决策-答复」/ 取消 ⇒ 没有答复（实测：`reply` 必须是**读 task 结果的 getter** —— 答复会当场唤醒发起方，写在 `settle` 里的字段来不及被读到）

## 2. 内核：流程槽（`Flow`）

- [x] 2.1 `server/core/flow.lua`（新）：`Flow : Effect`（`kind` = `flow`，字段 `handler`），`settle()` 就是调这个 handler 并返回它的返回值；门面 `moe.flow.create { game, handler }`
- [x] 2.2 `server/core/game.lua`：`game:registerFlow(handler)`（只在加载期、每局只能登记一次）与 `game:runFlow()`（返回 `Flow` 效果：可 `await`、可 `remove` 停掉）；`resetContent()` 里清掉已登记的流程；`server/core/init.lua` 挂 `include 'core.flow'`
- [x] 2.3 用例 `server/test/rule/flow.lua`（新）：登记后启动能拿到返回值 / 挂起中 `remove()` 能停掉（以取消结束）/ 非加载期登记报错 / 没登记就启动报错 / 重装后流程消失

## 3. 内容：回合流程（`package/@基础/回合.lua`）

- [x] 3.1 阶段与时机：六个阶段依次走完，各触发 `'阶段-开始'` / `'阶段-结束'`（ctx = 回合角色 + 阶段名），整段被 `'回合-开始'` / `'回合-结束'`（ctx = 回合角色）包住
- [x] 3.2 摸牌：摸 2 张（`抽牌` → `手牌`）；不够时把 `弃牌` 洗混当新抽牌堆（用局上的随机源）。实测：**`game:moveCard` 只认局上的牌区**（按名字查 `game.zoneMap`），`手牌` 是玩家侧的 ⇒ 直接用 `hand:put(deck:takeTop())`（挪到玩家侧牌区的能力留给拆牌那批）
- [x] 3.3 出牌阶段：循环询问（缘由 `'出牌'`）—— 答复「用哪张牌 + 哪些目标」就 `game:useCard` 再问；答复为空就结束阶段
- [x] 3.4 弃牌阶段：手牌 > 当前体力时询问（缘由 `'弃牌'`）并把答复的牌挪进 `弃牌`；弃不够或没答复 ⇒ 明确报错
- [x] 3.5 回合推进：首回合主公（1 号位）→ 按行动顺序交给下一个**存活**角色；只剩一个存活角色时流程返回
- [x] 3.6 用例 `server/test/rule/turn.lua`（新）：首回合主公 / 六阶段顺序与时机 / 摸 2 张与抽空洗回 / 出牌（出一张【杀】并结算）/ 弃牌到体力值 / 阵亡者被跳过（控制器一律「先让出再答复」；跑够若干回合后 `flow:remove()` 停）

## 4. 文档

- [x] 4.1 `sanguosha-rules`：§3 补「已实现（2026-09-21）」块（六阶段 / 摸牌 2 张与洗回 / 出牌循环 / 弃牌到体力值 / 本批不做）与口径；§9.2 补「流程怎么被启动」、【杀】的「本批不做」里把「回合与阶段」换成「次数限制」；§10 把摸牌的随机源口径移到「已定」
- [x] 4.2 `moe-kill-dev/references/architecture.md`：§12 机制表补 `game:ask` / `game:registerFlow` / `game:runFlow` 三行，并补三条要点（流程怎么被启动、决策询问与「要一张牌」的分工、挪牌只能落局上牌区）
- [x] 4.3 `moe-kill-dev/references/code-style.md`：**不改** —— 答复形状（`{ card, targets }` / `{ cards }`）是由发起方解释的内容约定，写在规格与内容文件里就够，不进通用风格文档

## 5. 验收

- [x] 5.1 `openspec validate add-turn-flow --strict` 通过
- [x] 5.2 问题面板 information 及以上 = 0
- [x] 5.3 `server/bin/moe-kill.exe --test` 全绿：**322 用例 0 失败**（改前 303）
- [x] 5.4 无头跑一局：`game:runFlow()` 从主公开始、连跑若干回合（脚本化控制器）后手动停掉，全程无错误日志

## 6. 挪牌的落点（用户 2026-09-21 追加）

- [x] 6.1 `server/core/move-card.lua`：路径上的一站 SHALL 可以是**牌区对象**（直接用）或**名字**（先在 `game.turnPlayer` 身上找，再找局上）—— 新增 `resolveStop`；`MoveCard.CreateOptions.zones` / `__init` 的类型改成 `(string|Zone)[]`
- [x] 6.2 `server/core/game.lua`：`moveCard(card, zone)` 的 `zone` 支持 `string|string[]|Zone|Zone[]`（单/串用 `Type(zone) == nil` 判）；新增公开字段 `turnPlayer`（由流程维护、`resetContent` 清空），并在类注解里写明"挪牌按名字找区时先找它身上"
- [x] 6.3 `package/@基础/回合.lua`：回合开始时写 `game.turnPlayer`、回合结束时清空
- [x] 6.4 用例 `server/test/core/game.lua`：直接传牌区对象 / 名字先找当前回合角色（局上有同名区也不改它）/ 只有玩家身上有的区名也能落 / 没有回合角色时落回局上 / 两边都没有 ⇒ 失败且不改状态
- [x] 6.5 规格：`core-move` 的「把牌挪进某个牌区」新增 delta（名字解析顺序 + 牌区对象）；`architecture.md` §12 的 `game:moveCard` 行与「挪牌的落点限制」要点同步
- [x] 6.6 「全走 moveCard」（用户 2026-09-21 追加）：`package/@基础/回合.lua` 的摸牌与 `牌堆.lua` 的建牌堆都改成 `game:moveCard(一批牌, 目标)`（摸牌传玩家身上的 `手牌` 对象、建牌堆传 `抽牌`），内容侧不再出现 `Zone:put`；`turn-flow` 的摸牌要求同步写明「内容侧 MUST NOT 自己往牌区里塞牌」
