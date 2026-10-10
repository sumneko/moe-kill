local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('询问：要一次使用，实体候选带目标区间，回包的 id 转回真牌', function ()
    local game, players = support.newPackageGame()
    local me    = assert(players[1])
    local other = assert(players[2])

    local slash = support.giveCard(game, me, '杀', '黑桃', 7)
    support.giveCard(game, me, '闪', '红桃', 2)
    local slashId = support.cardId(me, slash)

    ---@type Proto.Request.Ask.Use?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Use', function (_, params)
        ---@cast params Proto.Request.Ask.Use
        sent = params
        return { usedCard = slashId, targets = { other.id } }
    end)

    local ask = moe.askUseCard.create {
        game      = game,
        to        = me,
        reason    = '出牌',
        condition = { zone = '手牌' },
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('只有那张【杀】能使用', 1, #params.card)
    lt.assertEquals('没有视为选项', 0, #params.viewAs)
    local plan = assert(params.card[1])
    lt.assertEquals('候选带的是牌号', slashId, plan.id)
    lt.assertEquals('目标区间的张数', '1,1', plan.min .. ',' .. plan.max)
    lt.assertEquals('可用目标里有对方', true, moe.util.arrayHas(plan.ids, other.id))
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('拿到的是一张真牌', slash, ask.card)
    lt.assertEquals('目标就是对方', true, moe.util.arrayHas(ask.targets or {}, other))
end)

---@async
lt.test('询问：视为候选带来源与素材条件，同答给素材就不再问第二次', function ()
    local game, players = support.newPackageGame()
    local me    = assert(players[1])
    local other = assert(players[2])

    local jink = support.giveCard(game, me, '闪', '红桃', 2)
    local jinkId = support.cardId(me, jink)
    me:addViewAs('杀', nil, { condition = { name = '闪', zone = '手牌', min = 1 } })

    ---@type Proto.Request.Ask.Use?
    local sent = nil
    ---@type string[]
    local asked = {}
    local _ <close> = moe.client.register('Ask.Use', function (_, params)
        ---@cast params Proto.Request.Ask.Use
        sent = params
        asked[#asked + 1] = 'Ask.Use'
        local viewAs = assert(params.viewAs[1], '视为该进选项')
        return {
            usedViewAs = 1,
            cards      = assert(viewAs.card).ids,
            targets    = { other.id },
        }
    end)
    local _ <close> = moe.client.register('Ask.Select', function ()
        asked[#asked + 1] = 'Ask.Select'
        return { card = {} }
    end)

    local ask = moe.askUseCard.create {
        game      = game,
        to        = me,
        reason    = '出牌',
        condition = { zone = '手牌' },
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    local viewAs = assert(params.viewAs[1], '视为该进选项')
    lt.assertEquals('声明的牌名', '杀', viewAs.name)
    lt.assertEquals('没有关联来源就不给来源', nil, viewAs.sourceCard)
    lt.assertEquals('素材候选就是那张【闪】', jinkId, assert(viewAs.card).ids[1])
    lt.assertEquals('视为候选也带目标区间', true, #assert(viewAs.target).ids > 0)
    lt.assertEquals('只问了这一次', 'Ask.Use', table.concat(asked, '|'))
    lt.assertEquals('这次成了', true, ask.success)
    local produced = assert(ask.card)
    lt.assertEquals('造出来的是一张虚拟牌', true, produced.virtual == true)
    lt.assertEquals('素材就是那张【闪】', jink, assert(produced.subcards)[1])
end)

---@async
lt.test('询问：视为下标不认 ⇒ 这次不算成立', function ()
    local game, players = support.newPackageGame()
    local me = assert(players[1])

    support.giveCard(game, me, '闪', '红桃', 2)
    me:addViewAs('杀', nil, { condition = { name = '闪', zone = '手牌', min = 1 } })

    local _ <close> = moe.client.register('Ask.Use', function ()
        return { usedViewAs = 99 }
    end)

    local ask = moe.askUseCard.create {
        game      = game,
        to        = me,
        reason    = '出牌',
        condition = { zone = '手牌' },
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('没有牌', nil, ask.card)
end)

---@async
lt.test('询问：视为不带素材 ⇒ 内核再问一次收素材', function ()
    local game, players = support.newPackageGame()
    local me    = assert(players[1])
    local other = assert(players[2])

    local jink = support.giveCard(game, me, '闪', '红桃', 2)
    me:addViewAs('杀', nil, { condition = { name = '闪', zone = '手牌', min = 1 } })

    ---@type string[]
    local asked = {}
    local _ <close> = moe.client.register('Ask.Use', function (_, params)
        ---@cast params Proto.Request.Ask.Use
        asked[#asked + 1] = 'Ask.Use'
        assert(params.viewAs[1], '视为该进选项')
        return { usedViewAs = 1, targets = { other.id } }
    end)
    local _ <close> = moe.client.register('Ask.Select', function (_, params)
        ---@cast params Proto.Request.Ask.Select
        asked[#asked + 1] = 'Ask.Select:' .. params.reason
        local condition = assert(params.card)
        return { card = { condition.ids[1] } }
    end)

    local ask = moe.askUseCard.create {
        game      = game,
        to        = me,
        reason    = '出牌',
        condition = { zone = '手牌' },
    }
    ask:apply():await()

    lt.assertEquals('先选使用、再收素材', 'Ask.Use|Ask.Select:杀', table.concat(asked, '|'))
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('素材就是那张【闪】', jink, assert(assert(ask.card).subcards)[1])
end)

---@async
lt.test('询问：技能当来源的视为，来源发的是技能号', function ()
    local game, players = support.newPackageGame()
    local me = assert(players[1])

    local skill = me:addSkill('武圣')
    support.giveCard(game, me, '桃', '红桃', 3)

    ---@type Proto.Request.Ask.Use?
    local sent = nil
    local _ <close> = moe.client.register('Ask.Use', function (_, params)
        ---@cast params Proto.Request.Ask.Use
        sent = params
        return nil
    end)

    local ask = moe.askUseCard.create {
        game      = game,
        to        = me,
        reason    = '出牌',
        condition = { zone = '手牌' },
    }
    ask:apply():await()

    local viewAs = assert(assert(sent).viewAs[1], '武圣该进选项')
    lt.assertEquals('声明的牌名', '杀', viewAs.name)
    lt.assertEquals('来源发的是这个技能的号', skill.id, viewAs.sourceSkill)
    lt.assertEquals('来源牌那半不给', nil, viewAs.sourceCard)
end)
