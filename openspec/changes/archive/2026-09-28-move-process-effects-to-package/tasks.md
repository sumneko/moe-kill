# Tasks

## 1. 内容侧：四个文件（类 + 订阅 + 入口）

- [x] 1.1 `package/@基础/伤害.lua`：`Class('Damage', 'Effect')`（`__init` / `settle` 三个时机）+ 原有扣血订阅 + `Game:damage` 入口
- [x] 1.2 `package/@基础/回复.lua`：`Heal` + 原有加血 / 脱离濒死订阅 + `Game:heal`
- [x] 1.3 `package/@基础/抽牌.lua`：`Draw`（`settle` 里「已阵亡的不摸」）+ 原有订阅 + `Game:draw`
- [x] 1.4 `package/@基础/濒死.lua`：`Dying`（`hasLeft` / `leave` / `settle` 判死）+ 原有求桃订阅 + `Game:enterDying`（复用已有濒死、换致死伤害）/ `Game:getDying`（读玩家标签袋）

## 2. 内核：删掉这些概念

- [x] 2.1 删 `server/core/effect/{damage,heal,draw,dying}.lua`；`server/core/effect/init.lua` 去掉四行 include
- [x] 2.2 `server/core/game.lua`：删 `damage` / `heal` / `draw` / `enterDying` / `getDying` / `clearDying` 六个方法与 `dyingMap` 字段
- [x] 2.3 `server/core/loader/env-meta.lua`：删这 18 行时机重载（`'伤害-*'` / `'回复-*'` / `'摸牌-生效'` / `'濒死-*'`）
- [x] 2.4 `package/@基础/meta.lua`：把这几条时机按名收窄加进去（载荷 = 内容侧的类）

## 3. 测试

- [x] 3.1 `server/test/core/game-over.lua`：`moe.damage.create { … }` 改成 `game:damage(from, to, amount)`；验证：`--test core.game-over` 通过
- [x] 3.2 四个内核套件与 `core.effect.*` / `rule.*` 不改一行仍通过（默认包本来就装着）
- [x] 3.3 全量 `server/bin/moe-kill.exe --test` 0 失败；问题面板 information 及以上 0

## 4. 文档

- [x] 4.1 `architecture.md`：§10 时机清单里这 18 条改标 `@基础`；§12 效果族清单与「局上的入口」去掉这四个与六个方法；§9.x 里 `core/effect/` 子类名单同步
- [x] 4.2 `SKILL.md`：`server/core/effect/` 行与 `server/core/` 行（「使用牌与造成伤害的机制」）同步
- [x] 4.3 `sanguosha-rules/SKILL.md`：伤害 / 回复 / 摸牌 / 濒死那几处「谁提供这些时机」的说法跟上
- [x] 4.4 `progress.md`：记一条（含「基础规则 = 内核默认层」这条口径与「搬 / 留」判据）+ 验收基线
