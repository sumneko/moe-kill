---@class Args
---@field [string] Args.Value
---@field TEST? true | string
---@field DEVELOP? boolean
---@field DBGADDRESS? string
---@field DBGPORT? integer | string
---@field DBG_PORT? integer | string
---@field DBGWAIT? boolean
---@field LOGPATH? string
---@field LOGLEVEL? string
---@field ROOT? string
---@field MEM_LIMIT? integer
local m = {}

---@alias Args.Value string | number | boolean

---@param value string
---@return Args.Value
local function parseValue(value)
    if value == 'true' or value == '' then
        return true
    end
    if value == 'false' then
        return false
    end
    local num = tonumber(value)
    if num then
        return num
    end
    if value:sub(1, 1) == '"' and value:sub(-1, -1) == '"' then
        return value:sub(2, -2)
    end
    return value
end

---@param key string
---@return string
local function normalizeKey(key)
    local upper = key:upper():gsub('-', '_')
    return upper
end

---@param argv string[]
---@return Args
function m.parse(argv)
    local result = {}

    local i = 1
    while argv[i] do
        local argvI = argv[i]
        local key, tail = argvI:match '^%-%-([%w_%-]+)(.*)$'
        if not key then
            i = i + 1
        else
            local name = normalizeKey(key)
            local value = tail:match '^=(.*)$'
            if value then
                result[name] = parseValue(value)
                i = i + 1
            else
                local nextArg = argv[i + 1]
                if nextArg and nextArg:sub(1, 1) ~= '-' then
                    result[name] = parseValue(nextArg)
                    i = i + 2
                else
                    result[name] = true
                    i = i + 1
                end
            end
        end
    end

    return result
end

---@param argv string[]
---@return Args
function m.current(argv)
    local result = m.parse(argv or arg)
    result.DBGADDRESS = result.DBGADDRESS or '127.0.0.1'
    result.DBGPORT    = result.DBGPORT or 11418
    return result
end

return m
