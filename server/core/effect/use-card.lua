---@class UseCard.CreateOptions
---@field game Game
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targets Player[] # 目标（可以为空表）
---@field useOptions? Game.UseOptions # 这次使用的选项（放行 / 记账用）

---@class UseCard : Effect
---@field useOptions? Game.UseOptions # 这次使用的选项
local M = Class 'UseCard'

Extends('UseCard', 'Effect')

---@param game Game
---@param user Player
---@param card Card
---@param targets Player[]
---@param useOptions? Game.UseOptions
function M:__init(game, user, card, targets, useOptions)
    self.kind       = 'useCard'
    self.user       = user
    self.card       = card
    self.targets    = targets
    self.useOptions = useOptions
end

---@type Player
M.from = nil

---@param self UseCard
---@return Player # 来源：用这张牌的人
M.__getter.from = function (self)
    return self.user
end

--- 把 `unrespondable` 的四种写法解算成目标名单（一个角色 / 一串角色 / `true` = 这次的全部目标 / 谓词按这次的目标筛）
---@param useCard UseCard
---@param value Player|Player[]|true|fun(player: Player): boolean
---@return Player[]
local function resolveBans(useCard, value)
    if value == true then
        return moe.util.copy(useCard.targets)
    end
    if type(value) == 'function' then
        ---@cast value fun(player: Player): boolean
        ---@type Player[]
        local list = {}
        for _, target in ipairs(useCard.targets) do
            if value(target) then
                list[#list + 1] = target
            end
        end
        return list
    end
    return moe.util.toList(value)
end

--- 使用过程中追加这次的选项（内容侧在时机里用）：`unrespondable` 这类名单是**累加**，其余字段覆盖
---@param options Game.UseOptionsInput
---@return UseCard
function M:addUseOptions(options)
    local current = self.useOptions
    if not current then
        current = {}
        self.useOptions = current
    end
    if options.unrespondable then
        current.unrespondable = current.unrespondable or {}
        moe.util.arrayMerge(current.unrespondable, resolveBans(self, options.unrespondable))
    end
    for key, value in pairs(options) do
        if key ~= 'unrespondable' then
            current[key] = value
        end
    end
    return self
end

--- 这个目标被禁止响应这张牌吗
---@param target Player
---@return boolean
function M:isResponseBanned(target)
    local banned = self.useOptions?.unrespondable
    return banned ~= nil and moe.util.arrayHas(banned, target)
end

---@async
function M:settle()
    local ok, reason = self.game:canUse(self.user, self.card, self.targets, self.useOptions)
    if not ok then
        self:cancel(reason)
    end

    local name = self.card.name
    local phase = self.game:getUsePhase(self.user)
    if phase and not self.useOptions?.notCounted then
        phase:addUseCount(name, 1)
    end

    self.game:moveCard(self.card, self:getTempZone())
    self.game:fire('卡牌-结算前', self)
    self.user:fire('卡牌-结算前', self)
    -- 指定目标后：逐目标发三份（全局 → 使用者 → 目标），在牌的结算（'使用' 钩子）之前
    for target in self.game.desk:actionOrder(self.targets) do
        self.game:fire('卡牌-指定目标后', self, target)
        self.user:fire('卡牌-来源-指定目标后', self, target)
        target:fire('卡牌-目标-指定目标后', self, target)
    end
    self.card:fireHandlers('使用', self)
    if not self.card.def.skipsEffect then
        for target in self.game.desk:actionOrder(self.targets) do
            local effect = New 'CardEffect' (self.game, self.card, target, self)
            effect:apply():await()
        end
    end
    self.game:fire('卡牌-结算后', self)
end

--- 这张牌对某个目标的一次生效（使用期逐目标 / 判定阶段每张一次）
---@class CardEffect : Effect
---@field card Card
---@field target Player
---@field useCard? UseCard # 这次生效属于哪一次用牌（判定阶段的那次没有）
---@field user Player # 使用者（判定阶段的那次没有）
local CardEffect = Class 'CardEffect'

Extends('CardEffect', 'Effect')

---@param game Game
---@param card Card
---@param target Player
---@param useCard? UseCard # 这次生效属于哪一次用牌（判定阶段的不给）
function CardEffect:__init(game, card, target, useCard)
    self.kind    = 'cardEffect'
    self.card    = card
    self.target  = target
    self.useCard = useCard
    if useCard then
        self.user = useCard.user
    end
end

---@type Player?
CardEffect.from = nil

---@type Player
CardEffect.to = nil

---@param self CardEffect
---@return Player? # 来源：使用者（判定阶段的那次没有）
CardEffect.__getter.from = function (self)
    return self.user
end

---@param self CardEffect
---@return Player # 承受者：这次生效冲谁来的
CardEffect.__getter.to = function (self)
    return self.target
end

---@async
function CardEffect:settle()
    self.card:fireHandlers('生效', self, self.useCard)
end

---@class UseCard.API
moe.useCard = {}

---@param options UseCard.CreateOptions
---@return UseCard
function moe.useCard.create(options)
    return New 'UseCard' (options.game, options.user, options.card, options.targets, options.useOptions)
end
