# Tasks

## 1. 接口与调用点

- [x] 1.1 `package/身份场/身份.lua`（新）：`Class 'Player'` 的 `setIdentity(name)`（写 `player.identity`）
- [x] 1.2 `package/身份场/meta.lua`：删掉 4 行按名收窄的 `getTag` / `setTag` 签名，加 `---@field identity? 身份场.身份`
- [x] 1.3 `package/身份场/开局.lua`：2 处 `setTag('身份', …)` → `setIdentity(…)`
- [x] 1.4 `package/身份场/奖惩.lua` / `胜负.lua`：4 处 `getTag('身份')` → `player.identity`

## 2. 测试

- [x] 2.1 `server/test/rule/identity.lua`：helper 改读字段（返回类型 `身份场.身份?`）；用例名「身份被写进标签」→「身份写进字段」
- [x] 2.2 `server/test/rule/{setup,game-over,hero}.lua`：读 / 写全部换成字段与 `setIdentity`
- [x] 2.3 `server/test/core/player.lua` 那条 tag 用例**保留不动**（用户 2026-09-30 定：它测的是内核 tag 机制本身）

## 3. 验收

- [x] 3.1 `server/bin/moe-kill.exe --test` 全绿（788 用例 0 失败）
- [x] 3.2 问题面板 information 及以上清到 0
- [x] 3.3 同步文档：`references/architecture.md`（标签袋的推论 + `meta.lua` 示例）、`references/code-style.md`（跨文件签名兜底那条的例子）、`references/progress.md`（§1 新条目 + 包表格）、`references/infrastructure.md`（套件说明）、`sanguosha-rules`（§1 身份口径）
