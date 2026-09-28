# Design

## 1）为什么四个都能搬

判据沿用判定那次：**内核那层里如果只剩机制，就该搬**；顺带看内核是否还「认识」这个规则概念。

四个类的内核实现都是「fire 时机 + 工厂」，规则判断全在 `@基础` 的订阅里 —— 搬过去不改变任何行为，只是让「伤害 / 回复 / 摸牌 / 濒死」不再出现在 `server/core/`。搬完内核剩下的效果全是机制：`Effect` 基类、`UseCard` / `CardEffect` / `CardEffectToCard`（用牌链，与 `canUse` / 卡牌目标 / 次数账咬在一起）、`Ask*` 家族、`MoveCard`。

两处本来就属于规则层的判断，顺手收回内容侧：

- `Draw:settle()` 里的「**已阵亡的不摸**」；
- `Dying:settle()` 里的「**没脱离就 `setAlive(false)`**」。

## 2）濒死账的落点：玩家标签袋（用户 2026-09-28 选「乙」）

现状是局上的私有字段 `game.dyingMap` + 三个方法（`enterDying` / `getDying` / `clearDying`）。搬到内容侧时账要有个落点，三个候选：

- **甲：留内核**。改动最小，但内核继续认识「濒死」这个规则概念 —— 与本次方向相反。
- **乙：玩家标签袋**（`player:setTag('濒死', dying)`）—— **采用**。理由：「一个玩家现在处于哪个濒死状态」本来就是**这个玩家身上的状态**；`setTag` / `getTag` / `removeTag` 是内核早就提供的**通用**能力（与 `Phase` 同形），内容侧用它不需要内核新增任何概念。
- **丙：内容侧全局表**。跨文件要靠共享全局、且语义不如挂玩家准（「这个玩家的状态」写在「一个包的表」里）；`game:setValue`（规则数值袋）同理，语义更歪。

配套：`getDying(player)` 保留为**内容侧接口**（`身份场/奖惩.lua` 现在用它读凶手，语义清晰），实现就是读那个标签。`Dying:leave()` 与 `Dying:settle()` 自己清标签 ——

```lua
function Dying:settle()
    self.game:fire('濒死-进入', self)
    if self.left then return end
    self.player:setAlive(false)   -- 先死：'玩家-死亡' 里那次濒死的账还在（奖惩据此读凶手）
    self.player:removeTag('濒死')  -- 再清账
end
```

顺序与内核旧版（`setAlive(false)` → `clearDying`）逐字一致 ⇒ 行为不变。

## 3）类名与 `kind` 保持原值

`Damage` / `Heal` / `Draw` / `Dying` 与 `kind = 'damage' / 'heal' / 'draw' / 'dying'` **都不改**：

- 命名约定是「代码用英文」（这几个都是好翻译的通用词）；判定那个中文类名是**内容术语**的既有先例，不套用；
- 它们是**内核概念**（用户口径：基础规则就是内核），换了名字反而像「改造成了内容概念」；
- 保持原值 ⇒ 四个内核套件、若干断言与类型名一行都不用改。

## 4）测试口径：默认包本来就在装

内核测试一律 `moe.game.create { seats = count, random = random }`（**省略清单 ⇒ 装默认加载的包**）⇒ `@基础` 一直在跑。所以：

- `server/test/core/effect/{damage,heal,draw,dying}.lua` **保留原样**（它们测的就是默认规则层；`core.effect.damage` 里「改体力属规则侧」这条断言本来就是在断言 `@基础` 的订阅）；
- `core.effect.{init,play,ask-*}` 里借 `game:damage` 当**过程效果探针**的用法照旧（入口由内容侧装上，方法名不变）；
- 唯一要改的是 `server/test/core/game-over.lua` 里直接调 `moe.damage.create { … }` 的那处 —— 工厂没了，改成 `game:damage(from, to, amount)`。

## 5）什么时候「搬」、什么时候「留」

这次一并定下判据（写进文档）：

- **搬**：内核那层只剩「fire 时机 / 造实例 / 转发」的效果 —— 它的规则与流程都在内容侧；
- **留**：与内核机制咬在一起的效果（用牌链要看卡牌定义与目标校验、询问要挂起任务、挪牌要动牌区）；
- **永远留内核**：`Effect` 基类本身（内容侧要拿它声明子类）。
