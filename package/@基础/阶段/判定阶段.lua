-- 判定阶段：结算判定区里的牌（后置入的先判）

-- 结算某个角色的判定区：进入顺序先进在前，从尾往头逐张（后置入的先判），不在判定区里的跳过；结算完还留在判定区里的送弃牌堆
---@async
---@param player Player
local function resolveJudgeZone(player)
    local zone  = player:getZone('判定')
    local cards = zone:list()
    for i = #cards, 1, -1 do
        local card = cards[i]
        -- 快照可能过期：这张已经不在判定区里（被拿走 / 清掉）就不结算
        if card:getZone() ~= zone then
            goto continue
        end
        card:doEffect()
        -- 结完自己挪走了的（闪电判不中）就不弃
        if card:getZone() ~= zone then
            goto continue
        end
        game:moveCard(card, '弃牌')
        ::continue::
    end
end

game:on('阶段-生效', function (phase)
    if phase.name == '判定' then
        resolveJudgeZone(phase.player)
    end
end)
