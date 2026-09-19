require 'core.effect'

---@class UseCard.CreateOptions
---@field game Game
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targets Player[] # 目标（可以为空表）

---@class UseCard : Effect
---@field user Player # 使用者
---@field card Card # 被使用的牌
---@field targets Player[] # 目标（可以为空表）
local M = Class 'UseCard'

Extends('UseCard', 'Effect')

---@param game Game
---@param user Player
---@param card Card
---@param targets Player[]
function M:__init(game, user, card, targets)
    self.kind    = 'useCard'
    self.user    = user
    self.card    = card
    self.targets = targets
end

---@param user Player
---@param card Card
---@return Zone? # 牌所在的牌区（找到时才有）
---@return integer? # 牌在该牌区里的位置
local function findHeldZone(user, card)
    for _, zone in ipairs(user:getZones()) do
        for i, held in ipairs(zone:list()) do
            if held == card then
                return zone, i
            end
        end
    end
    return nil, nil
end

---@param def CardDef
---@param ctx UseCard
---@return Player[] # 各声明取交集后的合法目标
local function collectLegalTargets(def, ctx)
    local handlers = def:getHandlers('获取目标')
    if #handlers == 0 then
        error('「{}」没有声明「获取目标」，现在用不了' % { def.fullName }, 3)
    end
    ---@type Player[]?
    local legal = nil
    for _, handler in ipairs(handlers) do
        local list = handler(ctx)
        if type(list) ~= 'table' then
            error('「{}」的「获取目标」必须返回合法目标列表' % { def.fullName }, 3)
        end
        if legal then
            ---@type Player[]
            local narrowed = {}
            for _, player in ipairs(legal) do
                if moe.util.arrayHas(list, player) then
                    narrowed[#narrowed + 1] = player
                end
            end
            legal = narrowed
        else
            ---@type Player[]
            local copied = {}
            table.move(list, 1, #list, 1, copied)
            legal = copied
        end
    end
    if not legal or #legal == 0 then
        error('「{}」现在没有合法目标' % { def.fullName }, 3)
    end
    return legal
end

function M:settle()
    local name = self.card:getLabel()
    if type(name) ~= 'string' then
        error('这张牌没有牌名，查不到内容定义', 2)
    end
    local def = self.game:getCard(name)
    if not def then
        error('没有叫「{}」的内容定义' % { name }, 2)
    end

    local zone, index = findHeldZone(self.user, self.card)
    if not zone or not index then
        error('使用者手上没有这张牌', 2)
    end

    local legal = collectLegalTargets(def, self)
    if #self.targets == 0 then
        error('「{}」至少要指定一个目标' % { def.fullName }, 2)
    end
    for _, target in ipairs(self.targets) do
        if not moe.util.arrayHas(legal, target) then
            error('「{}」不能以这个角色为目标' % { def.fullName }, 2)
        end
    end

    zone:take(index)
    for _, handler in ipairs(def:getHandlers('使用')) do
        handler(self)
    end
    self.game:fire('卡牌-结算后', self)
end

---@class UseCard.API
local API = {}

---@param options UseCard.CreateOptions
---@return UseCard
function API.create(options)
    return New 'UseCard' (options.game, options.user, options.card, options.targets)
end

return API
