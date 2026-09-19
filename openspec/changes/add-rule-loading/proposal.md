# Proposal

## Why

`game/` 规则集要能用「中文写卡牌与技能」，也要能在运行期**清空并重新加载**（业务功能，见下）。这两件事是「能不能开始写 `game/`」的两半：没有中文标识符，规则集读起来不像规则集；没有加载器，规则集无处安放、无法重装。

## What Changes

- **Lua 运行时支持中文标识符**：以**构建期补丁**的方式让词法分析器接受非 ASCII 标识符字符（`game/` 里可以直接写 `local 杀 = ...`、`function 造成伤害(...)`）。补丁由**本项目**持有并接进构建，**不修改 `3rd/bee.lua` 子模块**。
- **分析器侧配套**：`.luarc.json` 打开 `runtime.unicodeName`，让编辑器接受中文名称（否则满屏假诊断）。
- **新增规则集加载器**（门面 `moe.rule`，落点 `server/rule/`）：
  - `moe.rule.load(清单)`：**按清单依次加载**；加载方式是**读文件 → `load` chunk → 执行**，**不通过 `require`**（因此与热重载无关）。清单从哪来先不管，测试里写死。
  - **不做卸载**：只有「清空规则表 + 重新加载」。
  - `rule.depends { '杀', '闪', '基础规则' }`：文件级依赖声明，表示加载本文件前先加载这些依赖；依赖是**文件**就直接加载，是**目录**就加载目录下所有文件。
  - `rule.card '杀'` 形式的**定义入口**：取得（或创建）一条定义，并支持链式登记回调（`rule.card '杀' :onTargets(f) :onUse(f)`）。具体回调名与签名**留到做「杀」时再定**。
- **BREAKING**：无（`moe.reload` 与 `core` 的行为不变；规则集加载是新增面）。

## Capabilities

### New Capabilities

- `chinese-identifier`: 让 Lua 运行时与分析器接受非 ASCII 标识符，并规定构建期注入方式（补丁链、不改第三方源码树、失败即报错）。
- `rule-loading`: 规则集的加载与重载：清单驱动的文件加载、文件级依赖声明、规则定义入口、清空重载。

### Modified Capabilities

（无。`hot-reload` 与 `core-*` 的行为不变；本变更只是新增「规则集重载」这条与它不同的业务通道。）

## Impact

- 构建：`make.lua`（自接 Lua 源码补丁链 + 自有 `source_moe_lua`）、新增 `make/lua-patch/`（应用脚本 + 中文标识符补丁）。**已按用户选定的 A 路线落地并验证**（提交 `a10c732`）。
- 配置：`.luarc.json` 加 `runtime.unicodeName`（已落）。
- 新增代码：`server/rule/`（加载器 + 规则表 + 定义入口）、`server/moe-kill.lua` 挂 `moe.rule`。
- 测试：`server/test/rule/`（加载清单、目录展开、依赖顺序与去重、清空重载、加载失败、中文标识符冒烟）。
- 文档：`moe-kill-dev` 的 `architecture.md`（新增规则集加载一节）与 `infrastructure.md`（Lua 补丁链的来龙去脉与维护注意）。
- 非目标：按名单卸载、清单的来源与约定、mod 式热安装/停用、卡牌与技能的具体规则内容（等做「杀」时定）。
