# Design

## Context

- **现状**（`server/core/effect/ask-card.lua`）：一个类 `AskCard` 兼任两种问法 —— `Condition` 有 `name?` / `zone?` / `card?` / `target?` 四条筛选条件，其中"要不要能用（跑 `canUse`）"由**缘由** `reason == '使用'` 或"给了 `target`"决定；选项带不带 `targets` 决定"答复该不该给目标"。
- **调用点**（全部）：出牌阶段（`'使用'` + `{ zone = '手牌' }`）、濒死求桃（`'使用'` + `{ name = '桃', target = player }`）、打出【闪】/【杀】（`'打出'` + `{ name = … }`）、五谷丰登（`{ card = 亮出的牌 }`）、过河拆桥 / 顺手牵羊（`{ zone = 目标的区 }`）。
- **用户口径**（2026-09-23）：`target` 只对"要一次使用"有意义 ⇒ 拆一个 `AskUseCard`；缘由取值随之回到"为什么问"的本义（出牌阶段 `'出牌'`、濒死 `'濒死'`），`'使用'` 退役。
- **机制**：询问与答复是一套独立于"要什么"的东西 —— 时机（`'卡牌-询问'` / `'卡牌-答复'` / `'卡牌-答复后'`）、选项校验（答复必须落在选项里）、让出、取消、重复应答只记 `info`。这些**一个字都不用为子类改**。

## Goals / Non-Goals

**Goals:**

- 「使用」的语义由**类型**携带（`askUseCard`），而不是缘由字符串。
- 通用类只回答「要一张牌」：候选只筛牌、答复只有牌；目标那套（`target` 条件、`canUse` 过滤、答复必须给目标）全在子类。
- 子类只覆写**两处**，机制一份。

**Non-Goals:**

- 合并 `Ask`（弃牌阶段的通用决策询问）与 `AskUseCard` —— `Ask` 的问与答都由发起方解释，形状本来就不同。
- `askSkill` / `timeout` / race（将来另开一个类）。
- 协议层的遮蔽（服务器侧看得见所有牌，与本次无关）。

## Decisions

### D1 两个类各回答一种问题

```lua
-- AskCard : Effect —— 「要一张牌」
---@class AskCard.Condition
---@field name? string|string[]
---@field zone? string|Zone|(string|Zone)[]
---@field card? Card|Card[]
---@class AskCard.Answer
---@field card? Card
---@class AskCard.Option
---@field card Card

-- AskUseCard : AskCard —— 「要一次使用」
---@class AskUseCard.Condition : AskCard.Condition
---@field target? Player|Player[] # 可用目标要与它至少有一个重合
---@class AskUseCard.Answer : AskCard.Answer
---@field targets? Player|Player[] # 给了牌就必须给目标
---@class AskUseCard.Option : AskCard.Option
---@field targets Player[] # 恒非空
```

- `Answer` / `Option` 的 `targets?` **留在基类类型里**（`AskCard.Answer` / `AskCard.Option` 各带一条可选），因为**答复的形状（线上约定）是共享的**，而"收不收 / 要不要"由类的策略决定：基类**拒收**目标、子类**必须**给目标。子类类型把 `targets` 收成必填（`AskUseCard.Option.targets`），于是子类里不用做空值判断。
- 归一的答复形状不变：`self.task:resolve { card = …, targets = … }`（`targets` 为 nil = 这次答复没有目标）。

### D2 机制在基类，子类只覆写两个钩子

```lua
-- 基类
function M:collectOptions()            -- 按条件算出选项：来源（zone / card / 被问者的牌区）→ 牌名筛 → 逐张 self:makeOption(card)
function M:checkAnswer(value)          -- 找到同牌的那个选项 → self:checkOption(option, value)
function M:makeOption(card)            -- 钩子 1（基类：{ card = card }）
    return { card = card }
end
function M:checkOption(option, value)  -- 钩子 2（基类：答复给目标就拒收）
    if value.targets ~= nil then
        return '这次答复不该给目标'
    end
    return nil
end

-- 子类：只有这两处
function M:makeOption(card)            -- 跑 canUse ⇒ 用不了的不算；带 targets（有 target 条件时取交集）
function M:checkOption(option, value)  -- 必须给目标，且落在 option.targets 里
```

- **备选（不取）**：子类覆写整个 `checkAnswer` / `collectOptions`（要复制"找选项 / 收集来源"那几行）；或者把两个类做成各自独立（机制也复制一份）。钩子的位置选在**策略不同的最小切面**上。
- **钩子的参数类型写基类类型、子类里 `---@cast` 收窄**：基类虚拟调用钩子时只能用基类签名（否则 LuaLS 在基类文件里报 `param-type-mismatch`）。
- 子类的 `condition` 字段要在自己文件里**再声明一次**（`---@field condition? AskUseCard.Condition`）—— 与 `task` 同样的「跨文件可见性按文件算」先例。

### D3 缘由回到不透明

- 删掉 `reason == '使用'` 的内核特判；`AskCard` / `AskUseCard` 都不看缘由。
- 调用点写法：出牌阶段 `game:askUseCard(player, '出牌', { zone = '手牌' })`；濒死 `game:askUseCard(current, '濒死', { name = '桃', target = player })`。
- 内容侧唯一认缘由的地方没变：`@基础/打出.lua` 认 `'打出'`。

### D4 落点与用例

- 内核：新文件 `server/core/effect/ask-use-card.lua`（`require 'core.effect.ask-card'` 后 `Extends('AskUseCard', 'AskCard')`），`core/effect/init.lua` 装载，`game:askUseCard` 入口，`env-meta.lua` 的三个时机载荷写成 `AskCard|AskUseCard`。
- 用例：新套件 `server/test/core/effect/ask-use-card.lua`（自带探针目录，与其它套件同款）；`ask-card.lua` 里**跟目标 / 使用语义有关的用例搬过去**（不是删掉），并补一条"`AskCard` 多给目标会被拒收"。

## 可延后的问题

- **`AskUseCard` 的 `target` 与"答复里的目标"是不是一回事**：现在 `target` 是**候选的收窄**（能用在这（些）人身上），答复的目标从选项目标里选 —— 将来若出现"询问的目标窗口 ≠ 可用目标"的场景（如技能改目标），再谈。
- **`askSkill` / `timeout`**：仍另开一个类；`Ask`（通用决策询问）与它的去留一起谈。
