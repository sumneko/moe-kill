-- 弃牌阶段：手牌数降到体力值（一张一张问，直到弃够；一次给多张也行）

---@param player Player
local function discardPhase(player)
    local hand = player:getZone('手牌')
    while true do
        local extra = hand:count() - player:getAttr('体力')
        if extra <= 0 then
            return
        end
        local cards = game:askCard(player, '弃牌', { zone = '手牌', max = extra, cancelable = false }).cards
        if #cards == 0 then
            -- 没答 / 被拒收就由服务器一次替他弃够：手牌从前往后数
            local handCards = hand:list()
            cards = {}
            for i = 1, extra do
                cards[i] = handCards[i]
            end
        end
        game:moveCard(cards, '弃牌')
    end
end

game:on('阶段-开始', function (phase)
    if phase.name == '弃牌' then
        discardPhase(phase.player)
    end
end)
