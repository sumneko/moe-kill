---@class Player.CreateOptions
---@field attributes Attributes
---@field name? string

---@class Player: Class.Base
---@field private name? string
---@field private attributes Attributes
---@field private zoneList Zone[]
---@field private zoneMap table<string, Zone>
---@field private buffs Buff[] # 挂在他身上的状态（按获得顺序）
---@field private tags table<string, any>
---@field private events Event # 他自己的时机表（内容侧用 player:on / player:fire）
---@field private alive boolean
---@field game Game # 属于哪一局（牌区顺着归属者找到局）
local M = Class 'Player'

---@param game Game
---@param attributes Attributes
---@param name? string
function M:__init(game, attributes, name)
    self.game       = game
    self.name       = name
    self.attributes = attributes
    self.zoneList   = {}
    self.zoneMap    = {}
    self.buffs      = {}
    self.tags       = {}
    self.events     = moe.event.create()
    self.alive      = true
    self:addZone('手牌')
    -- 判定区有序：结算顺序由进入顺序定（后入先出）
    self:addZone('判定', moe.orderedZone.create(self.game))
end

---@return Attributes # 他的属性实例
function M:getAttributes()
    return self.attributes
end

--- 写入一个属性
---@param name string
---@param value number
function M:setAttr(name, value)
    self.attributes:set(name, value)
end

--- 读一个属性
---@param name string
---@return number
function M:getAttr(name)
    return self.attributes:get(name)
end

--- 增减一个属性（返回撤销函数：精确减掉这次加的量）
---@param name string
---@param value number
---@return fun()
function M:addAttr(name, value)
    return self.attributes:addModifier(name, value)
end

---@return string? # 名字（建玩家时可以不给）
function M:getName()
    return self.name
end

--- 加一个牌区（返回撤销这次添加的函数）
---@param name string
---@param zone? Zone # 省略时新建一个普通牌区
---@return function # 撤销这次添加（移除该牌区）
function M:addZone(name, zone)
    if type(name) ~= 'string' or name == '' then
        error('牌区必须有个非空名字', 2)
    end
    if self.zoneMap[name] then
        error('这个玩家已经有叫 {} 的牌区了' % { name }, 2)
    end
    local instance = zone or New 'Zone' (self.game)
    instance:bindOwner(self)
    self.zoneMap[name] = instance
    self.zoneList[#self.zoneList+1] = instance
    local removed = false
    return function ()
        if removed then
            return
        end
        removed = true
        self.zoneMap[name] = nil
        for i, item in ipairs(self.zoneList) do
            if item == instance then
                table.remove(self.zoneList, i)
                break
            end
        end
    end
end

--- 玩家身上的牌区（`手牌` / `判定` 由内核建好，包不得重建；装备子区由内容侧在 `'游戏-开始'` 建）
---@overload fun(self: Player, name: '手牌'): Zone
---@overload fun(self: Player, name: '判定'): OrderedZone
---@param name string
---@return Zone?
function M:getZone(name)
    return self.zoneMap[name]
end

---@return Zone[] # 他身上的牌区（按加入顺序）
function M:getZones()
    ---@type Zone[]
    local zones = {}
    table.move(self.zoneList, 1, #self.zoneList, 1, zones)
    return zones
end

--- 获得一只状态：挂上（同名可并存）→ 发「获得」 → 返回实例
---@param name string
---@param payload? any # 内容侧自己约定的一份载荷（内核只存不解释）
---@return Buff
function M:addBuff(name, payload)
    local def = self.game:getBuff(name)
    if not def then
        error('没有叫「{}」的内容定义' % { name }, 2)
    end
    local buff = moe.buff.create(self.game, def, self, payload)
    self.buffs[#self.buffs + 1] = buff
    buff:fireHandlers('获得')
    return buff
end

--- 摘掉一只状态（`Buff:__del` 里调；内容侧用 `buff:remove()`）
---@param buff Buff
function M:removeBuff(buff)
    for i, item in ipairs(self.buffs) do
        if item == buff then
            table.remove(self.buffs, i)
            return
        end
    end
end

---@return Buff[] # 挂在他身上的状态（快照，按获得顺序）
function M:getBuffs()
    ---@type Buff[]
    local buffs = {}
    table.move(self.buffs, 1, #self.buffs, 1, buffs)
    return buffs
end

---@param name string
---@return boolean # 有没有挂着一只叫这个名字的状态
function M:hasBuff(name)
    for _, buff in ipairs(self.buffs) do
        if buff.name == name then
            return true
        end
    end
    return false
end

--- 这张牌在他哪个牌区里、第几位
---@param card Card
---@return Zone? # 这张牌所在的牌区
---@return integer? # 牌在牌区里的位置
function M:findCard(card)
    for _, zone in ipairs(self.zoneList) do
        for index, held in ipairs(zone:list()) do
            if held == card then
                return zone, index
            end
        end
    end
    return nil, nil
end

---@param key string
---@param value any
function M:setTag(key, value)
    if type(key) ~= 'string' or key == '' then
        error('标签键必须是非空字符串', 2)
    end
    self.tags[key] = value
end

---@param key string
---@return any
function M:getTag(key)
    return self.tags[key]
end

---@param key string
function M:removeTag(key)
    self.tags[key] = nil
end

--- 订阅一个时机
---@param name string
---@param callback fun(context: table): any
---@return function # 撤销这次注册
function M:on(name, callback)
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    if type(callback) ~= 'function' then
        error('时机回调必须是函数', 2)
    end
    return self.events:on(name, callback)
end

--- 触发一个时机
---@param name string
---@param ... any
---@return any # 第一个回调明确给出的返回值（快速返回）；没人给就是空
function M:fire(name, ...)
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    return self.events:fire(name, ...)
end

--- 触发一个时机并收集所有回调的返回值（修正链类用它；是非问 / 通知用 fire）
---@param name string
---@param ... any
---@return any[] # 每个回调的第一个返回值（没有 / 报错的不收）
function M:collect(name, ...)
    if type(name) ~= 'string' or name == '' then
        error('时机名必须是非空字符串', 2)
    end
    return self.events:collect(name, ...)
end

--- 当前正在进行的、属于他的阶段（没有就是空）
---@return Phase?
function M:currentPhase()
    local phase = self.game.phase
    if phase and phase.player == self then
        return phase
    end
end

---@type boolean
M.acting = nil

---@param self Player
---@return boolean # 是否参与行动顺序（当前：活着就参与）
M.__getter.acting = function (self)
    return self:isAlive()
end

---@return boolean # 还活着（初值：活着）
function M:isAlive()
    return self.alive
end

--- 置存活状态（从活变死会触发「玩家-死亡」）
---@param value boolean
function M:setAlive(value)
    local alive = value and true or false
    if self.alive == alive then
        return
    end
    self.alive = alive
    if not alive then
        self.game:fire('玩家-死亡', self)
    end
end

---@class Player.API
moe.player = {}

--- 建一个玩家
---@param game Game
---@param options Player.CreateOptions
---@return Player
function moe.player.create(game, options)
    if not game or not options or not options.attributes then
        error('玩家需要一局与一个属性实例', 2)
    end
    return New 'Player' (game, options.attributes, options.name)
end
