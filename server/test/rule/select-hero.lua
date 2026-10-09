local fs      = require 'bee.filesystem'
local lt      = require 'test.ltest'
local support = require 'test.rule.support'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'select-hero-probe'

---@type table<integer, 身份场.身份> # 4 人局固定的一套身份（用例里常要）
local IDENTITIES = {
    [1] = '主公',
    [2] = '反贼',
    [3] = '忠臣',
    [4] = '内奸',
}

---@param content string
local function useProbe(content)
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    local file = probeDir / '探针' / '武将.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), content)
    assert(ok, err)
end

--- 把每次「武将-询问」记下来；`answer` 为真就替他答第一张候选，为假就不表态（走服务器兜底）
---@param game Game
---@param asked AskHero[]
---@param answer boolean
local function record(game, asked, answer)
    game:on('武将-询问', function (askHero)
        asked[#asked + 1] = askHero
        if not answer then
            return
        end
        return assert(askHero.options)[1]
    end)
end

--- 被问的座位号（按被问顺序）
---@param asked AskHero[]
---@param desk Desk
---@return string
local function seatsOf(asked, desk)
    ---@type string[]
    local seats = {}
    for _, askHero in ipairs(asked) do
        seats[#seats + 1] = tostring(assert(desk:getIndex(assert(askHero.to))))
    end
    return table.concat(seats, ',')
end

lt.test('选将：config 点名了身份与武将 ⇒ 不问也不再随机', function ()
    ---@type AskHero[]
    local asked = {}
    local run = support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        beforeStart = function (game)
            record(game, asked, true)
        end,
        prepare = {
            identities = IDENTITIES,
            heroes     = { [1] = '曹操', [2] = '关羽', [3] = '张飞', [4] = '吕布' },
        },
    }

    lt.assertEquals('一次都没问', 0, #asked)
    lt.assertEquals('1 号位是主公', '主公', run.players[1].identity)
    lt.assertEquals('4 号位是内奸', '内奸', run.players[4].identity)
    lt.assertEquals('武将是点名的那张', '曹操', assert(run.players[1].hero).name)
    lt.assertEquals('四家都装上了武将', true,
        run.players[1].hero ~= nil and run.players[2].hero ~= nil
        and run.players[3].hero ~= nil and run.players[4].hero ~= nil)
end)

lt.test('选将：只给身份 ⇒ 武将照问（候选摆在询问上）', function ()
    ---@type AskHero[]
    local asked = {}
    local run = support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        beforeStart = function (game)
            record(game, asked, true)
        end,
        prepare = { identities = IDENTITIES },
    }

    lt.assertEquals('四家各问一次', 4, #asked)
    lt.assertEquals('主公的备选 = 3 张君主 + 5 张其他', 8, #assert(asked[1].options))
    lt.assertEquals('其余人 5 张', 5, #assert(asked[2].options))
    lt.assertEquals('四家都装上了武将', true,
        run.players[1].hero ~= nil and run.players[2].hero ~= nil
        and run.players[3].hero ~= nil and run.players[4].hero ~= nil)
end)

lt.test('选将：主公先选，然后按座位依次', function ()
    ---@type AskHero[]
    local asked = {}
    local run = support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        beforeStart = function (game)
            record(game, asked, true)
        end,
        prepare = { identities = IDENTITIES },
    }

    lt.assertEquals('1,2,3,4', '1,2,3,4', seatsOf(asked, run.desk))
end)

lt.test('选将：选走的不再出现（互斥）', function ()
    ---@type AskHero[]
    local asked = {}
    support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        beforeStart = function (game)
            record(game, asked, true)
        end,
        prepare = { identities = IDENTITIES },
    }

    for index, askHero in ipairs(asked) do
        local chosen = assert(askHero.options)[1]
        for later = index + 1, #asked do
            lt.assertEquals('选走的后面不再出现', false,
                moe.util.arrayHas(assert(asked[later].options), chosen))
        end
    end
end)

lt.test('选将：没人答 ⇒ 服务器替他拿第一张候选', function ()
    ---@type AskHero[]
    local asked = {}
    support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        beforeStart = function (game)
            record(game, asked, false)
        end,
        prepare = { identities = IDENTITIES },
    }

    lt.assertEquals('四家照问', 4, #asked)
    for _, askHero in ipairs(asked) do
        local player = assert(askHero.to)
        lt.assertEquals('拿的是第一张候选', assert(askHero.options)[1], assert(player.hero))
    end
end)

lt.test('选将：只给武将 ⇒ 身份照随机（主公仍坐 1 号位）', function ()
    ---@type AskHero[]
    local asked = {}
    local run = support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        beforeStart = function (game)
            record(game, asked, true)
        end,
        prepare = { heroes = { [1] = '曹操', [2] = '关羽', [3] = '张飞', [4] = '吕布' } },
    }

    lt.assertEquals('没人被问', 0, #asked)
    lt.assertEquals('主公坐 1 号位', '主公', run.players[1].identity)

    ---@type table<string, true>
    local seen = {}
    for _, player in ipairs(run.players) do
        local identity = assert(player.identity, '每个人都该有身份')
        seen[identity] = true
    end
    local distinct = 0
    for _ in pairs(seen) do
        distinct = distinct + 1
    end
    lt.assertEquals('四个身份各不相同', 4, distinct)
end)

lt.test('选将：武将不够就少亮', function ()
    useProbe([[
rule.cardTable = {}

Hero '甲'
Hero '乙'
Hero '丙'
Hero '丁'
]])
    ---@type AskHero[]
    local asked = {}
    support.start {
        count    = 4,
        packages = { '身份场', '探针' },
        sources  = { './package/*', probeDir:string() .. '/*' },
        beforeStart = function (game)
            record(game, asked, true)
        end,
        prepare = { identities = IDENTITIES },
    }

    lt.assertEquals('主公：0 张君主 + 4 张其他', 4, #assert(asked[1].options))
    lt.assertEquals('第二家剩 3 张', 3, #assert(asked[2].options))
    lt.assertEquals('第三家剩 2 张', 2, #assert(asked[3].options))
    lt.assertEquals('第四家剩 1 张', 1, #assert(asked[4].options))
end)

lt.test('身份：主公公开、自己的看得见、别人的看不见', function ()
    local run   = support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        prepare  = { identities = IDENTITIES },
    }
    local lord  = run.players[1]
    local other = run.players[2]

    lt.assertEquals('主公对谁都可见', true, lord:isIdentityVisibleTo(other))
    lt.assertEquals('自己的身份自己看得见', true, other:isIdentityVisibleTo(other))
    lt.assertEquals('别人的身份看不见', false, other:isIdentityVisibleTo(run.players[3]))
end)

lt.test('开局：身份给全了就不校验配置（全是主公也接受）', function ()
    local run = support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        prepare  = {
            identities = { '主公', '主公', '主公', '主公' },
            skipSelect = true,
        },
    }

    for i = 1, 4 do
        lt.assertEquals('第 ' .. i .. ' 个也是主公', '主公', run.players[i].identity)
    end
end)

lt.test('开局：身份给不全 ⇒ 报错（要么不给、要么给全）', function ()
    lt.expectErrors(1)
    local run = support.start {
        count    = 4,
        packages = { '身份场', '标准' },
        prepare  = {
            identities = { [1] = '主公', [2] = '反贼' },
            skipSelect = true,
        },
    }

    lt.assertEquals('给了的照给', '主公', run.players[1].identity)
    lt.assertEquals('没给的还是空', nil, run.players[3].identity)
end)

lt.test('坐次：没给就洗一遍，主公仍在 1 号位', function ()
    ---@type AskHero[]
    local asked = {}
    ---@type 身份场.准备配置
    local prepare = {
        identities = { [1] = '反贼', [2] = '内奸', [3] = '忠臣', [4] = '主公' },
        skipSelect = true,
    }
    local run = support.start {
        count       = 4,
        packages    = { '身份场', '标准' },
        beforeStart = function (game)
            record(game, asked, true)
        end,
        prepare = prepare,
    }

    lt.assertEquals('主公换到了 1 号位', '主公', assert(run.desk:getPlayer(1)).identity)
    lt.assertEquals('洗过牌：2、3 号位上的人都换过位', false, run.desk:getIndex(run.players[2]) == 2 and run.desk:getIndex(run.players[3]) == 3)
    for i = 1, 4 do
        lt.assertEquals('第 ' .. i .. ' 位有人', true, run.desk:getPlayer(i) ~= nil)
        lt.assertEquals('身份跟着玩家走', prepare.identities[i], run.players[i].identity)
    end
end)

lt.test('坐次：传了列表就照它排', function ()
    ---@type 身份场.准备配置
    local prepare = { skipSelect = true }
    local run = support.start {
        count       = 4,
        packages    = { '身份场', '标准' },
        beforeStart = function (game, players)
            prepare.seats = { players[4], players[3], players[2], players[1] }
        end,
        prepare = prepare,
    }

    lt.assertEquals('1 号位是原来的 4 号', run.players[4], run.desk:getPlayer(1))
    lt.assertEquals('4 号位是原来的 1 号', run.players[1], run.desk:getPlayer(4))
end)

lt.test('坐次：同时传身份与坐次 ⇒ 主公不必在 1 号位', function ()
    ---@type 身份场.准备配置
    local prepare = {
        identities = { '反贼', '主公', '忠臣', '内奸' },
        skipSelect = true,
    }
    local run = support.start {
        count       = 4,
        packages    = { '身份场', '标准' },
        beforeStart = function (game, players)
            prepare.seats = { players[1], players[2], players[3], players[4] }
        end,
        prepare = prepare,
    }

    lt.assertEquals('1 号位不是主公', false, assert(run.desk:getPlayer(1)).identity == '主公')
    lt.assertEquals('2 号位是主公', '主公', assert(run.desk:getPlayer(2)).identity)
end)

lt.test('选将：主公先选（主公不在 1 号位也先问他）', function ()
    ---@type AskHero[]
    local asked = {}
    ---@type 身份场.准备配置
    local prepare = { identities = { '反贼', '主公', '忠臣', '内奸' } }
    local run = support.start {
        count       = 4,
        packages    = { '身份场', '标准' },
        beforeStart = function (game, players)
            prepare.seats = { players[1], players[2], players[3], players[4] }
            record(game, asked, true)
        end,
        prepare = prepare,
    }

    lt.assertEquals('第一个被问的是主公（坐 2 号位）', run.players[2], assert(asked[1].to))
    lt.assertEquals('然后按座位依次', '2,1,3,4', seatsOf(asked, run.desk))
end)
