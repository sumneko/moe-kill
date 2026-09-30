# Tasks

## 1. 内核

- [x] 1.1 `server/core/effect/ask-offset-card.lua`（新）：`AskOffsetCard : AskPlayCard`（`kind` = `askOffsetCard`；settle：没打出 ⇒ `reject('没有打出')`；打出 ⇒ 两段时机 + 有人返回原因则 `cancel`）—— 以 3.1 验证
- [x] 1.2 `server/core/effect/init.lua`：装载顺序（父类之后）—— 以 4.1 面板验证
- [x] 1.3 `server/core/game.lua`：`game:askOffsetCard` 入口 —— 以 3.1 验证
- [x] 1.4 `server/core/loader/env-meta.lua`：`'效果-被抵消'`（Game）/ `'效果-来源-被抵消'`（Player）声明 + `'卡牌-询问 / 答复 / 答复后'` 载荷联合 —— 以 4.1 面板验证

## 2. 内容

- [x] 2.1 `package/标准/卡牌/杀.lua`：改用 `askOffsetCard(...).success` —— 以 3.2 验证
- [x] 2.2 `package/标准/卡牌/贯石斧.lua`：技能（订来源时机 → 弃两张（去掉自身）→ 返回原因驳回）—— 以 3.4 验证
- [x] 2.3 `package/标准/卡牌/青龙偃月刀.lua`：迁到 `'效果-来源-被抵消'` —— 以 3.4 验证

## 3. 用例

- [x] 3.1 新套件 `server/test/core/effect/ask-offset-card.lua`（+5：打出 / 没打出 / 驳回 / 两段 / 答错）与 `server/test.lua` 注册 —— `--test core.effect.ask-offset-card` 全绿
- [x] 3.2 `server/test/rule/slash.lua`：+1 两段时机集成 —— `--test rule.slash` 全绿
- [x] 3.3 `server/test/rule/equip.lua`：模拟「打出闪」的筛选改 kind（约 10 处）—— 全绿
- [x] 3.4 `server/test/rule/equip.lua`：+7（正例 / 不弃 / 凑不出 / 混弃 / 旁人 / 万箭 / 拆下）—— `--test rule.equip` 全绿

## 4. 共同

- [x] 4.1 全量 `--test` 0 失败（703 → 716）、问题面板 information 及以上 0
- [x] 4.2 文档：`architecture.md`（§10 玩家份事件名规则 + §12 表与样本）/ `sanguosha-rules` §9.11（贯石斧 + 青龙迁移 + 未做清单）/ `progress.md` / `HANDOVER.md`
