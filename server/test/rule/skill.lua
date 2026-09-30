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
