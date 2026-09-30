# Tasks

## 1. 内核：技能生效与挂载

- [x] 1.1 `server/core/skill.lua`：`SkillDef:on(钩子, 回调)` / `getHandlers(钩子)`；新增 `Skill : GCHost` 实例（`name` / `owner` + 私有的 `def` / `game` / `passiveSuppress` / `passiveHost`；`remove()`、`enablePassive()` / `disablePassive()`（对称、各返回 disposer、层数计数）、`---@private` 的 `applyPassive()`（建 `host` + 跑「被动」）/ `removePassive()`（`Delete(host)`）、`__del` 里先放容器再 `owner:removeSkill(self)`）
- [x] 1.2 `server/core/player.lua`：`skills` 字段 + `addSkill(名字)`（没定义就报错；建实例、登记、**启用**）/ `removeSkill` / `getSkills`（快照）/ `hasSkill`

## 2. 「造成伤害的牌」

- [x] 2.1 `package/@基础/伤害.lua`：`Damage.card?` + `Damage:__init(…, card?)` + `Game:damage(from, to, amount, card?)`；**`'伤害-结束'` 对承受者再发一份（`'伤害-目标-结束'`）**
- [x] 2.2 五处调用点传 `cardEffect.card`：【杀】/【决斗】/【南蛮入侵】/【万箭齐发】/【闪电】

## 3. 【奸雄】

- [x] 3.1 `package/标准/武将/曹操.lua`：`Skill '奸雄' : kind '被动' : on('被动', …)`（里面 `host:bindGC(owner:on('伤害-目标-结束', …))`）—— 没有牌就不问；问 `askChoice '发动'`（不答 = 不发动）；发动就把那张牌移进手牌；文件顶部补官方描述

## 4. 测试

- [x] 4.1 `server/test/core/skill.lua` +3：挂上就跑一次「被动」（`host` 里订的生效、`remove()` 后不再触发）；**停用后收不到、重新启用又收得到**；没有定义就报错
- [x] 4.2 `server/test/rule/skill.lua`（新，并在 `server/test.lua` 注册）：【奸雄】发动 ⇒ 拿到那张【杀】、不进弃牌堆、伤害照常；不发动 ⇒ 照常进弃牌堆；**没有「造成伤害的牌」时连问都不问**

## 5. 验收

- [x] 5.1 `server/bin/moe-kill.exe --test` 全绿（807 用例 0 失败）
- [x] 5.2 问题面板 information 及以上清到 0
- [x] 5.3 同步文档：`references/architecture.md`（`SkillDef` 行补钩子、`Player` 行补技能四件套、`Damage` / `game:damage` 补 `card`、`'伤害-结束'` 的当事人份）、`references/progress.md`（§1 条目 + 基线 + §2 武将系统行）、`sanguosha-rules`（§9.15 补生效口径 + 【奸雄】）
- [x] 5.4 类型面：新增的 `'伤害-目标-结束'` 在 `@基础/meta.lua` 里按名收窄（`Player` 一块、`SkillDef` 一块，各**自带 `name: string` 兜底**）；试过合并成一个公共类共用（`self: any` 确实可行），但两者回调形状不同 ⇒ 候选注定各写一条、兜底又必须跟着写 ⇒ **合并无收益，已拆开**
