# Tasks

## 1. 新增工具包

- [x] 1.1 `package/@tools/工具.lua`：内容侧写法实现 `filter` / `map` / `contains`，写下全局 `util`
- [x] 1.2 `package/@tools/meta.lua`：`---@class 工具.工具集` + `---@type 工具.工具集` 的全局 `util`

## 2. 内核不再注入 `util`

- [x] 2.1 `loader/init.lua`：删 `envUtil` 引用（真跑 `ctx.injected` 与试跑 `probe` 两处），`Loader.Context.injected` 的注释同步
- [x] 2.2 删 `server/core/loader/env-util.lua`
- [x] 2.3 `loader/env-meta.lua`：删 `---@type Loader.EnvUtil` + `util = nil`（类型搬到 `@tools/meta.lua`）

## 3. 用例

- [x] 3.1 `server/test/rule/init.lua`：加 `loadWithContent`（来源 = 探针目录 + 项目 `package` 目录），两条工具集用例改用它；用例名改成「能用工具包（@tools）的纯函数筛列表」
- [x] 3.2 验证：`--test rule` 与全量 `--test` 0 失败
- [x] 3.3 问题面板 information 及以上为 0（重点看 `package/标准/卡牌/杀.lua` 里的 `util.filter` 还有没有类型）

## 4. 文档

- [x] 4.1 `architecture.md`：注入面改成「内核只注入 `game` / `Card` / `Depends` + 白名单」+ 新增「`util` 由 `@tools` 提供」的说明；`util` 那条清单改指 `package/@tools/工具.lua`；类型面两处同步
- [x] 4.2 `sanguosha-rules` §9.1：注入面 / 工具集 / 「不需要 require」三条
- [x] 4.3 `code-style.md`（loader 内部子模块清单去掉 `env-util`）、`moe-kill-dev/SKILL.md` 的 `package/` 行（补 `@tools`）
