-- 阵亡清算（官方）：角色死亡后，其所有牌（手牌 / 装备区 / 判定区）置入弃牌堆；身上的技能一并禁用

game:on('玩家-死亡', function (player)
    -- 先禁用技能：否则下面这批牌离区时，死者的技能（如【枭姬】）还会响应
    for _, skill in ipairs(player:getSkills()) do
        skill:disablePassive()
    end

    ---@type Card[]
    local cards = {}
    for _, zone in ipairs(player:getZones()) do
        table.mergeArray(cards, zone:list())
    end
    if #cards > 0 then
        game:moveCard(cards, '弃牌')
    end
end)
