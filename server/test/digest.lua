--- C 模块 `bee.digest`：SHA1 与 base64（WebSocket 握手要用）

local lt     = require 'test.ltest'
local digest = require 'bee.digest'

--- 字节串转十六进制（好跟测试向量比对）
---@param text string
---@return string
local function hex(text)
    return (text:gsub('.', function (char)
        return string.format('%02x', char:byte())
    end))
end

lt.test('digest：sha1 对上 FIPS 180-1 的测试向量', function ()
    lt.assertEquals('三个字节', 'a9993e364706816aba3e25717850c26c9cd0d89d', hex(digest.sha1 'abc'))
    lt.assertEquals('五十六个字节', '84983e441c3bd26ebaae4aa1f95129e5e54670f1',
        hex(digest.sha1 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'))
    lt.assertEquals('中间那个分隔边界（55 / 56 / 64 字节都过一遍）', 20, #digest.sha1(string.rep('a', 64)))
    lt.assertEquals('空串也算得出', 'da39a3ee5e6b4b0d3255bfef95601890afd80709', hex(digest.sha1 ''))
end)

lt.test('digest：base64 对上 RFC 4648 的例子', function ()
    lt.assertEquals('空串', '', digest.base64 '')
    lt.assertEquals('一个字节', 'Zg==', digest.base64 'f')
    lt.assertEquals('两个字节', 'Zm8=', digest.base64 'fo')
    lt.assertEquals('三个字节', 'Zm9v', digest.base64 'foo')
    lt.assertEquals('四个字节', 'Zm9vYg==', digest.base64 'foob')
end)

lt.test('digest：WebSocket 握手那条链（RFC 6455 的例子）', function ()
    -- 客户端发一个 key，服务端回 base64(sha1(key .. 固定 GUID))，跟 RFC 里写的一字不差
    local key = 'dGhlIHNhbXBsZSBub25jZQ=='
    lt.assertEquals('跟 RFC 里写的一样', 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=',
        digest.base64(digest.sha1(key .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')))
end)
