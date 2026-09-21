# Tasks

## 1. 内核

- [x] 1.1 `server/tools/task.lua`：新增 `Task:cancel()`（`reject(CANCELED)`）—— **必须带「就地停住」**：`if moe.task.getCurrentTask() == self then coroutine.yield() end`。我第一版只写了 reject，于是流程在 `'回合-结束'` 里取消后会**继续跑下一个回合**（3 个回合用例立刻红：阶段事件 19 个而不是 12 个）
- [x] 1.2 `server/core/game.lua`：`runFlow()` 改成 `moe.task.create { game = self }` + `execute(handler)` 并返回该任务（注解 `---@return Task`）
- [x] 1.3 删 `server/core/flow.lua`（`git rm`）；`server/core/init.lua` 去掉 `include 'core.flow'`
- [x] 1.4 全仓 grep：`Flow` / `moe.flow` 已无引用（只剩 `registerFlow` / `runFlow` 这两个名字）

## 2. 用例

- [x] 2.1 `server/test/rule/flow.lua`：改用 Task API（`await` / `result` / `cancel`），「种类标识」那条断言换成**「流程不进记牌器（它是驱动，不是结算）」**（`#game:getEffects() == 0`）
- [x] 2.2 `server/test/rule/turn.lua`：字段 `flow` → `task`（含注解）、`state.flow:remove()` → `state.task:cancel()`
- [x] 2.3 `server/test/ltest.lua`：`assertFailed` 的参数注解放宽成 `Effect|Task`
- [x] 2.4 `server/bin/moe-kill.exe --test`：**339 用例 0 失败**（用例数不变 —— 只在既有用例里加了断言，没新增用例）

## 3. 文档与验收

- [x] 3.1 `architecture.md` §12：`game:runFlow()` 行与「这一局的流程怎么被启动」段改成任务口径（并写明为什么流程不是效果）
- [x] 3.2 `sanguosha-rules` §9.2 的「流程怎么被启动」改成任务口径
- [x] 3.3 `infrastructure.md` 的 `task.lua` 行补 `Task:cancel()`
- [x] 3.4 问题面板 0（information 及以上）
- [x] 3.5 提交（`【AI】` 前缀）并勾完本文件；归档变更 `flow-as-task`
