local JSON_ESCAPE = {
    ['"']  = '\\"',
    ['\\'] = '\\\\',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
}

--- 是不是从 1 连续到底的数组（空表不算）
---@param value table
---@return boolean
local function isArray(value)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' then
            return false
        end
        count = count + 1
    end
    return count > 0 and count == #value
end

--- 把值编成 JSON（只认 JSON 能表达的：字符串 / 数字 / 布尔 / 数组 / 表）
---@param value any
---@return string
local function encodeJson(value)
    local kind = type(value)
    if kind == 'string' then
        return '"' .. value:gsub('[%c\\"]', function (char)
            return JSON_ESCAPE[char] or '\\u%04x' % { char:byte() }
        end) .. '"'
    end
    if kind == 'number' or kind == 'boolean' then
        return tostring(value)
    end
    if kind ~= 'table' then
        error('参数表里只能放 JSON 能表达的值，给的是 ' .. kind, 3)
    end
    local parts = {}
    if isArray(value) then
        for i = 1, #value do
            parts[i] = encodeJson(value[i])
        end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    for key, item in pairs(value) do
        parts[#parts + 1] = encodeJson(tostring(key)) .. ':' .. encodeJson(item)
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

---@diagnostic disable-next-line: lowercase-global
util = {}

--- 拿一个 `<close>` 收尾对象：作用域一结束（正常、出错、提前 return 都算）就跑回调
---@param callback fun()
---@return table
function util.defer(callback)
    return setmetatable({ callback }, { __close = function (self) self[1]() end })
end

--- 本地化文本：占位写 `{键}` / `{键#类型}`；给了参数就拼成「模板@参数表」，没给就是纯文本
---@param text string
---@param params? table
---@return string
function util.locale(text, params)
    if not params or next(params) == nil then
        return text
    end
    return '${locale:' .. text .. '}@' .. encodeJson(params)
end
