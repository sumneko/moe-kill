# Tasks

## 1. 内核

- [x] 1.1 `server/core/game.lua`：`Game.UseOptions` 类 + `checkCardItself` / `collectLegalTargets` / `canUse` / `useCard` / `askUseCard` 透传 —— 以 3.1 / 3.2 验证
- [x] 1.2 `server/core/effect/use-card.lua`：`useOptions` 字段 + `notCounted` 不记账 + create 透传 —— 以 3.2 验证
- [x] 1.3 `server/core/effect/ask-use-card.lua`：`useOptions` 字段 + `makeOption` / `use()` 带上 —— 以 3.3 验证
- [x] 1.4 `server/core/loader/env-meta.lua`：「获取目标」回调第 2 参数（`Game.UseOptions`）声明 —— 以 4.1 面板验证

## 2. 内容

- [x] 2.1 `package/标准/卡牌/杀.lua`：`'获取目标'` 把选项喂给 `Player:isInRange`；`@基础/距离.lua` 新增 `isInRange`（认 `ignoreDistance`；`distance` 保持诚实）—— 以 3.1 验证
- [x] 2.2 `package/标准/卡牌/青龙偃月刀.lua`：技能（答复后筛 → 直接三旗标追加杀；不另问「是否发动」）—— 以 3.4 验证

## 3. 用例

- [x] 3.1 `server/test/core/effect/play.lua`：+1 无视距离 —— `--test core.effect.play` 全绿
- [x] 3.2 `server/test/core/effect/play.lua`：+1 无视上限 / 不计入次数
- [x] 3.3 `server/test/core/effect/play.lua`：+1 `askUseCard` 候选与用出去都按选项来
- [x] 3.4 `server/test/rule/equip.lua`：+7（正例+次数 / 不发动 / 候选空 / 链 / 旁人 / 万箭 / 拆下）—— `--test rule.equip` 全绿
- [x] 3.5 `server/test/rule/slash.lua`：+1 无视距离（`isInRange` 认标 + 范围外够得着）—— `--test rule.slash` 全绿
- [x] 3.5 全量回归：0 失败（记录新基线）

## 4. 收尾

- [x] 4.1 问题面板 information 及以上 0（全仓）
- [x] 4.2 文档：`architecture.md` / `sanguosha-rules` §9.11 / `progress.md` / `HANDOVER.md`
- [x] 4.3 `openspec validate add-qinglong-blade --strict` 通过；勾选全部 tasks 后 `openspec archive add-qinglong-blade --yes`
