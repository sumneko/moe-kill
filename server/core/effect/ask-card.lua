--- 一次答复：给出哪张牌（要一次使用时再带上目标）；单张或一张列表都行，入库前统一成列表
--- 由应答方从 `'卡牌-询问'` 里**返回**（返回空 = 不表态，问下一位）；答复不合法由内核拒收
---@class AskCard.Answer
---@field card? Card|Card[] # 给出的牌（答不上就是不给）
---@field viewAs? ViewAs # 选了哪份「视为」声明（与 `card` 互斥；只有使用族会出现）
---@field targets? Player|Player[] # 目标：`AskUseCard` / `AskCardWithTarget` 接受（别的类给了会被拒收）

--- 归一化之后存进结果里的形状
---@class AskCard.Result
---@field cards Card[] # 答复给出的牌（没答就是空表）
---@field targets? Player[] # 答复指定的目标（`AskUseCard` / `AskCardWithTarget` 用；别的类没有）

--- 一个合法选项：可以给出的一张牌
---@class AskCard.Option
---@field card? Card # 给出的牌（「视为」声明的选项没有牌 —— 牌要等素材到手才造）
---@field viewAs? ViewAs # 这个选项是哪份「视为」声明
---@field targets? Player[] # 这张牌的可用目标（「要一次使用」才有；有它就代表答复必须给目标、且要落在这里）

--- 要什么样的牌：每个字段都是一条筛选条件（数组 = 满足其一；单值 = 当成只有一个的数组；不填 = 无要求）
--- `min` / `max` 是「要给出几张」（`min` 不填 = 1、`max` 不填 = `min`）；「要一次使用」「要一张打出」恒为一张，别带这两个
--- 传单值就行 —— 构造询问时归一化一次（见 `AskCard.NormalizedCondition`）
---@class AskCard.Condition
---@field name? string|string[] # 牌名
---@field suit? string|string[] # 花色
---@field point? integer|integer[] # 点数
---@field color? string|string[] # 颜色（红 / 黑）
---@field zone? string|Zone|(string|Zone)[] # 牌在哪个区里（名字按「被问者 → 局上」解析；别人的区要传区对象）
---@field card? Card|Card[] # 牌必须在这批里（可以不属于任何牌区）
---@field min? integer # 至少要给几张（省略 = 1）
---@field max? integer # 至多给几张（省略 = min）
---@field cancelable? boolean # 允不允许主动取消（省略 = 允许：玩家可以不选 —— 没答复就是空答复；写 `false` 就是不给取消入口，没答复算拒收）

--- 询问身上存的是归一化之后的形状：字段名带复数 —— `names` / `cards` 是列表、`zones` 还解析成了区对象，另有 `min` / `max` 一定给出（订阅者与 `collectOptions` 直接读）
---@class AskCard.NormalizedCondition
---@field names? string[]
---@field suits? string[]
---@field points? integer[]
---@field colors? string[]
---@field zones? Zone[]
---@field cards? Card[]
---@field min integer
---@field max integer
---@field cancelable boolean # 允不允许主动取消（归一化时补默认：省略 = true）

---@class AskCard.CreateOptions
---@field game Game
---@field to Player # 被问者
---@field reason? string # 这次为什么问（内容由发起方定；原样带到应答方）
---@field condition? AskCard.Condition # 要什么样的牌（省略 = 不做限制；构造时归一化）

---@class AskCard : Effect
---@field to Player # 被问者
---@field reason string # 这次为什么问
---@field condition? AskCard.NormalizedCondition # 要什么样的牌（构造时归一化）
---@field options? AskCard.Option[] # 按条件算出的合法选项（询问交给应答方之前就摆好；没给条件时为空 = 不做限制）
---@field card? Card # 答复给出的第一张牌（没答就是空；= `.cards[1]`）
---@field cards Card[] # 答复给出的牌（没答就是空表）
---@field cancelable boolean # 这次允许主动取消吗（= 条件的 `cancelable`，省略就是允许）
local M = Class 'AskCard'

Extends('AskCard', 'Effect')

--- 找区：区对象直接用；名字按「被问者 → 局上」解析
---@param game Game
---@param to Player
---@param item string|Zone
---@return Zone?
local function resolveZone(game, to, item)
    if type(item) ~= 'string' then
        return item
    end
    return to:getZone(item) or game:getZone(item)
end

--- 把条件归一化一次：`name` → `names` / `card` → `cards` 成列表、`zone` → `zones` 解析成区对象（按「被问者 → 局上」，解析不到的丢掉）、`min` / `max` 补默认；子类自己加的字段原样保留（要归一就由子类自己补）
---@param game Game
---@param to Player
---@param condition AskCard.Condition?
---@return AskCard.NormalizedCondition?
local function normalizeCondition(game, to, condition)
    if not condition then
        return nil
    end
    local normalized = {}
    for key, value in pairs(condition) do
        normalized[key] = value
    end
    normalized.min  = condition.min or 1
    normalized.max  = condition.max or normalized.min
    normalized.cancelable = condition.cancelable ~= false
    if condition.name then
        normalized.names = moe.util.toList(condition.name)
        normalized.name  = nil
    end
    if condition.suit then
        normalized.suits = moe.util.toList(condition.suit)
        normalized.suit  = nil
    end
    if condition.point then
        normalized.points = moe.util.toList(condition.point)
        normalized.point  = nil
    end
    if condition.color then
        normalized.colors = moe.util.toList(condition.color)
        normalized.color  = nil
    end
    if condition.zone then
        ---@type Zone[]
        local zones = {}
        for _, item in ipairs(moe.util.toList(condition.zone)) do
            local zone = resolveZone(game, to, item)
            if zone then
                zones[#zones + 1] = zone
            end
        end
        normalized.zones = zones
        normalized.zone  = nil
    end
    if condition.card then
        normalized.cards = moe.util.toList(condition.card)
        normalized.card  = nil
    end
    ---@cast normalized AskCard.NormalizedCondition
    return normalized
end

--- 这张牌过不过这些筛选项（每项都是列表：不填 = 无要求；牌上没有对应属性时算不过）
---@param card Card
---@param condition AskCard.NormalizedCondition
---@return boolean
local function matches(card, condition)
    local names = condition.names
    if names and not moe.util.arrayHas(names, card.name) then
        return false
    end
    local suits = condition.suits
    if suits and not moe.util.arrayHas(suits, card.suit) then
        return false
    end
    local points = condition.points
    if points and not moe.util.arrayHas(points, card.point) then
        return false
    end
    local colors = condition.colors
    if colors and not moe.util.arrayHas(colors, card.color) then
        return false
    end
    return true
end

--- 按条件收集候选牌（`zones` / `cards` 指定来源，都不给就是被问者的所有牌区），再逐张过筛选项
---@param to Player # 被问者
---@param condition AskCard.NormalizedCondition
---@return Card[]
local function collectCandidates(to, condition)
    ---@type Card[]
    local cards = {}
    if condition.zones then
        for _, zone in ipairs(condition.zones) do
            moe.util.arrayMerge(cards, zone:list())
        end
    end
    if condition.cards then
        moe.util.arrayMerge(cards, condition.cards)
    end
    if not condition.zones and not condition.cards then
        for _, zone in ipairs(to:getZones()) do
            moe.util.arrayMerge(cards, zone:list())
        end
    end

    ---@type Card[]
    local result = {}
    for _, card in ipairs(cards) do
        if matches(card, condition) then
            result[#result + 1] = card
        end
    end
    return result
end

--- 一组目标过不过约束：个数落在区间里、都在可选项里（没给就不限制）、不重复
---@param list Player[] # 待校验的目标
---@param legal? Player[] # 可选项（不填 = 不做限制）
---@param min integer
---@param max integer
---@return any # 通过就是空
local function checkTargets(list, legal, min, max)
    if #list < min then
        return '至少要指定 {} 个目标' % { min }
    end
    if #list > max then
        return '至多指定 {} 个目标' % { max }
    end
    ---@type table<Player, true>
    local seen = {}
    for _, target in ipairs(list) do
        if legal and not moe.util.arrayHas(legal, target) then
            return '答复的目标不在可选项里'
        end
        if seen[target] then
            return '答复的目标重复了'
        end
        seen[target] = true
    end
    return nil
end

---@param game Game
---@param to Player
---@param reason string
---@param condition AskCard.Condition?
function M:__init(game, to, reason, condition)
    self.game      = game
    self.kind      = 'askCard'
    self.to        = to
    self.reason    = reason
    self.condition = normalizeCondition(game, to, condition)
end


--- 把一张牌装成一个选项（不算就返回空）—— 子类在这里补「能不能用、目标是谁」
---@param card Card
---@return AskCard.Option?
function M:makeOption(card)
    return { card = card }
end

--- 按条件算出合法选项（候选默认来自被问者的牌区；给了 `zone` / `card` 就只看那些）
---@return AskCard.Option[]? # 没给条件就是空 = 不做限制
function M:collectOptions()
    local condition = self.condition
    if not condition then
        return nil
    end

    ---@type AskCard.Option[]
    local options = {}
    for _, card in ipairs(collectCandidates(self.to, condition)) do
        local option = self:makeOption(card)
        if option then
            options[#options + 1] = option
        end
    end
    self:collectExtraOptions(options)
    return options
end

--- 追加「不是一张实体牌」的候选（子类在这里补 —— 如使用族的「视为」声明）
---@param options AskCard.Option[]
function M:collectExtraOptions(options)
end

--- 这个选项与这份答复配不配（子类在这里补「目标」那一半）
---@param option AskCard.Option
---@param value AskCard.Answer
---@return any # 通过就是空
function M:checkOption(option, value)
    if value.targets ~= nil then
        return '这次答复不该给目标'
    end
    return nil
end

--- 答复落在张数区间与合法选项里吗（不在就给原因）
---@param value AskCard.Answer
---@return any # 通过就是空
function M:checkAnswer(value)
    if type(value) ~= 'table' then
        return '答复必须是一张表（`{ card = ... }`）'
    end
    if value.viewAs ~= nil then
        for _, option in ipairs(self.options or {}) do
            if option.viewAs == value.viewAs then
                return self:checkOption(option, value)
            end
        end
        return '答复不在可选项里'
    end
    local cards = moe.util.toList(value.card)
    -- 允许取消的询问：空答复就是「取消」，不算不合法
    if #cards == 0 and self.cancelable then
        return nil
    end
    local min   = self.condition?.min or 1
    local max   = self.condition?.max or min
    if #cards < min then
        return '至少要给 {} 张牌' % { min }
    end
    if #cards > max then
        return '至多给 {} 张牌' % { max }
    end
    local options = self.options
    if not options or #cards == 0 then
        return nil
    end
    ---@type table<Card, true>
    local seen = {}
    for _, card in ipairs(cards) do
        if seen[card] then
            return '答复的牌重复了'
        end
        seen[card] = true
    end
    ---@type AskCard.Option?
    local matched = nil
    for _, card in ipairs(cards) do
        local found = nil
        for _, option in ipairs(options) do
            if option.card == card then
                found = option
                break
            end
        end
        if not found then
            return '答复不在可选项里'
        end
        matched = matched or found
    end
    return self:checkOption(assert(matched), value)
end

--- 答复入库前统一成 `{ cards = 列表, targets = 列表? }` 的形状（单张或一列都收）
---@param value AskCard.Answer
---@return AskCard.Result
function M:normalizeAnswer(value)
    ---@type Player[]?
    local targets = nil
    if value.targets ~= nil then
        targets = moe.util.toList(value.targets)
    end
    return {
        cards   = moe.util.toList(value.card),
        targets = targets,
    }
end

--- 答复给出的那些牌（没答就是空表）
---@param self AskCard
---@return Card[]
M.__getter.cards = function (self)
    return self.result?.cards or {}
end

--- 答复给出的第一张牌（没答就是空）
---@param self AskCard
---@return Card?
M.__getter.card = function (self)
    return self.cards[1]
end

--- 这次允许主动取消吗
---@param self AskCard
---@return boolean
M.__getter.cancelable = function (self)
    return self.condition?.cancelable ~= false
end

--- 答复已定下、答复时机之前跑一次（子类在这里处置那张牌）
---@async
function M:onAnswered()
end

--- 把问题交给应答方之前跑一次（子类在这里做别的事 —— 打出族用它开「替代」窗口）
---@async
function M:beforeAsk()
end

--- 答复校验过了、定下结果之前跑一次（子类在这里把「不是一张牌」的答复换成牌；给空 = 这次作废，原因自己 reject 过）
---@async
---@param value AskCard.Answer
---@return AskCard.Answer?
function M:beforeResolve(value)
    return value
end

--- 取值：先开替代窗口，没人替代就问应答方（**第一个给出答复的胜出，后面的订阅者不再调**）
---@async
---@return boolean # 有没有拿到答复（答复不合法时也已经拒收）
function M:collectAnswer()
    self:beforeAsk()
    if self.task.resolved then
        return true
    end

    local answer = self.game:fire('卡牌-询问', self)
    if answer == nil then
        -- 不允许取消的询问：不表态不是合法结局，记成拒收
        if not self.cancelable then
            self.task:reject('这次询问必须给出答复')
        end
        return false
    end

    local problem = self:checkAnswer(answer)
    if problem then
        self.task:reject(problem)
        return false
    end

    local resolved = self:beforeResolve(answer)
    if resolved == nil then
        return false
    end

    self.task:resolve(self:normalizeAnswer(resolved))
    return true
end

--- 把询问交给应答方（选项先摆好；答复一到，结果就定下了）
---@async
function M:settle()
    self.options = self:collectOptions()

    if not self:collectAnswer() then
        return
    end

    self:onAnswered()
    self.game:fire('卡牌-答复', self)
    self.game:fire('卡牌-答复后', self)
end

---@class AskCard.API
moe.askCard = {}

--- 把条件归一化一次（`ViewAs` 声明素材时也用它）
moe.askCard.normalizeCondition = normalizeCondition

--- 按条件收集候选牌（`ViewAs` 判「素材够不够」时也用它）
moe.askCard.collectCandidates = collectCandidates

--- 校验一组目标（个数 / 归属 / 重复；`AskCardWithTarget` 与 `AskUseSkill` 共用）
moe.askCard.checkTargets = checkTargets

---@param options AskCard.CreateOptions
---@return AskCard
function moe.askCard.create(options)
    return New 'AskCard' (options.game, options.to, options.reason, options.condition)
end
