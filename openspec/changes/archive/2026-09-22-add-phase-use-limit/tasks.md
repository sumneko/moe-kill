# Tasks

## 1. 内核：阶段成为一等对象

- [x] 1.1 `server/core/phase.lua` 新建 `Phase` 类：公开字段 `name` / `player` + 不透明标签袋（`setTag` / `getTag` / `removeTag`，与 `Player` 同形状）+ `__tostring`；验证：`server/test/core/phase.lua` 里能建实例并读写标签
- [x] 1.2 阶段实例上的两本账与四个接口：`addUseCount(名字, 次数变化)` / `getUseCount(名字)`（默认 0）/ `addLimit(名字, 次数变化)` / `getLimitDelta(名字)`（默认 0）；账**只按名字**（不分玩家）；验证：用例覆盖增减与默认值、负值可减
- [x] 1.3 `Phase:__close()` = `Delete(self)`、`Phase:__del()` = 离开阶段（触发 `'阶段-结束'` → 出栈 → `game.phase` 回到上一层或空）；不是栈顶就报错；验证：用例覆盖 `<close>` 结束与嵌套 LIFO、非栈顶报错
- [x] 1.4 `server/core/game.lua`：`phaseStack`（私有）+ `phase`（公开字段，初始为空）+ `game:enterPhase(player, name)`（校验 + 压栈 + 触发 `'阶段-开始'` + 返回实例）；阶段栈**不放进** `resetContent`（重装规则集不清栈，与号源 `nextId` 同样处理）；验证：用例覆盖进入触发事件、`game.phase` 回退、重装内容后栈照常
- [x] 1.5 `server/core/init.lua` 的 include 清单加 `core.phase`（`Phase` 由 `game:enterPhase` 建，**不需要门面工厂**，所以没有 `moe.phase`）；验证：`server/bin/moe-kill.exe --test core.phase` 能跑通
- [x] 1.6 `CardDef:limit(阶段名, 次数)`（链式，返回 `self`）/ `CardDef:getLimit(阶段名)`（**没为这个阶段声明过就返回 1000**）；阶段名是不透明字符串（内核不校验取值）；验证：用例覆盖按阶段写与读、同名重复写后者覆盖、没声明得到 1000
- [x] 1.7 `server/core/loader/env-meta.lua` 同步类型：`Phase` 类（含四个账接口）、`'阶段-开始' / '阶段-结束'` 的 ctx 换成 `Phase`、`Game.enterPhase` 与 `Game.phase` 字段、`CardDef:limit / getLimit`；验证：问题面板 information 及以上 0

## 2. 内核：按次数的限制

- [x] 2.1 `game:canUse` 加一条**内建条目**：阶段存在且 `phase.player == user` 时，`phase:getUseCount(名字) < CardDef:getLimit(阶段名) + phase:getLimitDelta(名字)` 不成立就返回原因（“本阶段已经用过「{}」了”），**不触发 `'卡牌-能否使用'`**；阶段不属于使用者或不在阶段里就不判；验证：用例里挂一个计数用的 `'卡牌-能否使用'` 回调，超额时断言它**一次都没跑**
- [x] 2.2 `UseCard:settle()` 在校验通过之后记账（`phase:addUseCount(名字, 1)`，条件同 2.1）；`canUse` 保持只读（不能在里面记账，它会被筛选项调用几十次）；验证：用例覆盖用一次后账 +1、阶段外 / 别人的回合不记账
- [x] 2.3 复核内建条目与内容侧条目的先后：内建不通过时不得触发 `'卡牌-能否使用'`；内建通过的内容侧仍可否决（回归 `server/test/rule/` 全绿）

## 3. 内容侧与用例

- [x] 3.1 `package/@基础/回合.lua` 改用 `game:enterPhase(player, 阶段名)` + `<close>`，删掉自己 `fire` 的阶段时机；验证：`server/test/rule/turn.lua` 的六阶段用例改为读 `ctx.player` / `ctx.name` 后通过
- [x] 3.2 `package/标准/卡牌/杀.lua` 用 `Card '杀' : limit('出牌', 1)` 声明限额；验证：回合用例里【杀】的限额仍然生效，且用完一张后选项里不再有【杀】
- [x] 3.3 **删除 `package/@基础/使用限制.lua`**（用户 2026-09-22 同意）；删前 grep 实例名与文件名确认无引用；验证：全量用例照常绿
- [x] 3.4 `server/test/rule/` 补用例：阶段事件上下文、两种口径（`addUseCount('杀', -1)` 后还能再用 / `addLimit('杀', 1)` 后额度 +1 / `addLimit('杀', 1000)` 后超额也能用）、**别人的回合里用牌不计数也不受限**；验证：`server/bin/moe-kill.exe --test rule` 全绿

## 4. 文档与验收

- [x] 4.1 `moe-kill-dev/references/architecture.md`：时机清单里阶段 ctx 的说明、接口表加 `enterPhase` / `Phase`（含两本账的四个接口）/ `CardDef:limit`、`canUse` 的内建条目多一条次数检查、在 §8.4 的跨重载载体里说明阶段栈与号源同样挂在局实例上；验证：文档与代码一致（读一遍对得上）
- [x] 4.2 `.agents/skills/sanguosha-rules/SKILL.md`：§3 回合流程（内核触发阶段时机）、§9.2 与次数口径（两种口径各自怎么调接口、限制已在内核）；验证：与 `package/` 实际写法一致
- [x] 4.3 `moe-kill-dev/references/progress.md`：内核现状（阶段、限额、两本账、内核内建次数检查、`@基础/使用限制.lua` 已删）与用例数；验证：数字与 `--test` 输出一致
- [x] 4.4 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀，正文写清 BREAKING 的阶段 ctx 变更与删除的文件）
