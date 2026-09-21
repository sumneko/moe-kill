# Tasks

## 1. 内核：伤害不再自己改体力（改成「伤害-生效」事件）

- [x] 1.1 `server/core/damage.lua`：`settle()` 改成 `fire('伤害-前', self)` → `fire('伤害-生效', self)` → `fire('伤害-后', self)`，**不再 `addAttr`**（内核从此不碰属性名）；验证 `--test core.damage` 通过
- [x] 1.2 `server/core/loader/env-meta.lua`：补 `'伤害-生效'` 的按名收窄（上下文 = `Damage`）
- [x] 1.3 `package/@基础/伤害.lua`（新）：`game:on('伤害-生效', function (damage) damage.to:addAttr('体力', -damage.amount) end)`（将来护甲 / 改伤害值挂这里）
- [x] 1.4 内核用例**不需要改**：这些「裸局」默认就会加载 `@基础`（默认来源 + `@` 默认包），扣血由 `@基础/伤害.lua` 提供 —— 我一度给 4 个 helper 加了订阅，造成双重扣血（掉 2 点），已撤干净

## 2. 内核：回复（`Heal`）

- [x] 2.1 `server/core/heal.lua`（新）：`Heal : Effect`（`kind` = `heal`，字段 `to` / `amount`）+ 门面 `moe.heal`；`settle()` = `'回复-前'` → `'回复-生效'` → `'回复-后'`（与伤害对称，同样不碰属性）
- [x] 2.2 `package/@基础/回复.lua`（新）：`game:on('回复-生效', ...)` 给 `to` 加体力（上界由属性自己钳制）
- [x] 2.3 `server/core/game.lua`：`game:heal(player, amount)` 便利入口（`apply()` + `await()`，返回 `Heal` 实例）
- [x] 2.4 `server/core/init.lua` + `env-meta.lua`：挂 `moe.heal`、补三个回复时机的类型

## 3. 内核：濒死（`Dying`）

- [x] 3.1 `server/core/dying.lua`（新）：`Dying : Effect`（`kind` = `dying`，字段 `player`）；`settle()` **只** `fire('濒死', self)` —— 判死由规则侧在同一个时机里做（内核零属性知识）
- [x] 3.2 `server/core/game.lua`：`game:enterDying(player)` —— 只**记账**（同一玩家后来居上），**返回撤销函数**；`game:flushDying()`（结算收尾时按账起 `Dying`，阵亡的跳过）
- [x] 3.3 `server/core/effect.lua`：结算体返回之后调一次 `game:flushDying()`（用 `moe.util.defer` 保证抛错路径也走到）；不在任何结算里时 `enterDying` 当场起（`flushDying` 在不能让出的协程里直接返回，待办留着）
- [x] 3.4 `server/core/init.lua` + `env-meta.lua`：挂 `moe.dying`、补 `'濒死'` 时机的类型

## 4. 规则与内容

- [x] 4.1 `package/@基础/濒死.lua`（新）：订阅每个玩家的 `体力`（`attrs:onChange`，回调签名是 `(instance, newValue, oldValue)`）—— 从 >0 跨到 ≤0 时 `pending = game:enterDying(player)`，跨回 >0 时 `pending()` 撤销；订阅 `'濒死'` 时机：**从濒死者开始按行动顺序**（`desk:getNext` 绕一圈）问桃，体力 ≥1 就停，一圈问完仍 ≤0 就 `player:setAlive(false)`
- [x] 4.2 `package/标准/卡牌/桃.lua`（新，顶部写官方描述）：`'获取目标'` = 已受伤的自己 + 处于濒死（体力 ≤0）的存活角色；`'生效'` = `game:heal(ctx.target, 1)`
- [x] 4.3 确认【桃】在求桃路径上走的是「使用」：缘由 `'使用'` 时基础规则不动那张牌 ⇒ 牌还在手上，正好交给 `game:useCard`（牌最终经 `处理` 进 `弃牌`，无需手工挪牌）

## 5. 用例

- [x] 5.1 `server/test/core/heal.lua`（新，3 例）：回血 / 三个时机的先后与上下文（体力变化在「生效」里）/ 建实例先不结算就不回血
- [x] 5.2 `server/test/core/dying.lua`（新，6 例）：不在结算里当场起 / 在结算里记账要等收尾（`伤害-前,伤害-后,濒死`）/ 撤销 / 阵亡的不再起 / 濒死里再记账自然嵌套 / 内核不判死
- [x] 5.3 `server/test/rule/dying.lua`（新，8 例，端到端）：没人给桃就阵亡（含 `'玩家-死亡'`）/ 自己给一张就活 / 从濒死者开始按行动顺序问下家 / 差 2 点连给两张 / 出牌阶段用桃回复自己 / 满血不能对自己用 / 不能拿去给别人回血
- [x] 5.4 `server/test.lua`：登记三个新套件
- [x] 5.5 全量 `server/bin/moe-kill.exe --test`：**339 用例 0 失败**（比之前多 17 例，既有 `rule.slash` / 回合流程等不受影响）

## 6. 文档与验收

- [x] 6.1 `sanguosha-rules`：§7 补「伤害只发事件 / 回复 / 濒死已落地」与修正濒死询问起点，新增 **§9.4 濒死与【桃】**，§10 记下询问起点的不确定性
- [x] 6.2 `moe-kill-dev/references/architecture.md` §12：伤害/回复行改成「只发事件」、新增 `Heal` / `Dying` / `enterDying` / `flushDying` 行与两条说明、测试清单补三套件
- [x] 6.3 `infrastructure.md` 命令速查 + `SKILL.md` 目录表补新内核文件与新套件
- [x] 6.4 问题面板 0（information 及以上）；只改 Lua，不需要 `luamake`
- [x] 6.5 提交（`【AI】` 前缀）并勾完本文件
