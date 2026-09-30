---@meta

--- 装备子区名单挂在装载器给的共享袋上（内容侧跨包共享；装载器每轮新建一张）
---@class Loader.Rule
---@field equipZones string[] # 装备子区名（= 装备的分类名；想加子区的包在加载期往这里追加）

---@class Game
---@field getValue fun(self: Game, name: '默认体力'|'主公额外体力'): integer
---@field getValue fun(self: Game, name: string): any
---@field setValue fun(self: Game, name: '默认体力'|'主公额外体力', value: integer)
---@field setValue fun(self: Game, name: string, value: any)

--- 性别（由武将写入；没有武将时常常没有 —— 官方：没有性别的角色不能判断别人与其性别是否相同）
---@alias 基础.性别 '男'|'女'

--- 势力（由武将写入；官方：魏 / 蜀 / 吴 / 群 / 西 / 神，标准包只用前四个）
---@alias 基础.势力 '魏'|'蜀'|'吴'|'群'

---@class Player: Class.Base
---@field sex? 基础.性别
---@field hero? HeroDef # 这名角色用的是哪张武将（由 @基础/武将.lua 的 setHero 写入）
---@field kingdom? 基础.势力 # 势力（同上）
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

--- 伤害的时机也由本包提供：按名收窄 `on` / `fire` 的载荷
--- 「开始」= 官方「造成伤害时」、在扣体力之前：全局发 `'伤害-开始'`、再对来源发 `'伤害-来源-开始'`
---@class Game
---@field on fun(self: Game, name: '伤害-开始', callback: fun(damage: Damage): any): function
---@field fire fun(self: Game, name: '伤害-开始', damage: Damage): any
---@field on fun(self: Game, name: '伤害-结束', callback: fun(damage: Damage): any): function
---@field fire fun(self: Game, name: '伤害-结束', damage: Damage): any

---@class Player: Class.Base
--- 伤害（本包提供）：承受侧那份对当事人再发一份
---@field on fun(self: Player, name: '伤害-来源-开始', callback: fun(damage: Damage): any): function # 自己造成的伤害开始了（全局那份之外、对来源再发一份）
---@field fire fun(self: Player, name: '伤害-来源-开始', damage: Damage): any
---@field on fun(self: Player, name: '伤害-目标-结束', callback: fun(damage: Damage): any): function # 自己受到了伤害（全局那份之外、对承受者再发一份）
---@field fire fun(self: Player, name: '伤害-目标-结束', damage: Damage): any
--- 兜底：跨文件加候选时必须自带（不带的话同名的整张候选表都不解析，见 architecture §9.6 配方）
---@field on fun(self: Player, name: string, callback: fun(payload: any): any): function
---@field fire fun(self: Player, name: string, ...: any): any

--- 技能定义上的钩子：`'被动'` 在**每次启用**时跑一次（如技能被克制 / 封印后恢复），要挂什么就 `host:bindGC(…)`
---@class SkillDef
---@field on fun(self: SkillDef, event: '被动', handler: fun(skill: Skill, host: GCHost)): SkillDef
---@field on fun(self: SkillDef, event: string, handler: function): SkillDef
