Depends { './奖惩' }

game:on('玩家-死亡', function ()
    if game:getResult() then
        return
    end

    if not game.desk:getPlayer(1):isAlive() then
        local alive = game.desk.alivePlayers
        if #alive == 1 and alive[1]:getTag('身份') == '内奸' then
            game:endGame { side = '内奸', reason = '主公阵亡，内奸成为唯一的存活者' }
        else
            game:endGame { side = '反贼', reason = '主公阵亡' }
        end
        return
    end

    for _, player in ipairs(game.desk.alivePlayers) do
        local identity = player:getTag('身份')
        if identity == '反贼' or identity == '内奸' then
            return
        end
    end
    game:endGame { side = '主公方', reason = '反贼与内奸全部阵亡' }
end)
