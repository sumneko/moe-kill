require 'core.effect.effect'

---@class Judge.CreateOptions
---@field game Game # 这次判定属于哪一局
---@field player Player # 谁要判定
---@field reason? string # 为什么判（内容由发起方定，内核不解释）

---@class Judge : Effect
---@field player Player # 谁要判定
---@field reason? string # 为什么判
---@field card? Card # 判定牌（内容侧在 `'判定-亮牌'` 里放上）
---@field replaced Card[] # 被换下的判定牌（按换下的顺序；它们也在这次判定的临时区里）
---@field private replacing boolean # 现在是不是 `'判定-前'` 的窗口里
local M = Class 'Judge'

Extends('Judge', 'Effect')

---@param game Game
---@param player Player
---@param reason? string
function M:__init(game, player, reason)
    self.game      = game
    self.kind      = 'judge'
    self.player    = player
    self.reason    = reason
    self.replaced  = {}
    self.replacing = false
end

--- 这次判定就是一次结算：临时区自己建，不向父层取
---@return Zone
function M:getTempZone()
    return self:createTempZone()
end

--- 换掉当前判定牌：只能在 `'判定-前'` 里调；新牌进这次判定的临时区，被换下的那张记进 `replaced`（也在临时区里，收尾统一处置）
---@param card Card
function M:replace(card)
    if not self.replacing then
        error('换牌只能在「判定-前」里做', 2)
    end
    if self.card then
        table.insert(self.replaced, self.card)
    end
    self.game:moveCard(card, self:getTempZone())
    self.card = card
end

--- 发改判窗口：窗口开着的时候才允许换牌
---@private
function M:fireBefore()
    self.replacing = true
    local guard <close> = moe.util.defer(function ()
        self.replacing = false
    end)
    self.game:fire('判定-前', self)
end

--- 判定结算：亮牌 → 改判窗口 → 结果已定；内核不搬牌、不认识牌面
---@async
function M:settle()
    self.game:fire('判定-亮牌', self)
    self:fireBefore()
    self.game:fire('判定-后', self)
end

---@class Judge.API
moe.judge = {}

---@param options Judge.CreateOptions
---@return Judge
function moe.judge.create(options)
    return New 'Judge' (options.game, options.player, options.reason)
end
