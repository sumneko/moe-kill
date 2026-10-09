local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'death-probe'

---@param content string
---@return unknown # 配 <close> 用
local function useProbe(content)
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    fs.create_directories((probeDir / '探针'):string())
    local ok, err = moe.util.saveFile((probeDir / '探针/技能.lua'):string(), content)
    assert(ok, err)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@param run Test.RuleSupport
---@param name string
---@return Card
local function putCard(run, name)
    return run.game:createCard(name)
end

lt.test('阵亡清算：死者的手牌 / 装备 / 判定区的牌都进弃牌堆', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local dead = run.players[2]

    run.game:moveCard(putCard(run, '杀'), assert(dead:getZone('手牌')))
    run.game:moveCard(putCard(run, '青龙偃月刀'), assert(dead:getZone('武器')))
    run.game:moveCard(putCard(run, '乐不思蜀'), assert(dead:getZone('判定')))
    local before = assert(run.game:getZone('弃牌')):count()

    dead:setAlive(false)

    lt.assertEquals('手牌清空', 0, assert(dead:getZone('手牌')):count())
    lt.assertEquals('装备区清空', 0, assert(dead:getZone('武器')):count())
    lt.assertEquals('判定区清空', 0, assert(dead:getZone('判定')):count())
    lt.assertEquals('三张都进了弃牌堆', before + 3, assert(run.game:getZone('弃牌')):count())
end)

lt.test('阵亡清算：没有牌的死者也不出错', function ()
    local run  = support.start { count = 2, packages = { '标准' } }
    local dead = run.players[2]
    local before = assert(run.game:getZone('弃牌')):count()

    dead:setAlive(false)

    lt.assertEquals('弃牌堆没变', before, assert(run.game:getZone('弃牌')):count())
end)

lt.test('阵亡清算：死者身上的技能被禁用（牌离区也不再响应）', function ()
    local guard <close> = useProbe([[
Skill '记账'
    : event('卡牌-离开区域', function ()
        game:setValue('离开次数', (game:getValue('离开次数') or 0) + 1)
    end)
]])
    local run = support.start {
        count    = 2,
        packages = { '标准', '探针' },
        sources  = { './package/*', probeDir:string() .. '/*' },
        beforeStart = function (game, players)
            players[2]:addSkill('记账')
        end,
    }
    local dead = run.players[2]
    run.game:moveCard(putCard(run, '杀'), assert(dead:getZone('手牌')))

    local before = run.game:getValue('离开次数') or 0
    dead:setAlive(false)

    lt.assertEquals('清算时技能一次都没响应', before, run.game:getValue('离开次数') or 0)
    lt.assertEquals('牌照旧清了', 0, assert(dead:getZone('手牌')):count())
end)

lt.test('对照：活着的时候失去手牌，技能会响应', function ()
    local guard <close> = useProbe([[
Skill '记账'
    : event('卡牌-离开区域', function ()
        game:setValue('离开次数', (game:getValue('离开次数') or 0) + 1)
    end)
]])
    local run = support.start {
        count    = 2,
        packages = { '标准', '探针' },
        sources  = { './package/*', probeDir:string() .. '/*' },
        beforeStart = function (game, players)
            players[2]:addSkill('记账')
        end,
    }
    local alive = run.players[2]
    local card  = putCard(run, '杀')
    run.game:moveCard(card, assert(alive:getZone('手牌')))

    run.game:moveCard(card, '弃牌')

    lt.assertEquals('活着的角色照旧响应', 1, run.game:getValue('离开次数') or 0)
end)

lt.test('阵亡清算与奖惩：杀反贼 ⇒ 凶手摸三张，死者的牌照清', function ()
    local run    = support.start {
        count    = 2,
        packages = { '身份场', '标准' },
        prepare  = {
            identities = { [1] = '主公', [2] = '反贼' },
        },
    }
    local killer = run.players[1]
    local victim = run.players[2]

    run.game:moveCard(putCard(run, '杀'), assert(victim:getZone('手牌')))
    run.game:moveCard(putCard(run, '青龙偃月刀'), assert(victim:getZone('武器')))
    local handBefore = assert(killer:getZone('手牌')):count()

    run.game:damage(killer, victim, 5)

    lt.assertEquals('反贼阵亡', false, victim:isAlive())
    lt.assertEquals('死者的手牌清了', 0, assert(victim:getZone('手牌')):count())
    lt.assertEquals('死者的装备也清了', 0, assert(victim:getZone('武器')):count())
    lt.assertEquals('凶手照旧摸三张', handBefore + 3, assert(killer:getZone('手牌')):count())
end)
