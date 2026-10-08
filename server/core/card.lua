---@class Card: Class.Base
---@field private id integer # 号（这一局发的）
---@field name string # 牌名（内容侧给的值，内核只存不解释）
---@field suit? string # 花色
---@field point? integer # 点数（1..13）
---@field virtual boolean # 是不是虚拟牌（没有实体牌；进不了任何牌区）
---@field subcards Card[] # 对应的实体牌（普通牌是空表）—— **一律是实体牌**，虚拟牌不进这里（构造时已经解包）
---@field physical Card[] # 对应的实体牌（普通牌就是自己、虚拟牌是它的素材）
---@field private zone? Zone # 现在在哪个牌区里（不在任何牌区时为「不存在」）
---@field game Game # 属于哪一局（读自己的内容定义时用）
---@field def CardDef # 内容定义（建牌时查一次就定格；查不到直接报错）
---@field private passiveSuppress integer # 被动被压制的层数（出厂 1 = 未启用）
---@field private passiveHost? GCHost # 本次应用被动时给回调的容器（懒建；停用时释放）
local M = Class 'Card'

---@param game Game # 属于哪一局（读自己的内容定义时用）
---@param name string # 牌名
---@param id integer # 号由局发（`game:nextId`）
---@param suit? string # 花色
---@param point? integer # 点数
function M:__init(game, name, id, suit, point)
    self.game     = game
    self.id       = id
    self.name     = name
    self.suit     = suit
    self.point    = point
    self.virtual  = false
    self.subcards = {}
    local def = game:getCard(name)
    if not def then
        error('没有叫「{}」的内容定义' % { name }, 2)
    end
    self.def = def
    self.passiveSuppress = 1
end

---@return integer # 牌的号（这一局发的）
function M:getId()
    return self.id
end

---@type Card[]
M.physical = nil

--- 这张牌对应的实体牌（普通牌就是它自己，虚拟牌是它的素材）
---@return Card[]
M.__getter.physical = function (self)
    if self.virtual then
        return self.subcards
    end
    return { self }
end

--- 跑这张牌这条钩子的所有处理器
---@param event string
---@param ... any
function M:fireHandlers(event, ...)
    for _, handler in ipairs(self.def:getHandlers(event)) do
        handler(...)
    end
end

--- 让这张牌生效一次（判定阶段用；判定者 = 它所在区的主人）
---@async
function M:doEffect()
    local player = assert(self:getZone()?.owner)
    local effect = New 'CardEffect' (self.game, self, player)
    effect:apply():await()
end

--- 以这次装备发动为归因地跑一段（里面起的结算都挂在它下面；发动者 = 它所在区的主人）
---@async
---@param body fun() # 这次发动做的事
---@return Cast # 这次发动
function M:cast(body)
    local cast = New 'Cast' (self.game, self, self:getZone()?.owner, body)
    cast:apply():await()
    return cast
end

--- 问一次要不要发动（装备没有「自动同意」的开关，每次都问）
---@async
---@return boolean
function M:confirm()
    local owner = assert(self:getZone()?.owner)
    return self.game:askChoice(owner, self.name, { '发动' }).choice ~= nil
end

--- 启用被动：松开一层压制（松开到 0 时应用）
---@return function # 撤销这一次松开
function M:enablePassive()
    self.passiveSuppress = self.passiveSuppress - 1
    if self.passiveSuppress == 0 then
        self:applyPassive()
    end
    return function ()
        self:disablePassive()
    end
end

--- 停用被动：压上一层压制（压回 1 时撤销已应用的效果）
---@return function # 撤销这一次压制
function M:disablePassive()
    self.passiveSuppress = self.passiveSuppress + 1
    if self.passiveSuppress == 1 then
        self:removePassive()
    end
    return function ()
        self:enablePassive()
    end
end

--- 跑『被动』钩子：给它一个随本次应用存活的容器（要挂什么就 `host:bindGC(…)`）
---@private
function M:applyPassive()
    local zone  = assert(self:getZone())
    local owner = zone.owner
    local host  = moe.gc.host()
    self.passiveHost = host
    for _, handler in ipairs(self.def:getHandlers('被动')) do
        handler(self, zone, host)
    end
    if owner then
        for _, decl in ipairs(self.def:getViewAsList()) do
            local viewAs = owner:addViewAs(decl.name, self, decl.options)
            if decl.on then
                viewAs:on('发动', decl.on)
            end
            host:bindGC(viewAs)
        end
        for _, decl in ipairs(self.def:getEventList()) do
            host:bindGC(owner:on(decl.name, self:makeEventCallback(decl)))
        end
    end
    for _, decl in ipairs(self.def:getGlobalEventList()) do
        host:bindGC(self.game:on(decl.name, self:makeEventCallback(decl)))
    end
end

--- 把声明里的回调包一层：第一参补上这张牌，载荷与返回值都原样转
---@private
---@param decl CardDef.EventDecl
---@return function
function M:makeEventCallback(decl)
    return function (...)
        return decl.handler(self, ...)
    end
end

--- 释放本次应用挂下的东西（先摘掉再释放，重复触发不会重复）
---@private
function M:removePassive()
    local host = self.passiveHost
    self.passiveHost = nil
    if host then
        Delete(host)
    end
end

--- 这张牌是不是这个分类
---@param name string
---@return boolean
function M:isKind(name)
    return self.def:isKind(name)
end

--- 读这张牌上的一条数据
---@param name string # 数据的名字
---@return any # 没声明过就是「不存在」
function M:getValue(name)
    return self.def:getValue(name)
end

--- 这次使用最少 / 最多几个目标（声明值 + 这次使用的选项里的额外目标数；与打算选谁无关；「0、0」恒为「0、0」）
---@param useOptions? Game.UseOptions # 这次使用的选项（`extraTargets` 加在上限上）
---@return integer # 最少几个
---@return integer # 最多几个
function M:getTargetCount(useOptions)
    local min, max = self.def:getTargetCount()
    if max == 0 then
        return min, max
    end
    return min, max + (useOptions?.extraTargets or 0)
end

---@type string
M.fullName = nil

---@param self Card
---@return string # 完整名（包名.名字）
M.__getter.fullName = function (self)
    return self.def.fullName
end

---@type string?
M.color = nil

---@param self Card
---@return string? # 颜色（红桃 / 方块 = 红，黑桃 / 梅花 = 黑）
M.__getter.color = function (self)
    local suit = self.suit
    if suit == '红桃' or suit == '方块' then
        return '红'
    end
    if suit == '黑桃' or suit == '梅花' then
        return '黑'
    end
    return nil
end

--- 这张牌现在在哪个牌区
---@return Zone? # 不在任何牌区时为「不存在」
function M:getZone()
    return self.zone
end

--- 解除和牌区的绑定（只清归属；牌区列表由搬牌的人自己摘）
function M:unbindZone()
    self:bindZone(nil)
end

--- 记下这张牌所在的牌区（只有牌区自己用：放进 / 取出时维护）
---@param zone Zone?
function M:bindZone(zone)
    self.zone = zone
end

---@return string
function M:__tostring()
    return '牌#{}' % { self.id }
end

---@class Card.API
moe.card = {}

--- 建一张牌
---@param game Game # 属于哪一局
---@param name string # 牌名
---@param id integer # 号由局发（`game:nextId`）
---@param suit? string # 花色
---@param point? integer # 点数
---@return Card
function moe.card.create(game, name, id, suit, point)
    return New 'Card' (game, name, id, suit, point)
end

--- 建一张虚拟牌（`subcards` 一律解包成**实体牌** —— 虚拟牌不能当素材；原始牌可给一或多张，花色与点数默认：实体牌只有一张 ⇒ 抄它，其余 ⇒ 无）
---@param game Game # 属于哪一局
---@param name string # 牌名
---@param id integer # 号由局发（`game:nextId`）
---@param subcards? Card|Card[] # 对应的实体牌（可以不给、可以多张；虚拟牌会被换成它的实体牌）
---@return Card
function moe.card.createVirtual(game, name, id, subcards)
    ---@type Card[]
    local physical = {}
    for _, card in ipairs(subcards and moe.util.toList(subcards) or {}) do
        moe.util.arrayMerge(physical, card.physical)
    end
    local suit, point
    if #physical == 1 then
        suit, point = physical[1].suit, physical[1].point
    end
    local card = moe.card.create(game, name, id, suit, point)
    card.virtual  = true
    card.subcards = physical
    return card
end
