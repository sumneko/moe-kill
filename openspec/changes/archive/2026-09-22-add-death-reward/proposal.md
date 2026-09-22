# Proposal

## Why

官方死亡时序是「死亡 → **奖惩** → 胜负判定」，现在只做了两头：`'玩家-死亡'` 触发后，`package/身份场/胜负.lua` 直接把游戏判结束。**奖惩**（杀死反贼摸三张、主公杀忠臣弃所有牌）是这条链里唯一缺的一环。

还差一个前提：**「谁杀的」没人记**。`'玩家-死亡'` 只带死者，内核的濒死链路（`Damage` → 体力 ≤0 → `enterDying` → `Dying`）里，那次伤害实例在中途就丢了 —— 奖惩无从判断凶手。

另外按用户口径补两处：濒死要能区分**进入 / 离开**（救活也是规则事件），摸牌对**已阵亡**的角色应当无效（奖惩照发、由 `draw` 拦掉）。

## What Changes

- **内核：濒死当场结算，并带上「这次伤害」**
  - `game:enterDying(player, damage?)` 改成**当场把濒死结掉**（返回结完的 `Dying`）：`Dying` 持有那次伤害实例（`.damage`），`'濒死-进入'` 的上下文就是它 ⇒ 规则侧读 `ctx.damage` 就知道是谁打的那一下（`damage.from`），也拿得到牌 / 点数。内核只搬运、不解释（不知道点数、不认识“凶手”）。
  - **时序（用户 2026-09-22 核对后定）**：濒死**早于 `'伤害-后'`** —— 检查点在扣完血之后、`'伤害-后'` 之前，于是「受到伤害后」类技能在濒死（连带的死亡 / 奖惩 / 胜负）之后才跑。
  - 旧的延迟机制（`dyingPending` 记账 + `flushDying()` 收尾结算 + `enterDying` 返回 disposer 供撤销）**一并删掉**：濒死不需要“等结算收尾”也不需要“事后撤销”。
- **内核：濒死时机改名 + 新增离开时机（BREAKING）**
  - `'濒死'` → **`'濒死-进入'`**（上下文 = `Dying`）。
  - 新增 **`'濒死-离开'`**：`Dying:settle()` 收尾时**玩家还活着**就触发（没救活不触发，走 `'玩家-死亡'`）—— 内容包按约定不主动 `fire`，所以由内核判「存活」（内核只认存活、不认识体力）。
- **内核：摸牌对已阵亡的角色无效**：`game:draw` / `Draw` 在目标已阵亡时**直接完成**（不触发 `'摸牌'`、不摸牌、不算失败）。于是奖惩可以照口径无条件调用，死者的那份由内核拦掉（用户 2026-09-22 定）。
- **内容侧：检查点与记账**
  - `@基础/伤害.lua`：扣完血之后（同一个 `'伤害-生效'` 回调里）**血量 ≤0 就 `game:enterDying(玩家, 这次伤害)`** —— 濒死不再靠监听属性变化。
  - `@基础/濒死.lua`：**删掉体力变化监听与那套撤销**，只订阅 `'濒死-进入'`（求桃、没人救就 `setAlive(false)`）；进入时把凶手（`ctx.damage and ctx.damage.from`）记到死者标签上，`'濒死-离开'`（被救活）时清掉。
- **内容侧：死亡奖惩**（新文件 `package/身份场/奖惩.lua`）
  - 杀死**反贼** ⇒ 凶手摸 3 张（`game:draw(凶手, 3)`；凶手已阵亡 ⇒ 内核拦掉）。
  - **主公**杀死**忠臣** ⇒ 主公弃置其所有手牌（装备牌等装备批次；装备区还不存在）。
  - 注册顺序：奖惩的 `'玩家-死亡'` 钩子必须**在胜负判定之前**跑 ⇒ `package/身份场/胜负.lua` 顶部 `Depends { './奖惩' }` 定序（依赖先加载、先注册）。

## Capabilities

### New Capabilities

无（探索期不写规格：见 `openspec/config.yaml` 与 `AGENTS.md` 的「工作流」，本变更在 `.openspec.yaml` 里设 `skip_specs: true`，契约以用例为准）。

### Modified Capabilities

无（同上）。

## Impact

- 内核：`server/core/effect/dying.lua`（持仓、两个时机）、`server/core/effect/draw.lua`（死者不摸）、`server/core/game.lua`（`enterDying(player, damage?)` 当场结、删掉 `flushDying` 与记账）、`server/core/effect/init.lua`（`apply()` 尾部不再 flush）、`server/core/loader/env-meta.lua`（两个濒死时机的类型）。
- 内容：`package/@基础/伤害.lua`（扣完血判 ≤0 并进濒死）、`package/@基础/濒死.lua`（删监听与撤销）、`package/身份场/奖惩.lua`（新）、`package/身份场/胜负.lua`（加 `Depends`）。
- 用例：`server/test/core/effect/dying.lua`（时机会名 + 携带伤害）、`server/test/core/effect/draw.lua`（死者不摸）、`server/test/rule/dying.lua`（进入 / 离开）、`server/test/rule/game-over.lua` 或新增一条奖惩端到端。
- 文档：`moe-kill-dev` 的 `references/architecture.md`（§12 的 `dying` / `draw` 行）、`references/progress.md`；`sanguosha-rules` 的 §2（奖惩已落地）、§7 与 §9.4（时机名与濒死时序）。
