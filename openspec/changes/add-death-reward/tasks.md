# Tasks

## 1. 内核：濒死当场结算 + 两个时机

- [x] 1.1 `Dying` 持有 `damage`（可选）：`Dying.CreateOptions.damage?`、`moe.dying.create` 透传、`Dying:__init(game, player, damage)`；验证：`moe.dying.create { …, damage = 某次伤害 }` 后 `dying.damage` 读得到
- [x] 1.2 `Dying:settle()`：触发 **`'濒死-进入'`**（原 `'濒死'` 改名，BREAKING）；收尾时 `player:isAlive()` 为真再触发 **`'濒死-离开'`**（没救活不触发）；验证：用例覆盖「救活 ⇒ 两个时机都有」「没救活 ⇒ 只有进入、后来触发 `'玩家-死亡'`」
- [x] 1.3 `game:enterDying(player, damage?)` 改成**当场结算**（`moe.dying.create` → 驱动 + 等 → 返回结完的 `Dying`，不再返回 disposer）
- [x] 1.4 **删掉旧的延迟机制**：`game.dyingPending` 记账、`game:flushDying()`、`Effect:apply()` 收尾的那次 `flushDying()` 调用（删掉的代码在 design 的 D6 里列了理由与影响面）；验证：全量用例绿（簿记相关的旧用例改掉或删掉）
- [x] 1.5 `server/core/loader/env-meta.lua`：`'濒死'` → `'濒死-进入'`，新增 `'濒死-离开'`（上下文都是 `Dying`）；验证：问题面板 information 及以上 0
- [x] 1.6 grep 全部 `'濒死'` 订阅点改掉（`@基础/濒死.lua`、`server/test/core/effect/dying.lua`、`server/test/rule/dying.lua`）；验证：`server/bin/moe-kill.exe --test` 全绿

## 2. 内核：摸牌对已阵亡角色无效

- [x] 2.1 `Draw:settle()` 开头：`not player:isAlive()` ⇒ 直接完成（不触发 `'摸牌'`）；验证：`server/test/core/effect/draw.lua` 补一条「死人不摸、不触发时机、不算失败」
- [x] 2.2 确认既有调用点不受影响（`@基础/抽牌.lua`、`@基础/回合.lua` 摸牌阶段、奖惩）；验证：`--test rule` 全绿

## 3. 内容侧：检查点与凶手记账

- [x] 3.1 `@基础/伤害.lua`：`'伤害-生效'` 里扣完血之后判 **≤0 就 `game:enterDying(damage.to, damage)`**（把这次伤害实例一并交出去）；验证：用例断言濒死排在 `'伤害-后'` **之前**（两个时机各记一笔，比对顺序）
- [x] 3.2 `@基础/濒死.lua`：**删掉**「`'游戏-开始'` 挂体力变化监听 + disposer 撤销」那一整套，只留 `'濒死-进入'`（求桃、没人救就 `setAlive(false)`）；在 `'濒死-进入'` 里 `setTag('凶手', ctx.damage and ctx.damage.from)`、`'濒死-离开'` 里清掉；验证：`--test rule.dying` 全绿 + 新增「救活后凶手标签被清掉」

## 4. 内容侧：死亡奖惩

- [x] 4.1 `package/身份场/奖惩.lua`（新）：`'玩家-死亡'` 里读死者身份与 `'凶手'` 标签；杀死反贼 ⇒ `game:draw(凶手, 3)`；主公杀死忠臣 ⇒ 主公弃所有手牌（`game:moveCard(手牌里的全部牌, '弃牌')`，空手牌不动）；凶手为空 / 等于死者 ⇒ 不奖惩；装备牌留一行说明（等装备批次）
- [x] 4.2 `package/身份场/胜负.lua` 顶部 `Depends { './奖惩' }`（保证奖惩的钩子先注册）；验证：用例断言「杀死最后一个反贼 ⇒ 凶手先摸到 3 张、然后才判胜」
- [x] 4.3 `server/test/rule/` 补端到端：杀死反贼摸 3 张 / 主公杀忠臣弃所有手牌 / 同归于尽（凶手已死）⇒ 一张都不摸 / 自杀 ⇒ 不奖惩；验证：`server/bin/moe-kill.exe --test rule` 全绿

## 5. 文档与验收

- [x] 5.1 `moe-kill-dev/references/architecture.md`：§12 的 `dying` 行（当场结算、携带伤害、两个时机、早于 `'伤害-后'`）与 `draw` 行（死者不摸），并去掉 `flushDying` 的说明
- [x] 5.2 `.agents/skills/sanguosha-rules/SKILL.md`：§2 奖惩改成已落地（装备部分标待做）、§7 / §9.4 的时机名与**濒死早于伤害后**的时序同步
- [x] 5.3 `moe-kill-dev/references/progress.md`：内核现状（濒死时机改名、draw 拦死者）与内容包（奖惩）与新用例数
- [x] 5.4 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀，正文写清 BREAKING 的时机改名）
