---@meta

-- 本文件只声明注入环境的类型：环境对象本身、内容定义入口、以及 game 上的**事件**（按名收窄 on/fire 的上下文）。
-- Game 上其余入口（askCard / moveCard …）的声明在 `server/core/game.lua`，别往这里抄一份。

---@type Game
game = nil

---@type fun(name: string): CardDef
Card = nil

---@type fun(items: string[])
Depends = nil

---@class CardDef # 牌的钩子是**固定**的：名字由内核约定、与启用的包无关，清单以本文件为准（不留 string 兜底，拼错在编辑期就报）
---@field on fun(self: CardDef, event: '获取目标', handler: fun(ctx: CardDef.TargetCtx): Player[]): CardDef
---@field on fun(self: CardDef, event: '生效', handler: fun(ctx: CardEffect)): CardDef
---@field limit fun(self: CardDef, phase: string, count: integer): CardDef # 声明这个阶段里最多用几次（没声明 = 1000）
---@field getLimit fun(self: CardDef, phase: string): integer
---@field kind fun(self: CardDef, name: string): CardDef # 加一个分类（可多次调；取值省略「牌」字：基本 / 锦囊 / 装备）
---@field isKind fun(self: CardDef, name: string): boolean
---@field getKinds fun(self: CardDef): string[]
---@field zone fun(self: CardDef, zone: string): CardDef # 必须从哪个牌区用（不声明 = 使用者任一牌区都行）
---@field getZone fun(self: CardDef): string?
---@field extends fun(self: CardDef, name: string): CardDef # 把基类定义的钩子与字段抖过来（基类的钩子跑在前面）

---@class CardDef.TargetCtx # 「获取目标」的上下文：这次想用哪张牌（还没定目标）
---@field user Player # 使用者
---@field card Card # 要用的牌

---@class Game.EventCtx.游戏开始 # 目前没有事件参数：触发时给空表，环境对象从 game 取

---@class Game.EventCtx.回合 # 回合级时机：谁是回合角色
---@field player Player # 回合角色

---@class Game.EventCtx.卡牌能否使用 # 这张牌此刻能不能用：返回非 nil 值即否决（返回值就是原因）
---@field user Player # 使用者
---@field card Card # 要用的牌
---@field targets? Player[] # 要校验的目标（省略 = 只判「此刻能不能用」）

---@class Game
---@field on fun(self: Game, name: '游戏-开始', callback: fun(ctx: Game.EventCtx.游戏开始): any): function
---@field fire fun(self: Game, name: '游戏-开始', ctx: Game.EventCtx.游戏开始): any
---@field on fun(self: Game, name: '卡牌-询问', callback: fun(ctx: AskCard): any): function
---@field fire fun(self: Game, name: '卡牌-询问', ctx: AskCard): any
---@field on fun(self: Game, name: '卡牌-答复', callback: fun(ctx: AskCard): any): function
---@field fire fun(self: Game, name: '卡牌-答复', ctx: AskCard): any
---@field on fun(self: Game, name: '卡牌-答复后', callback: fun(ctx: AskCard): any): function
---@field fire fun(self: Game, name: '卡牌-答复后', ctx: AskCard): any
---@field on fun(self: Game, name: '卡牌-能否使用', callback: fun(ctx: Game.EventCtx.卡牌能否使用): any): function
---@field fire fun(self: Game, name: '卡牌-能否使用', ctx: Game.EventCtx.卡牌能否使用): any # 返回值就是那条否决原因
---@field on fun(self: Game, name: '卡牌-结算前', callback: fun(ctx: UseCard): any): function
---@field fire fun(self: Game, name: '卡牌-结算前', ctx: UseCard): any
---@field on fun(self: Game, name: '卡牌-结算后', callback: fun(ctx: UseCard): any): function
---@field fire fun(self: Game, name: '卡牌-结算后', ctx: UseCard): any
---@field on fun(self: Game, name: '伤害-前', callback: fun(ctx: Damage): any): function
---@field fire fun(self: Game, name: '伤害-前', ctx: Damage): any
---@field on fun(self: Game, name: '伤害-生效', callback: fun(ctx: Damage): any): function
---@field fire fun(self: Game, name: '伤害-生效', ctx: Damage): any
---@field on fun(self: Game, name: '伤害-后', callback: fun(ctx: Damage): any): function
---@field fire fun(self: Game, name: '伤害-后', ctx: Damage): any
---@field on fun(self: Game, name: '回复-前', callback: fun(ctx: Heal): any): function
---@field fire fun(self: Game, name: '回复-前', ctx: Heal): any
---@field on fun(self: Game, name: '回复-生效', callback: fun(ctx: Heal): any): function
---@field fire fun(self: Game, name: '回复-生效', ctx: Heal): any
---@field on fun(self: Game, name: '回复-后', callback: fun(ctx: Heal): any): function
---@field fire fun(self: Game, name: '回复-后', ctx: Heal): any
---@field on fun(self: Game, name: '摸牌', callback: fun(ctx: Draw): any): function
---@field fire fun(self: Game, name: '摸牌', ctx: Draw): any
---@field on fun(self: Game, name: '判定-亮牌', callback: fun(ctx: Judge): any): function
---@field fire fun(self: Game, name: '判定-亮牌', ctx: Judge): any
---@field on fun(self: Game, name: '判定-前', callback: fun(ctx: Judge): any): function
---@field fire fun(self: Game, name: '判定-前', ctx: Judge): any # 改判窗口：只能在这里面换牌
---@field on fun(self: Game, name: '判定-后', callback: fun(ctx: Judge): any): function
---@field fire fun(self: Game, name: '判定-后', ctx: Judge): any
---@field on fun(self: Game, name: '濒死-进入', callback: fun(ctx: Dying): any): function
---@field fire fun(self: Game, name: '濒死-进入', ctx: Dying): any
---@field on fun(self: Game, name: '濒死-离开', callback: fun(ctx: Dying): any): function
---@field fire fun(self: Game, name: '濒死-离开', ctx: Dying): any
---@field on fun(self: Game, name: '玩家-死亡', callback: fun(ctx: Player): any): function
---@field fire fun(self: Game, name: '玩家-死亡', ctx: Player): any
---@field on fun(self: Game, name: '回合-开始', callback: fun(ctx: Game.EventCtx.回合): any): function
---@field fire fun(self: Game, name: '回合-开始', ctx: Game.EventCtx.回合): any
---@field on fun(self: Game, name: '回合-结束', callback: fun(ctx: Game.EventCtx.回合): any): function
---@field fire fun(self: Game, name: '回合-结束', ctx: Game.EventCtx.回合): any
---@field on fun(self: Game, name: '阶段-开始', callback: fun(ctx: Phase): any): function
---@field fire fun(self: Game, name: '阶段-开始', ctx: Phase): any
---@field on fun(self: Game, name: '阶段-结束', callback: fun(ctx: Phase): any): function
---@field fire fun(self: Game, name: '阶段-结束', ctx: Phase): any
---@field on fun(self: Game, name: '决策-询问', callback: fun(ctx: Ask): any): function
---@field fire fun(self: Game, name: '决策-询问', ctx: Ask): any
---@field on fun(self: Game, name: '决策-答复', callback: fun(ctx: Ask): any): function
---@field fire fun(self: Game, name: '决策-答复', ctx: Ask): any
---@field on fun(self: Game, name: '游戏-结束', callback: fun(ctx: Game.Result): any): function
---@field fire fun(self: Game, name: '游戏-结束', ctx: Game.Result): any
---@field on fun(self: Game, name: string, callback: fun(ctx: any): any): function
---@field fire fun(self: Game, name: string, ...: any): any # 第一个回调明确给出的返回值（快速返回）
