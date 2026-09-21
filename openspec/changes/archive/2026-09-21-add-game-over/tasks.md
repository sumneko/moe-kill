# Tasks

## 1. 内核：结果与结束信号（`server/core/game.lua`）

- [x] 1.1 `Game.Result` 类型 + `---@field private result? Game.Result` + `---@field private flowTask? Task`；`game:getResult()`（没结果 = 没结束）
- [x] 1.2 `game:endGame(result)`：幂等（有结果直接返回）；否则记结果 → `fire('游戏-结束', result)` → `flowTask:cancel()`
- [x] 1.3 `runFlow()` 把建出来的任务记进 `flowTask`
- [x] 1.4 验证：`--test core.game` / `rule.turn` 照旧全绿（没结束时行为不变）

## 2. 内核：结束后不再起新结算（`server/core/effect/init.lua`）

- [x] 2.1 `Effect:apply()` 开头检查 `self.game:getResult()`：已结束 ⇒ 建一个已取消的任务并返回（不触发「即将生效」、不结算）
- [x] 2.2 验证：`--test core.effect` / `core.effect.play` 全绿

## 3. 规则侧：身份场胜负（`package/身份场/胜负.lua` 新增）

- [x] 3.1 订阅 `'玩家-死亡'`：已有结果就返回；主公阵亡 ⇒ 只剩内奸一人则「内奸」、否则「反贼」；主公活着且存活者里没有反贼与内奸 ⇒ 「主公方」
- [x] 3.2 验证：`--test rule.game-over` 全绿

## 4. 用例

- [x] 4.1 `server/test/core/game-over.lua`（套件 `core.game-over`）：没结束时 `getResult()` 为空；`endGame` 记结果 + 触发 `'游戏-结束'`（上下文就是那个结果）；幂等（第二次不改结果、不再触发）；结束后流程任务被取消；结束后起的结算以「取消」收尾（`err` = canceled、没有结果、目标没掉血）；结束后已记账的濒死不再起
- [x] 4.2 `server/test/rule/game-over.lua`（套件 `rule.game-over`）：反贼没死光时不结束；反贼与内奸全灭 ⇒ 主公方胜；主公阵亡 ⇒ 反贼胜；主公阵亡且只剩内奸 ⇒ 内奸胜；结束后流程不再转回合
- [x] 4.3 `server/test.lua` 登记两个套件

## 5. 文档与验收

- [x] 5.1 `server/core/loader/env-meta.lua` 补 `'游戏-结束'` 的 `on` / `fire`（上下文 = `Game.Result`）
- [x] 5.2 `sanguosha-rules`：§2 标已实现、§7 / §9 的「奖惩与胜负判定还没做」改成实际状态 + 「游戏结束」写法
- [x] 5.3 `moe-kill-dev` 的 `architecture.md`：`endGame` / `getResult` / `'游戏-结束'` 口径 + 「再开一局 = 新建 Game 实例（将来）」
- [x] 5.4 `infrastructure.md` 命令速查补 `--test core.game-over` / `rule.game-over`
- [x] 5.5 全量 `--test` 0 失败；问题面板 information 及以上为 0
