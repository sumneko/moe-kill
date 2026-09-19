---@meta

---@type Game
game = nil

---@type fun(name: string): CardDef
Card = nil

---@type fun(items: string[])
Depends = nil

---@class Game.EventCtx.游戏开始 # 目前没有事件参数：触发时给空表，环境对象从 game 取

---@class Game
---@field on fun(self: Game, name: '游戏-开始', callback: fun(ctx: Game.EventCtx.游戏开始)): function
---@field fire fun(self: Game, name: '游戏-开始', ctx: Game.EventCtx.游戏开始)
---@field on fun(self: Game, name: '卡牌-结算后', callback: fun(ctx: UseCard)): function
---@field fire fun(self: Game, name: '卡牌-结算后', ctx: UseCard)
---@field on fun(self: Game, name: '伤害-前', callback: fun(ctx: Damage)): function
---@field fire fun(self: Game, name: '伤害-前', ctx: Damage)
---@field on fun(self: Game, name: '伤害-后', callback: fun(ctx: Damage)): function
---@field fire fun(self: Game, name: '伤害-后', ctx: Damage)
---@field on fun(self: Game, name: string, callback: fun(ctx: any)): function
---@field fire fun(self: Game, name: string, ...: any)
