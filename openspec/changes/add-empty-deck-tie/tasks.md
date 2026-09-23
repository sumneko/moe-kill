# Tasks

## 1. 内容侧：牌堆耗尽 ⇒ 平局

- [x] 1.1 `package/@基础/牌堆.lua`：抽牌区的不足回调里，弃牌也为空（洗不回来）⇒ `game:endGame { side = '平局', reason = '牌堆与弃牌堆都没有牌' }`（其余不动：有牌就照旧全部洗回 + `shuffle()`）；验证：`--test rule.game-over` 新用例全绿，`--test rule.draw` / `--test rule.judge` 回归不变

## 2. 内核：结局取值补上「平局」

- [x] 2.1 `server/core/game.lua`：`Game.Result` 的注释里 `side` 取值补一项「平局」（主公方 / 反贼 / 内奸 / 平局）；**行为一行不改**；验证：问题面板 information 及以上 0

## 3. 用例

- [x] 3.1 `server/test/rule/game-over.lua` 补三条：① **摸牌时两堆都空 ⇒ 平局**（把抽牌堆的牌全挪进处理区、弃牌本来就空 ⇒ `game:draw(玩家, 1)` 后 `getResult().side == '平局'`，且这次摸牌本身不算失败）；② **判定时两堆都空 ⇒ 平局**（`game:judge` 翻不出牌、`judge.card` 为空，结果同样是平局）；③ **抽牌堆空但弃牌还有牌 ⇒ 不算耗尽**（洗回后照常取牌，`getResult()` 仍为空）；验证：`--test rule.game-over` 全绿

## 4. 文档与验收

- [x] 4.1 `.agents/skills/sanguosha-rules/SKILL.md`：§2 补官方口径「牌堆与弃牌堆都没有牌 ⇒ 平局」并标已落地（落在 `@基础/牌堆.lua` 的不足回调里）；§9.6 的结局链路补一句「四种 `side`：主公方 / 反贼 / 内奸 / 平局」与触发点
- [x] 4.2 `moe-kill-dev/references/architecture.md`：§12 的牌区取顶段（`OrderedZone:draw` / `setShortageHandler`）补一句「洗不回来 ⇒ 基础规则判平局」；§12 的判定段保持「不改判定阶段」
- [x] 4.3 `moe-kill-dev/references/progress.md`：内核现状（`Game.Result` 的取值）与用例数；§2 候选表若有「平局」相关条目则划掉
- [x] 4.4 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）
