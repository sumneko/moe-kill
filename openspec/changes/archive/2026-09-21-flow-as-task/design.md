# Design

## Context

- 现状：`game:runFlow()` 造 `moe.flow.create { game, handler }` → `effect:apply()` → 返回效果。`Effect:apply()` 在没有外层时把效果记进**只增记牌器**（`game:addEffect`），并给它挂 `parent = nil`。流程跑得比谁都长 ⇒ 它是唯一的根，真结算全在它下面。
- 效果与任务的差别（`server/core/effect.lua`、`server/tools/task.lua`）：效果 = 结算（`'即将生效'` 时机、`parent` / `deep` / `childs`、进记牌器、`settle()` 的返回值就是结果）；任务 = 可等待的执行体（`execute` / `await` / `result` / `err` / `setTimeout` / `onResolved` / `onRejected`）。
- 流程需要的能力恰好是任务这一层：等它跑完、拿返回值、失败读 `.err`、能从外面停掉。
- 用户已定：**直接用 Task**，`Flow` 与 `moe.flow` 一起退休。

## Goals / Non-Goals

**Goals:** 记牌器恢复意义（只记真结算）；流程不再具有"结算"语义；启停等待的口径比现在更清楚（`.result` / `.err` / `cancel()`）。

**Non-Goals:** 不动 `registerFlow` 与「加载期登记 / 装配侧启动」的分工；不动内容侧（回合流程本身）；不引入"流程也是可插入结算"这类新语义。

## Decisions

### D1：`game:runFlow()` 返回 Task

```lua
function M:runFlow()
    if not self.flow then
        error('这一局没有登记流程', 2)
    end
    local handler = self.flow
    local task    = moe.task.create { game = self }
    task:execute(function ()
        return handler()
    end)
    return task
end
```

- 装配侧：`local task = game:runFlow()`；等它 `task:await()`；看结果 `task.result`；看失败 `task.err`；停它 `task:cancel()`。
- **不再进记牌器**（没有 `Effect:apply()` 这一步）⇒ 根效果是真结算。

**Alternatives**：① 保留 `Flow : Effect` 但在记牌器里给它开白名单（特例、更脏）；② 保留 `Flow` 类但不继承 `Effect`（等于把 `await` / 结果 / 失败 / 取消重写一遍，且 `flow.kind` 这类 Effect 属性还是得删）。

### D2：`Task:cancel()`（新）

```lua
--- 停掉这次任务：以「取消」收尾（不算失败），并收掉还挂着的执行体
function M:cancel()
    self:reject(API.CANCELED)
end
```

- `reject` 已经做了三件事：标 `resolved`、叫醒等它的人（结果为空、`err` = `canceled`）、`Delete(self)` —— 而 `__del` 会 `coroutine.close` 掉还挂着的协程 ⇒ **流程真的停住**（不会在下一次被唤醒时继续跑）。
- 与效果侧的取消**同一口径**：`.err` 记 `canceled`、不算"报错"，不进错误处理器。

**Alternatives**：让调用方自己写 `task:reject(moe.task.CANCELED)`（把内部常量泄给调用方，且没人负责"收掉协程"这件事的说法）。

## Risks / Trade-offs

- [测试里原本断言 `flow.kind == 'flow'`] → 这条断言改为断言返回的是任务（有 `await` / `cancel`），并在 `rule.flow` 里补一条**记牌器只记真结算**的断言（否则这个变更有回归风险而没人看得见）。
- [`Task:cancel()` 用 `reject` 实现 ⇒ 取消被记成 `.err`] → 与效果侧取消完全一致（`Effect:__del` 也是 `reject(CANCELED)`），是既有口径，不新增概念。
- [删文件]：`server/core/flow.lua` 已与用户确认退休；`moe.flow` 这个门面同时消失（`env-meta.lua` 里没有它的声明，内容侧也拿不到 `moe`，无外部消费者）。
