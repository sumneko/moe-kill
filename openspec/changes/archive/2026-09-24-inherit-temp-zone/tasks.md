# Tasks

## 1. 内核：继承与归属

- [x] 1.1 `server/core/effect/effect.lua`：`getTempZone()` 改成「自己有 ⇒ 用；否则 `parent:getTempZone()`；否则就地建」，并把「自己那块（没有才建）」抽成 `createTempZone()`；验证：`--test core.effect` 中「临时处理区按需建，顶层效果各自一块」通过
- [x] 1.2 `server/core/effect/effect.lua`：`bindFinish()` 收紧 —— 任务结完时 `self.tempZone` 非空才 `fire('效果-收尾', self)`（在完成点上判，不在绑定处判）；验证：新增用例「没要过区的效果不发收尾」通过
- [x] 1.3 `server/core/effect/use-card.lua`：`UseCard` 与 `CardEffect` 各重写 `getTempZone()` 为 `return self:createTempZone()`；验证：新增用例「内层效果沿父层拿到同一块区，归属者身上才有区」与 `--test core.effect.play` 的「每个目标的生效自己建区」断言通过
- [x] 1.4 `server/core/effect/judge.lua`：`Judge` 同样重写；验证：新增用例「判定：嵌在别的结算里也用自己的临时区」与规则级的「判定：嵌在别的结算里，判定牌在该次判定结束时就走」通过
- [x] 1.5 `server/core/effect/ask-play-card.lua`：`onAnswered()` 改 `self.game:moveCard(card, self:getTempZone())`（`parent` 只当「有没有外层结算」的条件，不再当区的归属者）；验证：`--test core.effect.ask-play-card` 通过（答复的牌仍进发起那次结算的区、收尾后进弃牌；顶层仍不动那张牌）

## 2. 用例

- [x] 2.1 新增：子效果与归属者拿到**同一块**区，且 `tempZone` 字段只在归属者身上有值；验证：`--test core.effect` 通过
- [x] 2.2 新增：`'效果-收尾'` 只对归属者发（子效果不发），两次发仍按「内层先、外层后」；验证：`--test core.effect` 通过
- [x] 2.3 改现有 4 条收尾用例（`结完时收尾一次` / `不成立也收尾` / `取消也收尾` / `内层效果先收尾，外层后收尾`）：先要一块区才发收尾；验证：`--test core.effect` 通过
- [x] 2.4 复核落点不变的四处：打出的【闪】（该目标生效结束时）、判定牌（该次判定结束时）、【五谷丰登】亮出的牌（整次用牌结束时）、顶层 `game:damage` 里打出的牌（该次伤害结束时）；验证：`--test core.effect.ask-play-card`、`--test core.effect.play` 与 `--test rule` 里的判定 / 锦囊用例通过
- [x] 2.5 全量回归：`server/bin/moe-kill.exe --test` ⇒ 490 用例 0 失败

## 3. 文档

- [x] 3.1 `references/architecture.md` 第 12 节 `Effect` 行：写清 `getTempZone()` 沿 `parent` 继承（`UseCard` / `CardEffect` / `Judge` 自建、就地建用 `createTempZone()`）、`tempZone` 字段 = 自己那块；`CardEffect` 行与 `askPlayCard` 行同步改；验证：与代码一致
- [x] 3.2 `references/architecture.md` 第 10 节收尾时机那条：触发条件改成「只对区的归属者发」；验证：与 `bindFinish()` 一致
- [x] 3.3 `server/core/loader/env-meta.lua`：`'效果-收尾'` 的 `on` 上补一行说明「只发给区的归属者」（签名不变，载荷仍是效果本身）；验证：`--test` 仍通过
- [x] 3.4 `references/progress.md`：§1 补本变更的记录、验收基线改 490、§2 候选表与 §3「主要 / 次要」改成「处理区归属已落地，只剩严格报错 / 回溯读法 / 记牌器」；验证：读一遍无自相矛盾
- [x] 3.5 问题面板 information 及以上清到 0（工作区级检查通过）

## 4. 收尾

- [x] 4.1 `openspec validate inherit-temp-zone --strict` 通过
- [ ] 4.2 `tasks.md` 全部勾选后归档：`openspec archive inherit-temp-zone --yes`
