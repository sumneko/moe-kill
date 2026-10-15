---@meta

---@alias 身份场.身份 '主公'|'忠臣'|'反贼'|'内奸'

---@class 身份场.准备配置
---@field identities? table<integer, 身份场.身份> # 座位号 → 身份（**要么不给、要么给全**：给全了就不再校验「身份配置」）
---@field seats? Player[] # 按坐次给全的一列玩家（给了就照它排；没给就洗一遍、最后把主公换到 1 号位）
---@field heroes? table<integer, string> # 座位号 → 武将名（点名了的直接装、不再询问）
---@field skipSelect? boolean # 整段跳过选将（用例 / 快速开局的开关）

---@class Game.Event.游戏准备
---@field config? 身份场.准备配置

---@class 身份场.身份配置项
---@field identity 身份场.身份
---@field count integer

--- 身份场的规则数值挂在装载器给的共享袋上
---@class Loader.Rule
---@field heroCandidateCount? integer
---@field identityConfig? table<integer, 身份场.身份配置项[]>

---@class Proto.Custom
---@field identity? 身份场.身份 # 身份（由 身份.lua 的 setIdentity 写入；主公正面朝上）

--- 玩家侧的自由数据里本包写入的那个键（与 `@基础/meta.lua` 的同名 class 声明合并）
---@class Player.Custom
---@field identity? 身份场.身份 # 身份（由 身份.lua 的 setIdentity 写入）

---@class Player: Class.Base
---@field isIdentityVisibleTo fun(self: Player, viewer: Player): boolean # 身份牌对他可见吗
