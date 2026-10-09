# 设计：取消记成失败

## D1 判据：这次询问允不允许「不给」

一条式子管全部询问族：**「不给」是不是合法答复**。

| 情形 | `.err` | `.success` | 结果 |
| --- | --- | --- | --- |
| 没人表态 / 空答复，且 `min` 给 `0` | 空 | 真 | 空（`.cards = {}` / `.players = {}`） |
| 没人表态 / 空答复，且 `min ≥ 1` | `'取消'` | 假 | 空 |
| 没人表态，且 `cancelable = false` | `'这次询问必须给出答复'` | 假 | 空 |
| 空答复，且 `cancelable = false`、`min ≥ 1` | `'至少要给 N 张牌'`（张数校验挡下，沿用旧文案） | 假 | 空 |

- `min` 的默认值沿用既有口径（省略 = `1`、`max` 省略 = `min`），所以**不写条件** = 必须给 ⇒ 取消记失败。
- **不表态（`nil`）与空答复（`{}`）是同一件事**（既有文档就这么写：`cancelable` 那段的「不表态 / 空答复都算取消」）—— 本批只是把它们的**结果**改成 `.err`，不合并成一个入口（`nil` 连应答方都没走到，`{}` 是应答方明确给了空表，时机要不要发不同）。
- 两种「合法的取消」走的是**同一条**：都**不写 `.err`**（`.success` 真、`.result` 空）。`min = 0` 时没人表态这条**什么都不做就返回** —— 任务由执行体的返回值（`nil`）收尾，`.result` / `.err` 都空，读法（`.cards` / `.players` 恒列表）本来就把「空」读成空表 ⇒ 不用造一个空结果对象。

## D2 形状（内核）

```lua
-- ask-card.lua
local function isEmptyAnswer(value)
    return value.viewAs == nil and #moe.util.toList(value.card) == 0
end

--- 这次允许「一个都不给」吗（`min` 为 0 ⇒ 取消也是合法答复、算成立）
function M:allowNone()
    return (self.condition?.min or 1) == 0
end

function M:collectAnswer()
    ...
    local answer = self.game:fire('卡牌-询问', self)
    if answer == nil then
        -- 没人表态：这次允许「一个都不给」就当空答复（成立、没有结果），否则是「取消」
        -- （不允许取消的询问连取消入口都没有：记成拒收）
        if not self:allowNone() then
            self.task:reject(self.cancelable and '取消' or '这次询问必须给出答复')
        end
        return false
    end
    ...
    -- 空答复 = 取消：这次允许不给才算一次答复，否则记成「取消」
    if isEmptyAnswer(answer) and not self:allowNone() then
        self.task:reject('取消')
        return false
    end
    ...
end
```

- **`isEmptyAnswer` 认「牌」与「声明」两条**：选了「视为」声明（`viewAs`）的答复没有牌、但它是一次正经答复（素材在 `beforeResolve` 里收）⇒ 不能当空答复。
- **判据放在 `checkAnswer` 之后**：不合法（不在候选 / 张数不对 / 目标不对）优先，理由更具体。
- `AskPlayer:settle` 加同形的 `allowNone()` 与一句 `reject('取消')`（它有自己的 `settle`，不复用 `collectAnswer`）。
- `Ask` / `AskChoice` / `AskUseSkill` 没有 `min` ⇒ 没人表态一律 `reject('取消')`。

## D3 收编 `AskPlayCard`

上一批（【无双】）在 `AskPlayCard:beforeResolve` 里把**响应询问的空答复**作废，并靠 `settle` 里的 `if responseTo then reject('没有打出')` 兜底。基类现在统一处理 ⇒ 两段都删：

| 旧 | 新 |
| --- | --- |
| `settle` 里 `if not settleAnswer() then if responseTo then reject('没有打出') end` | 基类已 `reject('取消')`，`settle` 只留「答复到手 ⇒ 发两段时机」 |
| `beforeResolve` 把空答复返回 `nil` 作废 | 基类 `isEmptyAnswer` + `reject('取消')` |

**理由词统一成「取消」**（用户 2026-10-09 定：「在 Effect 里就用『取消』2 字好了」）：`.success` 是内容侧的正式读法（【杀】），`.err` 只在排查时看；保留两套近义词只会分叉。

## D4 两根轴：「成没成立」与「进不进错误处理器」

| 轴 | 是什么 | 谁在喂 | 取消时 |
| --- | --- | --- | --- |
| `.success` | `.err == nil`（现算） | 效果自己 | **假**（没成立） |
| 错误处理器 | 生产 `log.error` / 测试 `lt.errors` | **只有抛出来的 error** | **不进**（不是故障） |

- 证据：`Task:executeSync` / `executeAsync` 的 `xpcall` 处理器里才调 `errorHandler(err)`，而 `reject` / `cancel` 只是把 `.err` 记下来 —— 既有的「被阻止」（`'效果-能否生效'` 返回原因）/「被驳回」（`ask:cancel`）都是「`.err` 有值 + 不进错误处理器」，取消并入这一族。
- 用例侧因此**两条断言一起写**：`.err == '取消'` **且** `#lt.errors == 0` —— 少了后一条就会把「取消报成故障」当成通过。

## D5 落点

| 面 | 文件 | 改什么 |
| --- | --- | --- |
| 内核 | `server/core/effect/ask-card.lua` | `isEmptyAnswer` + `allowNone()`；`collectAnswer` 两处按 D1/D2 记 `.err`；`checkAnswer` 那句注释改口径 |
| 内核 | `server/core/effect/ask-player.lua` | `allowNone()`；`settle` 没人表态时 `reject('取消')` |
| 内核 | `server/core/effect/ask.lua` / `ask-choice.lua` / `ask-use-skill.lua` | `settle` 没人表态时 `reject('取消')` |
| 内核 | `server/core/effect/ask-play-card.lua` | 删 `reject('没有打出')` 与 `beforeResolve`（D3）；类注释改「没答上就是『取消』」 |
| 内核 | `server/core/game.lua` | `askPlayCard` 的说明同步 |
| 用例 | `test/core/effect/ask-card.lua` | 1 条改断言 + 1 条改名 + **加 1 条**（`min` 给 0 且没人表态也算成立） |
| 用例 | `test/core/effect/ask.lua` / `ask-choice.lua` / `ask-player.lua` / `ask-use-card.lua` / `ask-use-card-to-card.lua` / `ask-card-with-target.lua` / `ask-use-skill.lua` / `ask-play-card.lua` | 9 条改断言（`nil, ask.err` → `'取消'`）+ 1 条改名（`ask-player` 的 `min = 0` 那条点明「取消也算成立」） |
| 文档 | `moe-kill-dev/references/architecture.md` / `progress.md` / 变更工件 | 同步口径 |
| 文档 | `openspec/specs/**` | **不动**（冻结期） |

## D6 反面：为什么不「一律记失败」

用户补的那句是关键：**「取消」的合法性是这次询问自己声明出来的**。写死成失败会把 `min = 0`（【雌雄双股剑】的「给一张手牌就行，不给也行」、【张辽】【突袭】的「选 0~2 名」）变成假失败 —— 内容侧读 `.err` 就会把「玩家主动不选」当成异常路径。所以判据必须挂在**条件上的 `min`**，而不是「取消」这个词本身。

## D7 反向验证（实测）

| 拆掉什么 | 结果 |
| --- | --- |
| `allowNone` 钉成 `false` | **恰好 2 红**（`min` 给 0 那两条） |
| `AskCard` 的两处取消拒收 | **65 红**（全是「杀 / 闪」这类响应流 —— `.success` 会把「没人出闪」读成响应成立） |
| 其余四类的 `reject('取消')` | **恰好 5 红** |

第二条说明**这个改动的爆炸半径主要由 `.success` 的读法承接**：一旦取消回到「`.err` 空」，【杀】与【决斗】的整条链立刻反过来。
