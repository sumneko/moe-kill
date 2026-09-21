---@meta

-- 本文件只声明注入环境的类型：环境对象本身、内容定义入口、以及 game 上的**事件**（按名收窄 on/fire 的上下文）。
-- Game 上其余入口（askCard / moveCard …）的声明在 `server/core/game.lua`，别往这里抄一份。

---@type Game
game = nil

---@type Loader.EnvUtil # 收窄的纯函数工具集（清单见 `server/core/loader/env-util.lua`），不是 `moe.util` 本体
util = nil

---@type fun(name: string): CardDef
Card = nil

---@type fun(items: string[])
Depends = nil

---@class CardDef # 牌的钩子是**固定**的：名字由内核约定、与启用的包无关，清单以本文件为准（不留 string 兜底，拼错在编辑期就报）
---@field on fun(self: CardDef, event: '获取目标', handler: fun(ctx: UseCard): Player[]): CardDef
---@field on fun(self: CardDef, event: '生效', handler: fun(ctx: CardEffect)): CardDef

---@class Game.EventCtx.游戏开始 # 目前没有事件参数：触发时给空表，环境对象从 game 取

---@class Game.EventCtx.回合 # 回合级时机：谁是回合角色
---@field player Player # 回合角色

---@class Game.EventCtx.阶段 # 阶段级时机：谁是回合角色、哪个阶段
---@field player Player # 回合角色
---@field phase string # 阶段名（准备 / 判定 / 摸牌 / 出牌 / 弃牌 / 结束）

---@class Game
---@field on fun(self: Game, name: '游戏-开始', callback: fun(ctx: Game.EventCtx.游戏开始)): function
---@field fire fun(self: Game, name: '游戏-开始', ctx: Game.EventCtx.游戏开始)
---@field on fun(self: Game, name: '卡牌-询问', callback: fun(ctx: AskCard)): function
---@field fire fun(self: Game, name: '卡牌-询问', ctx: AskCard)
---@field on fun(self: Game, name: '卡牌-答复', callback: fun(ctx: AskCard)): function
---@field fire fun(self: Game, name: '卡牌-答复', ctx: AskCard)
---@field on fun(self: Game, name: '卡牌-答复后', callback: fun(ctx: AskCard)): function
---@field fire fun(self: Game, name: '卡牌-答复后', ctx: AskCard)
---@field on fun(self: Game, name: '卡牌-结算前', callback: fun(ctx: UseCard)): function
---@field fire fun(self: Game, name: '卡牌-结算前', ctx: UseCard)
---@field on fun(self: Game, name: '卡牌-结算后', callback: fun(ctx: UseCard)): function
---@field fire fun(self: Game, name: '卡牌-结算后', ctx: UseCard)
---@field on fun(self: Game, name: '伤害-前', callback: fun(ctx: Damage)): function
---@field fire fun(self: Game, name: '伤害-前', ctx: Damage)
---@field on fun(self: Game, name: '伤害-生效', callback: fun(ctx: Damage)): function
---@field fire fun(self: Game, name: '伤害-生效', ctx: Damage)
---@field on fun(self: Game, name: '伤害-后', callback: fun(ctx: Damage)): function
---@field fire fun(self: Game, name: '伤害-后', ctx: Damage)
---@field on fun(self: Game, name: '回复-前', callback: fun(ctx: Heal)): function
---@field fire fun(self: Game, name: '回复-前', ctx: Heal)
---@field on fun(self: Game, name: '回复-生效', callback: fun(ctx: Heal)): function
---@field fire fun(self: Game, name: '回复-生效', ctx: Heal)
---@field on fun(self: Game, name: '回复-后', callback: fun(ctx: Heal)): function
---@field fire fun(self: Game, name: '回复-后', ctx: Heal)
---@field on fun(self: Game, name: '摸牌', callback: fun(ctx: Draw)): function
---@field fire fun(self: Game, name: '摸牌', ctx: Draw)
---@field on fun(self: Game, name: '濒死', callback: fun(ctx: Dying)): function
---@field fire fun(self: Game, name: '濒死', ctx: Dying)
---@field on fun(self: Game, name: '玩家-死亡', callback: fun(ctx: Player)): function
---@field fire fun(self: Game, name: '玩家-死亡', ctx: Player)
---@field on fun(self: Game, name: '回合-开始', callback: fun(ctx: Game.EventCtx.回合)): function
---@field fire fun(self: Game, name: '回合-开始', ctx: Game.EventCtx.回合)
---@field on fun(self: Game, name: '回合-结束', callback: fun(ctx: Game.EventCtx.回合)): function
---@field fire fun(self: Game, name: '回合-结束', ctx: Game.EventCtx.回合)
---@field on fun(self: Game, name: '阶段-开始', callback: fun(ctx: Game.EventCtx.阶段)): function
---@field fire fun(self: Game, name: '阶段-开始', ctx: Game.EventCtx.阶段)
---@field on fun(self: Game, name: '阶段-结束', callback: fun(ctx: Game.EventCtx.阶段)): function
---@field fire fun(self: Game, name: '阶段-结束', ctx: Game.EventCtx.阶段)
---@field on fun(self: Game, name: '决策-询问', callback: fun(ctx: Ask)): function
---@field fire fun(self: Game, name: '决策-询问', ctx: Ask)
---@field on fun(self: Game, name: '决策-答复', callback: fun(ctx: Ask)): function
---@field fire fun(self: Game, name: '决策-答复', ctx: Ask)
---@field on fun(self: Game, name: string, callback: fun(ctx: any)): function
---@field fire fun(self: Game, name: string, ...: any)
