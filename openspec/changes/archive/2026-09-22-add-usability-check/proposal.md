# Proposal

## Why

出牌阶段的 `playPhase` 把「要哪张牌、打给谁」整个交给应答方，**用牌没有任何"能不能用"的检查**：

- 手上有【杀】就能无限杀（官方是每出牌阶段限一次）；
- 应答方给一张用不了的牌时，`UseCard:settle()` 的 8 处校验**全走 `error`**（被 `Task:execute` 的处理器收进 `.err`，与真故障混在一起），而失败又发生在 `zone:take()` **之前** ⇒ 牌没动、手牌没变 ⇒ 答复方给同样的答复就一直转（现在靠 `for _ = 1, MAX_PLAY_COUNT`（1000）兜住）。

两个缺口都得补：**规则侧**要知道「这张牌此刻能不能用、能打给谁」（还有每阶段的使用次数上限）；**询问侧**要把「能选什么」告诉应答方 —— 前端不做规则判断，不筛就等于让前端 / AI 去猜，而且一定会猜错。

用户 2026-09-22 定的口径：**ask 与 use 两侧都要做** —— ask 负责筛出「能用的牌 + 每张的可用目标」发给客户端，客户端回复后 use 要做**二次校验**；校验不过**不用 `error`，但要 `reject` 进 `.err`**。

## What Changes

- **新增使用校验（内核机制）**：`game:canUse(使用者, 牌, 目标?)` —— **普通函数**（不造对象、不结算、不进记牌器），返回 `ok` / 原因 / 合法目标。不能靠「试一次 `useCard`」代替：每次 `Effect:apply()` 都会 `game:addEffect`，试探会把记牌器灌满垃圾。
- **新增内容侧扩展点**：`'卡牌-能否使用'` 时机 —— **回调返回非 nil 值即否决，且该值就是原因**（`return false` = 无原因）；注册走 `game:on`（返回 disposer，与既有时机一致）。**名字用疑问式（能否…）**：约定「疑问式 = 期望返回值的事件」，与通知型时机一眼分得开。内建条目 = 现在 `UseCard:settle()` 里那 8 条。
- **事件系统支持「快速返回」**（照搬件改动，用户已同意）：任意触发里**明确返回了返回值就跳过之后的事件，并以该返回值为结果** —— `server/tools/simple-event.lua` 的 `fire` 收 `xpcall` 的返回值，第一个非 nil 即胜出并停止调用后续回调；要在 `moe-kill-dev` 的 `infrastructure.md` 里记账。
- **校验失败改用 `reject`**：`Task:reject(原因)` ⇒ 调用方读 `.err`（原因是正常结果，不是故障），**不再 `error`** —— 落实「`error` 只表示报错」（`code-style.md` §10）。顺带给 `Effect` 加 `reject(原因)`（reject + 就地让出，照搬 `Task:cancel()` 的收尾）。
- **询问带「合法选项」**：`game:askCard(被问者, 缘由, 选项?)` 的第三参数从「内核不解释的匹配条件 `condition`」升级为「**内核持有并校验的合法选项**」`options`（`{ card, targets? }[]`）—— 询问时带给应答方（读 `ask.options`），**答复回来校验「答复 ∈ 选项」**，不在则 `reject`。不给选项 = 不做限制（与今天等价）。
- **出牌阶段**：询问前用 `canUse` 过一遍手牌 ⇒ 选项 = 「能用的牌 → 各自的可用目标」；没有可选项就不问、直接结束阶段。
- **每出牌阶段每牌名使用上限**：新文件 `package/@基础/使用限制.lua`（上限表默认 `{ 杀 = 1 }`，计数是阶段作用域的状态）；**实现为一条 `'卡牌-能否使用'` 校验条目** ⇒ 筛选与二次校验两侧自动同时生效。
- **调用点跟着改**：`package/标准/卡牌/杀.lua`（打出的选项 = 手牌里的【闪】）、`package/@基础/濒死.lua`（求桃的选项 = 手牌里的【桃】，目标 = 濒死者）、`package/@基础/回合.lua`（出牌阶段）。
- **BREAKING（内部）**：`askCard` 第三参数换语义（`condition` 退役）；`UseCard` 校验失败的 `.err` 从错误对象变成原因；`'卡牌-能否使用'` 是新增时机（`env-meta.lua` 要补声明）；**`game:fire` 与回调的返回值开始有意义** —— 回调意外返回值会短路掉后面注册的回调。

**明确不做**：

- 不做「是否发动某技能」这类**可等待**的使用前询问 —— 校验条目必须**同步判定**（`canUse` 在筛选里逐张手牌跑），要问的留给以后的时机。
- 不做装备与距离修正、即时锦囊、无懈可击、武将技能（它们以后挂同一套校验，本批只把机制立起来）。
- 不改 `Ask`（弃牌阶段还在用，用户已表态「等那批到位再谈去留」）。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设 `skip_specs: true`）：可执行契约由用例承担 —— `server/bin/moe-kill.exe --test`（新增 `core.can-use`，补 `rule.event` 的快速返回，改写 `core.effect.play` / `core.effect.ask-card`，`rule.turn` / `rule.slash` / `rule.dying`）。

## Impact

- 内核：`server/tools/simple-event.lua`（照搬件：`fire` 支持快速返回）、`server/core/event.lua`（把结果透传给调用方）、`server/core/game.lua`（`canUse` 普通函数、`askCard` 参数）、`server/core/effect/init.lua`（`Effect:reject`）、`effect/use-card.lua`（校验段挪进 `canUse` + 失败改 reject）、`effect/ask-card.lua`（`condition` → `options` + 答复校验）、`loader/env-meta.lua`（新时机 + 新入口的类型声明）
- 内容：`package/@基础/使用限制.lua`（新）、`package/@基础/回合.lua`、`package/@基础/濒死.lua`、`package/标准/卡牌/杀.lua`
- 用例：`server/test/core/can-use.lua`（新套件）、`test/rule/event.lua`（快速返回）、`core/effect/play.lua`（「报错」→「被拒」）、`core/effect/ask-card.lua`（选项与拒收）、`test/rule/{turn,slash,dying}.lua`
- 文档：`moe-kill-dev/references/architecture.md` §12、`sanguosha-rules` §3 / §6 / §7 / §9.2 / §9.4、`references/progress.md`
- **行为变化**：出牌阶段的选项变成「能用的牌」（【闪】这类用不了的牌不再出现）；用不了的答复会被**拒收**（`.err` = 原因、`.card` 不存在）⇒ 出牌阶段据此结束（不再空转）；【杀】**每出牌阶段限一次**。
