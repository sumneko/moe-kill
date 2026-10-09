# 设计：面板与 `askPanel`

## D1 `Panel` 的形状

```lua
-- 全局（内容包拿不到 `moe`，所以跟 `Card` / `Skill` / `Hero` 一样由内核装成全局）
---@param reason? string        # 这次为什么摆（内容侧定，原样带到应答方）
---@param visible? Visibility  # 牌面的可见性（`true` = 都看得见、一批角色 = 只有他们；看不见 = 背面朝上）
---@param options? Panel.Options  # 选项（服务器不解释语义，只照它校验）
local panel = createPanel('观星', skill.owner, { moveable = true })
    : row(shown:list(), '牌堆顶')   -- 行（第一行是 1 号；行内有序；标题只给客户端展示）
    : row({},           '牌堆底')
```

| 成员 | 作用 |
| --- | --- |
| `Panel:row(cards, title?)` | 追加一行（**行序号 = 1 起，协议里就用它**；`title` 只是给客户端排版的标题）；返回自己（可链） |
| `Panel.rows` | 各行（`Panel.Row[]`：格带着 `disabled` / `marks` 状态；**被禁用的牌仍留在行里**） |
| `Panel.cardsByRow` | 各行按顺序的牌（`Card[][]`，就是询问结果里 `rows` 那个形状） |
| `Panel:cards()` | 面板上所有牌（按行序） |
| `Panel:disableCard(card)` | 禁用一张（**不挪走**：它仍留在行里，只是「不能再动 / 不能再选」，界面据标记显示「被谁拿走了」） |
| `Panel:isDisabled(card)` | 查询某张在不在、被不被禁用（兜底取「第一张可用的」就用它） |
| `Panel:addMark(card, text)` / `Panel:marks(card)` | 给某张牌挂一条展示用标记（`'${hero:{name}}'` 这类模板由内容侧定，内核只存字符串、不解释） |
| `Panel.visible` / `Panel:isVisibleTo(视角)` | 牌面的可见性（**面板本身人人可见** —— 连「几行、每行几张」都看得见） |

- **牌仍住在区里**：面板是「布局 + 交互状态」的**视图**，不是新的容器 ⇒ `placeTop` / `moveCard` 照旧按「牌在哪」办事；面板不负责搬牌。
- **寿命**：`Panel` 是 `GCHost` ⇒ 观星 `<close>`（这次发动结束）、五谷 `useCard:bindGC(panel)` ⇒ 沿用「挂谁 = 活多久」。
- **与区级可见性无关**（用户 2026-10-09 定）：区照旧 `setVisible`；面板管的是「这份牌面给客户端怎么看」。

## D2 `askPanel` 的形状（一次询问「开着」到点确定）

```lua
local result = game:askPanel(被问者, 缘由, 面板)
-- result = { rows = 面板各行（当前形状）, card = 选中那张（如有） }
```

- **一次询问可以有多次往返**（这是新的交互模式）：`AskPanel:settle()` 循环 fire `'面板-询问'`，每次回复是**变化值**；直到某一回复里 `done = true` 才定结果（上限 1000 次，防止答复不前进）。
- **每次回复（应答方返回的）**：

  | 字段 | 含义 |
  | --- | --- |
  | `moves = { { cards = Card\|Card[], row = integer }, … }` | **移动型变化**：「把这串牌按这个顺序放到第 `row` 行（插到该行末尾）」—— 行内重排也能用它表达（把该行整体重放一遍）。**合法才应用**：每张都在面板上、没被禁用、`row` 存在、选项允许 `moveable` |
  | `card = Card` | **挑选型变化**：选中一张（必须**在面板上且没被禁用**）；记进这次的选中集合 |
  | `done = true` | 点确定了：按 `min` / `max` 校验选中张数 ⇒ 定结果 |

- **服务器只校验「这条变化合法吗」**，不解释「这是选择还是移动」（选项不赋予语义，只当约束）。
- **result 恒含 `rows`**（不允许移动的面板 ⇒ `rows` 就是创建时的形状）；`card` **有选择才有**（挑选型面板读它）。
- **`min` 默认 0** = 不必选牌也能确定；`cancelable` 保留（与 ask 系列同一套字段，面板不特例）。
- 时机名 **`'面板-询问'`**（与 `'卡牌-询问'` / `'决策-询问'` / `'技能-询问'` 同族）；载荷 = 这次询问（`AskPanel`）。
- **不做的事**：不校验「整块面板的守恒」（用户定：只验每条变化），所以观星的「两行合起来 = 全部牌」是**内容侧的读法**（它读 `result.rows` 直接 `placeTop` / `placeBottom`，牌本来就一张不多不少）。

## D3 两个消费者

**【观星】**（`min = 0`；**无论问没问成、答复到了哪一步，都照面板当前的形状放回** —— 摆的事本来就记在面板上）：

```lua
local panel = createPanel('观星', skill.owner, { moveable = true, min = 0 })
    : row(shown:list(), '牌堆顶')
    : row({},           '牌堆底')
game:askPanel(skill.owner, '观星', panel)
local rows = panel.cardsByRow
deck:placeTop(rows[1])
deck:placeBottom(rows[2])
```

**【五谷丰登】**（`min = 1` + 兜底）：

```lua
-- '使用'：亮出的牌摊成一行，面板挂到这次使用上（活到这次使用结束）
local panel = createPanel('五谷丰登', true, { min = 1, max = 1, cancelable = false }):row(cards)
useCard:bindGC(panel)
useCard:setTag('panel', panel)

-- '生效'（逐目标）：
local card = game:askPanel(target, '五谷丰登', panel).card
if not card then
    -- 底本「每名目标角色获得其中一张」⇒ 没答（超时之类）就替他拿第一张还能用的
    for _, one in ipairs(panel:cards()) do
        if not panel:isDisabled(one) then
            card = one
            break
        end
    end
end
if not card then
    return
end
panel:disableCard(card)
panel:addMark(card, '${hero:{name}}' % { name = target:getName() })
game:moveCard(card, target:getZone('手牌'))
```

## D4 协议面（`specs/` 增量）

本变更**不设 `skip_specs`**：面板的表示与「一次询问的往返」是对外契约（客户端要据此渲染与回话）。增量写进 `specs/card-panel/spec.md`：① 面板的形状（行 / 顺序 / 禁用 / 标记 / 牌面可见性 / 布局与张数人人可见）；② 一次询问的往返（变化 → 校验 → 状态更新 → `done` 定结果）；③ 校验失败的处理（拒收这条变化、面板状态不变）。

## D5 落点

| 面 | 文件 | 改什么 |
| --- | --- | --- |
| 内核 | `server/core/panel.lua`（新） | `Panel` 类型 + `moe.panel.create`；`row` / `rows` / `cards` / `disableCard` / `isDisabled` / `addMark` / `visible` / `isVisibleTo`；`GCHost` |
| 内核 | `server/core/effect/ask-panel.lua`（新） | `AskPanel : Effect`（`settle` 循环 + 变化校验 + result 形状） |
| 内核 | `server/core/game.lua` | `game:askPanel(被问者, 缘由, 面板)` |
| 内核 | `server/core/loader/env-meta.lua` | `'面板-询问'` 的订阅面与载荷类型；`createPanel` 全局声明；`Panel` / `Panel.Options` / 变化类型 |
| 内核 | `server/core/loader/*` | 把 `createPanel` 装成内容侧全局（与 `Card` / `Skill` / `Hero` 同处） |
| 内核 | `server/core/effect/init.lua` | include 新文件 |
| 内容 | `package/标准/武将/诸葛亮.lua` | 观星：占位分配 → 面板版（D3） |
| 内容 | `package/标准/卡牌/五谷丰登.lua` | 面板版 + 兜底（D3） |
| 用例 | `server/test/core/panel.lua`（新）/ `ask-panel.lua`（新） | 面板成员 + 询问往返与校验 |
| 用例 | `server/test/rule/hero-skill.lua` / `trick.lua` | 观星改成按答复放回；五谷丰登共享面板 + 兜底 |
| 文档 | `architecture.md` / `sanguosha-rules` / `progress.md` / specs 增量 | 见 proposal |

## D6 反向验证

| 拆掉什么 | 结果 |
| --- | --- |
| 观星的 `placeBottom` | **1 红** ⇒ 上批那条「只注掉 `placeBottom` 也 0 红」的已知缺口钉住了 |
| 观星改成「全放顶」（不照面板形状） | **2 红** ⇒ 两条摆过底堆的观星用例都钉住了 |
| 变化校验（不验就应用） | ⏳ 待做 |
| `min` 的确定校验 | ⏳ 待做 |
| 五谷丰登的兜底 | ⏳ 待做（连带 4.x 一起做） |
