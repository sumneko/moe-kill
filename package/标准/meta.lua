---@meta

---@class 标准.牌表项
---@field name string
---@field count integer

---@class Game
---@field getValue fun(self: Game, name: '牌表'): 标准.牌表项[]
---@field getValue fun(self: Game, name: string): any
---@field setValue fun(self: Game, name: '牌表', value: 标准.牌表项[])
---@field setValue fun(self: Game, name: string, value: any)
