rule.depends { '../基础' }

rule:on('游戏-开始', function (ctx)
    local 座次 = ctx.desk:getPlayers()
    local 配置 = rule:getValue('身份配置')
    local 名单 = 配置 and 配置[#座次]
    if not 名单 then
        error('身份配置里没有 {} 人局' % { #座次 })
    end
    local 随机源 = ctx.random
    if not 随机源 then
        error('分配身份需要注入随机源')
    end

    local 待分配 = {}
    for _, 项 in ipairs(名单) do
        local 数量 = 项.人数 - (项.身份 == '主公' and 1 or 0)
        for _ = 1, 数量 do
            待分配[#待分配 + 1] = 项.身份
        end
    end
    if #待分配 ~= #座次 - 1 then
        error('身份配置与 {} 人局对不上：除了主公还差 {} 个人' % { #座次, #待分配 })
    end
    随机源:shuffle(待分配)

    for i = 2, #座次 do
        座次[i]:setTag('身份', 待分配[i - 1])
    end

    local 主公 = 座次[1]
    主公:setTag('身份', '主公')

    local 加成 = rule:getValue('主公体力上限加成') or 0
    if 加成 ~= 0 then
        local 属性 = 主公:getAttributes()
        属性:add('体力上限', 加成)
        属性:add('体力', 加成)
    end
end)
