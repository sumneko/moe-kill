---@meta

---@class Game
---@field getValue fun(self: Game, name: '默认体力'|'主公额外体力'): integer
---@field getValue fun(self: Game, name: string): any
---@field setValue fun(self: Game, name: '默认体力'|'主公额外体力', value: integer)
---@field setValue fun(self: Game, name: string, value: any)

---@class Player: Class.Base
---@field getAttr fun(self: Player, name: '体力'|'体力上限'|'攻击范围'): number
---@field getAttr fun(self: Player, name: string): any
---@field setAttr fun(self: Player, name: '体力'|'体力上限'|'攻击范围', value: number)
---@field setAttr fun(self: Player, name: string, value: any)
---@field addAttr fun(self: Player, name: '体力'|'体力上限'|'攻击范围', delta: number)
---@field addAttr fun(self: Player, name: string, delta: any)
