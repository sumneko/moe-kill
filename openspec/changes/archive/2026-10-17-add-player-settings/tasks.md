# Tasks

## 1 内核机制

- [x] 1.1 `server/core/game.lua`：`defineSetting { name, default, describe? }` / `getSettingDefault(name)` / `listSettings()`（按声明顺序，重复声明以后者为准）。验证：内核用例「声明一条就能查到默认值」「内核不预设条目」
- [x] 1.2 `server/core/player.lua`：`Player:getSetting(name)` 转发 `self.user`，没有连接回默认值。验证：用例「没有连接的玩家取到默认值」

## 2 设置的袋子与协议

- [x] 2.1 `server/user/user.lua`：`User.settings`（复用 `client.settings`，没有连接就自持）、`User:getSetting(name)`（改过的值优先，否则默认值）、`User:updateSettings(patch)`。验证：用例「没改过就是默认值」「重开一局后设置还在」
- [x] 2.2 `server/proto.d.lua`：`Proto.Setting`、`Proto.Settings`（Record）、`Proto.SnapShot.settings`、`Proto.Request.Settings.Change`、`Proto.Result.Settings.Change`、`Proto.Notify.Settings.Update`。验证：`server/bin/moe-kill.exe --gen-proto` 生成的 `client/src/proto.d.ts` 里有 `Setting` / `Settings.Update`
- [x] 2.3 `server/user/settings-sync.lua`（新增）：注册 `Settings.Change`（未知键整包 `-32602`）、`toProto(user)` 组装全量、变更后给本人发一条 `Settings.Update`。验证：用例「改一项」「未知键整包拒收」「只推给本人」
- [x] 2.4 `server/user/snapshot.lua`：快照带 `settings`。验证：用例「快照带自己的设置」

## 3 内容侧

- [x] 3.1 `package/@基础/设置.lua`（新增）：在包文件顶层（装载时）声明 `无懈可击不响应自己的锦囊`（默认 `true`）+ `describe`；`meta.lua` 不用改（声明走 `game:defineSetting`）。验证：真实开局快照里出现这一条
- [x] 3.2 `package/标准/卡牌/无懈可击.lua`：`nullified` 一圈里跳过「使用者本人且该设置开着」。验证：`rule.trick` 用例「开启时自己的锦囊不问自己」「关闭后照问自己」「别人的锦囊不受影响」

## 4 前端

- [x] 4.1 `client/src/state/agent.ts`：`settings`（`Map<name, Proto.Setting>`）+ `applySettings(list)` + `changeSettings(patch)`（走 `Settings.Change`，回包整份替换）；`Settings.Update` 通知接上；`reset()` 清空
- [x] 4.1b `client/src/state/agent.ts`：本地存档（`localStorage`，key 带服务器 + 用户名）+ 每次拿到快照后 `restoreLocalSettings()` 重传不一致的项（用户 2026-10-17「重连后应该重新上传本地配置」）
- [x] 4.2 `client/src/view/App.ts` 顶栏：「设置」按钮 + 设置卡片（逐条复选框 / 输入，改完即提交）；「重新同步」「调试抽屉」只在 `agent.debug` 时渲染
- [x] 4.3 `client/src/view/table.css`：设置卡片的样式（顶栏弹出、正式功能风格）

## 5 用例

- [x] 5.1 内核 `server/test/core/game.lua`：定义 / 默认值 / 重复声明 / 空清单
- [x] 5.2 `server/test/user/settings-sync.lua`（新增）：快照带全量、改一项、未知键拒收、只推本人、跨重开保留
- [x] 5.3 `server/test/rule/trick.lua`：三条内容侧场景

## 6 收尾

- [x] 6.1 全量验收：`server/bin/moe-kill.exe --test` 全绿（报出基线数）
- [x] 6.2 问题面板 information 及以上 0；`npm --prefix client run build` 过
- [x] 6.3 真链路（4 页）：顶栏出现「设置」，非调试模式看不到「重新同步」「调试抽屉」；改一项后开关自己的锦囊会/不会被问无懈
- [x] 6.4 文档：`references/architecture.md`（设置一段 + 下行表）、`references/progress.md`（§1 + 基线 + 待办表把 #3 标完成）
- [x] 6.5 归档前 `openspec validate add-player-settings --strict`

