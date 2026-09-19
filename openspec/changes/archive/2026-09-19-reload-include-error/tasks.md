# Tasks

## 1. 改 `include` 的失败路径

- [x] 1.1 `server/tools/reload.lua`：新增 `onLoadError`（`log.error` 记日志 + 原样返回错误），`M.include` 用它当 message handler；失败时 `error(result, 0)`（不再 `return false, err`）
- [x] 1.2 `server/tools/reload.lua`：`M:fire()` 重新加载模块时改成 `pcall(M.include, name)`（单个模块失败不中断整轮重载）
- [x] 1.3 `server/tools/reload.lua`：注释与 `---@return` 注解同步（「加载出错会记日志并抛出」）

## 2. 去掉中间层

- [x] 2.1 `server/core/init.lua`：删掉 `includeCore`，13 行直接 `moe.X = include 'core.X'`。验证：问题面板 information 及以上为 0

## 3. 用例

- [x] 3.1 `server/test/core/reload.lua`：「加载失败的模块以明确失败暴露」改成断言**抛出**（`lt.assertError`）且错误信息带上出处；用 `<close>` 把探针从重载名单里摘掉
- [x] 3.2 全量 `server\bin\moe-kill.exe --test` 0 失败（273 个用例）；日志里失败一条（带堆栈）+ 后续 `reload finish` 正常（实测 `[error][server\tools\reload.lua:133] server\test\core\reload.lua:66: 探针模块故意报错`）

## 4. 文档与验收

- [x] 4.1 `architecture.md` §8 接口表（`include 'x'` 契约改成「记日志 + 抛出；重载时 `pcall` 隔离」）、§8.4 与 §9.1 两处 `includeCore` → `include`
- [x] 4.2 `infrastructure.md`：`reload.lua` 这条照搬记录的「改写点」更新（原来的「把错误信息交回调用方」与已不存在的 `reportError` 一并修掉）
- [ ] 4.3 `openspec validate --all --strict` 全通过；勾完任务 → 提交推送 → 归档 → 再提交推送
