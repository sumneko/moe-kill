local lt      = require 'test.ltest'
local support = require 'test.transport.tcp-support'

lt.test('TCP 链路：写过去对面收得到', function ()
    local fd, dialer = support.connectPair()
    local link = moe.link.tcp(fd)
    local _ <close> = moe.util.defer(function () link:close() end)

    lt.assertEquals('发得出去', true, link:write '你好')
    lt.assertEquals('对面收到了', '你好', support.spin(function () return dialer:recv() end))
end)

lt.test('TCP 链路：要几个字节就等几个字节（半包 / 粘包都接得住）', function ()
    local fd, dialer = support.connectPair()
    local link = moe.link.tcp(fd)
    local _ <close> = moe.util.defer(function () link:close() end)

    support.spin(function () return dialer:send 'ab' end)
    lt.assertEquals('先读两个', 'ab', link:read(2))

    support.spin(function () return dialer:send 'cde' end)
    lt.assertEquals('一次来的先取一个', 'c', link:read(1))
    lt.assertEquals('剩下的还在缓冲里', 'de', link:read(2))
end)

lt.test('TCP 链路：一边发一边收（读写各自挂起，互不挡）', function ()
    local fd, dialer = support.connectPair()
    local link = moe.link.tcp(fd)
    local _ <close> = moe.util.defer(function ()
        link:close()
        dialer:close()
    end)

    local text = string.rep('牌', 40000)
    local got = ''
    moe.await.call(function ()
        while #got < #text do
            local chunk = support.spin(function () return dialer:recv() end)
            if not chunk then
                return
            end
            got = got .. chunk
        end
    end)
    support.spin(function () return link:write(text) end)
    support.spin(function () return #got >= #text end)
    lt.assertEquals('对面收全了', #text, #got)
end)

lt.test('TCP 链路：对面关掉 ⇒ 读给空 + 原因', function ()
    local fd, dialer = support.connectPair()
    local link = moe.link.tcp(fd)
    local _ <close> = moe.util.defer(function () link:close() end)

    dialer:close()
    local text, err = link:read(1)
    lt.assertEquals('读不到东西', nil, text)
    lt.assertNotEquals('给了原因', nil, err)
end)
