# Proposal

## Why

两处口径不统一，用起来得记例外：

1. **「省略清单」两边含义不同**：`room.create` 省略 `packages` 会装**默认加载的包**（`@基础`），而 `moe.rule.create {}` 却建出一份**什么都没装**的实例。同一件事两套含义，调用方（测试、将来的会话层）得记住「场地省略 = 装默认包、实例省略 = 不装」。
2. **上下文里塞了环境对象**：`ctx` 现在是 `{ desk, random, room }`，规则包拿牌区要写 `ctx.room`、拿桌子写 `ctx.desk`。但时机上下文的定位应是**承载该事件的参数**（如将来「伤害-后」的 `{ 目标, 伤害值 }`）；环境对象（这一局的场地）本来就属于这一局，从 `rule:getRoom()` 取才对。

## What Changes

- **`moe.rule.create` 与场地口径统一**：建实例**总是加载**；`packages` 省略视同空清单 ⇒ 只装默认加载的包（`moe.rule.create {}` 与 `moe.rule.create { packages = {} }` 行为一致）。要换规则就 `rule:load(清单)`。
- **规则实例能读回所属场地**：`rule:getRoom()`（由场地建出的实例返回该场地；不是场地建的实例读它报错）。场地建规则的顺序改为「先建场地对象 → 建规则实例并绑定回去 → 装到场地上」。
- **`ctx` 只承载事件参数**：`'游戏-开始'` 目前没有额外参数 ⇒ **上下文就是一张空表**（`rule:fire('游戏-开始', {})`），`env-meta` 里对应的类型是空类；规则包要这一局的场地 / 桌子 / 随机源，一律从 `rule:getRoom()` 取（`room:getDesk()` / `room:getRandom()`）。
- 规则包同步改写：`@基础/牌堆.lua`、`@基础/体力.lua`、`身份场/开局.lua` 不再用 `ctx.*`。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `rule-loading`：「规则实例」（建实例即加载、省略清单 = 空清单；新增读回场地的接口）；「规则集执行环境的注入面」（环境对象从实例取，上下文只承载事件参数）。

## Impact

- 内核：`server/core/rule/init.lua`（`create` 总加载、`room` 字段与 `getRoom`）、`server/core/room.lua`（先建场地对象再建规则并绑定）、`server/core/rule/env-meta.lua`（`游戏-开始` 的上下文变空类）。
- 规则包：`package/@基础/牌堆.lua`、`package/@基础/体力.lua`、`package/身份场/开局.lua`。
- 测试：`server/test/rule/support.lua`（触发改传空表）、`server/test/core/room.lua`（补「读回所属场地」）、`server/test/rule/*`（省略清单的写法简化）。
- 文档：`architecture.md` 第 9 / 10 节、`moe-kill-dev/SKILL.md`、`sanguosha-rules`（§8 上下文口径、§9.1 示例）。
