---@meta

---@type Game
game = nil

---@type fun(name: string): CardDef
Card = nil

---@type fun(items: string[])
Depends = nil

---@class CardDef # 牌的钩子是**固定**的：名字由内核约定、与启用的包无关，清单以本文件为准（不留 string 兜底，拼错在编辑期就报）
---@field on fun(self: CardDef, event: '获取目标', handler: fun(ctx: UseCard): Player[]): CardDef
---@field on fun(self: CardDef, event: '使用', handler: fun(ctx: UseCard)): CardDef

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
