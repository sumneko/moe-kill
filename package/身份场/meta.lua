---@meta

---@alias 身份场.身份 '主公'|'忠臣'|'反贼'|'内奸'

---@class 身份场.身份配置项
---@field identity 身份场.身份
---@field count integer

---@class Game
---@field getValue fun(self: Game, name: '身份配置'): table<integer, 身份场.身份配置项[]>
---@field getValue fun(self: Game, name: string): any
---@field setValue fun(self: Game, name: '身份配置', value: table<integer, 身份场.身份配置项[]>)
---@field setValue fun(self: Game, name: string, value: any)

---@class Player: Class.Base
---@field getTag fun(self: Player, key: '身份'): 身份场.身份
---@field getTag fun(self: Player, key: string): any
---@field setTag fun(self: Player, key: '身份', value: 身份场.身份)
---@field setTag fun(self: Player, key: string, value: any)
