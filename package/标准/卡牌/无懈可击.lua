-- 【无懈可击】（标准版）
-- 使用时机：一张锦囊牌对一个目标生效前。
-- 使用目标：一张对一个目标生效前的锦囊牌。
-- 作用效果：抵消此锦囊牌。
-- 它不能主动使用（没有「对角色使用」这一支），只由「生效前」的询问发起

--- 声明「对卡牌生效」= 它能被「对一张牌使用」（效果由下面那个窗口落地：内核的取消只能由被取消的那个效果自己的执行体发起）
Card '无懈可击'
    : extends '锦囊牌'
    : on('对卡牌生效', function () end)

--- 问一圈：有没有人对这张牌使用【无懈可击】（它自己还能被再抵消 ⇒ 递归）
---@param card Card # 当前待抵消的那张牌
---@return boolean # 它有没有被抵消
local function askNullify(card)
    for player in game.desk:actionOrder(game.desk.alivePlayers) do
        ---@type AskUseCardToCard.Condition
        local condition = { name = '无懈可击', target = card }
        local used = game:askUseCardToCard(player, card:getLabel(), condition).card
        if used then
            game:useCardToCard(player, used, card)
            return not askNullify(used)
        end
    end
    return false
end

game:on('效果-即将生效', function (effect)
    if effect.kind ~= 'cardEffect' then
        return
    end
    ---@cast effect CardEffect
    if effect.card:isKind('锦囊') and askNullify(effect.card) then
        effect:remove()
    end
end)
