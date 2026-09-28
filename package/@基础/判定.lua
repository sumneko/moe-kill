-- 判定：一次结算
-- 判定牌从抽牌堆顶翻出、进这次判定自己的临时处理区；改判只能在「判定-前」里做，换下的牌也进临时区。
-- 收尾由内核做（`Effect` 基类）：把临时区里剩下的牌送弃牌。

---@class Judge : Effect
---@field card? Card # 判定牌（翻出来就放上）
---@field replaced Card[] # 被换下的判定牌（按换下的顺序；它们也在这次判定的临时区里）
local Judge = Class('Judge', 'Effect')

---@param game Game
---@param player Player
---@param reason? string
function Judge:__init(game, player, reason)
    self.kind      = 'judge'
    self.player    = player
    self.reason    = reason
    self.replaced  = {}
    self.replacing = false
end

--- 换掉当前判定牌：只能在「判定-前」里调；新牌进这次判定的临时区，被换下的那张记进 `replaced`
---@param card Card
function Judge:replace(card)
    if not self.replacing then
        -- 不在改判窗口里就什么也不做（窗口外改判是调用方写错，不该炸局）
        return
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
    local guard <close> = util.defer(function ()
        judge.replacing = false
    end)
    judge.game:fire('判定-前', judge)
end

--- 判定结算
---@async
function Judge:settle()
    -- 亮牌
    local cards = self.game:drawCards(self.player, 1, self:getTempZone())
    if #cards > 0 then
        self.card = cards[1]
    end
    -- 改判窗口
    fireReplaceWindow(self)
    -- 结束
    self.game:fire('判定-后', self)
end

---@class Game
local Game = Class 'Game'

--- 判一次定：结完返回，结果读 `.card`
---@async
---@param player Player
---@param reason? string
---@return Judge
function Game:judge(player, reason)
    local judge = New 'Judge' (self, player, reason)
    judge:apply():await()
    return judge
end
