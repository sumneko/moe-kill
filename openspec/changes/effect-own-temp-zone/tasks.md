# Tasks

## 1. 内核

- [x] 1.1 `server/core/effect/effect.lua`：`getTempZone()` 去掉沿 `parent` 回溯那一支、改成懒建自己这块（`moe.zone.create(self.game)`），删 `createTempZone()`，更新 `tempZone` 字段与方法的中文说明；验证：`server/bin/moe-kill.exe --test core.effect` 的「临时处理区按需建，顶层效果各自一块」通过
- [x] 1.2 `server/core/effect/use-card.lua`：删 `UseCard:getTempZone` 与 `CardEffect:getTempZone` 两处重写（连同两行中文说明）
- [x] 1.3 `server/core/effect/use-card-to-card.lua`：删 `UseCardToCard:getTempZone` 与 `CardEffectToCard:getTempZone` 两处重写
- [x] 1.4 `server/core/effect/ask-play-card.lua`：`onAnswered()` 改 `self.game:moveCard(card, self.parent:getTempZone())`（`self.parent` 的判断保留）、更新方法说明
- [x] 1.5 `package/@基础/判定.lua`：删 `Judge:getTempZone()` 重写（默认即自建）

## 2. 测试

- [x] 2.1 `server/test/core/effect/init.lua`：「内层效果沿父层拿到同一块区，归属者身上才有区」这条语义反转 ⇒ 改成「内层效果自己一块区、外层那块不受影响」（`ZoneProbeEffect` 的探针不再靠继承）
- [x] 2.2 同文件补一条：子效果**显式点名** `self.parent:getTempZone()` 时拿到的是外层那块（把「借区」的写法固化成用例）
- [x] 2.3 `server/test/core/effect/ask-play-card.lua`：既有「答复的牌进发起那次结算的区、收尾后进弃牌、顶层不动那张牌」仍通过
- [x] 2.4 全量 `server/bin/moe-kill.exe --test` 0 失败；问题面板 information 及以上 0

## 3. 文档

- [x] 3.1 `references/architecture.md`：`Effect` 行（临时区默认自建、`createTempZone` 已删、借外层要显式点名）、`CardEffect` 行（「两处都能拿、且不是同一块」仍成立）、`askPlayCard` 行（把「用 `self:getTempZone()`，即最近的归属者那块」改成 `parent:getTempZone()`）
- [x] 3.2 `SKILL.md`：`server/core/effect/` 行里 `getTempZone()` 的一句说明跟上
- [x] 3.3 `references/progress.md`：记一条本次决策；把用户的待办「借区变多就考虑收成字段」写进待办区
