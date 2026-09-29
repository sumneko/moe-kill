---@meta

--- 装备子区名单挂在装载器给的共享袋上（内容侧跨包共享；装载器每轮新建一张）
---@class Loader.Rule
---@field equipZones string[] # 装备子区名（= 装备的分类名；想加子区的包在加载期往这里追加）

---@class Game
---@field getValue fun(self: Game, name: '默认体力'|'主公额外体力'): integer
---@field getValue fun(self: Game, name: string): any
---@field setValue fun(self: Game, name: '默认体力'|'主公额外体力', value: integer)
---@field setValue fun(self: Game, name: string, value: any)

---@class Player: Class.Base
---@field getAttr fun(self: Player, name: '体力'|'体力上限'|'攻击范围'|'进攻修正'|'防御修正'): number
---@field getAttr fun(self: Player, name: string): any
---@field setAttr fun(self: Player, name: '体力'|'体力上限'|'攻击范围'|'进攻修正'|'防御修正', value: number)
---@field setAttr fun(self: Player, name: string, value: any)
---@field addAttr fun(self: Player, name: '体力'|'体力上限'|'攻击范围'|'进攻修正'|'防御修正', delta: number): fun()
---@field addAttr fun(self: Player, name: string, delta: any): fun()

--- 判定是本包提供的时机（内核不再认识它们）：按名收窄 `on` / `fire` 的载荷
---@class Game
---@field on fun(self: Game, name: '判定-前', callback: fun(judge: Judge): any): function
---@field fire fun(self: Game, name: '判定-前', judge: Judge): any # 改判窗口：只能在这里面换牌
---@field on fun(self: Game, name: '判定-后', callback: fun(judge: Judge): any): function
---@field fire fun(self: Game, name: '判定-后', judge: Judge): any

--- 伤害的收尾时机也由本包提供：按名收窄 `on` / `fire` 的载荷
---@class Game
---@field on fun(self: Game, name: '伤害-结束', callback: fun(damage: Damage): any): function
---@field fire fun(self: Game, name: '伤害-结束', damage: Damage): any
