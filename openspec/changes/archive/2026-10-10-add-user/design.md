# Design

## Context

- 内核的询问一律是「一次效果 + 一条全局时机」：`Ask*` 类的 `settle()` 调 `game:fire('卡牌-询问', self)`，**返回值就是答复**（第一个给出答复的胜出；没人表态给空）。共 11 个询问类、5 条时机。
- 「被问者」在每条时机里都能从载荷读到 —— `Ask.to` / `AskCard.to` / `AskPlayer.to` … 全都有 `to`。也就是说**分派所需的信息早已存在**，缺的只是「谁来分派」。
- `Player` 现在没有任何「谁控制它」的概念；`server/session/` 的 `requestInput → 挂起 → submit` 通道原本是为这个位置准备的，但它挂在「会话」而不是「座位」上，而且不认识 User。

## Goals / Non-Goals

**Goals**

- 让「问谁」有落点：询问先问 `to.user`，没人表态再走全局时机。
- 让「来源」可替换：`User` 是基类，真实玩家 / 电脑 / 测试夹具都是它的子类。
- 让「绑定」灵活：`Player` 可以没有 User，也可以中途更换。

**Non-Goals**

- 不做真 AI（`AIUser` 的决策逻辑另开变更）。
- 不做协议（`ClientUser` 只留接口）。
- 不定 `AskPanel` 的多轮接口形状（之后单独决策）。
- 不动 `server/session/`（保留，之后单独删）。
- 不迁移现有测试（内核的全局时机仍在，老写法照旧可用）。

## Decisions

### D1. `User` 是「座位控制者」，住 `server/user/`

`server/user/user.lua` 定义 `User` 基类（`Class 'User'`），`server/user/client-user.lua` 定义 `ClientUser`，`server/user/init.lua` **只做装载**（先基类后子类，照 `core/effect/init.lua` 的形状）；走 `require` 加载（在 `server/moe-kill.lua` 里 `require 'user'`，**不参与热重载**，与 `server/session/` 同一层）；User 没有工厂，所以不挂门面（类按 `Class` 名全局可用）。

理由：它要跟外部（协议 / AI）打交道，属**外层**；内核只依赖**接口**（`Player.user` 的类型），不 `require` 实现。

### D2. 每类询问一个方法，名字与类名一致

| 询问类 | 全局时机 | `User` 上的方法 |
| --- | --- | --- |
| `Ask` | `'决策-询问'` | `ask` |
| `AskChoice` | `'决策-询问'` | `askChoice` |
| `AskPlayer` | `'决策-询问'` | `askPlayer` |
| `AskCard` | `'卡牌-询问'` | `askCard` |
| `AskCardWithTarget` | `'卡牌-询问'` | `askCardWithTarget` |
| `AskUseCard` | `'卡牌-询问'` | `askUseCard` |
| `AskUseCardToCard` | `'卡牌-询问'` | `askUseCardToCard` |
| `AskPlayCard` | `'卡牌-询问'` | `askPlayCard` |
| `AskUseSkill` | `'技能-询问'` | `askUseSkill` |
| `AskHero` | `'武将-询问'` | `askHero` |
| `AskPanel` | `'面板-询问'` | `askPanel` |

方法签名：收一个参数（这次询问的实例），返回**与内核同一形状的答复**（`AskCard.Answer` / `Player` / `HeroDef` / …）。**返回空 = 不表态**（继续走全局时机；最终按内核现有规则判「取消 / 必须给出答复」）。

### D3. 「不表态」= 返回空，不是「明确取消」

内核里这两件事本来就分开：**不返回**（空）= 不表态、问下一位；**返回空答复**（如 `AskCard` 的 `{}`）= 明确取消（`cancelable` 时成立）。`User` 的方法沿用同一套 —— 基类 11 个方法全 `return nil`，于是「没有 User」「User 不关心这类询问」「User 认为该走全局」是同一个结果，实现上只需一条判断。

### D4. 顺序：User 先，全局后

`to.user` 存在就先问它；返回空才 `game:fire(时机, ask)`。**同一个询问**只走一遍这两步（不是两次询问）。全局那段「第一个给出答复的胜出」不变 —— 于是「User 的答复优先于任何全局订阅者」。

### D5. `Player.user` 是公开字段 + `setUser`

```lua
---@field user? User # 谁在控制他（没有就是没人应答，交给全局时机）
```

- 读取按 `code-style.md` §11：**无参读取用字段**（`player.user`），不写 `getUser`。
- 绑定 / 更换 / 解绑统一走 **`Player:setUser(user?)`**（中途更换 = 再 set 一次）。
- **不发事件**（「换了人」没有消费者；将来要时再加）。

### D6. 「优先问 User」的落点

11 个类的取值处各改一行，共用一段逻辑（先问 User、空则走全局）。落点二选一，实现时定：

- **甲**：`Effect` 上一个保护方法（注释写明「询问类用」）—— 改动面最小、集中一处，代价是 `Effect` 多一个不是所有效果都用的方法；
- **乙**：`core/effect/` 下一个只给询问类用的局部 helper 模块 —— 概念更干净，代价是 11 个文件各加一行 `require`。

倾向**甲**。

### D7. 与 `server/session/` 的关系

用户 2026-10-09 定：**session 之后去掉**（它是没有 User 概念时的临时外壳）。本批**不动**它 —— 不删、不改、不接线；删除是后续批次（要先把「挂起 / 恢复」的职责交回给 User 那条路）。

### D8. 本批是骨架，真 AI 另开

`ClientUser` 本批只留接口（各方法照基类返回空），协议接线后续做。`AIUser` 不在本批：真 AI 会**引入不确定性**（用例开始依赖「AI 会怎么打」），与这层骨架不是一件事。

## Risks / Trade-offs

- **内核多认识一个概念**：`Player` 上多了 `user` 字段、询问取值多一步判断 ⇒ 内核从「只发时机」变成「先问 User」。这是明确要的（「Ask 会优先问 User 然后才走全局事件」），收益是「问谁」有落点。
- **两条通道并存**：内核仍 fire 全局时机 ⇒ 存在「User 与全局订阅者都答」的可能，但顺序定死（User 先、先答者胜出）⇒ 行为确定。
- **`User` 类型被内核引用**：内核的 `player.lua` 注解写 `---@field user? User`，而 `User` 定义在外层 ⇒ **类型上的跨层引用**（运行期无依赖）。这层引用充当「内核与应答者的契约」，留意 `User` 不要反向吃内核实例以外的东西。

## Migration Plan

- 旧写法零改动：现有 300 余处 `game:on(…)` 照旧工作（`Player` 上没有 User ⇒ 直接走全局）。
- 新用例：`server/test/core/user.lua` 覆盖「有 User 时先问 User」「User 不表态时回落全局」「User 先于全局订阅者」「中途更换 / 解绑」「没有 User 时行为不变」。
- 后续批次（不在本批）：`ClientUser` 接协议、`AIUser`、`AskPanel` 多轮形状、删除 `session/`。

## Open Questions

无 —— 用户 2026-10-09 已逐条定：每类一个方法 / `Player` 可无 User 且可换 / `AskPanel` 与 `ClientUser` 接线之后单独决策 / 本批只做骨架。
