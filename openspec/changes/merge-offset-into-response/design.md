# 设计：响应收成一个概念

## D1 形状（内核）

`AskOffsetCard` 相对 `AskPlayCard` 只多三件事（全部搬进 `AskPlayCard:settle`）：

```lua
---@async
function M:settle()
    local responseTo = self.responseOptions?.responseTo
    if not self:settleAnswer() then
        if responseTo then
            self.task:reject('没有打出')
        end
        return
    end
    if responseTo then
        self.game:fire('效果-被响应', self)
        responseTo.from:fire('效果-来源-被响应', self)
    end
end
```

- **「这次询问是一次响应」的判据 = 给了 `responseTo`**（四个调用点都给了：杀 / 万箭 / 南蛮 / 决斗）。
- **没答上（或答复被拒收）** ⇒ `reject('没有打出')` ⇒ `.success` 假、`.card` 空 ⇒ 【杀】读 `.success`、【决斗】读 `.card` **两处都不用改读法**。
- **不给 `responseTo` 的 `askPlayCard`**（「要一张打出的牌」这条原义）**照旧**：没答上 = 空答复、不 reject，`.success` 不变 —— 这样既有用例与语义都不动。
- **「答复之后被驳回 ⇒ 时机不发」不需要写判据**（落地时实测出来的）：`Task:cancel` 在「自己就是那个执行体」时**当场让出且不再被唤醒**（`server/tools/task.lua`）⇒ 订阅者在时机回调（或答复后那一段）里 `ask:cancel` 会把这次响应就此停住，后面的段自然不发。我先前写的 `and self.success` 实测**不可达**（去掉它一条用例都不红）⇒ 按「不过度防御」删掉，只留一行注释说明这条机制。

## D2 事件名

| 旧 | 新 |
| --- | --- |
| `'效果-被抵消'` | `'效果-被响应'` |
| `'效果-来源-被抵消'` | `'效果-来源-被响应'` |

- 沿用「分类-动作」与「全局 + 来源再发一份」的既有形状（与 `'效果-能否生效'` / `'效果-来源-能否生效'` 同形），只换词。
- 语义放宽成「**一次响应成立**」：杀的闪、万箭 / 南蛮的杀与闪、决斗的杀都发。**算不算抵消由订阅者自己判**（青龙 / 斧子已经只认 `reason == '杀'` + `ask.card?.name == '闪'`）。
- 载荷仍是那次询问（`AskPlayCard`）；驳回仍是 `ask:cancel(原因)`（调用后不返回）。

## D3 落点

| 面 | 文件 | 改什么 |
| --- | --- | --- |
| 内核 | `server/core/effect/ask-play-card.lua` | 加 `settle`（D1）+ 类注释补响应语义 |
| 内核 | `server/core/effect/ask-offset-card.lua` | **删**（连 `moe.askOffsetCard` 门面） |
| 内核 | `server/core/effect/init.lua` | 去掉那一行 `include` |
| 内核 | `server/core/game.lua` | 删 `game:askOffsetCard`；`askPlayCard` 的说明补响应语义 |
| 内核 | `server/core/loader/env-meta.lua` | 8 处（两张事件名的四种订阅面 + 询问族联合类型 + `'效果-被响应'` 载荷类型） |
| 内容 | `package/标准/卡牌/杀.lua` | `askOffsetCard(…)` → `askPlayCard(…)`（判法不变，仍读 `.success`） |
| 内容 | `package/标准/卡牌/青龙偃月刀.lua`、`贯石斧.lua` | 订 `'效果-来源-被响应'`（判据不变；顶部官方牌面照抄不动） |
| 用例 | `server/test/core/effect/ask-offset-card.lua` | 10 条并进 `ask-play-card.lua`（「抵消：…」→「响应：…」）、删文件 |
| 用例 | `equip.lua` / `hero-skill.lua` / `slash.lua` | 应答脚本筛 `kind` 的 ~25 处 |
| 用例 | `ask-use-card-to-card.lua` / `use-card-to-card.lua` | 夹具牌名 `'抵消牌'` → `'目标牌'`（「对一张牌使用」的靶子牌） |
| 文档 | `architecture.md` / `sanguosha-rules` / `progress.md` / 变更工件 | 引擎措辞改「响应」；官方引文保留原词 |

## D4 「抵消」这个词的边界（用户 2026-10-09 定）

- **引擎自己的名字里不再出现**：事件名、类名（`AskOffsetCard` 整个删掉）、方法名、我们自己写的说明与测试名。
- **官方原文保留**：卡牌定义顶部的牌面（【杀】【闪】【青龙偃月刀】【贯石斧】）、规则集引文（【无懈可击】「作用效果：抵消此锦囊牌」、官方 §2.7 的「抵消」定义）—— 改了就是篡改底本，以后没法跟规则书对账。
- 无懈可击那条机制我们自己的说法用「**阻止生效 / 挡下**」（它的落地本来就不是「一次响应」，而是 `'效果-能否生效'` 里返回原因）。

## D5 被否的方案

- **保留 `AskOffsetCard` 不变**（只加 `count` 给【无双】）：用户 2026-10-09 定「内部不区分」，且它只有一个调用点、概念与打出的响应族重叠。
- **按 `responseTo` 有值就发时机（不分给没给）**：`responseTo` 现在还被「不能响应」(`isResponseBanned`) 与「视为声明」窗口读，两个用途混在一起会让「要一张打出的牌」也发时机 —— 所以判据保持「给了 `responseTo`」，并且**只在响应语境下**才 reject。
- **没答上也让 `.success` 为真、【杀】改读 `.card`**：那会把「一次响应没成立」这件事藏进 `.card` 为空，且【杀】要跟着改读法；保留 `reject` 更省（`.success` 在两处调用点都是对的）。
- **事件名改成别的词**（`'效果-被挡下'` 等）：用户定「改成响应」。

## D6 反向验证（落地时实测）

- 去掉「没答上 ⇒ `reject('没有打出')`」⇒ **58 条红**（【杀】不再造成伤害，一批规则用例连锁）。
- 无条件发时机（不判 `responseTo`）⇒ **恰好 1 条红**；那条用例起初写成「没答上就算不上响应」（早退，恒过）⇒ 已补强成「**有答复**也算不上响应」。
- 去掉「来源」那一段（`responseTo.from:fire`）⇒ **9 条红**（青龙 / 斧子与两段时机用例钉着）。
- 去掉 `and self.success` ⇒ **0 条红** ⇒ 那行不可达，已删（见 D1）。
