---@param player Player
---@param name string
---@return Card? # 这个角色名下任一牌区里第一张叫这个名字的牌
local function findCard(player, name)
    for _, zone in ipairs(player:getZones()) do
        for _, card in ipairs(zone:list()) do
            if card:getLabel() == name then
                return card
            end
        end
    end
    return nil
end

Card '杀'
    : on('获取目标', function (ctx)
        local desk  = game.desk
        local range = ctx.user:getAttr('攻击范围')
        return util.filter(desk.alivePlayers, function (player)
            return player ~= ctx.user
               and desk:getDistance(ctx.user, player) <= range
        end)
    end)
    : on('生效', function (ctx)
        local target = ctx.target
        if game:ask(target, { name = '闪' }) then
            local jink = findCard(target, '闪')
            if jink then
                game:respond(target, jink)
                ctx:remove()
                return
            end
        end
        game:damage(ctx.user, target, 1)
    end)
