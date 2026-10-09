# Proposal

## Why

标准包余下几将里，大乔是**只差「改目标」机制**的一个：

- **【流离】**（当你成为【杀】的目标时，弃一张牌并把此【杀】转给你攻击范围内的一名合法目标）—— 内核没有「改目标」的能力，而且**玩家对象上也没有「这张牌此刻的合法目标」这份读数**（`canUse` 的返回被丢掉了，而它给的名单还带着使用者的距离限制）。
- **【国色】**（把一张方块牌当【乐不思蜀】使用）—— 撞上「虚拟牌进不了牌区」：延时锦囊的使用结算要把牌放进判定区，`Zone:accept` 会把虚拟牌**降级成实体子牌** ⇒ 判定期会跑那张实体牌的『生效』（方块【杀】会对判定者要闪）✗ ⇒ **本批不做**（见 design 的 Non-Goals）。

## What Changes

- **内核：官方「转移」的落地 —— `UseCard:replaceTarget(换掉谁, 换成谁)`**
  - 依据：规则集 `Chapter2/Section5.md` 的「转移」条 —— 「取消此目标并生成一个与角色 B 具有对应关系的新的目标并将此目标加入此牌的目标列表，然后**将所有还未生成过『成为目标时』的目标重新排序**」。
  - 实现：改 `self.targets` 里的那个元素（**目标个数与其它目标不动**），并**立刻对新目标补发一遍三份「指定目标后」**（全局 → 使用者 → 新目标）。补发这条是「流离触发流离」的**必要条件**（新目标要生成「成为目标」）。
  - 生效那轮按 `self.targets` 现算 `desk:actionOrder` ⇒ 被换掉的不再生效、换上的会（正好是官方说的「重新排序」）。
- **内核：新读取口 `game:getLegalTargets(使用者, 牌, 选项?)`** = 「这张牌此刻的全量合法目标」
  - 它就是 `collectLegalTargets` 的公开版：跑牌的 `targets` 条件（含逐候选 `'卡牌-目标-能否指定'`），**不判「能不能用」、不合并选项、不看这次打算打谁**。
  - 顺手**拆 `canUse`**：牌本体那半 → `checkCardItself`（已有）、目标那半 → 新的局部 `checkTargets`，`canUse` 只剩「合并选项 → 判牌本体 → 判目标 → 问内容侧」四步。
- **内核：`ignoreDistance` 的声明搬出内核**（用户提）
  - 它只被 `@基础/距离.lua` 的 `isInRange` 读 ⇒ 按「谁读谁声明」搬进那个文件；内核自己读的只剩 `ignoreUseLimit` / `notCounted` / `extraTargets` / `unrespondable`。
- **内容：新武将 `package/标准/武将/大乔.lua`**（吴 · 女 · 体力上限 3）
  - **【流离】**：订 `'卡牌-目标-指定目标后'`（目标自己那份）→ 认牌名【杀】+ 只认「我是目标」→ 候选 = `getLegalTargets(使用者, 这张【杀】, 选项带 ignoreDistance)` ∩ 「大乔攻击范围内（**算距离**）」− 自己 → 一次 `askCardWithTarget` 拿「弃哪张 + 转给谁」（**没答 = 不发动**）→ `skill:cast` 里 `moveCard(弃牌)` + `useCard:replaceTarget(自己, 新目标)`。
  - 底本那两句判据**分开读**：①「你攻击范围内」要算距离；②「为此【杀】合法目标（**无距离限制**）」—— 括号修饰的是**后半句**（判合法性时不判距离）。

## Capabilities

### New Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）—— 理由见 `AGENTS.md`「工作流」。

### Modified Capabilities

无。`openspec/specs/` 已冻结、不回头改。（⚠️ `UseCard:replaceTarget` 与 `game:getLegalTargets` 都是**对外契约**（第三方包可见）—— 已同步进 `architecture.md` 与 `sanguosha-rules` §9.30。）

## Impact

- **内核**：`server/core/game.lua`（拆 `canUse` + 新 `getLegalTargets` + `ignoreDistance` 声明外移）、`server/core/effect/use-card.lua`（`replaceTarget`）
- **内容侧**：`package/标准/武将/大乔.lua`（新）、`package/@基础/距离.lua`（接管 `ignoreDistance` 的声明）
- **用例**：`server/test/core/effect/play.lua`（+2）、`server/test/core/can-use.lua`（+3）、`server/test/rule/hero-skill.lua`（+4）
- **文档**：`sanguosha-rules`（§9.2 补读取口、新增 §9.30 大乔）、`moe-kill-dev/references/architecture.md`（`canUse` 行、新 `getLegalTargets` 行、新 `replaceTarget` 行、`UseOptions` 声明归属）、`progress.md`（基线 / 23 将 / 缺口表划掉「改目标」）
- **明确不做**：【国色】（待「虚拟牌进判定区」的机制）；「已转移过」的标记（官方无禁止连锁的条文，弃牌代价 + 深度安全阀足够）
