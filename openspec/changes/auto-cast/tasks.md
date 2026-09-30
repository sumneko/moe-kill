# auto-cast

## 1 内核

- [x] 1.1 `server/core/view-as.lua`：`tryProduce` 有关联来源就把整段包成 `source:cast(…)`、无来源照旧；拆出 `---@private` 的 `launch(ask)`（跑 `'发动'` 表态 + 造牌）

- [x] 1.2 `ViewAs.source` / `Player:addViewAs` 的 `source` 收窄成 `Card|Skill`（原先 `any`，用户 2026-10-01 要求）⇒ `source:cast(…)` 有类型检查

## 2 内容侧

- [x] 2.1 `package/标准/卡牌/八卦阵.lua`：撤掉上一批手写的 `card:cast`（内核自动包了）
- [x] 2.2 `package/标准/卡牌/仁王盾.lua`：阻止时补一次空跑 `card:cast(function () end)`

## 3 用例

- [x] 3.1 `server/test/core/view-as.lua` +1：`'发动'` 钩子里起的结算挂在关联来源名下（`move.parent` 收窄成 `Cast` 后读 `.source`）

## 4 验收

- [x] 4.1 `server/bin/moe-kill.exe --test` 全绿（**814 用例 0 失败**）
- [x] 4.2 问题面板 information 及以上 0
- [x] 4.3 文档同步：`architecture.md`（`ViewAs` / `Cast` 行）、`sanguosha-rules`、`progress.md`
