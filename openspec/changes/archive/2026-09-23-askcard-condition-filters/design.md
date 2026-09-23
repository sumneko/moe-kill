# Design

## Context

- **现状**（`server/core/effect/ask-card.lua`）：`Condition = { name?, targets?, cards?, zones? }`；`collectOptions` 按条件产出 `ask.options`；`answerProblem` 校验「答复必须落在选项里」；`reason` 是不透明字符串（内核只原样带给规则层）；答复读 `.card` / `.targets` / `.zone`。
- **现状的调用点**：

  | 调用点 | 现在写的条件 | 意图 |
  | --- | --- | --- |
  | `@基础/回合.lua` 出牌阶段 | `{ targets = {} }` | 只要"用得出去"的牌（空表 = 只要求至少有一个合法目标） |
  | `@基础/濒死.lua` 求桃 | `{ name = '桃', targets = { player } }` | 能救他的【桃】 |
  | `标准/卡牌/{杀,万箭齐发}` | `{ name = '闪' }` | 打出【闪】 |
  | `标准/卡牌/{南蛮入侵,决斗}` | `{ name = '杀' }` | 打出【杀】 |
  | `标准/卡牌/五谷丰登` | `{ cards = 亮出的牌 }` | 从一批不属于任何人的牌里选一张 |
  | `标准/卡牌/{过河拆桥,顺手牵羊}` | `{ cards = 明区的牌, zones = 暗区 }` | 明区逐张挑、暗区盲选 |
- **用户 2026-09-23 的口径**（三条，本设计全部照此）：
  1. 「每一个字段都是筛选条件，如果是数组则满足其一即可，如果不是数组则需要满足这个（可以先归一化为数组），不填则是无要求。字段名我们改成单数形式。`zone` 表示牌需要在这个区域内。`target` 去掉"至少有一个合法目标"的规则，应该是用不到的」。
  2. 「不可见是指和客户端通讯的时候隐瞒，服务器这边肯定还是可见的……客户端会实现个秘密映射，在这个区域内的卡会替换成别的『未知卡牌』，客户端选择后服务器把它映射回来（或者直接丢弃结果随机），然后把正确的卡返回给 `askCard`」⇒ **内核不按明暗分候选**。
  3. 「只有『获取目标』返回至少 1 个目标的牌才能使用……换句话说内核需要知道『使用』的语义……内核直接判断 `reason == '使用'`」⇒ 使用语义由**缘由**表达，不塞进 `Condition`。

## Goals / Non-Goals

**Goals:**

- `Condition` 只有**一种语义**：筛选条件；数组 = 其一；单值 = 归一化成一个元素；不填 = 无要求。
- 「使用」的语义回到它该在的地方（`canUse`），由内核按**缘由**触发；`target` 只负责"要能用在谁身上"。
- 调用点各写各的意图，不再有多种字段充当"来源 / 窗口 / 开关"三重身份。

**Non-Goals:**

- 协议层的遮蔽与「秘密映射」（会话与协议批次）、`askSkill` / `timeout` / race、武将技能。
- 官方的"看不见 ⇒ 随机一张"：服务器侧一律看得见，随机与否由**将来客户端那套**决定（映射回来或丢弃重抽）。

## Decisions

### D1 字段：单数、统一语义、一律归一化

```lua
--- 要什么样的牌：每个字段都是一条筛选条件（数组 = 满足其一；单值 = 当成只有一个的数组；不填 = 无要求）
---@class AskCard.Condition
---@field name? string|string[] # 牌名
---@field zone? string|Zone|(string|Zone)[] # 牌在哪个区里
---@field card? Card|Card[] # 牌必须在这批里
---@field target? Player|Player[] # 可用目标要与它至少有一个重合
```

- **归一化直接用现成的 `moe.util.toList`**：非表 ⇒ 包一层（`'手牌'` / 一个 `Card` 实例）；空表 ⇒ 它自己；严格列表 ⇒ 原样；**类实例与具名字段的表**（`Card` / `Zone` / `Player` 都是）⇒ 包一层。四个字段共用一个规则，不再手写类型分派。
- `Answer` / `Option` 回到「只要一张牌」：`---@field card? Card` / `---@field targets? Player[]`；`ask.zone` 与 `Condition.zones` **撤掉**（见 D6）。

### D2 候选从哪来（`zone` / `card` 是来源，`name` / `target` 是纯筛选）

| 条件 | 候选 |
| --- | --- |
| 给了 `zone` | 那些区里的牌（数组 = 并集） |
| 给了 `card` | 那批牌（可以不属于任何区 —— 【五谷丰登】亮出的牌） |
| 两样都给 | 上面两者的并集 |
| 都没给 | 被问者名下所有牌区的牌 |

- **`zone` 的名字按「被问者 → 局上」解析**（与 `moveCard` 同规则，只是起点是被问者）：`{ zone = '手牌' }` 就是"他被问时手上那些牌"；**别人的区要传区对象**（【过河拆桥】`{ zone = 目标身上有牌的区 }`）。
- 解析不出来（区名不存在）⇒ **这次询问算出空选项**（不给候选），与"条件把牌筛没了"同一个结果。

### D3 「使用」的语义由缘由触发：`reason == '使用'`

- 内核**认识 `'使用'` 这一个缘由取值**（其余缘由仍不解释）：`reason == '使用'` ⇒ 候选逐张跑 `game:canUse(to, card)`，用不了的牌（没有合法目标 / 次数用满 / 不在声明的牌区 / 内容侧 `'卡牌-能否使用'` 否决）**不进选项**；选项带 `targets` = 它的合法目标。
- 出牌阶段因此改成 `game:askCard(player, '使用', { zone = '手牌' })` —— 与今天 `{ targets = {} }` 的选项**逐项等价**（含"选项带各自的可用目标"），但语义回到「这次是要**使用**一张牌」。`'出牌'` 这个缘由退役（内容侧只有【闪】等"打出"路径在用 `'打出'`）。
- **为什么不由 `Condition` 表达**：官方「`'获取目标'` 返回至少 1 个合法目标才能使用」是**使用**的语义，内核本来就拥有它（`canUse` + 次数限制 + 牌区声明），条件只该描述"要什么样的牌"。

### D4 `target` 的新语义（`{}` 不再是特例）

- 给了 `target` ⇒ 「**合法目标 ∩ 给定名单 ≠ ∅**」（数组 = 其一），选项里的 `targets` = 那个**交集**（于是应答方只能从名单里选）。
- 所以需要跑 `canUse` 的判据 = **`reason == '使用'` 或 给了 `target`**（给了 `target` 就说明"要能用得上"）；此时选项必定带 `targets`（非空），答复必须给目标。
- `target = {}` ⇒ 没有任何"其一" ⇒ **没有候选**（旧的「至少有一个合法目标」特例随 `targets = {}` 一起退役）；正常写法里不会出现空表，内核也不为它特判。

### D5 一律逐张给 `card`（不管明暗）

- 过河拆桥 / 顺手牵羊 因此变成：

  ```lua
  -- 过河拆桥：{ zone = 目标身上有牌的区 }
  local ask  = game:askCard(user, '过河拆桥', { zone = table.filter(target:getZones(), 有牌) })
  local card = ask.card
  if card then
      game:moveCard(card, '弃牌')
  end
  ```

  顺手牵羊同形（多一条距离条件，拿到的东西进自己的手牌）。
- `Zone.visible` / `setVisible` / `isVisibleTo` / `owner` **留着但不再参与候选**：它们是将来协议层"哪些区的牌要换成『未知卡牌』"的输入（`@基础/牌堆.lua` 里 `手牌` 仍标暗）。

### D6 撤掉的东西（上一批为「盲选」加的，新口径下没有用户）

- `AskCard.Condition.zones`、`AskCard.Option.zone`、`AskCard.Answer.zone`、`AskCard.__getter.zone`；
- `server/test/rule/support.lua` 里为"答区域"加的 `(Card|AskCard.Answer)[]` 与 `---@cast`（回到 `Card[]`）；
- `server/core/effect/ask-card.lua` 里 `collectOptions` / `answerProblem` 的区域分支。

### D7 落点

- 内核：`server/core/effect/ask-card.lua`（`Condition` / `Answer` / `Option` / `collectOptions` / `optionOf` / `answerProblem`）。
- 内容：`@基础/回合.lua`（`'使用'` + `{ zone = '手牌' }`）、`@基础/濒死.lua`（`target = player`）、`标准/卡牌/{过河拆桥,顺手牵羊}.lua`（逐张候选）、`标准/卡牌/五谷丰登.lua`（`card = 剩余`）。
- 用例：`core.effect.ask-card`（新语义各条 + 撤掉区域用例）、`rule/{support,turn,trick,slash,dying}`。
- 文档：`architecture.md` §12 的 `askCard` 行与「询问与应答方」、牌区可见性那条（改成"协议层的输入"）、`progress.md`、`sanguosha-rules` §6/§7/§9.10 的写法示例。

## 可延后的问题

- **协议的遮蔽与「秘密映射」**（哪些区要遮蔽、映射怎么做、客户端选完怎么映射回来 / 丢弃重抽）—— 会话与协议批次。
- **`name` 数组**：现在没有用户（都是单值），语义先定下、等"要从若干牌名里选一个"的场景（如技能）再用。
- **`askSkill` / `timeout`**：仍另开一个类；届时 `AskCard` 的名字与"要牌"的关系一并谈。
