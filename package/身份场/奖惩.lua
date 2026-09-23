-- 死亡奖惩（官方）：杀死反贼的角色摸三张牌；主公杀死忠臣，主公弃置其所有手牌与装备牌。
-- 装备区还没做 ⇒ 现在只弃手牌，等装备批次补上。

game:on('玩家-死亡', function (player)
    local dying  = game:getDying(player)          -- 死亡时机里那次濒死的账还在
    local damage = dying and dying.damage         -- 致死伤害 = 最后一次打他那一丁
    local killer = damage and damage.from
    if not killer or killer == player then
        return
    end

    if player:getTag('身份') == '反贼' then
        game:draw(killer, 3)
        return
    end

    if player:getTag('身份') == '忠臣' and killer == game.desk:getPlayer(1) then
        local hand = killer:getZone('手牌')
        if hand and hand:count() > 0 then
            game:moveCard(hand:list(), '弃牌')
        end
    end
end)
