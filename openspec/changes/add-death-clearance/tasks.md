# Tasks

## 1. 内容

- [x] 1.1 `package/@基础/阵亡.lua`（新）：订阅 `'玩家-死亡'` —— 先 `disablePassive()` 死者所有技能，再把所有牌区的牌一次 `game:moveCard(cards, '弃牌')`
- [x] 1.2 `package/@基础/阶段/判定阶段.lua`：撤掉「回合角色死了就停」的提前退出

## 2. 用例

- [x] 2.1 新套件 `server/test/rule/death.lua`（5 条）并注册进 `server/test.lua`
- [x] 2.2 `rule/delayed-trick.lua` 的「阵亡清算不在本批」断言改成「清算把判定区的牌也清了」
- [x] 2.3 `rule/hero-skill.lua` 的【急救】用例：死者的手牌被清算清掉（改断手牌为 0）

## 3. 收尾

- [x] 3.1 测试全绿（**1114**）
- [x] 3.2 问题面板 information 及以上 0
- [x] 3.3 反向验证：不先禁用技能 ⇒ 1 红；只清手牌 ⇒ 3 红；不清牌 ⇒ 5 红（填进 `design.md` D4）
- [x] 3.4 `openspec validate --all --strict`
- [x] 3.5 文档同步（`sanguosha-rules` §9.7 / §9.12 / 判定阶段、`progress.md`、`architecture.md`）
- [x] 3.6 停在待确认状态，等「提交」
