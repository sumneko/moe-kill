---@meta

-- 本文件只声明注入环境的类型：环境对象本身、内容定义入口、以及 game 上的**事件**（按名收窄 on/fire 的上下文）。
-- Game 上其余入口（askCard / moveCard / drawCards …）的声明在 `server/core/game.lua`，别往这里抄一份。
-- 内核建好的四个基础牌区（局上 `抽牌` / `弃牌`，玩家身上 `手牌` / `判定`）是**对内容侧的约定**：包可以直接取（`game:getZone('弃牌')`），但不得重建同名区；声明见 `game.lua` / `player.lua` 里 getZone 的重载。

---@type Game
game = nil

---@type fun(name: string): CardDef
Card = nil

---@type fun(name: string): BuffDef
Buff = nil

---@type fun(items: string[])
Depends = nil

--- 内容侧共享的规则数据袋：装载器每轮装载给一张新的空表（内核不认识里面的东西 —— 字段由内容侧自己声明，如 `@基础/meta.lua` 里的 `equipZones`）
---@class Loader.Rule
---@type Loader.Rule
rule = nil

--- 牌的钩子是**固定**的：名字由内核约定、与启用的包无关，清单以本文件为准（不留 string 兜底，拼错在编辑期就报）
---@class CardDef
---@field on fun(self: CardDef, event: '进入区域', handler: fun(card: Card, zone: Zone): any): CardDef # 这张牌进入某个牌区之后跑（只有有归属者的区会发）
---@field on fun(self: CardDef, event: '离开区域', handler: fun(card: Card, zone: Zone): any): CardDef # 这张牌离开某个牌区时跑（发的时候它已经不在那个区里）
---@field on fun(self: CardDef, event: '获取目标', handler: fun(plan: CardDef.TargetPlan): Player[]): CardDef
---@field on fun(self: CardDef, event: '获取卡牌目标', handler: fun(plan: CardDef.CardTargetPlan): Card[]): CardDef # 返回你认下的那批牌（发起方给的那张不在里面 = 不能对这张牌使用）；声明它 = 这张牌能「对牌使用」
---@field on fun(self: CardDef, event: '使用', handler: fun(useCard: UseCard|UseCardToCard)): CardDef # 使用结算开始时跑一次（逐目标之前；声明了 skipEffect 的牌就到这）
---@field on fun(self: CardDef, event: '生效', handler: fun(cardEffect: CardEffect, useCard: UseCard?)): CardDef # 一次生效（使用期逐目标 / 判定阶段每张一次）
---@field on fun(self: CardDef, event: '被动', handler: fun(card: Card, zone: Zone): (fun()?)): CardDef # 被动启用时跑一次：应用效果、返回撤销函数（停用时内核调它）

--- 「获取目标」的上下文：想用哪张牌、打算打谁
---@class CardDef.TargetPlan
---@field user Player # 使用者
---@field card Card # 要用的牌
---@field targets? Player[] # 期望的目标（没给目标就是空）

--- 「获取卡牌目标」的上下文：想用哪张牌、要对哪张牌
---@class CardDef.CardTargetPlan
---@field user Player # 使用者
---@field card Card # 要用的牌
---@field targets Card[] # 要对的那批牌

--- 状态的时机是**固定**的：名字由内核约定、与启用的包无关（清单以本文件为准，不留 string 兜底）
---@class BuffDef
---@field on fun(self: BuffDef, event: '获得', handler: fun(buff: Buff)): BuffDef # 挂到某人身上之后跑一次（在这里挂资源 / 订阅：`buff:bindGC(...)`）
---@field on fun(self: BuffDef, event: '失去', handler: fun(buff: Buff)): BuffDef # 失去时跑一次（资源已经挂在 bindGC 上，这里只在「真的需要知道」时才用）

--- 目前没有事件参数：触发时给空表，环境对象从 game 取
---@class Game.Event.游戏开始

--- 回合级时机：谁是回合角色
---@class Game.Event.Turn
---@field player Player # 回合角色

--- 这张牌此刻能不能用：返回非 nil 值即否决（返回值就是原因）
---@class Game.Event.卡牌能否使用
---@field user Player # 使用者
---@field card Card # 要用的牌
---@field targets? Player[] # 要校验的角色目标（省略 = 只判「此刻能不能用」）
---@field target? Card # 要校验的牌目标（对牌使用这一支才有）

--- 这次的目标数修正：每个订阅者返回一个整数增量（可正可负；没有贡献就不返回）
---@class Game.Event.卡牌目标数修正
---@field user Player # 使用者
---@field card Card # 要用的牌

---@class Game
---@field on fun(self: Game, name: '游戏-开始', callback: fun(event: Game.Event.游戏开始): any): function
---@field fire fun(self: Game, name: '游戏-开始', event: Game.Event.游戏开始): any
---@field on fun(self: Game, name: '效果-能否生效', callback: fun(effect: Effect): any): function # 询问要不要阻止这一次生效（第一段：问全局）：返回非 nil 即阻止（返回值就是原因）
---@field fire fun(self: Game, name: '效果-能否生效', effect: Effect): any # 返回值就是那条阻止的原因
---@field on fun(self: Game, name: '效果-收尾', callback: fun(effect: Effect): any): function # 每次结算结完都发一次（载荷 = 效果自己）
---@field fire fun(self: Game, name: '效果-收尾', effect: Effect): any
---@field on fun(self: Game, name: '卡牌-询问', callback: fun(askCard: AskCard|AskUseCard|AskUseCardToCard|AskPlayCard): any): function
---@field fire fun(self: Game, name: '卡牌-询问', askCard: AskCard|AskUseCard|AskUseCardToCard|AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-答复', callback: fun(askCard: AskCard|AskUseCard|AskUseCardToCard|AskPlayCard): any): function
---@field fire fun(self: Game, name: '卡牌-答复', askCard: AskCard|AskUseCard|AskUseCardToCard|AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-答复后', callback: fun(askCard: AskCard|AskUseCard|AskUseCardToCard|AskPlayCard): any): function
---@field fire fun(self: Game, name: '卡牌-答复后', askCard: AskCard|AskUseCard|AskUseCardToCard|AskPlayCard): any
---@field on fun(self: Game, name: '卡牌-能否使用', callback: fun(check: Game.Event.卡牌能否使用): any): function
---@field fire fun(self: Game, name: '卡牌-能否使用', check: Game.Event.卡牌能否使用): any # 返回值就是那条否决原因
---@field on fun(self: Game, name: '卡牌-目标数修正', callback: fun(check: Game.Event.卡牌目标数修正): (integer?)): function
---@field on fun(self: Game, name: '卡牌-结算前', callback: fun(useCard: UseCard|UseCardToCard): any): function
---@field fire fun(self: Game, name: '卡牌-结算前', useCard: UseCard|UseCardToCard): any
---@field on fun(self: Game, name: '卡牌-结算后', callback: fun(useCard: UseCard|UseCardToCard): any): function
---@field fire fun(self: Game, name: '卡牌-结算后', useCard: UseCard|UseCardToCard): any
---@field on fun(self: Game, name: '玩家-死亡', callback: fun(player: Player): any): function
---@field fire fun(self: Game, name: '玩家-死亡', player: Player): any
---@field on fun(self: Game, name: '回合-开始', callback: fun(turn: Game.Event.Turn): any): function
---@field fire fun(self: Game, name: '回合-开始', turn: Game.Event.Turn): any
---@field on fun(self: Game, name: '回合-结束', callback: fun(turn: Game.Event.Turn): any): function
---@field fire fun(self: Game, name: '回合-结束', turn: Game.Event.Turn): any
---@field on fun(self: Game, name: '阶段-开始', callback: fun(phase: Phase): any): function
---@field fire fun(self: Game, name: '阶段-开始', phase: Phase): any
---@field on fun(self: Game, name: '阶段-结束', callback: fun(phase: Phase): any): function
---@field fire fun(self: Game, name: '阶段-结束', phase: Phase): any
---@field on fun(self: Game, name: '决策-询问', callback: fun(ask: Ask|AskPlayer): any): function
---@field fire fun(self: Game, name: '决策-询问', ask: Ask|AskPlayer): any
---@field on fun(self: Game, name: '决策-答复', callback: fun(ask: Ask|AskPlayer): any): function
---@field fire fun(self: Game, name: '决策-答复', ask: Ask|AskPlayer): any
---@field on fun(self: Game, name: '游戏-结束', callback: fun(result: Game.Result): any): function
---@field fire fun(self: Game, name: '游戏-结束', result: Game.Result): any
---@field on fun(self: Game, name: string, callback: fun(payload: any): any): function
---@field fire fun(self: Game, name: string, ...: any): any # 第一个回调明确给出的返回值（快速返回）

--- 玩家自己的时机表（与 Game 同形）：技能挂在它身上，只在自己被问到的那一段醒来
---@class Player
---@field on fun(self: Player, name: '阶段-开始', callback: fun(phase: Phase): any): function # 自己这个玩家的阶段开始（全局那份之外、对当事人再发一份）
---@field fire fun(self: Player, name: '阶段-开始', phase: Phase): any
---@field on fun(self: Player, name: '阶段-结束', callback: fun(phase: Phase): any): function # 自己这个玩家的阶段结束（全局那份之外、对当事人再发一份）
---@field fire fun(self: Player, name: '阶段-结束', phase: Phase): any
---@field on fun(self: Player, name: '效果-来源-能否生效', callback: fun(effect: Effect): any): function # 询问要不要阻止这一次生效（第二段：问来源）：返回非 nil 即阻止（返回值就是原因）
---@field fire fun(self: Player, name: '效果-来源-能否生效', effect: Effect): any # 返回值就是那条阻止的原因
---@field on fun(self: Player, name: '效果-目标-能否生效', callback: fun(effect: Effect): any): function # 询问要不要阻止这一次生效（第三段：问目标）：返回非 nil 即阻止（返回值就是原因）
---@field fire fun(self: Player, name: '效果-目标-能否生效', effect: Effect): any # 返回值就是那条阻止的原因
---@field on fun(self: Player, name: '效果-收尾', callback: fun(effect: Effect): any): function # 冲自己来的效果结完时再发一份（全局那份之外、对当事人再发一份）
---@field fire fun(self: Player, name: '效果-收尾', effect: Effect): any
---@field on fun(self: Player, name: '卡牌-结算前', callback: fun(useCard: UseCard|UseCardToCard): any): function # 自己使用的牌开始结算时再发一份（全局那份之外、对使用者再发一份）
---@field fire fun(self: Player, name: '卡牌-结算前', useCard: UseCard|UseCardToCard): any
---@field on fun(self: Player, name: string, callback: fun(payload: any): any): function
---@field fire fun(self: Player, name: string, ...: any): any # 第一个回调明确给出的返回值（快速返回）
