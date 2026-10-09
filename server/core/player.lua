---@alias Player.DirtyKind 'base'|'custom'

---@class Player.CreateOptions
---@field attributes Attributes
---@field name? string

---@class Player: Class.Base
---@field private name? string
---@field private attributes Attributes
---@field private zoneList Zone[]
---@field private zoneMap table<string, Zone>
---@field private buffs Buff[] # 挂在他身上的状态（按获得顺序）
---@field private skills Skill[] # 他拥有的技能（按获得顺序）
---@field private viewAsList ViewAs[] # 他身上的「视为」声明（按声明顺序）
---@field private tags table<string, any>
---@field private events Event # 他自己的时机表（内容侧用 player:on / player:fire）
---@field private alive boolean
---@field private limitDeltas table<string, table<string, integer>> # 各阶段里各名字的上限增减（阶段名 → 名字 → 增减）
---@field game Game # 属于哪一局（牌区顺着归属者找到局）
---@field user? User # 谁在控制他（没有就是没人应答，交给全局时机）
---@field id integer # 局内唯一号（建号走局上的号源）
---@field custom Custom # 内容侧往他身上挂的自由数据（写就同步）
local M = Class 'Player'

---@param game Game
---@param attributes Attributes
---@param name? string
function M:__init(game, attributes, name)
    self.game        = game
    self.name        = name
    self.id          = game:nextId()
    self.custom      = moe.custom.create(self)
    self.attributes  = attributes
    self.zoneList    = {}
    self.zoneMap     = {}
    self.buffs       = {}
    self.skills      = {}
    self.viewAsList  = {}
    self.tags        = {}
    self.events      = moe.event.create()
    self.alive       = true
    self.limitDeltas = {}
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

--- 指定谁在控制他（换人 / 解绑都走这里）
---@param user? User
function M:setUser(user)
    self.user = user
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
    instance:bindName(name)
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
    return moe.util.copy(self.zoneList)
end

--- 这些牌区里有没有牌（不传 = 他自己所有牌区；名字按「自己 → 局上」解析）
---@param ... Zone|string # 要看哪几个区
---@return boolean
function M:hasCard(...)
    local zones = { ... }
    if #zones == 0 then
        zones = self:getZones()
    end
    for _, item in ipairs(zones) do
        local zone
        if type(item) == 'string' then
            zone = self:getZone(item) or self.game:getZone(item)
        else
            zone = item
        end
        if zone and zone:count() > 0 then
            return true
        end
    end
    return false
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
    return moe.util.copy(self.buffs)
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

--- 让这名角色拥有一个技能（挂上即启用：跑一次它的「被动」钩子，内容侧在那里订阅 / 建状态）
---@param name string
---@return Skill
function M:addSkill(name)
    local def = self.game:getSkill(name)
    if not def then
        error('没有叫「{}」的技能定义' % { name }, 2)
    end
    local skill = New 'Skill' (self.game, def, self)
    self.skills[#self.skills + 1] = skill
    skill:enablePassive()
    return skill
end

--- 摘掉一个技能（`Skill:__del` 里调；内容侧用 `skill:remove()`）
---@param skill Skill
function M:removeSkill(skill)
    for i, item in ipairs(self.skills) do
        if item == skill then
            table.remove(self.skills, i)
            return
        end
    end
end

---@return Skill[] # 他拥有的技能（快照，按获得顺序）
function M:getSkills()
    return moe.util.copy(self.skills)
end

---@param name string
---@return boolean # 有没有拥有一个叫这个名字的技能
function M:hasSkill(name)
    for _, skill in ipairs(self.skills) do
        if skill.name == name then
            return true
        end
    end
    return false
end

--- 声明一份「视为某牌」（如【八卦阵】的「视为一张【闪】」）：撤销用 `viewAs:remove()`
---@param name string # 视为哪张牌
---@param source? Card|Skill # 关联的来源（装备传那张牌、技能传技能实例；发动归因到它名下）
---@param options? ViewAs.Options # 这份声明的选项（素材条件、要不要先问一句）
---@return ViewAs
function M:addViewAs(name, source, options)
    local viewAs = moe.viewAs.create(self.game, self, name, source, options)
    self.viewAsList[#self.viewAsList + 1] = viewAs
    return viewAs
end

--- 摘掉一份声明（`ViewAs:remove()` 里调）
---@param viewAs ViewAs
function M:removeViewAs(viewAs)
    for i, item in ipairs(self.viewAsList) do
        if item == viewAs then
            table.remove(self.viewAsList, i)
            return
        end
    end
end

---@return ViewAs[] # 他身上的「视为」声明（快照，按声明顺序）
function M:getViewAsList()
    return moe.util.copy(self.viewAsList)
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

--- 改自己某阶段里某名字的上限（+1 = 可以多用一次；+1000 = 事实上不限次数）
---@param name string # 牌名 / 技能名（取值由你定）
---@param phase string # 阶段名（取值由你定）
---@param delta integer
---@return fun() # 撤销这次修改（精确减掉这一笔）
function M:addLimit(name, phase, delta)
    local byName = self.limitDeltas[phase]
    if not byName then
        byName = {}
        self.limitDeltas[phase] = byName
    end
    byName[name] = (byName[name] or 0) + delta
    local undone = false
    return function ()
        if undone then
            return
        end
        undone = true
        byName[name] = (byName[name] or 0) - delta
    end
end

--- 自己某阶段里某名字的上限增减
---@param name string
---@param phase string
---@return integer
function M:getLimitDelta(name, phase)
    local byName = self.limitDeltas[phase]
    if byName then
        return byName[name] or 0
    end
    return 0
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

--- 把这个玩家的一类数据标脏（下一笔调度之前真正发）
---@param kind Player.DirtyKind
function M:markDirty(kind)
    self.game:markDirty(self, kind)
end

--- 组装这个玩家的基础信息
---@param player Player
---@return Proto.Player.Base
function moe.player.toBase(player)
    return {
        id       = player.id,
        userName = player:getName() or '',
        seat     = player.game.desk:getIndex(player),
    }
end

--- 把这一批脏玩家下发下去（基础信息人人一份、custom 按各人视角裁剪）
---@param game Game
---@param dirty table<Player, table<string, boolean>>
function moe.player.sendUpdates(game, dirty)
    ---@type Proto.Player.Base[]
    local baseList = {}
    for player, kinds in pairs(dirty) do
        if kinds.base then
            baseList[#baseList + 1] = moe.player.toBase(player)
        end
    end
    for _, viewer in ipairs(game.desk.players) do
        local user = viewer.user
        if user then
            ---@type Proto.Notify.Update
            local data = {}
            if #baseList > 0 then
                data.base = baseList
            end
            ---@type Proto.Player.Custom[]
            local customList = {}
            for player, kinds in pairs(dirty) do
                if kinds.custom then
                    local visible = player.custom:allVisibles(viewer)
                    if next(visible) then
                        customList[#customList + 1] = { id = player.id, custom = visible }
                    end
                end
            end
            if #customList > 0 then
                data.custom = customList
            end
            if data.base or data.custom then
                user:update(data)
            end
        end
    end
end

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
