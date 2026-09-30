# Proposal

## Why

上一批只做了技能的**定义**（名字 / 发动方式 / 标签），`: skills { … }` 里的技能名依然没有任何生效路径 —— 技能挂不到角色身上、定义里也登记不了时机。用**第一个真技能【奸雄】**把这条链路打通：

> 【奸雄】（标准版，经典曹操；来源 BWIKI「奸雄」页）：**当你受到伤害后，你可以获得对你造成伤害的牌。** —— 有「可以」⇒ 与底本 `Chapter2/Section5`「可」条第 2 款一致：**可以不发动** ⇒ `kind '被动'`。

实现它顺带暴露了两个真缺口：**技能怎么订阅时机**、**「造成伤害的牌」内核里根本没有**。

## What Changes

- **`SkillDef:on('被动', 回调)`** + 读法 `getHandlers(钩子)`（照 `BuffDef`）：技能**唯一的钩子是「被动」**，**每次启用**跑一次、回调收 `(skill, host)`（实现过程中按用户口径从「内核自动订阅登记的时机」改成这个 —— 与装备技能逐字同款）。
- **`Skill : GCHost` 实例** + **`Player:addSkill(名字)`**（照 `addBuff`）：**挂上即启用**（跑一次「被动」、给它 `host`），内容侧在那里 `host:bindGC(owner:on(...))` 订阅 / 建状态（照装备技能）；**`skill:disablePassive()` / `enablePassive()`** 停用与恢复（技能被克制 / 封印时用）；`skill:remove()` 摘掉、容器跟着放掉；配 `removeSkill` / `getSkills`（快照）/ `hasSkill`。
- **`Damage.card?`**（造成伤害的牌）+ **`game:damage(from, to, amount, card?)`** 第 4 个可选参数；5 处造成伤害的牌（【杀】/【决斗】/【南蛮入侵】/【万箭齐发】/【闪电】）把 `cardEffect.card` 传进去。
- **`'伤害-结束'` 对承受者再发一份**（时机名 **`'伤害-目标-结束'`** —— 照「对当事人再发一份时玩家的那份带「来源」/「目标」」这条规则）⇒ 内容侧写 `owner:on('伤害-目标-结束', ...)` 不用自己比字段。
- **【奸雄】**写进 `package/标准/武将/曹操.lua`（与武将定义同文件）：被动、问「发动」、拿到那张牌。

## Capabilities

无。本变更属探索期的**决策记录**，不写规格增量（`.openspec.yaml` 设 `skip_specs: true`）。可执行契约由用例承担，见 `AGENTS.md`「工作流」。

## Impact

- 内核：`core/skill.lua`（钩子 + `Skill` 实例）、`core/player.lua`（技能四件套）。
- 内容侧：`@基础/伤害.lua`（`card` + 当事人份）；`标准/卡牌/{杀,决斗,南蛮入侵,万箭齐发,闪电}.lua`（传牌）；`标准/武将/曹操.lua`（【奸雄】）。
- 测试：`core.skill` +2、新套件 `rule.skill`（3 条端到端）。
- **本批不做**：`setHero` 里自动挂技能（等主公技的时序口径定下来）、主动技的发动入口、主公技过滤、【护驾】。
- 文档：`references/architecture.md`、`progress.md`、`sanguosha-rules`。
