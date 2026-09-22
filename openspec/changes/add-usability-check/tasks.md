## 1 内核：校验机制（事件的快速返回 + `game:canUse`）
- [x] 1.1 `server/tools/simple-event.lua`（**照搬件改动，已获用户同意**）：`SimpleEvent:fire` 用 `table.pack(xpcall(callback, self.onError, ...))` 收返回值；`pack[1]` 为真（没报错）且 `pack[2] ~= nil` ⇒ 立刻 `return table.unpack(pack, 2, pack.n)`、后面的回调不再调用；一圈都没返回值 ⇒ 返回空
- [x] 1.2 `server/core/event.lua`：`M:fire` 把 `instance:fire(...)` 的结果透传给调用方（**只取第一个返回值** —— 约定就是「返回值即原因」，多返回值的透传会跟 `---@return any` 的声明打架）
- [x] 1.3 审一遍现有回调有没有「意外返回值」（有就会静默短路后面的回调）：`package/**` 全部核过 —— `@基础/抽牌.lua` 的 `return true/false` 在局部函数里、不在回调本体上；`身份场/胜负.lua` / `标准/卡牌/杀.lua` 的 `return` 都是无值早退 ⇒ 不短路
- [x] 1.4 `server/core/game.lua`：`M:canUse(user, card, targets?)` → `ok, reason, legalTargets`（**普通方法**：不造对象、不进记牌器、不结算；`Player|Player[]` 的目标按 `useCard` 同一写法归一 —— 顺手抽了 `toPlayerList` 给 `useCard` 共用）
- [x] 1.5 内建条目（从 `effect/use-card.lua` 的 `collectLegalTargets` 与 `settle` 校验段搬到 `game.lua`，逐条改成「返回原因」而不是 `error`）：牌没牌名 / 没有同名内容定义 / 使用者手上没有这张牌 / 没声明「获取目标」/「获取目标」没返回列表 / 合法目标为空 / 未指定目标 / 目标不在合法目标里
- [x] 1.6 内建全过之后 `game:fire('卡牌-能否使用', { user = user, card = card, targets = list })`；**非 nil 返回值 = 否决且该值即原因**（只给 `false` 时归一成「这张牌现在不能使用」）
- [x] 1.7 `server/core/loader/env-meta.lua`：`'卡牌-能否使用'` 的上下文类型与 `on` / `fire` 重载声明；`CardDef:on('获取目标')` 的上下文由 `UseCard` 改成普通表（`CardDef.TargetCtx` = `user` / `card` —— 筛选时根本没有 `UseCard` 可传）
- [x] 1.8 记账：`moe-kill-dev/references/infrastructure.md` 的照搬件表加了一行（`simple-event.lua`：`fire` 支持快速返回）
- [x] 1.9 （追加，面板要求）`env-meta.lua` 里所有时机回调的类型改成 `fun(ctx: X): any`、`fire` 声明的返回值为 `any` —— 否则「回调返回值」会被当成错误（`最多只有 0 个返回值`）

## 2 内核：失败改 `reject`（不再 `error`）
- [x] 2.1 `server/core/effect/init.lua`：`Effect:reject(原因)` = `task:reject(原因)` + 就地让出（照搬 `Task:cancel()` 的写法）
- [x] 2.2 `server/core/effect/use-card.lua`：`settle()` 先 `game:canUse`，不过就 `self:reject(reason)`（**不 `zone:take()`、不触发 `'卡牌-结算前'`**）；过的路径行为不变；`collectLegalTargets` 与那一段校验已从本文件搬走
- [x] 2.3 `CardEffect` / 其余效果子类不受影响（确认：全套用例绿）

## 3 内核：询问带「合法选项」
- [x] 3.1 `server/core/effect/ask-card.lua`：第三参数 `condition` → `options`（`AskCard.Option = { card Card, targets? Player[] }`；挂在询问上，应答方读 `ask.options`）；`CreateOptions` / `__init` / 门面同步
- [x] 3.2 `M:answer` 里校验答复（`answerProblem`）：牌不在选项里 ⇒ `'答复不在可选项里'`；选项带 `targets` ⇒ 答复要给非空子集（没给 ⇒ `'这次答复要给出目标'`，给了选项外的 ⇒ `'答复的目标不在可选项里'`）；选项不带 `targets` ⇒ 答复不许给目标（`'这次答复不该给目标'`）；拒收 = `task:reject(原因)`；不给选项 = 不做限制
- [x] 3.3 `server/core/game.lua`：`M:askCard(to, reason, options?)` 的参数名与文档（读 `.card` / `.targets`，失败读 `.err`）
- [x] 3.4 `server/core/loader/env-meta.lua`：`AskCard` 相关声明同步（`canUse` 不需要 —— 它是 `game.lua` 上的真方法，内容侧直接看得到）

## 4 内容：出牌阶段筛选项（`package/@基础/回合.lua`）
- [x] 4.1 新增 `usableOptions(player)`：过一遍手牌，`game:canUse` 通过的装成 `{ card, targets = 合法目标 }`
- [x] 4.2 `playPhase`：每轮重筛；选项为空直接结束阶段；`game:askCard(player, '出牌', options)`；答复被拒（`ask.card` 为空）也结束阶段；**追加**：`useCard` 真失败（`.err` 非空）也结束阶段 —— 否则会拿同一批选项再问一次（就是那个「白问」的老毛病）；`MAX_PLAY_COUNT` 保留

## 5 内容：每出牌阶段每牌名上限（`package/@基础/使用限制.lua` 新）
- [x] 5.1 上限表（`{ ['杀'] = 1 }`，作用域 = 出牌阶段）与牌名取值（`card:getLabel()`）
- [x] 5.2 `'阶段-开始'`（出牌）建计数标签、`'阶段-结束'`（出牌）删掉（`player:setTag/getTag/removeTag`）
- [x] 5.3 `'卡牌-能否使用'` 条目：已达上限 ⇒ **返回原因**（`return '本阶段已经用过「杀」了'` —— 非 nil 返回值即否决）
- [x] 5.4 `'卡牌-结算前'` 计数 +1（用成功才计；打出不会被误计；筛选期的校验条目不改状态）

## 6 内容：另外两处选项
- [x] 6.1 `package/标准/卡牌/杀.lua`：打出的选项 = 被问者手牌里名为「闪」的牌（不给 `targets`）；读 `ask.card` 的写法不变；**选项为空也照旧问一次**（官方是「需打出」的询问，不能因为没牌就跳过）
- [x] 6.2 `package/@基础/濒死.lua`：求桃的选项 = 当前被问者手牌里的【桃】，`targets = { 濒死者 }`（用 `game:canUse(current, card, { player })` 过滤）；**选项为空也照旧问**（保住「从濒死者开始按行动顺序询问」的顺序）

## 7 用例（`server/test/`）
- [x] 7.1 新增套件 `core/can-use.lua`（12 条）：内建条目逐条、内容侧条目否决（`return '原因'` / `return false`）、`ok` 时给得出合法目标、多个「获取目标」取交集、目标为空 / 目标不合法、**跑校验不进记牌器**
- [x] 7.1b `rule/event.lua` 补 4 条：**快速返回**（第一个返回非 nil 的回调胜出且后续回调不再触发）、没人返回值时全部触发、回调报错（`log.error` 有返回值）**不算否决且不打断其余回调**、递归 fire 不串
- [x] 7.2 `core/effect/play.lua`：现有「…报错」那批改叫「…用不了」；`.err` 不再是错误对象而是原因 —— 断言用 `assertFailed` 的地方照旧过（其 `.err` 语义不变），`ok` 路径的用例（顺序 / 父效果 / 取消 / 栈恢复）全绿
- [x] 7.3 `core/effect/ask-card.lua`：选项挂在询问上（`ask.options`）、答复 ∈ 选项才收、答复不在选项里 / 目标该给不该给不给对 ⇒ `.err` 有原因且 `.card` 不存在、不给选项时不限制
- [x] 7.4 `rule/support.lua`：新增 `pickFirst(ask)`（从 `ask.options` 里挑第一个、目标只取第一个 = 客户端的形状），turn 的用例用它；原来的脚本应答方（按顺序给固定牌）留着当「乱答」的助手
- [x] 7.5 `rule/turn.lua`：选项里只有能用的牌（【闪】不在内）、用完【杀】后选项空了就不再问、无可用牌时不问且阶段直接过、答选项外的牌 ⇒ 拒收且阶段结束、【杀】每阶段限一次且**阶段外不受限**
- [x] 7.6 `rule/slash.lua`：打出时答一张不是【闪】的牌被拒（视为没打出 ⇒ 目标照常受伤、那张牌还在手上）
- [x] 7.7 `rule/dying.lua`：求桃的选项与**答复带上目标**（三条例例改写）
- [x] 7.8 `server/bin/moe-kill.exe --test`：**383 用例 0 失败** + 问题面板 information 及以上 **0**（重启语言服务器后重查）
- [x] 7.9 （追加）`rule/turn.lua` 的 `startTurn` 控制器：`stopAfter` 的取消改成**先让出一次再取消** —— 出牌阶段可以没有询问（没有可选项），流程会一口气同步跑到回合结束，那时 `state.task` 还没赋值，旧写法会漏取消、多跑一个回合

## 8 文档
- [x] 8.1 `moe-kill-dev/references/architecture.md`：§12 新增 `canUse` 行 + `useCard` / `askCard` 两行改写（校验、选项、`.err` 语义、校验条目必须同步只读）；§10 补两条 —— 「`fire` 的返回值 = 快速返回」与「**疑问式名字（能否…）= 期望返回值的事件，返回值即结论**」，并把 meta 示例改成新签名
- [x] 8.2 `code-style.md` §10 已足够（“需要中断执行体时…由 Task 收尾 / 表达因为什么结束用 `task:reject`”就是这次的先例）⇒ 不另加
- [x] 8.3 `sanguosha-rules`：§3（出牌阶段：先筛选项 + 杀限一次）/ §6 / §7（`askCard` 第三参数换语义、内核为何挑不了候选、`'卡牌-能否使用'`、限一次已做）/ §9.2（用牌入口、响应打出、示例代码）/ §9.4（求桃选项）
- [x] 8.4 `moe-kill-dev/references/progress.md`：验收改成 383、链条与内核现状补 `canUse` / 快速返回 / 询问选项，§2 换成「下一批待你挑」的候选表，§3 只留细节备忘

## 9 归档
- [ ] 9.1 `openspec validate add-usability-check --strict`
- [ ] 9.2 勾完 tasks 后提交（`【AI】` 前缀）
- [ ] 9.3 `openspec archive add-usability-check --yes`
