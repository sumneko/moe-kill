/* 本工程自己的 C 模块都挂在这里（`make.lua` 的 moe-kill 把它当 sources） */
#include <bee/lua/module.h>

#include <cstdint>
#include <cstring>

#include "sha1.h"

namespace bee::lua_digest {
    /* base64 的字母表（RFC 4648） */
    constexpr char Base64Table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /* sha1(文本) ⇒ 20 字节 */
    static int l_sha1(lua_State* L) {
        size_t len = 0;
        const char* text = luaL_checklstring(L, 1, &len);
        unsigned char digest[20];
        SHA1(reinterpret_cast<char*>(digest), text, static_cast<uint32_t>(len));
        lua_pushlstring(L, reinterpret_cast<const char*>(digest), sizeof(digest));
        return 1;
    }

    /* base64(文本) ⇒ 文本 */
    static int l_base64(lua_State* L) {
        size_t len = 0;
        const unsigned char* text = reinterpret_cast<const unsigned char*>(luaL_checklstring(L, 1, &len));
        luaL_Buffer buf;
        luaL_buffinit(L, &buf);
        for (size_t i = 0; i < len; i += 3) {
            const uint32_t n = (static_cast<uint32_t>(text[i]) << 16)
                             | (i + 1 < len ? static_cast<uint32_t>(text[i + 1]) << 8 : 0)
                             | (i + 2 < len ? static_cast<uint32_t>(text[i + 2]) : 0);
            const char out[4] = {
                Base64Table[(n >> 18) & 0x3F],
                Base64Table[(n >> 12) & 0x3F],
                i + 1 < len ? Base64Table[(n >> 6) & 0x3F] : '=',
                i + 2 < len ? Base64Table[n & 0x3F] : '=',
            };
            luaL_addlstring(&buf, out, sizeof(out));
        }
        luaL_pushresult(&buf);
        return 1;
    }

    static int luaopen(lua_State* L) {
        luaL_Reg lib[] = {
            { "sha1", l_sha1 },
            { "base64", l_base64 },
            { NULL, NULL },
        };
        luaL_newlib(L, lib);
        return 1;
    }
}

DEFINE_LUAOPEN(digest)
