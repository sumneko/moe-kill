---@meta

---@type Moe.Game
game = nil

---@type fun(name: string): Moe.CardDef
Card = nil

---@type fun(items: string[])
Depends = nil

---@class Moe.Game.EventCtx.游戏开始 # 目前没有事件参数：触发时给空表，环境对象从 game 取

---@class Moe.Game
---@field on fun(self: Moe.Game, name: '游戏-开始', callback: fun(ctx: Moe.Game.EventCtx.游戏开始)): function
---@field fire fun(self: Moe.Game, name: '游戏-开始', ctx: Moe.Game.EventCtx.游戏开始)
---@field on fun(self: Moe.Game, name: string, callback: fun(ctx: any)): function
---@field fire fun(self: Moe.Game, name: string, ...: any)
