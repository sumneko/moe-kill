# core-flow Specification

## Purpose
把「这一局怎么跑」做成内核里的一个通用槽：内容包在**加载期登记**本局的流程，装配侧（无头测试 / 房间 / 会话）在**运行期启动**它。内核 MUST NOT 认识任何游戏流程 —— 它只提供「登记 + 启动」这对机制，流程本身是内容（见 `turn-flow`）。

## Requirements

### Requirement: 流程槽

内核 SHALL 提供一对通用入口，让「这一局的流程」由**内容**决定、由**装配侧**启动：

- `game:registerFlow(handler)`：**加载规则集期间**由内容包登记本局的流程（一个函数）。非加载期调用、重复登记、传入非函数，MUST 以明确错误失败。
- `game:runFlow()`：**装配侧**（无头测试 / 房间 / 会话）启动这一局的流程，SHALL 返回一个**效果**（`Flow : Effect`，`kind` = `flow`）—— 于是它可被 `await`（等这局跑完）、可被 `remove()`（停掉这局）、失败读 `.err`，与其它效果一致；没有登记流程时调用 MUST 以明确错误失败。

内核 MUST NOT 认识任何游戏流程：流程是什么、有几个回合、有哪些阶段，全部是内容 —— 内核只提供"登记 + 启动"这对机制。

清空重装（`moe.loader.install`）SHALL 连同内容一起清掉已登记的流程（与规则表、规则数值同生命周期）。

#### Scenario: 登记后可以被启动

- **WHEN** 内容包在加载期登记了流程，装配侧调用 `game:runFlow()`
- **THEN** 流程在自己的协程里执行；`await` 这个效果能得到流程的返回值，流程结束即效果完成

#### Scenario: 流程可被停掉

- **WHEN** 装配侧在流程跑着的时候对启动返回的效果调用 `remove()`
- **THEN** 流程停止执行（不再继续跑回合），这次流程以「被取消」结束：没有结果、`.err` 记为取消

#### Scenario: 加载之外不能登记

- **WHEN** 在非加载期调用 `game:registerFlow(...)`
- **THEN** 以明确错误失败

#### Scenario: 没有流程时启动失败

- **WHEN** 局上没有登记任何流程，装配侧调用 `game:runFlow()`
- **THEN** 以明确错误失败

#### Scenario: 清空重装后流程消失

- **WHEN** 装好规则后重新 `install` 一套不含流程登记的清单
- **THEN** `game:runFlow()` 以明确错误失败

