local fs = require 'bee.filesystem'
local lt = require 'test.ltest'

local probeDir = moe.env.ROOT_PATH / 'tmp' / 'card-passive-probe'

local probeSource = [[
Card '被动牌'
    : on('被动', function (card, zone, host)
        game:setValue('应用', (game:getValue('应用') or 0) + 1)
        host:bindGC(function ()
            game:setValue('撤销', (game:getValue('撤销') or 0) + 1)
        end)
    end)
Card '记位置'
    : on('被动', function (card, zone)
        game:setValue('记下的牌', card)
        game:setValue('记下的区', zone)
    end)
Card '挂两份'
    : on('被动', function (card, zone, host)
        host:bindGC(function ()
            game:setValue('第一份', (game:getValue('第一份') or 0) + 1)
        end)
        host:bindGC(function ()
            game:setValue('第二份', (game:getValue('第二份') or 0) + 1)
        end)
    end)
Card '无撤销'
    : on('被动', function (card, zone)
        game:setValue('无撤销应用', (game:getValue('无撤销应用') or 0) + 1)
    end)
]]

---@return unknown # 配 <close> 用
local function useProbe()
    fs.remove_all(probeDir)
    fs.create_directories(probeDir)
    return moe.util.defer(function ()
        fs.remove_all(probeDir)
    end)
end

---@return Game
local function newGame()
    local file = probeDir / '探针' / '牌.lua'
    fs.create_directories(file:parent_path())
    local ok, err = moe.util.saveFile(file:string(), probeSource)
    assert(ok, err)
    return moe.game.create {
        seats    = 2,
        random   = moe.random.create(1),
        sources  = { probeDir:string() .. '/*' },
        packages = { '探针' },
    }
end

lt.test('牌：标识与牌名都由调用方给出', function ()
    local card = moe.card.create(lt.game(), '杀', 7)

    lt.assertEquals('标识就是给进来的号', 7, card:getId())
    lt.assertEquals('牌名就是给进来的那个值', '杀', card.name)

    local other = moe.card.create(lt.game(), '闪', 8)
    lt.assertEquals('两张牌各自用各自的号', false, card:getId() == other:getId())
end)

lt.test('牌：没给牌名建不出来', function ()
    lt.assertError('空牌名直接报错', function ()
        moe.card.create(lt.game(), '', 9)
    end)
end)

lt.test('牌：内核不解释牌名与牌面，只搬运内容给的取值', function ()
    local card = lt.card('杀')
    local keys = {}

    for key in pairs(card) do
        if type(key) == 'string' and key:sub(1, 2) ~= '__' then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    lt.assertEquals('没给牌面时的字段就是这几样', 'def,game,id,name,passiveSuppress,subcards,virtual', table.concat(keys, ','))

    ---@type any
    local raw = card
    lt.assertEquals('没有名称字段', nil, raw['名称'])
    lt.assertEquals('没有效果字段', nil, raw['效果'])
end)

lt.test('牌：花色与点数直接读字段', function ()
    local card = moe.card.create(lt.game(), '杀', 7, '黑桃', 9)

    lt.assertEquals('花色就是给进来的那个', '黑桃', card.suit)
    lt.assertEquals('点数就是给进来的那个', 9, card.point)

    local plain = moe.card.create(lt.game(), '闪', 8)
    lt.assertEquals('没给花色就是空', nil, plain.suit)
    lt.assertEquals('没给点数就是空', nil, plain.point)
end)

lt.test('牌：虚拟牌带标记、原始牌按创建时给的记下', function ()
    local game   = lt.game()
    local source = moe.card.create(game, '杀', 100, '黑桃', 9)
    local plain  = moe.card.create(game, '闪', 101)

    lt.assertEquals('普通牌不是虚拟牌', false, plain.virtual)
    lt.assertEquals('普通牌没有原始牌', 0, #plain.subcards)

    local virtual = game:createVirtualCard('闪', source)
    lt.assertEquals('标记为虚拟牌', true, virtual.virtual)
    lt.assertEquals('单张原始牌记在 subcards 里', source, virtual.subcards[1])
    lt.assertEquals('号由局发、与别的牌都不同', false, virtual:getId() == source:getId())
end)

lt.test('牌：虚拟牌的花色与点数默认从原始牌算', function ()
    local game   = lt.game()
    local source = moe.card.create(game, '杀', 100, '黑桃', 9)

    local single = game:createVirtualCard('闪', source)
    lt.assertEquals('一张原始牌：花色抄它', '黑桃', single.suit)
    lt.assertEquals('一张原始牌：点数抄它', 9, single.point)

    local none = game:createVirtualCard('闪')
    lt.assertEquals('没给原始牌：花色为空', nil, none.suit)
    lt.assertEquals('没给原始牌：点数为空', nil, none.point)
    lt.assertEquals('没给原始牌：subcards 空表', 0, #none.subcards)

    local other = moe.card.create(game, '杀', 101, '红桃', 3)
    local many  = game:createVirtualCard('闪', { source, other })
    lt.assertEquals('多张原始牌：花色为空', nil, many.suit)
    lt.assertEquals('多张原始牌：点数为空', nil, many.point)
    lt.assertEquals('两张都记着', 2, #many.subcards)
end)

lt.test('牌：虚拟牌的素材里不会套虚拟牌（解包成实体牌）', function ()
    local game   = lt.game()
    local first  = moe.card.create(game, '杀', 100, '黑桃', 9)
    local second = moe.card.create(game, '杀', 101, '红桃', 3)

    local inner = game:createVirtualCard('杀', { first, second })
    lt.assertEquals('内层虚拟牌带着两张实体', 2, #inner.subcards)

    local outer = game:createVirtualCard('闪', inner)
    lt.assertEquals('再套一层还是那两张实体', 2, #outer.subcards)
    lt.assertEquals('第一张是实体牌', first, outer.subcards[1])
    lt.assertEquals('第二张是实体牌', second, outer.subcards[2])
    lt.assertEquals('没有虚拟牌混进来', false, outer.subcards[1].virtual or outer.subcards[2].virtual)

    lt.assertEquals('牌面按解包后的实体算：两张 ⇒ 没有花色', nil, outer.suit)
    lt.assertEquals('牌面按解包后的实体算：两张 ⇒ 没有点数', nil, outer.point)
end)

lt.test('牌：颜色由花色当场算（红桃 / 方块 = 红，黑桃 / 梅花 = 黑）', function ()
    local game = lt.game()
    local heart   = moe.card.create(game, '闪', 110, '红桃', 2)
    local diamond = moe.card.create(game, '闪', 111, '方块', 3)
    local spade   = moe.card.create(game, '杀', 112, '黑桃', 4)
    local club    = moe.card.create(game, '杀', 113, '梅花', 5)

    lt.assertEquals('红桃是红', '红', heart.color)
    lt.assertEquals('方块是红', '红', diamond.color)
    lt.assertEquals('黑桃是黑', '黑', spade.color)
    lt.assertEquals('梅花是黑', '黑', club.color)

    local plain = moe.card.create(game, '闪', 114)
    lt.assertEquals('没有花色就没有颜色', nil, plain.color)

    local virtual = game:createVirtualCard('闪', heart)
    lt.assertEquals('抄了花色的虚拟牌颜色跟着算出来', '红', virtual.color)

    local none = game:createVirtualCard('闪')
    lt.assertEquals('没有花色的虚拟牌也没有颜色', nil, none.color)

    spade.suit = '红桃'
    lt.assertEquals('改了花色，颜色立刻跟着变（当场算）', '红', spade.color)
end)

lt.test('牌：被动出厂不生效，启用时才应用、停用时撤销', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('被动牌')
    game:getZone('弃牌'):accept(card)

    lt.assertEquals('没启用过：回调没跑', nil, game:getValue('应用'))

    card:enablePassive()
    lt.assertEquals('启用返回时就已经应用（同步）', 1, game:getValue('应用'))

    card:disablePassive()
    lt.assertEquals('停用后撤销被调了一次', 1, game:getValue('撤销'))

    card:enablePassive()
    lt.assertEquals('再启用会重新应用', 2, game:getValue('应用'))
end)

lt.test('牌：被动压制可叠加，逐层松开才恢复', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('被动牌')
    game:getZone('弃牌'):accept(card)

    card:enablePassive()
    card:disablePassive()
    card:disablePassive()
    lt.assertEquals('压了两层：效果已撤', 1, game:getValue('撤销'))

    card:enablePassive()
    lt.assertEquals('松开一层还没到 0：不恢复', 1, game:getValue('应用'))

    card:enablePassive()
    lt.assertEquals('松到 0：重新应用', 2, game:getValue('应用'))
end)

lt.test('牌：重复压制不会重复撤销', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('被动牌')
    game:getZone('弃牌'):accept(card)

    card:enablePassive()
    card:disablePassive()
    card:disablePassive()
    card:enablePassive()
    lt.assertEquals('撤销只发生过一次', 1, game:getValue('撤销'))
end)

lt.test('牌：启用与停用各返回一只精确的撤销函数', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('被动牌')
    game:getZone('弃牌'):accept(card)

    local undoEnable = card:enablePassive()
    undoEnable()
    lt.assertEquals('撤销这次松开 ⇒ 效果被撤', 1, game:getValue('撤销'))

    local undoDisable = card:disablePassive()
    undoDisable()
    lt.assertEquals('撤销这次压制时没有东西可应用', 1, game:getValue('应用'))

    card:enablePassive()
    lt.assertEquals('再松开才应用', 2, game:getValue('应用'))
end)

lt.test('牌：被动回调拿到牌与它所在的区', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('记位置')
    local zone = game:getZone('弃牌')
    zone:accept(card)

    card:enablePassive()
    lt.assertEquals('回调收到的就是这张牌', card, game:getValue('记下的牌'))
    lt.assertEquals('回调收到的是它所在的区', zone, game:getValue('记下的区'))
end)

lt.test('牌：被动回调什么都不挂也能启用停用', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('无撤销')
    game:getZone('弃牌'):accept(card)

    card:enablePassive()
    card:disablePassive()
    card:enablePassive()
    lt.assertEquals('停用时没东西可释放、也不报错；再启用照常应用', 2, game:getValue('无撤销应用'))
end)

lt.test('牌：一个被动挂两份资源，停用时都释放', function ()
    local guard <close> = useProbe()
    local game = newGame()
    local card = game:createCard('挂两份')
    game:getZone('弃牌'):accept(card)

    card:enablePassive()
    card:disablePassive()
    lt.assertEquals('第一份释放了', 1, game:getValue('第一份'))
    lt.assertEquals('第二份也释放了', 1, game:getValue('第二份'))
end)
