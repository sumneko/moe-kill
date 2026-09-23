# Tasks

## 1. 内核：`Judge` 效果 + `game:judge` 入口

- [x] 1.1 `server/core/effect/judge.lua`（新）：`Judge.CreateOptions`（`game` / `player` / `reason?`）、`Judge`（`kind` = `'judge'`；字段 `player` / `reason` / `card?`（判定牌，内容侧亮出时放上）/ `replaced`（被换下的牌，按顺序）/ `replace` 的窗口标记）、`Judge:replace(card)`（**不在窗口里调直接报错**；换牌 + 把旧的记进 `replaced`）、`Judge:settle()`（依次发 `'判定-亮牌'` →（窗口内）`'判定-前'` → `'判定-后'`）、`moe.judge.create`；验证：`--test core.effect.judge` 全绿
- [x] 1.2 `server/core/init.lua`：加一行 `include 'core.effect.judge'`；验证：`--test` 能加载、`game:judge` 可用
- [x] 1.3 `server/core/game.lua`：`game:judge(player, reason?)` 入口（`@async`，`apply():await()` 后返回实例；注释一行中文：谁的判定 / 缘由内核不解释）；验证：内核用例能读到 `kind` / `player` / `reason`
- [x] 1.4 `server/core/ordered-zone.lua`：`OrderedZone:draw(count)`（从区顶逐张取；取空了调一次不足回调，补到了接着取、补不到就少给；`@async`）与 `OrderedZone:setShortageHandler(handler)`；验证：`--test core.zone` 补的用例全绿
- [x] 1.5 `server/core/loader/env-meta.lua`：声明三个时机（`'判定-亮牌'` / `'判定-前'` / `'判定-后'`，上下文 = `Judge`）；验证：问题面板 information 及以上 0

## 2. 内容侧：亮牌、收牌、不足就洗回

- [x] 2.1 `package/@基础/牌堆.lua`：开牌堆时给抽牌区挂不足回调（弃牌全部挪回抽牌 + `zone:shuffle()`；弃牌也空就不管），把 `@基础/抽牌.lua` 里局部 `recycleDiscard` 的语义收进来（**只有一份实现**）；验证：`--test rule.draw` / `--test rule.turn` 全绿（行为不变）
- [x] 2.2 `package/@基础/抽牌.lua`：`'摸牌'` 改成 `local cards = deck:draw(draw.count)`（局部 `recycleDiscard` 退休）；验证：同上
- [x] 2.3 `package/@基础/判定.lua`（新）：`'判定-亮牌'` 取顶一张当判定牌（取不到就留空，不算失败）、`'判定-后'` 把 `replaced` + 判定牌一起 `game:moveCard(..., '弃牌')`；验证：`--test rule.judge` 全绿

## 3. 用例

- [x] 3.1 `server/test/core/effect/judge.lua`（新，内核视角、不装内容包）：入口返回结完的实例（`kind` / `player` / `reason`）、三个时机按次序各发一次且上下文是同一个实例、在 `'判定-前'` 里 `replace` 换牌后 `card` 是新牌且 `replaced` 记着旧的（换两次按顺序记两张）、**在窗口外调 `replace` 报错**（`'判定-后'` 里、或根本没起判定时）、没人亮牌时 `card` 为空不报错；验证：`--test core.effect.judge` 全绿
- [x] 3.2 `server/test/core/zone.lua`（补）：`draw(n)` 取满 n 张且按取顶顺序；不够就少给（不报错）；取空时调不足回调、回调补到牌就接着取；回调补不到就少给；没挂回调的区取空直接少给；验证：`--test core.zone` 全绿
- [x] 3.3 `server/test/rule/judge.lua`（新，装 `@基础` + `标准`）：判定牌就是抽牌堆顶那张（与 `deck:peek(1)` 一致）且结完进了弃牌堆；抽牌堆空时把弃牌洗回再翻；测试自己注册 `'判定-前'` 换一张手牌 ⇒ `judge.card` 是新牌、新旧两张都在弃牌堆里；`reason` 原样带给内容侧；验证：`--test rule.judge` 全绿
- [x] 3.4 回归：`server/bin/moe-kill.exe --test`（重点看 `--test rule.draw` / `--test rule.turn`：摸牌改走有序区取顶后行为不变）；验证：全量 0 失败

## 4. 文档与验收

- [x] 4.1 `moe-kill-dev/references/architecture.md`：§12 加 `Judge` / `game:judge` 两行（三个时机、`replace` 与 `replaced`、窗口外调报错、内核不搬牌不认牌面）+ `OrderedZone:draw` / `setShortageHandler` 两行 + 判定实现段（谁翻牌、谁收牌、不足回调洗回）+ 第 10 节时机清单（21 → 24）
- [x] 4.2 `.agents/skills/sanguosha-rules/SKILL.md`：新增「判定」一节（形状：亮牌 → 改判 → 结果；内核不认识牌面，结果就是那张牌；本批不做判定区 / 延时锦囊）；§7 的「还没做」里判定改成「动作已落地，消费方（延时锦囊 / 八卦阵）未做」；§3 判定阶段注明仍不结算；§10 的「判定的随机源口径」结掉（判定牌来自抽牌堆顶，随机性由开局洗牌 + 洗回承担）
- [x] 4.3 `moe-kill-dev/references/progress.md`：内核现状（效果族加 `judge`、局上入口加 `game:judge`）、时机个数、用例数、§2 候选表里划掉判定
- [x] 4.4 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）
