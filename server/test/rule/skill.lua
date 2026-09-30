local lt      = require 'test.ltest'
local support = require 'test.rule.support'

---@param run Test.RuleSupport
---@param player Player
---@param name string # 要哪张牌
---@return Card
local function takeCard(run, player, name)
    local deck = assert(run.game:getZone('抽牌'))
    for _, card in ipairs(deck:list()) do
        if card.name == name then
            run.game:moveCard(card, player:getZone('手牌'))
            return card
        end
    end
    error('牌堆里没有「' .. name .. '」')
end

lt.test('奸雄：受到伤害后可以拿到那张牌', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local caocao = run.players[2]
    caocao:addSkill('奸雄')

    local slash = takeCard(run, user, '杀')

    ---@type string[]
    local trace = {}
    run.game:on('决策-询问', function (ask)
        if ask.reason == '奸雄' then
            ---@cast ask AskChoice
            trace[#trace + 1] = '是否发动'
            return '发动'
        end
    end)

    run.game:useCard(user, slash, { caocao })

    lt.assertEquals('问了一次「要不要发动」', '是否发动', table.concat(trace, ','))
    lt.assertEquals('那张【杀】到了曹操手里', true,
        moe.util.arrayHas(caocao:getZone('手牌'):list(), slash))
    lt.assertEquals('伤害照常结算', 4, caocao:getAttr('体力'))
    lt.assertEquals('没进弃牌堆', false,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), slash))
end)

lt.test('奸雄：不发动就不拿', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local caocao = run.players[2]
    caocao:addSkill('奸雄')

    local slash = takeCard(run, user, '杀')
    -- 应答方对「奸雄」不表态 = 不发动

    run.game:useCard(user, slash, { caocao })

    lt.assertEquals('那张【杀】进了弃牌堆', true,
        moe.util.arrayHas(assert(run.game:getZone('弃牌')):list(), slash))
    lt.assertEquals('曹操手里没有它', false,
        moe.util.arrayHas(caocao:getZone('手牌'):list(), slash))
    lt.assertEquals('伤害照常结算', 4, caocao:getAttr('体力'))
end)

lt.test('奸雄：没有「造成伤害的牌」时连问都不问', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local caocao = run.players[2]
    caocao:addSkill('奸雄')

    local asked = false
    run.game:on('决策-询问', function (ask)
        if ask.reason == '奸雄' then
            ---@cast ask AskChoice
            asked = true
            return '发动'
        end
    end)

    run.game:damage(nil, caocao, 1)

    lt.assertEquals('没问过', false, asked)
    lt.assertEquals('伤害照常结算', 4, caocao:getAttr('体力'))
end)

lt.test('奸雄：那张牌已经不在原处 ⇒ 拿不到，也不问', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local caocao = run.players[2]
    caocao:addSkill('奸雄')

    local slash = takeCard(run, user, '杀')

    -- 伤害结算里把牌挪给别人（模拟「发动之前已经被人拿走」）
    run.game:on('伤害-开始', function (damage)
        if damage.card then
            run.game:moveCard(damage.card, user:getZone('手牌'))
        end
    end)

    local asked = false
    run.game:on('决策-询问', function (ask)
        if ask.reason == '奸雄' then
            ---@cast ask AskChoice
            asked = true
            return '发动'
        end
    end)

    run.game:useCard(user, slash, { caocao })

    lt.assertEquals('没问过「要不要发动」', false, asked)
    lt.assertEquals('曹操没拿到', false,
        moe.util.arrayHas(caocao:getZone('手牌'):list(), slash))
    lt.assertEquals('牌在别人手里', true,
        moe.util.arrayHas(user:getZone('手牌'):list(), slash))
    lt.assertEquals('伤害照常结算', 4, caocao:getAttr('体力'))
end)

lt.test('奸雄：虚拟牌的素材被挪走 ⇒ 一样拿不到', function ()
    local run    = support.start { count = 2, packages = { '标准' } }
    local user   = run.players[1]
    local caocao = run.players[2]
    caocao:addSkill('奸雄')

    local first   = takeCard(run, caocao, '桃')
    local second  = takeCard(run, caocao, '桃')
    local virtual = run.game:createVirtualCard('杀', { first, second })

    -- 虚拟牌自己没动，是它的素材被挪走了
    run.game:on('伤害-开始', function ()
        run.game:moveCard({ first, second }, user:getZone('手牌'))
    end)

    local asked = false
    run.game:on('决策-询问', function (ask)
        if ask.reason == '奸雄' then
            ---@cast ask AskChoice
            asked = true
            return '发动'
        end
    end)

    local before = caocao:getAttr('体力')
    run.game:damage(nil, caocao, 1, virtual)

    lt.assertEquals('没问过「要不要发动」', false, asked)
    lt.assertEquals('曹操没拿到', false,
        moe.util.arrayHas(caocao:getZone('手牌'):list(), first))
    lt.assertEquals('素材在别人手里', true,
        moe.util.arrayHas(user:getZone('手牌'):list(), first))
    lt.assertEquals('伤害照常结算（掉 1 点）', before - 1, caocao:getAttr('体力'))
end)

lt.test('奸雄：素材只剩一张在原处 ⇒ 能拿的那张照拿', function ()
    local run    = support.start { count = 3, packages = { '标准' } }
    local user   = run.players[1]
    local caocao = run.players[2]
    local other  = run.players[3]
    caocao:addSkill('奸雄')

    local first   = takeCard(run, user, '桃')
    local second  = takeCard(run, user, '桃')
    local virtual = run.game:createVirtualCard('杀', { first, second })

    -- 结算里只把其中一张挪给第三方（另一张还在原位）
    run.game:on('伤害-开始', function ()
        run.game:moveCard(second, other:getZone('手牌'))
    end)

    local asked = false
    run.game:on('决策-询问', function (ask)
        if ask.reason == '奸雄' then
            ---@cast ask AskChoice
            asked = true
            return '发动'
        end
    end)

    run.game:damage(nil, caocao, 1, virtual)

    lt.assertEquals('问过「要不要发动」', true, asked)
    lt.assertEquals('还在原位的那张拿到了', true,
        moe.util.arrayHas(caocao:getZone('手牌'):list(), first))
    lt.assertEquals('被挪走的那张没拿', false,
        moe.util.arrayHas(caocao:getZone('手牌'):list(), second))
    lt.assertEquals('它留在别人手里', true,
        moe.util.arrayHas(other:getZone('手牌'):list(), second))
end)
