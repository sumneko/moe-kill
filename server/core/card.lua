---@class Card: Class.Base
---@field private id integer # 号（这一局发的）
---@field name? any # 牌名（内容侧给的值，内核只存不解释）
---@field suit? string # 花色
---@field point? integer # 点数（1..13）
---@field private zone? Zone # 现在在哪个牌区里（不在任何牌区时为「不存在」）
---@field private zoneGCHost? GCHost # 随「这张牌在牌区里」存活的容器（懒建）
---@field private game Game # 属于哪一局（读自己的内容定义时用）
local M = Class 'Card'

---@param game Game # 属于哪一局（读自己的内容定义时用）
---@param name? any # 牌名
---@param id integer # 号由局发（`game:nextId`）
---@param suit? string # 花色
---@param point? integer # 点数
function M:__init(game, name, id, suit, point)
    self.game  = game
    self.id    = id
    self.name  = name
    self.suit  = suit
    self.point = point
end

---@return integer # 牌的号（这一局发的）
function M:getId()
    return self.id
end

--- 改这张牌的牌名
---@param name? any # 新牌名
function M:setName(name)
    self.name = name
end

---@return CardDef? # 这张牌的内容定义（查不到就是空）
function M:getDef()
    return self.game:getCard(self.name)
end

--- 这张牌是不是这个分类
---@param name string
---@return boolean
function M:isKind(name)
    local def = self:getDef()
    return def?:isKind(name)
end

--- 读这张牌上的一条数据
---@param name string # 数据的名字
---@return any # 没声明过（或没有定义 / 不在局里）就是「不存在」
function M:getValue(name)
    local def = self:getDef()
    return def?:getValue(name)
end

---@type string?
M.fullName = nil

---@param self Card
---@return string? # 完整名（包名.名字）
M.__getter.fullName = function (self)
    local def = self:getDef()
    return def?.fullName
end

--- 这张牌现在在哪个牌区
---@return Zone? # 不在任何牌区时为「不存在」
function M:getZone()
    return self.zone
end

--- 牌离开这个牌区时调它
---@param disposer function
function M:withZone(disposer)
    if not self.zoneGCHost then
        self.zoneGCHost = moe.gc.host()
    end
    self.zoneGCHost:bindGC(disposer)
end

--- 记下这张牌所在的牌区（只有牌区自己用：放进 / 取出时维护）
---@param zone Zone?
function M:bindZone(zone)
    -- 只在真的换区时扔掉容器：同区内部调序不算离开
    if self.zone ~= zone and self.zoneGCHost then
        Delete(self.zoneGCHost)
        self.zoneGCHost = nil
    end
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
---@param name? any # 牌名
---@param id integer # 号由局发（`game:nextId`）
---@param suit? string # 花色
---@param point? integer # 点数
---@return Card
function moe.card.create(game, name, id, suit, point)
    return New 'Card' (game, name, id, suit, point)
end
