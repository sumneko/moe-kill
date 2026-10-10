local lt      = require 'test.ltest'
local support = require 'test.user.support'

---@async
lt.test('技能下行：挂上技能就广播一条 Skill.Update', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    ---@type Proto.Notify.skill.Update[]
    local got = {}
    local _ <close> = moe.client.register('Skill.Update', function (client, params)
        if client == front then
            got[#got + 1] = params
        end
    end)

    local skill = me:addSkill('马术')
    moe.await.sleep(0)

    lt.assertEquals('收到一条', 1, #got)
    local proto = assert(assert(got[1]).skill)
    lt.assertEquals('技能名', '马术', proto.name)
    lt.assertEquals('协议号就是技能自己的', skill.id, proto.id)
    lt.assertEquals('记在主人名下', me.id, proto.player)
    lt.assertEquals('自动开关默认关', false, proto.auto)
    lt.assertEquals('锁定技带标签', true, moe.util.arrayHas(proto.tag or {}, '锁定技'))
    lt.assertEquals('挂着就是启用着', false, proto.disabled)
end)

---@async
lt.test('技能下行：摘掉技能就广播一条 Skill.Remove', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local skill = me:addSkill('马术')
    moe.await.sleep(0)

    ---@type Proto.Notify.Skill.Remove[]
    local got = {}
    local _ <close> = moe.client.register('Skill.Remove', function (client, params)
        if client == front then
            got[#got + 1] = params
        end
    end)

    skill:remove()
    moe.await.sleep(0)

    lt.assertEquals('收到一条', 1, #got)
    lt.assertEquals('带的是那个号', skill.id, assert(got[1]).id)
end)

---@async
lt.test('技能上行：客户端改自动开关 ⇒ 回包并广播更新', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local skill = me:addSkill('马术')
    moe.await.sleep(0)

    ---@type Proto.Notify.skill.Update[]
    local got = {}
    local _ <close> = moe.client.register('Skill.Update', function (client, params)
        if client == front then
            got[#got + 1] = params
        end
    end)

    local result = front:request('Skill.ChangeAuto', { id = skill.id, auto = true }):await()

    lt.assertEquals('回包说了新状态', true, assert(result).auto)
    lt.assertEquals('技能真的切了', true, skill.auto)
    moe.await.sleep(0)
    lt.assertEquals('顺带广播了一条更新', 1, #got)
    lt.assertEquals('广播里也是新状态', true, assert(assert(got[1]).skill).auto)
end)

---@async
lt.test('技能上行：不是他的技能 ⇒ 请求失败，状态不动', function ()
    local game, players, fronts = support.newPackageGame()
    local me    = assert(players[1])
    local front = assert(fronts[1])

    local skill = me:addSkill('马术')
    moe.await.sleep(0)

    lt.expectErrors(1)
    local result = front:request('Skill.ChangeAuto', { id = skill.id + 999, auto = true }):await()

    lt.assertEquals('没有回包', nil, result)
    lt.assertEquals('技能没被动过', false, skill.auto)
end)
