---@meta

---@class 标准.牌表项 # 一张牌一条（逐张：同名多张各有各的花色与点数）
---@field name string
---@field suit string # 花色：黑桃 / 红桃 / 梅花 / 方块
---@field point integer # 点数：1..13（A=1 … K=13）

---@class Game
---@field getValue fun(self: Game, name: '牌表'): 标准.牌表项[]
---@field getValue fun(self: Game, name: string): any
---@field setValue fun(self: Game, name: '牌表', value: 标准.牌表项[])
---@field setValue fun(self: Game, name: string, value: any)
