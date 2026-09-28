# Proposal

## Why

判定搬走之后（`move-judge-to-package`），内核里还剩四个**只 fire 时机**的薄壳效果：

| 类 | 内核那段 | 规则在哪 |
| --- | --- | --- |
| `Damage` | fire `'伤害-前'` / `'伤害-生效'` / `'伤害-后'` + `moe.damage` 工厂 | `@基础/伤害.lua`（扣体力、≤0 进濒死） |
| `Heal` | fire `'回复-前'` / `'回复-生效'` / `'回复-后'` + 工厂 | `@基础/回复.lua` |
| `Draw` | fire `'摸牌-生效'` + 工厂（外加一句「已阵亡的不摸」） | `@基础/抽牌.lua` |
| `Dying` | fire `'濒死-进入'` / `'濒死-离开'` + `leave`/`hasLeft` + 判死 + 工厂 | `@基础/濒死.lua` |

加上它们的入口（`game:damage` / `heal` / `draw` / `enterDying` / `getDying` / `clearDying`）、那本濒死账（`game.dyingMap`）与 `env-meta.lua` 里 18 行时机声明 —— 内核继续**认识**「伤害 / 回复 / 摸牌 / 濒死」四个规则概念。用户 2026-09-28 定：这四个也搬进 `@基础`。

**口径（用户 2026-09-28 明确）**：**基础规则就是内核的一部分**（默认层），只是落点在 `package/@基础`、从而可被 mod 覆盖 —— 搬家的意义**不是**「把规则赶出内核」，而是「把默认实现放到可替换的位置」。

## What Changes

- **四个类搬进同名内容文件**（判定先例：类 + 订阅 + 入口一个文件）：`Damage` → `package/@基础/伤害.lua`、`Heal` → `回复.lua`、`Draw` → `抽牌.lua`、`Dying` → `濒死.lua`（文件名不变，文件数不增）。
- **入口由内容侧装上**：`Game:damage` / `heal` / `draw` / `enterDying` / `getDying`（`Class 'Game'`）；内核 `game.lua` 删掉这六个方法与 `dyingMap` 字段。
- **濒死账搬内容侧（用户 2026-09-28 选乙）**：账挂在**玩家标签袋**上（`player:setTag('濒死', dying)`），不再是局上的私有字段；「已在濒死就复用那一次、把致死伤害换成新的」写进内容侧的 `Game:enterDying`。
- **`moe.damage` / `moe.heal` / `moe.draw` / `moe.dying` 四个门面工厂删**（内容侧用 `New` 造实例）。
- **类型面**：`env-meta.lua` 里这 18 行时机重载挪进 `package/@基础/meta.lua`。
- **类名与 `kind` 不变**（`Damage` / `kind = 'damage'` …）—— 它们是内核概念，不改成内容术语。
- **顺带把两条规则收回规则层**：`Draw` 的「已阵亡的不摸」、`Dying` 的「没脱离就 `setAlive(false)`」。
- **内核测试四个套件保留原样**：`moe.game.create { seats, random }` 省略清单本来就装默认包，`core.effect.{damage,heal,draw,dying}` 照旧跑；只有 `core/game-over.lua` 里直接调 `moe.damage.create` 的那处改 `game:damage`。

## Capabilities

### New Capabilities

无。探索期的架构决策记录，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。

### Modified Capabilities

无（同上）。

## Impact

- 内容：`package/@基础/{伤害,回复,抽牌,濒死}.lua`（各加类与入口）、`package/@基础/meta.lua`。
- 内核：`server/core/effect/{damage,heal,draw,dying}.lua`（删）、`effect/init.lua`、`game.lua`、`loader/env-meta.lua`。
- 测试：`server/test/core/game-over.lua`（一处）。
- 文档：`architecture.md`（§10 时机清单、§12 效果族与局入口）、`SKILL.md`、`progress.md`、`sanguosha-rules/SKILL.md`。

## Non-goals

- 不动 `UseCard` / `CardEffect` / `CardEffectToCard` / `Ask*` / `MoveCard` 与 `Effect` 基类（它们是机制）。
- 不新增 / 不改时机名，不改类名与 `kind`。
- 不改 `game:drawCards`（内核的抽牌工具，与「摸牌」这次结算不是一回事）。
