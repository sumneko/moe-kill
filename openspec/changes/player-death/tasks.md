# Tasks

## 1. 玩家：存活状态与所属局

- [x] 1.1 `server/core/player.lua`：加 `alive` 字段（默认活着）+ `isAlive()` / `setAlive(值)`（从活变死触发 `self.game:fire('玩家-死亡', self)`）+ `bindGame(game)`。验证：`--test core.player` 通过
- [x] 1.2 `server/core/player.lua`：`game` 字段标 `private`、跨模块只走 `bindGame`（LuaDoc 可见性检查：`package` 的可见范围是同一文件）。验证：问题面板 information 及以上为 0

## 2. 桌子：字段式读取与交给局

- [x] 2.1 `server/core/desk.lua`：删掉 `getPlayers()`，改成 `__getter` 的 `desk.players` / `desk.alivePlayers`（**每次现算，不缓存**）
- [x] 2.2 `server/core/desk.lua`：加 `bindGame(game)`（记下局 + 转交给座位上已有的玩家）；`sit` 时若已有局则一并绑定
- [x] 2.3 `server/core/game.lua`：建局时 `desk:bindGame(self)`（放在 `self.events` 建好之后）
- [x] 2.4 `server/core/loader/env-meta.lua`：补 `'玩家-死亡'` 的 `on` / `fire` 重载（上下文 = `Player`）

## 3. 调用点与用例

- [x] 3.1 规则包改用字段：`package/@基础/{体力,攻击范围,牌堆}.lua`、`package/身份场/开局.lua` → `game.desk.players`；`package/标准/卡牌/杀.lua` → `desk.alivePlayers`
- [x] 3.2 用例改用字段：`server/test/core/desk.lua`、`server/test/rule/setup.lua`、`server/test/core/play.lua`（探针）
- [x] 3.3 补用例：桌子「座位列表跟着入座更新」「存活列表跟着死亡更新」「先有局再入座，玩家也拿得到局」；玩家「默认活着，死亡时触发时机」（含重复置死不重复、复活后可再触发）「没上桌的玩家也能置存活状态」
- [x] 3.4 全量 `server\bin\moe-kill.exe --test` 0 失败（273 个用例）；问题面板 information 及以上为 0

## 4. 文档与验收

- [x] 4.1 `architecture.md`：§12 例子换成 `desk.alivePlayers` + 新增「桌子与玩家的属性式读取」说明（含「为什么不缓存」）；§10 补「内核侧订阅不能用 `game:on`、事件表是内容会被 clear」的实测结论；`moe-kill-dev/SKILL.md` 目录表与 `sanguosha-rules` §7/§9.2 同步
- [ ] 4.2 `openspec validate --all --strict` 全通过；勾完任务 → 提交推送 → 归档 → 再提交推送

## 5. 待用户定夺（已记进 design.md 的 Open Questions）

- [ ] 5.1 死亡要不要自动清「参与行动」标记（`setAlive(false)` 里联动 `setActing(false)`）？
- [ ] 5.2 是否保留现在的“现算不缓存”口径（原写法是缓存 + 订阅失效，已被事件表 `clear()` 证否）？
