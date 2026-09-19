---@meta

---@type Moe.Game
game = nil

---@type fun(name: string): Moe.CardDef
Card = nil

---@type fun(items: string[])
Depends = nil

---@class Moe.Game.EventCtx.游戏开始 # 目前没有事件参数：触发时给空表，环境对象从 game 取

---@class Moe.Game.EventCtx.卡牌 # 使用一张牌时的上下文：内容侧的回调与「卡牌-结算后」共用
---@field user Moe.Player # 使用者
---@field card Moe.Card # 被使用的牌
---@field targets Moe.Player[] # 目标（可以为空表）

---@class Moe.Game.EventCtx.伤害 # 「伤害-前」与「伤害-后」共用：前者触发时体力未变，后者已变
---@field from Moe.Player # 伤害来源
---@field to Moe.Player # 承受者
---@field amount integer # 点数

---@class Moe.Game
---@field on fun(self: Moe.Game, name: '游戏-开始', callback: fun(ctx: Moe.Game.EventCtx.游戏开始)): function
---@field fire fun(self: Moe.Game, name: '游戏-开始', ctx: Moe.Game.EventCtx.游戏开始)
---@field on fun(self: Moe.Game, name: '卡牌-结算后', callback: fun(ctx: Moe.Game.EventCtx.卡牌)): function
---@field fire fun(self: Moe.Game, name: '卡牌-结算后', ctx: Moe.Game.EventCtx.卡牌)
---@field on fun(self: Moe.Game, name: '伤害-前', callback: fun(ctx: Moe.Game.EventCtx.伤害)): function
---@field fire fun(self: Moe.Game, name: '伤害-前', ctx: Moe.Game.EventCtx.伤害)
---@field on fun(self: Moe.Game, name: '伤害-后', callback: fun(ctx: Moe.Game.EventCtx.伤害)): function
---@field fire fun(self: Moe.Game, name: '伤害-后', ctx: Moe.Game.EventCtx.伤害)
---@field on fun(self: Moe.Game, name: string, callback: fun(ctx: any)): function
---@field fire fun(self: Moe.Game, name: string, ...: any)
