# Tasks

## 1. 玩家：存活状态与所属局

- [x] 1.1 `server/core/player.lua`：加 `alive` 字段（默认活着）+ `isAlive()` / `setAlive(值)`（从活变死触发 `self.game:fire('玩家-死亡', self)`）+ `bindGame(game)`。验证：`--test core.player` 通过
- [x] 1.2 `server/core/player.lua`：`game` 字段标 `private`、跨模块只走 `bindGame`（LuaDoc 可见性检查：`package` 的可见范围是同一文件）。验证：问题面板 information 及以上为 0
- [x] 1.3 `server/core/player.lua`：`acting` 从存储字段改成 **`__getter` 派生属性**（当前只检查 `alive`），删掉 `setActing` / `isActing`；`desk:getNext` 改读 `player.acting`。验证：面板 0（`Player` 需 `: Class.Base`，getter 里走公开的 `isAlive()` 以免碰到 `alive` 的私有可见性）
- [x] 1.4 用例跟着改：`test/core/desk.lua`「跳过不参与行动的玩家」改用 `setAlive`；`test/core/player.lua` 那条改成「参与行动由存活派生」

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
- [x] 4.2 `openspec validate --all --strict` 全通过；勾完任务 → 提交推送 → 归档 → 再提交推送

## 5. 已定的口径（原待定项）

- [x] 5.1 「参与行动」怎么定？——**用户 2026-09-19 定：改成 `__getter` 派生属性，实现体先只检查 `alive`**（活着就参与），别的来源（退出 / 旁观 / 未参与本局）等遇到再说；因此删掉 `setActing` / `isActing`（不再让调用方直接置位）
- [x] 5.2 桌子两个列表的口径？——**现算、不缓存**（原写法是“getter 缓存 + 订阅 `玩家-死亡` 清缓存”，被“事件表是内容、每次加载会 `clear()`”证否，见 design 的风险条目）

