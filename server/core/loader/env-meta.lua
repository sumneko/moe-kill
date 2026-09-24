---@meta

-- 本文件只声明注入环境的类型：环境对象本身、内容定义入口、以及 game 上的**事件**（按名收窄 on/fire 的上下文）。
-- Game 上其余入口（askCard / moveCard / drawCards …）的声明在 `server/core/game.lua`，别往这里抄一份。
-- 内核建好的五个基础牌区（局上 `抽牌` / `弃牌`，玩家身上 `手牌` / `装备` / `判定`）是**对内容侧的约定**：包可以直接取（`game:getZone('弃牌')`），但不得重建同名区；声明见 `game.lua` / `player.lua` 里 getZone 的重载。

---@type Game
game = nil

---@type fun(name: string): CardDef
Card = nil

---@type fun(items: string[])
Depends = nil

--- 牌的钩子是**固定**的：名字由内核约定、与启用的包无关，清单以本文件为准（不留 string 兜底，拼错在编辑期就报）
---@class CardDef
---@field on fun(self: CardDef, event: '获取目标', handler: fun(target: CardDef.Target): Player[]): CardDef
---@field on fun(self: CardDef, event: '结算前', handler: fun(useCard: UseCard)): CardDef # 使用结算开始时跑一次（逐目标之前）
---@field on fun(self: CardDef, event: '生效', handler: fun(cardEffect: CardEffect, useCard: UseCard)): CardDef
---@field on fun(self: CardDef, event: '结算后', handler: fun(useCard: UseCard)): CardDef # 所有目标结算完之后跑一次
---@field limit fun(self: CardDef, phase: string, count: integer): CardDef # 声明这个阶段里最多用几次（没声明 = 1000）
---@field getLimit fun(self: CardDef, phase: string): integer
---@field kind fun(self: CardDef, name: string|string[]): CardDef # 声明分类（一次调用定下；要多个就给一张列表；取值省略「牌」字：基本 / 锦囊 / 装备）
---@field isKind fun(self: CardDef, name: string): boolean
---@field getKinds fun(self: CardDef): string[]
---@field zone fun(self: CardDef, zone: string): CardDef # 必须从哪个牌区用（不声明 = 使用者任一牌区都行）
---@field getZone fun(self: CardDef): string?
---@field noTarget fun(self: CardDef): CardDef # 声明这张牌不指定目标（官方装备牌；给了目标就不成立）
---@field isNoTarget fun(self: CardDef): boolean
---@field value fun(self: CardDef, name: string, value: any): CardDef # 声明这张牌上的一条数据（名字与取值都由写牌的人定）
---@field getValue fun(self: CardDef, name: string): any
---@field extends fun(self: CardDef, name: string): CardDef # 把基类定义的钩子与字段抖过来（基类的钩子跑在前面）

--- 「获取目标」的上下文：这次想用哪张牌（还没定目标）
---@class CardDef.Target
---@field user Player # 使用者
---@field card Card # 要用的牌

--- 目前没有事件参数：触发时给空表，环境对象从 game 取
---@class Game.Event.游戏开始

--- 回合级时机：谁是回合角色
---@class Game.Event.回合
---@field player Player # 回合角色

--- 这张牌此刻能不能用：返回非 nil 值即否决（返回值就是原因）
---@class Game.Event.卡牌能否使用
---@field user Player # 使用者
---@field card Card # 要用的牌
---@field targets? Player[] # 要校验的目标（省略 = 只判「此刻能不能用」）

---@class Game
---@field on fun(self: Game, name: '游戏-开始', callback: fun(event: Game.Event.游戏开始): any): function
---@field fire fun(self: Game, name: '游戏-开始', event: Game.Event.游戏开始): any
---@field on fun(self: Game, name: '效果-收尾', callback: fun(effect: Effect): any): function # 只发给区的归属者（结完时自己建过临时处理区的那次结算）
---@field fire fun(self: Game, name: '效果-收尾', effect: Effect): any
---@field on fun(self: Game, name: '卡牌-询问', callback: fun(askCard: AskCard|AskUseCard|AskPlayCard): any): function
---@field fire fun(self: Game, name: '卡牌-询问', askCard: AskCard|AskUseCard|AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-答复', callback: fun(askCard: AskCard|AskUseCard|AskPlayCard): any): function
---@field fire fun(self: Game, name: '卡牌-答复', askCard: AskCard|AskUseCard|AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-答复后', callback: fun(askCard: AskCard|AskUseCard|AskPlayCard): any): function
---@field fire fun(self: Game, name: '卡牌-答复后', askCard: AskCard|AskUseCard|AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-能否使用', callback: fun(check: Game.Event.卡牌能否使用): any): function
---@field fire fun(self: Game, name: '卡牌-能否使用', check: Game.Event.卡牌能否使用): any # 返回值就是那条否决原因
---@field on fun(self: Game, name: '卡牌-结算前', callback: fun(useCard: UseCard): any): function
---@field fire fun(self: Game, name: '卡牌-结算前', useCard: UseCard): any
---@field on fun(self: Game, name: '卡牌-结算后', callback: fun(useCard: UseCard): any): function
---@field fire fun(self: Game, name: '卡牌-结算后', useCard: UseCard): any
---@field on fun(self: Game, name: '伤害-前', callback: fun(damage: Damage): any): function
---@field fire fun(self: Game, name: '伤害-前', damage: Damage): any
---@field on fun(self: Game, name: '伤害-生效', callback: fun(damage: Damage): any): function
---@field fire fun(self: Game, name: '伤害-生效', damage: Damage): any
---@field on fun(self: Game, name: '伤害-后', callback: fun(damage: Damage): any): function
---@field fire fun(self: Game, name: '伤害-后', damage: Damage): any
---@field on fun(self: Game, name: '回复-前', callback: fun(heal: Heal): any): function
---@field fire fun(self: Game, name: '回复-前', heal: Heal): any
---@field on fun(self: Game, name: '回复-生效', callback: fun(heal: Heal): any): function
---@field fire fun(self: Game, name: '回复-生效', heal: Heal): any
---@field on fun(self: Game, name: '回复-后', callback: fun(heal: Heal): any): function
---@field fire fun(self: Game, name: '回复-后', heal: Heal): any
---@field on fun(self: Game, name: '摸牌', callback: fun(draw: Draw): any): function
---@field fire fun(self: Game, name: '摸牌', draw: Draw): any
---@field on fun(self: Game, name: '判定-亮牌', callback: fun(judge: Judge): any): function
---@field fire fun(self: Game, name: '判定-亮牌', judge: Judge): any
---@field on fun(self: Game, name: '判定-前', callback: fun(judge: Judge): any): function
---@field fire fun(self: Game, name: '判定-前', judge: Judge): any # 改判窗口：只能在这里面换牌
---@field on fun(self: Game, name: '判定-后', callback: fun(judge: Judge): any): function
---@field fire fun(self: Game, name: '判定-后', judge: Judge): any
---@field on fun(self: Game, name: '濒死-进入', callback: fun(dying: Dying): any): function
---@field fire fun(self: Game, name: '濒死-进入', dying: Dying): any
---@field on fun(self: Game, name: '濒死-离开', callback: fun(dying: Dying): any): function
---@field fire fun(self: Game, name: '濒死-离开', dying: Dying): any
---@field on fun(self: Game, name: '玩家-死亡', callback: fun(player: Player): any): function
---@field fire fun(self: Game, name: '玩家-死亡', player: Player): any
---@field on fun(self: Game, name: '回合-开始', callback: fun(turn: Game.Event.回合): any): function
---@field fire fun(self: Game, name: '回合-开始', turn: Game.Event.回合): any
---@field on fun(self: Game, name: '回合-结束', callback: fun(turn: Game.Event.回合): any): function
---@field fire fun(self: Game, name: '回合-结束', turn: Game.Event.回合): any
---@field on fun(self: Game, name: '阶段-开始', callback: fun(phase: Phase): any): function
---@field fire fun(self: Game, name: '阶段-开始', phase: Phase): any
---@field on fun(self: Game, name: '阶段-结束', callback: fun(phase: Phase): any): function
---@field fire fun(self: Game, name: '阶段-结束', phase: Phase): any
---@field on fun(self: Game, name: '决策-询问', callback: fun(ask: Ask): any): function
---@field fire fun(self: Game, name: '决策-询问', ask: Ask): any
---@field on fun(self: Game, name: '决策-答复', callback: fun(ask: Ask): any): function
---@field fire fun(self: Game, name: '决策-答复', ask: Ask): any
---@field on fun(self: Game, name: '游戏-结束', callback: fun(result: Game.Result): any): function
---@field fire fun(self: Game, name: '游戏-结束', result: Game.Result): any
---@field on fun(self: Game, name: string, callback: fun(payload: any): any): function
---@field fire fun(self: Game, name: string, ...: any): any # 第一个回调明确给出的返回值（快速返回）
