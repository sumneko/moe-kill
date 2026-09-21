# Proposal

## Why

内容侧的类型面现在只有**内核一处**（`server/core/loader/env-meta.lua`），而包自己的概念**无处声明**：

- `player:getTag('身份')` → `any`（内核的标签是 `table<string, any>`，它不解释取值 —— 这是对的）；
- `game:getValue('默认体力')` / `getValue('身份配置')` / `getValue('牌表')` → `any`；
- `player:getAttr('体力')` → `any`。

于是「身份写成了 `'反贼'` 还是 `'反贼 '`」「规则数值的名字拼错」「属性名拼错」这些错，都要到运行期才发现（拼错的键取回 `nil`，静默）。用户 2026-09-21 提出：**在包里加点 meta 文件**。

实测（三个包各带一份、同时生效）验证了这条路可行：

```
game:getValue('主公额外体力')   →  '主公额外体力'|'默认体力'  →  integer   （来自 @基础/meta.lua）
game:getValue('身份配置')       →  '身份配置'                →  table<integer, table>（来自 身份场/meta.lua）
player:getTag('身份')           →  '身份'                    →  '主公'|'忠臣'|'反贼'|'内奸'
```

## What Changes

- **约定：包目录下可以放 `meta.lua`** —— 一份**纯 LuaDoc** 文件（`---@meta` 开头），用来声明这个包自己的类型面：`---@alias`、以及给 `Player` / `Game` 这类内核类**追加按名收窄的字段签名**。名字固定叫 `meta`（用户 2026-09-21 定：它是**纯代码功能**，不是规则内容，所以不按「包内文件名用中文」的约定）。
- **装载器不特殊对待它**：`meta.lua` 照常被当普通内容文件执行 —— 里面只有注释 ⇒ 是空操作（实测全量 354 用例全绿）。不引入「跳过某些文件」的新机制。
- **三个包各自补一份**：
  - `package/@基础/meta.lua`：规则数值 `默认体力` / `主公额外体力` → `integer`；属性名 `体力` / `体力上限` / `攻击范围` → `number`（`getAttr` / `setAttr` / `addAttr`）。
  - `package/身份场/meta.lua`：`---@alias 身份场.身份`（四种身份）+ `身份配置` 的结构 + `player:getTag/setTag('身份')` 收窄。
  - `package/标准/meta.lua`：`牌表` 的结构（`{ name, count }[]`）。
- **配方（有过坑，见 design D3）**：收窄那几条**后面必须再写一条兜底签名**（`key: string` / `name: string`），否则会把内核原来的签名吃掉。
- **文档**：`architecture.md` 增补「包自带 meta」的约定与配方（并改掉「类型面只有 env-meta 一处」的旧口径）；`sanguosha-rules` §9.1 补一条写法；`code-style.md` 记下「跨文件重声明同名 `---@field` 必须带兜底签名」这个坑。

**明确不做**：

- **便捷函数**（「是否已受伤」这类）：用户 2026-09-21 定「遇到再说」。
- 让装载器**跳过** `meta.lua`（纯注释执行无害；真要跳过再说）。
- 把收窄继续堆进内核 `env-meta.lua`（内核文件里会写满各内容包的概念，第三方包也改不了）。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- （无）

> 探索期不写规格（`.openspec.yaml` 设 `skip_specs: true`）：类型收窄没有运行期契约可测 —— 验证靠**问题面板 0 + hover 抽查**，再加一条用例锁住「`meta.lua` 照常参与装载、不报错、不进规则表」。

## Impact

- 新增：`package/@基础/meta.lua`、`package/身份场/meta.lua`、`package/标准/meta.lua`
- 改动：`server/test/rule/meta.lua`（补一条「包里的 meta 文件不参与规则表」用例）
- 文档：`architecture.md`（包作者的类型面 + 配方）、`sanguosha-rules` §9.1、`code-style.md`、`moe-kill-dev/SKILL.md` 的 `package/` 行
- 运行期行为：**零变化**（文件里只有注释）
