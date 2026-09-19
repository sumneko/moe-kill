---@class Core.Random
---@field private state integer[]
local M = Class 'Core.Random'

local GOLDEN = 0x9E3779B97F4A7C15
local MIX_A  = 0xBF58476D1CE4E5B9
local MIX_B  = 0x94D049BB133111EB

---@param x integer
---@param n integer
---@return integer
local function rotl(x, n)
    return (x << n) | (x >> (64 - n))
end

---@param z integer
---@return integer
local function mix(z)
    local t = (z ~ (z >> 30)) * MIX_A
    t = (t ~ (t >> 27)) * MIX_B
    return t ~ (t >> 31)
end

---@param state integer[]
---@return integer
local function draw(state)
    local value = rotl(state[2] * 5, 7) * 9
    local shift = state[2] << 17
    state[3] = state[3] ~ state[1]
    state[4] = state[4] ~ state[2]
    state[2] = state[2] ~ state[3]
    state[1] = state[1] ~ state[4]
    state[3] = state[3] ~ shift
    state[4] = rotl(state[4], 45)
    return value
end

---@param seed integer
function M:__init(seed)
    assert(math.type(seed) == 'integer', '随机源的种子必须是整数')
    local state = {}
    for i = 1, 4 do
        state[i] = mix(seed + i * GOLDEN)
    end
    self.state = state
end

---@param seed integer
---@return Core.Random
function M.create(seed)
    return New 'Core.Random' (seed)
end

---@param min integer
---@param max integer
---@return integer
function M:nextInt(min, max)
    assert(math.type(min) == 'integer'
        and math.type(max) == 'integer',
        '随机范围的两端必须是整数')
    assert(min <= max, '随机范围的下界不能大于上界')
    local span = max - min + 1
    if span == 1 then
        return min
    end
    local state = self.state
    local mask  = span - 1
    mask = mask | (mask >> 1)
    mask = mask | (mask >> 2)
    mask = mask | (mask >> 4)
    mask = mask | (mask >> 8)
    mask = mask | (mask >> 16)
    mask = mask | (mask >> 32)
    local value
    repeat
        value = draw(state) & mask
    until value < span
    return min + value
end

---@generic T
---@param list T[]
---@return T
function M:pick(list)
    assert(#list > 0, '不能从空序列中取元素')
    return list[self:nextInt(1, #list)]
end

---@generic T
---@param list T[]
---@return T[]
function M:shuffle(list)
    for i = #list, 2, -1 do
        local j = self:nextInt(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

return M
