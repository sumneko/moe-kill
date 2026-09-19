---@meta

---@type Game
game = nil

---@type fun(name: string): CardDef
Card = nil

---@type fun(items: string[])
Depends = nil

---@class Game.EventCtx.游戏开始 # 目前没有事件参数：触发时给空表，环境对象从 game 取

---@class Game.EventCtx.卡牌 # 使用一张牌时的上下文：内容侧的回调与「卡牌-结算后」共用
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targets Player[] # 目标（可以为空表）

---@class Game.EventCtx.伤害 # 「伤害-前」与「伤害-后」共用：前者触发时体力未变，后者已变
---@field from Player # 伤害来源
---@field to Player # 承受者
---@field amount integer # 点数

---@class Game
---@field on fun(self: Game, name: '游戏-开始', callback: fun(ctx: Game.EventCtx.游戏开始)): function
---@field fire fun(self: Game, name: '游戏-开始', ctx: Game.EventCtx.游戏开始)
---@field on fun(self: Game, name: '卡牌-结算后', callback: fun(ctx: Game.EventCtx.卡牌)): function
---@field fire fun(self: Game, name: '卡牌-结算后', ctx: Game.EventCtx.卡牌)
---@field on fun(self: Game, name: '伤害-前', callback: fun(ctx: Game.EventCtx.伤害)): function
---@field fire fun(self: Game, name: '伤害-前', ctx: Game.EventCtx.伤害)
---@field on fun(self: Game, name: '伤害-后', callback: fun(ctx: Game.EventCtx.伤害)): function
---@field fire fun(self: Game, name: '伤害-后', ctx: Game.EventCtx.伤害)
---@field on fun(self: Game, name: string, callback: fun(ctx: any)): function
---@field fire fun(self: Game, name: string, ...: any)
