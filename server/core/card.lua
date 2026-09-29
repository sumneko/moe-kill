---@class Card: Class.Base
---@field private id integer # 号（这一局发的）
---@field name string # 牌名（内容侧给的值，内核只存不解释）
---@field suit? string # 花色
---@field point? integer # 点数（1..13）
---@field private zone? Zone # 现在在哪个牌区里（不在任何牌区时为「不存在」）
---@field private zoneGCHost? GCHost # 随「这张牌在牌区里」存活的容器（懒建）
---@field game Game # 属于哪一局（读自己的内容定义时用）
---@field def CardDef # 内容定义（建牌时查一次就定格；查不到直接报错）
---@field private passiveSuppress integer # 被动被压制的层数（出厂 1 = 未启用）
---@field private passiveUndo? fun() # 本次应用的被动效果的撤销函数
local M = Class 'Card'

---@param game Game # 属于哪一局（读自己的内容定义时用）
---@param name string # 牌名
---@param id integer # 号由局发（`game:nextId`）
---@param suit? string # 花色
---@param point? integer # 点数
function M:__init(game, name, id, suit, point)
    self.game  = game
    self.id    = id
    self.name  = name
    self.suit  = suit
    self.point = point
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

--- 跑『被动』钩子、把返回的撤销函数收成一只（后应用的先撤）
---@private
function M:applyPassive()
    local zone = assert(self:getZone())
    ---@type fun()[]
    local undos = {}
    for _, handler in ipairs(self.def:getHandlers('被动')) do
        local undo = handler(self, zone)
        if undo then
            undos[#undos + 1] = undo
        end
    end
    self.passiveUndo = function ()
        for i = #undos, 1, -1 do
            undos[i]()
        end
    end
end

--- 把记下的撤销函数调掉（先清空再调，重复触发不会重复撤）
---@private
function M:removePassive()
    local undo = self.passiveUndo
    self.passiveUndo = nil
    if undo then
        undo()
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

---@type string
M.fullName = nil

---@param self Card
---@return string # 完整名（包名.名字）
M.__getter.fullName = function (self)
    return self.def.fullName
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

--- 解除和牌区的绑定（只清归属；牌区列表由搬牌的人自己摘）
function M:unbindZone()
    self:bindZone(nil)
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
---@param name string # 牌名
---@param id integer # 号由局发（`game:nextId`）
---@param suit? string # 花色
---@param point? integer # 点数
---@return Card
function moe.card.create(game, name, id, suit, point)
    return New 'Card' (game, name, id, suit, point)
end
