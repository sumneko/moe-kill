# Proposal

## Why

法规包（`package/`）能看到的接口面有两处该收拾：

1. **缺工具**：规则包的执行环境只有「局对象 + 两个加载期入口 + 标准库白名单」，拿不到内核的工具库 ⇒ 每张有目标限制的牌都要手写同样的筛选循环（`local legal = {}` + `for` + `if` + `insert`）。工具**不能整个给它**（`moe.util` 里有 `saveFile` 这类 IO，与"内容不该开文件"的口径冲突），所以要挑一份收窄的纯函数集。
2. **一个概念两套 API**：`Game.desk` 公开字段与 `game:getDesk()` 方法**并存**，包与测试两种写法都有。规格其实早站字段这边（`core-game`：「SHALL 以**公开字段** `desk` / `random` 提供对它们的读取」），getter 从来不是要求。

## What Changes

- **注入一份收窄的工具集 `util`**（纯函数，先放三个）：`util.filter(列表, 判定)` / `util.map(列表, 变换)` / `util.contains(列表, 值)`。它 MUST NOT 是内核工具库本体 —— 只放不碰 IO / 进程 / 时间的纯函数，清单以类型文件为准。
- **注入面口径跟着写清**：内容侧能看到的是「`game` + `Card` / `Depends` + `util` + 标准库白名单」；`moe` / `require` / `io` / `os` 仍一律不给。
- **删 `getDesk` / `getRandom`**，`game` 的读取统一走公开字段（包、测试、文档一起改）。这是 API 收敛，不改规格（`core-game` 已是字段口径）。
- **本批不做**：换成"增强标准库"（往注入的 `table` 上加 `filter`）—— 那会让人误以为 `table.filter` 是 Lua 自带的；也不挂在局上（`game.table.*` 语义不对，还会与局的字段抢名字）。

## Capabilities

### Modified Capabilities

- `rule-loading`: 「规则集执行环境的注入面」增加 `util`（收窄的纯函数工具集），并把"不给副作用能力"的口径写清

## Impact

- **装载器**：新增 `server/core/loader/env-util.lua`（纯函数集：`filter` / `map` / `contains`，其中后两个转调 `moe.util.map` / `moe.util.arrayHas`）；`server/core/loader/init.lua` 把它注入环境；`server/core/loader/env-meta.lua` 声明 `util` 的类型（包作者有补全）。
- **内核**：`server/core/game.lua` 删掉 `getDesk` / `getRandom`（字段保留）。
- **规则包**：`package/@基础/{体力,牌堆,攻击范围}.lua`、`package/身份场/开局.lua`、`package/标准/卡牌/杀.lua` 改用 `game.desk` / `game.random`；「杀」的目标筛选改用 `util.filter`。
- **测试**：`server/test/core/{game,reload}.lua` 改用字段；`server/test/rule/**` 补「注入面里有 `util`」「工具集里没有 IO 类函数」用例。
- **文档**：`moe-kill-dev` 的 `architecture.md` §9.6（注入面）与 §12（示例）、`sanguosha-rules/SKILL.md` §9.1（可用工具）；`infrastructure.md` 目录表若涉及。
