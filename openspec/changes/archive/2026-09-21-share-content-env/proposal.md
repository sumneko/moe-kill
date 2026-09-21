# Proposal

## Why

装载器**给每个文件各造一份书写环境**（`loadFile` 里 `makeEnv { game, Card, Depends, util }`）⇒ 一个文件里写的全局（`function 帮手() end`）**只有这个文件自己看得见**，包与包（甚至同包两个文件）之间**没有任何共享函数的通道**。于是「是否已受伤」这类小判定、小工具，每个包只能各写一遍；而「规则数值不许存函数」又堵死了数据通道（用户 2026-09-21 记下的待办）。

用户 2026-09-21 定：**先把环境改成共享的** —— 与其专门造一套「服务表 / 注册表」机制，不如让内容侧直接写全局函数（同一个环境里的普通全局），内核不进这个圈子。

## What Changes

- **装载器：整轮装载共用一份书写环境**（`Loader.Context.env`）——
  - 真跑一份、试跑一份（两趟各自的语义一致，免得试跑因为「跨文件调用」误报）。
  - 于是**包 A 里写的全局函数，包 B 直接就能用**（顺序 = 加载顺序）。
- **注入项每个文件加载前刷回**：`game` / `Card` / `Depends` / `util` 在每次 `load` 之前重新赋一遍 ⇒ 某个包把 `game` 顺手改成别的值，也影响不到后面的文件（零元表机制，也不用 `__newindex` 守卫）。
- 用例（`rule` 套件 +3）：共享全局函数、注入项刷回、重装换新环境。
- 文档：`architecture.md` §9.6 与 `sanguosha-rules` §9.1 改掉「注入面 / 没有共享函数通道」的旧口径。

**明确不做**（留给下一批，见 design D4）：

- **把 `env-util` 挪进 `package/`**（用户 2026-09-21 提到「感觉可以」）：共享环境之后它**技术上可行**（`@基础` 写一个全局 `util = { ... }`），但会让「`util` 由内核保证」变成「不装基础就没有 `util`」，且类型面要从 `env-meta.lua` 挪到包的 `meta.lua` —— 单独确认后再做。
- 显式的服务表（`game:provide` / `game:call`）：先不上，共享全局函数够用。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设 `skip_specs: true`）：契约由用例承担 —— `--test rule`（三条新用例）。

## Impact

- 改动：`server/core/loader/init.lua`（`Loader.Context` 增 `env` / `injected`；`install` 建一份共享环境；`loadFile` 用它 + 刷回注入项；试跑的 `probeEnv` 同样一份）、`server/test/rule/init.lua`（+3 用例）
- 文档：`architecture.md` §9.6、`sanguosha-rules` §9.1
- 沙箱口径**不变**：白名单仍是那 24 个基函数，**没有** `__index = _G`（`moe` / `require` / `io` / `os` 照旧拿不到）
