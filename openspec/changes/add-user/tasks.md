# Tasks

## 1. 内核：Player 的 User

- [x] 1.1 `Player` 加 `---@field user? User` + `Player:setUser(user?)`（绑定 / 更换 / 解绑）
- [x] 1.2 用例：设置 / 更换 / 解绑 / 没有 User 时读出来是空

## 2. 内核：询问优先问 User

- [x] 2.1 每个询问类在自己的取值处先问 `to.user`；`AskCard` 一族共用一个取值处 ⇒ 加可覆写钩子 `AskCard:askUser(user)`（基类转发 `askCard`，四个子类各覆写一行）
- [x] 2.2 接上 11 个询问类（`ask` / `ask-choice` / `ask-player` / `ask-card` / `ask-card-with-target` / `ask-use-card` / `ask-use-card-to-card` / `ask-play-card` / `ask-use-skill` / `ask-hero` / `ask-panel`）
- [x] 2.3 用例：User 表态 ⇒ 全局订阅者不被调用；User 不表态 ⇒ 回落全局；User 与全局都表态 ⇒ 按 User 的

## 3. User 基类

- [x] 3.1 `server/user/user.lua`：`User` 基类 + 11 个方法（默认返回空）；`init.lua` 只做装载
- [x] 3.2 在 `server/moe-kill.lua` 里 `require 'user.client'`（注册两个类；不参与热重载）

## 4. ClientUser 骨架

- [x] 4.1 `server/user/client-user.lua`：`ClientUser : User`，11 个方法先照基类（协议接线留待后续）

## 5. 文档与验收

- [x] 5.1 `references/architecture.md` 新增一节（User 与询问的分派：落点 / 顺序 / 与 session 的关系）
- [x] 5.2 `references/progress.md` §1 加条目、基线更新
- [x] 5.3 `server/bin/moe-kill.exe --test` 全绿（1121 用例 0 失败）、问题面板 information 及以上为 0
- [x] 5.4 技能文档同步：`SKILL.md` 目录表加 `server/user/` 行（session 行注明「之后去掉」）
