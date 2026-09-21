# Design

## D1 答复为什么要带目标：读法 A（用户 2026-09-21 定）

出牌 = 「用哪张牌」+「打给谁」，本来就是**一个决策**。若拆成两次询问（先要牌、再要目标），前端要来回两趟、脚本要写两段、将来 `timeout` 也要管两个计时 —— 而三国杀的官方表述里这是一次"使用"。

所以：**`askCard` 的答复带目标**，形状

```lua
---@class AskCard.Answer
---@field card Card
---@field targets? Player|Player[] # 单目标可以只给一个，多目标给一张列表
```

`targets` 用 `Player|Player[]` 这个**联合类型**（用户指定）：答"桃自己"这种单目标时直接给对象，答"南蛮/万箭"那种一群时给列表。这与 `moveCard` 的 `Card|Card[]` / `string|string[]|Zone|Zone[]` 是同一个口径 —— **入参形状可以宽松，入口负责归一**。

**否掉的读法 B**（答复仍只有一张牌、目标另开一个询问）：多一趟往返与多一个类，而这次询问本身就是"使用一张牌"这一个决策。

## D2 归一放在 `game:useCard`，不放在内容侧

`UseCard.targets` 内部仍然只认 `Player[]`（`#targets` / `ipairs` 都靠它），**归一化放在 `game:useCard` 入口**：

```lua
local list = {}
if Type(targets) ~= nil then     -- 单个 Player（类实例）
    list[1] = targets
else                              -- 一张列表（空表 = 没指定目标，照旧报错）
    list = targets
end
```

理由：将来每个"要用牌"的内容（锦囊、技能、借刀杀人…）都会从询问拿到这个联合类型，归一只写一处；而且 `moveCard` 已经确立了"入口接受联合类型"的先例。判据用 `Type(...)` 而不是 `x[1] ~= nil`：**空列表也得被认成列表**（`{}` 落到 `x[1] == nil` 那一支会被包成 `{ {} }`，那是错的）。

## D3 `card` / `targets` 用 getter 转存，不在 `settle` 里赋值

用户的原话是"`.result?.card` 或者 `.card`（askCard 里帮忙转存一下）"。用 **getter** 实现转存：

```lua
M.__getter.card    = function (self) return self.result?.card    end
M.__getter.targets = function (self) return self.result?.targets end
```

- 不会有两份状态（`AskCard` 原来在 `settle` 里 `self.card = self.result`，结果一改形状就得多转存一个字段，且"什么时候转存过了"要看代码才知道）；
- 先例现成：`Ask.__getter.reply`、`Effect.__getter.result` 都是这么写的；
- 结果在**应答的那一刻**就定下（`answer` 里直接 `resolve`）⇒ 答复时机里 `ctx.card` 照样读得到。

**不变的**：`.result` 仍然是"这次询问的结果"（效果基类的口径），只是结果从"一张牌"变成了"一次答复"。

## D4 `answer(nil)` = 没答上

出牌阶段的脚本应答方（`rule/turn.lua` 的 `endPhase()`）就是 `return nil`。让 `answer(nil)` 直接返回（不 resolve）⇒ `ask.card` 为空、`'卡牌-答复'` 不触发 —— 与"没人应答"完全同义，脚本写法不必分叉。

重复应答仍然是"先给出的算数 + 记一条 `info`"（改成读 `self.task.resolved`，与 `Ask` 一致；不再依赖"结果是否为真"）。

## D5 第三参数：`question` → `condition`（匹配条件）

- **语义**：要什么样的牌。`{}` = **任意牌**（用户明确：想允许任意牌就传空表，不必列候选）。
- **内核不解释**：与 `reason` / 时机名同一口径。内核没有牌表、不认识花色点数，也不做"答复的牌是否匹配"的校验（本批明确不做 —— 应答方自律；真要校验得等条件有个内核认识的形状）。
- **候选不再塞进询问**：出牌阶段原来是 `{ cards = hand:list() }`（把整副手牌当载荷传出去），现在传 `{}` —— 候选由**应答方**按匹配条件从被问者的牌区自己算（对将来的前端也更自然：可选项 = 被问者手上匹配的牌）。

## D6 出牌阶段的新形状

```lua
local function playPhase(player)
    while true do
        local ask  = game:askCard(player, '出牌', {})
        local card = ask.card
        if not card then
            return                          -- 答不上 = 不出牌，阶段结束
        end
        game:useCard(player, card, ask.targets or {})
    end
end
```

- 取局部变量再判空（字段的窄化不落到后面的语句 —— 见 `code-style.md`）。
- **`reason` 用 `'出牌'`**：`'卡牌-答复'` / `'卡牌-答复后'` 会连着触发，基础规则只管 `reason == '打出'`（`@基础/打出.lua`）⇒ 不会误把牌挪走。
- 顺手删掉 `local hand = ...`（候选不再由这里算）。

**本批不修**的已知问题：应答方给一张用不了的牌（或给了牌却没给目标）⇒ `game:useCard` 失败、牌没动、循环再问 ⇒ **可能原地死循环**。正解是"询问前过滤候选"，属出牌阶段的使用限制那一批（已在对话中单独提出，等用户定）。

## D7 用例怎么锁

| 用例 | 锁什么 |
| --- | --- |
| `core.effect.ask-card` 全部改写 | 答复形状（`{ card }` / `{ card, targets }`）、`.card` / `.targets` 转存、`condition` 挂在询问上、没人应答 / 取消 / 重复应答 |
| 新增「答复带目标」一条 | `{ card, targets }` 两样都读得到 |
| `rule.turn` 出牌阶段那条 | 出牌阶段真的走 `askCard`（`reason = '出牌'`）、目标生效（掉 1 点体力）、答不上就结束阶段 |

`rule/turn.lua` 的应答要从 `'决策-询问'` 挪到 **`'卡牌-询问'`**，并且**保持"先让出一次再答复"的形状**（同步答复会让流程不进事件循环 —— 那条注释写的坑）。

## D8 影响面

- `--test`：全量应保持 0 失败（条数不变）。
- 问题面板：information 及以上 0。
- `Ask` 只剩弃牌阶段一个用户（本批不动）。
