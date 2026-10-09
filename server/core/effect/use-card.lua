---@class UseCard.CreateOptions
---@field game Game
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targets Player[] # 目标（可以为空表）
---@field useOptions? Game.UseOptions # 这次使用的选项（放行 / 记账用）

---@class UseCard : Effect
---@field targets Player[] # 这次使用的目标：一开始是**预选**（答复 / 调用方给的），进「成为目标时」起就是**最终目标列表**
---@field private targetsPending? (Player|false)[] # 生成期间那条排好的序列（`false` = 已被取消的位置）
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
---@param value Player|Player[]|true|fun(player: Player): boolean
---@param targets Player[] # 这次使用的目标
---@return Player[]
local function resolveBans(value, targets)
    if value == true then
        return moe.util.copy(targets)
    end
    if type(value) == 'function' then
        ---@cast value fun(player: Player): boolean
        ---@type Player[]
        local list = {}
        for _, target in ipairs(targets) do
            if value(target) then
                list[#list + 1] = target
            end
        end
        return list
    end
    return moe.util.toList(value)
end

--- 把一份选项片段并进选项表（返回新表，不改原来的）：`unrespondable` / `extraTargets` 是**累加**（前者四种写法先按 `targets` 解算），其余字段覆盖
---@param base? Game.UseOptions
---@param part Game.UseOptionsInput
---@param targets Player[]? # 这次使用的目标（解算 `true` / 谓词用）
---@return Game.UseOptions
local function mergeOptions(base, part, targets)
    ---@type Game.UseOptions
    local result = {}
    if base then
        for key, value in pairs(base) do
            result[key] = value
        end
    end
    for key, value in pairs(part) do
        if key == 'unrespondable' then
            ---@cast value Player|Player[]|true|fun(player: Player): boolean
            result.unrespondable = result.unrespondable or {}
            moe.util.arrayMerge(result.unrespondable, resolveBans(value, targets or {}))
        elseif key == 'extraTargets' then
            ---@cast value integer
            result.extraTargets = (result.extraTargets or 0) + value
        else
            result[key] = value
        end
    end
    return result
end

--- 使用过程中追加这次的选项（内容侧在时机里用）：`unrespondable` 这类名单是**累加**，其余字段覆盖
---@param options Game.UseOptionsInput
---@return UseCard
function M:addUseOptions(options)
    self.useOptions = mergeOptions(self.useOptions, options, self.targets)
    return self
end

--- 这个目标被禁止响应这张牌吗
---@param target Player
---@return boolean
function M:isResponseBanned(target)
    local banned = self.useOptions?.unrespondable
    return banned ~= nil and moe.util.arrayHas(banned, target)
end

--- 取消这个角色的一次「成为目标」（只在生成期间有效；同一个角色的重复条目一次撤一条）
---@param target Player
---@return UseCard
function M:removeTarget(target)
    if self.targetsPending then
        for i, t in ipairs(self.targetsPending) do
            if t == target then
                self.targetsPending[i] = false
                break
            end
        end
    end
    return self
end

--- 这个角色也成为这次使用的目标（只在生成期间有效：追加到末尾，本条时机结束后剩下的按行动顺序重排）
---@param target Player
---@return UseCard
function M:addTarget(target)
    if self.targetsPending then
        self.targetsPending[#self.targetsPending + 1] = target
    end
    return self
end

---@async
function M:settle()
    -- 内容侧可以给这次使用加选项（【奇才】这类）：写回自己的，后续钩子（如【杀】读 `isResponseBanned`）都认得
    self.useOptions = self.game:mergeUseOptions(self.user, self.card, self.useOptions, self.targets)

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
    self.user:fire('卡牌-来源-结算前', self)

    self.targetsPending = self.game.desk:sortPlayers(self.targets)
    local targetsPendingNum = #self.targetsPending
    for i = 1, 1000 do
        local target = self.targetsPending[i]
        if target == nil then
            break
        end
        if target == false then
            goto continue
        end
        self.game:fire('卡牌-指定目标后', self, target)
        self.user:fire('卡牌-来源-指定目标后', self, target)
        target:fire('卡牌-目标-指定目标后', self, target)

        if targetsPendingNum < #self.targetsPending then
            -- 被追加了目标，后面重新排序
            local after = moe.util.arrayFilter(table.move(self.targetsPending, i + 1, #self.targetsPending, 1, {}), function (item)
                return item ~= false
            end)
            after = self.game.desk:sortPlayers(after)
            targetsPendingNum = i + #after
            table.move(after, 1, #after, i + 1, self.targetsPending)
            for j = targetsPendingNum + 1, #self.targetsPending do
                self.targetsPending[j] = nil
            end
        end

        ::continue::
    end

    self.targets = moe.util.arrayFilter(self.targetsPending, function (item)
        return item ~= false
    end)
    self.targetsPending = nil

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

--- 把一份选项片段并进选项表（返回新表）：`unrespondable` / `extraTargets` 累加（前者按 `targets` 解算），其余字段覆盖
---@param base? Game.UseOptions
---@param part Game.UseOptionsInput
---@param targets? Player[] # 这次使用的目标（解算 `true` / 谓词用）
---@return Game.UseOptions
function moe.useCard.mergeOptions(base, part, targets)
    return mergeOptions(base, part, targets)
end

---@param options UseCard.CreateOptions
---@return UseCard
function moe.useCard.create(options)
    return New 'UseCard' (options.game, options.user, options.card, options.targets, options.useOptions)
end
