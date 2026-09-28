# Tasks

## 1. 内核

- [x] 1.1 `server/core/card.lua`：`__init` 查一次定义、查不到 `error`；`def` 成公开字段；删 `getDef()`
- [x] 1.2 `server/core/card.lua`：`fireHandlers` / `isKind` / `getValue` / `fullName` 去掉「定义可能为空」
- [x] 1.3 `server/core/game.lua`：`checkCardItself` 去掉「没有内容定义」分支
- [x] 1.4 `server/core/effect/use-card.lua`：`skipsEffect` 改读 `self.card.def`

## 2. 内容侧（补被炸出来的缺口）

- [x] 2.1 新增 `package/@基础/卡牌/防具牌.lua`（`Depends { './装备牌' }` + `extends '装备牌'` + `addKind '防具'`）
- [x] 2.2 新增 `package/标准/卡牌/八卦阵.lua` / `仁王盾.lua`（官方描述 + `extends '防具牌'`；技能未做）

## 3. 用例

- [x] 3.1 `ltest.lua`：新增公共牌定义来源 `lt.cardSource`（`tmp/lt-fixture/@测试/牌.lua`），`lt.game()` 挂上
- [x] 3.2 `core.game` / `core.effect.{init,ask,ask-play-card}` 的局挂上公共来源；`ask-card` 探针补 `杀` / `桃` / `随便`
- [x] 3.3 `rule.delayed-trick`：改判用的判定牌从「测试牌」换成有定义的「杀」
- [x] 3.4 三条前提已死的用例改写：`core.can-use`（⇒ 建牌时报错）、`core.card-def`（去掉「没定义的牌不发」那半句）、`core.effect.play`（⇒ 断言 `createCard` 报错）
- [x] 3.5 `core.card` 字段清单断言加 `def`；`core.game`「重装规则内容不重置号源」改用 `moe.loader.install(game)` 重装

## 4. 文档与验收

- [x] 4.1 文档同步：`architecture.md`（`Card` 行 / `canUse` 行）、`code-style.md` §12、`progress.md`、`sanguosha-rules`（§9.11 防具定义已补）
- [x] 4.2 `server/bin/moe-kill.exe --test` ⇒ **584 用例 0 失败**；问题面板 information 及以上 0
