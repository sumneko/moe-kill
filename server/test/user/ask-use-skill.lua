local lt      = require 'test.ltest'
local support = require 'test.user.support'

--- 备好一局：他挂着【青囊】、手里一张牌、对方受了伤（能当它的目标）
---@async
---@return Game
---@return Player # 被问的人
---@return Player # 对方
---@return Skill # 【青囊】
---@return Card # 手上那张
local function prepare()
    local game, players = support.newPackageGame()
    local me    = assert(players[1])
    local other = assert(players[2])
    local skill = me:addSkill('青囊')
    local card  = support.giveCard(game, me, '桃', '红桃', 3)
    other:setAttr('体力', 2)
    return game, me, other, skill, card
end

---@async
lt.test('询问：要一次技能使用，候选带技能号与能挑的牌 / 目标，答复直接发动', function ()
    local game, me, other, skill, card = prepare()

    ---@type Proto.Request.Ask.UseSkill?
    local sent = nil
    local _ <close> = moe.client.register('Ask.UseSkill', function (_, params)
        ---@cast params Proto.Request.Ask.UseSkill
        sent = params
        local plan = assert(params.skills[1])
        return {
            usedSkill = plan.id,
            cards     = assert(plan.cards).ids,
            targets   = { other.id },
        }
    end)

    local ask = moe.askUseSkill.create {
        game   = game,
        to     = me,
        reason = '出牌',
    }
    ask:apply():await()

    local params = assert(sent, '没问过客户端')
    lt.assertEquals('候选只有那个技能', 1, #params.skills)
    local plan = assert(params.skills[1])
    lt.assertEquals('发的是技能号', skill.id, plan.id)
    lt.assertEquals('能挑的牌就是那张', support.cardId(me, card), assert(plan.cards).ids[1])
    lt.assertEquals('牌只要一张', '1,1', assert(plan.cards).min .. ',' .. assert(plan.cards).max)
    lt.assertEquals('目标里有对方', true, moe.util.arrayHas(assert(plan.targets).ids, other.id))
    lt.assertEquals('这次成了', true, ask.success)
    lt.assertEquals('选中的就是这个技能', skill, ask.skill)
    lt.assertEquals('发动时带着那张牌', true, moe.util.arrayHas(assert(ask.result).cards or {}, card))
end)

---@async
lt.test('询问：技能号不认 ⇒ 这次不算成立', function ()
    local game, me = prepare()

    local _ <close> = moe.client.register('Ask.UseSkill', function ()
        return { usedSkill = 9999 }
    end)

    local ask = moe.askUseSkill.create {
        game   = game,
        to     = me,
        reason = '出牌',
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('没发动技能', nil, ask.skill)
end)

---@async
lt.test('询问：该给牌却没给 ⇒ 内核拒收', function ()
    local game, me = prepare()

    local _ <close> = moe.client.register('Ask.UseSkill', function (_, params)
        ---@cast params Proto.Request.Ask.UseSkill
        return { usedSkill = assert(params.skills[1]).id }
    end)

    local ask = moe.askUseSkill.create {
        game   = game,
        to     = me,
        reason = '出牌',
    }
    ask:apply():await()

    lt.assertEquals('这次没成', false, ask.success)
    lt.assertEquals('原因是没给牌', '至少要给 1 张牌', ask.err)
end)
