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

---@class Game
---@field getValue fun(self: Game, name: '身份配置'): table<integer, 身份场.身份配置项[]>
---@field getValue fun(self: Game, name: string): any
---@field setValue fun(self: Game, name: '身份配置', value: table<integer, 身份场.身份配置项[]>)
---@field setValue fun(self: Game, name: string, value: any)

---@class Player: Class.Base
---@field identity? 身份场.身份 # 身份（由 身份.lua 的 setIdentity 写入）
---@field isIdentityVisibleTo fun(self: Player, viewer: Player): boolean # 身份牌对他可见吗
