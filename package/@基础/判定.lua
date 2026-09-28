-- 判定：一次结算（亮牌 → 改判窗口 → 结束）
-- 判定牌从抽牌堆顶翻出、进这次判定自己的临时处理区；改判只能在「判定-前」里做，换下的牌也进临时区。
-- 收尾由内核做（`Effect` 基类）：把临时区里剩下的牌送弃牌。

---@class 判定 : Effect
---@field card? Card # 判定牌（在「判定-亮牌」里放上）
---@field replaced Card[] # 被换下的判定牌（按换下的顺序；它们也在这次判定的临时区里）
local Judge = Class('判定', 'Effect')

---@param game Game
---@param player Player
---@param reason? string
function Judge:__init(game, player, reason)
    self.kind      = '判定'
    self.player    = player
    self.reason    = reason
    self.replaced  = {}
    self.replacing = false
end

--- 这次判定就是一次结算：临时区自己建，不向父层取
---@return Zone
function Judge:getTempZone()
    return self:createTempZone()
end

--- 换掉当前判定牌：只能在「判定-前」里调；新牌进这次判定的临时区，被换下的那张记进 `replaced`
---@param card Card
function Judge:replace(card)
    if not self.replacing then
        error('换牌只能在「判定-前」里做', 2)
    end
    if self.card then
        table.insert(self.replaced, self.card)
    end
    self.game:moveCard(card, self:getTempZone())
    self.card = card
end

--- 开改判窗口：只有窗口开着的时候才允许换牌
local function fireReplaceWindow(judge)
    judge.replacing = true
    local guard <close> = setmetatable({}, { __close = function ()
        judge.replacing = false
    end })
    judge.game:fire('判定-前', judge)
end

--- 判定结算：亮牌 → 改判窗口 → 结束（翻牌与收牌都由本文件做）
---@async
function Judge:settle()
    self.game:fire('判定-亮牌', self)
    fireReplaceWindow(self)
    self.game:fire('判定-后', self)
end

-- 翻牌：从抽牌堆顶翻一张，放进这次判定自己的临时处理区（不够时由牌区上挂的回调补 —— 洗回弃牌）
game:on('判定-亮牌', function (judge)
    local cards = game:drawCards(judge.player, 1, judge:getTempZone())
    if #cards > 0 then
        judge.card = cards[1]
    end
end)

---@class Game
local Game = Class 'Game'

--- 判一次定：结完返回，结果读 `.card`
---@async
---@param player Player
---@param reason? string
---@return 判定
function Game:judge(player, reason)
    local judge = New '判定' (self, player, reason)
    judge:apply():await()
    return judge
end
