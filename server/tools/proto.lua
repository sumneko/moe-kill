--- 协议声明（`proto.d.lua`）的解析与形状翻译：声明是唯一真相源，要校验的形状都从这儿推

--- 声明里的一个字段
---@class Proto.Field
---@field name string # 字段名
---@field type string # 类型写法（原文）
---@field optional boolean # 声明里带 `?`
---@field comment string # `#` 后的说明（没有就是空串）

--- 声明里的一个类
---@class Proto.Class
---@field name string # 类名
---@field bases string[] # 基类名
---@field fields Proto.Field[] # 自己声明的字段（不含继承来的）
---@field comment string # 类上方的说明（没有就是空串）

---@class Proto.API
moe.proto = {}

--- 解析类型写法时的游标
---@class Proto.Scanner
---@field text string # 整段类型写法
---@field pos integer # 下一个字符的位置

--- 解析出来的类（懒解析一次 —— 跑起来之后声明文件不会变）
---@type table<string, Proto.Class>?
moe.proto._classes = nil

--- 翻好的形状（按类名缓存）
---@type table<string, Shape>?
moe.proto._shapes = nil

--- 声明文件（就在服务端目录下）
local DECLARATION = 'proto.d.lua'

--- 认得的叶子类型（不在这里的名字都当类名去查）
local LEAF_TYPES = {
    integer = true,
    number  = true,
    string  = true,
    boolean = true,
    table   = true,
    any     = true,
}

--- 去掉两头空白
---@param text string
---@return string
local function trim(text)
    return (text:gsub('^%s*(.-)%s*$', '%1'))
end

--- 解析声明文本（纯函数：给文本，给类表）
---@param text string
---@return table<string, Proto.Class>
function moe.proto.parse(text)
    ---@type table<string, Proto.Class>
    local classes = {}
    ---@type string[] # 紧挨着的说明行
    local comment = {}
    ---@type Proto.Class?
    local current = nil
    for rawLine in text:gmatch('[^\n]+') do
        local body = rawLine:gsub('\r$', ''):match('^%-%-%-%s?(.*)$')
        if not body then
            comment = {}
        else
            local classText = body:match('^@class%s+(.+)$')
            local fieldText = body:match('^@field%s+(.+)$')
            if classText then
                local name, bases = classText:match('^([^:%s]+)%s*:%s*(.+)$')
                ---@type string[]
                local baseList = {}
                if name then
                    for one in bases:gmatch('[^,]+') do
                        baseList[#baseList + 1] = trim(one)
                    end
                else
                    name = trim(classText)
                end
                ---@type Proto.Class
                local declared = {
                    name    = name,
                    bases   = baseList,
                    fields  = {},
                    comment = table.concat(comment, '\n'),
                }
                classes[name] = declared
                current = declared
                comment = {}
            elseif fieldText then
                local rawName, rest = fieldText:match('^([%w_%.%?]+)%s+(.+)$')
                if not rawName then
                    error('认不出的字段声明：' .. rawLine)
                end
                if not current then
                    error('字段声明前面没有类：' .. rawLine)
                end
                local optional = rawName:sub(-1) == '?'
                local typeText, note = rest:match('^(.-)%s*#%s*(.*)$')
                if not typeText then
                    typeText = rest
                    note = ''
                end
                current.fields[#current.fields + 1] = {
                    name     = optional and rawName:sub(1, -2) or rawName,
                    type     = trim(typeText),
                    optional = optional,
                    comment  = trim(note),
                }
            else
                comment[#comment + 1] = trim(body)
            end
        end
    end
    return classes
end

--- 往前跳过空白
---@param state Proto.Scanner
local function skipSpace(state)
    local _, stop = state.text:find('^%s*', state.pos)
    state.pos = stop + 1
end

--- 读一个名字（类名或叶子类型名）
---@param state Proto.Scanner
---@return string
local function takeName(state)
    local name, stop = state.text:match('^([%w_%.]+)()', state.pos)
    if not name then
        error('认不出的类型写法：「' .. state.text:sub(state.pos) .. '」')
    end
    state.pos = stop
    return name
end

---@type fun(state: Proto.Scanner): table
local parseType

--- 解析一个基本类型：内联结构 / 字面量 / 名字
---@param state Proto.Scanner
---@return table
local function parsePrimary(state)
    skipSpace(state)
    local char = state.text:sub(state.pos, state.pos)
    if char == '{' then
        state.pos = state.pos + 1
        ---@type table[]
        local fields = {}
        while true do
            skipSpace(state)
            if state.text:sub(state.pos, state.pos) == '}' then
                state.pos = state.pos + 1
                return { kind = 'struct', fields = fields }
            end
            local rawName, stop = state.text:match('^([%w_%.%?]+)%s*:%s*()', state.pos)
            if not rawName then
                error('认不出的内联结构：「' .. state.text:sub(state.pos) .. '」')
            end
            state.pos = stop
            local optional = rawName:sub(-1) == '?'
            fields[#fields + 1] = {
                name     = optional and rawName:sub(1, -2) or rawName,
                optional = optional,
                type     = parseType(state),
            }
            skipSpace(state)
            if state.text:sub(state.pos, state.pos) == ',' then
                state.pos = state.pos + 1
            end
        end
    end
    if char == "'" then
        local literal, stop = state.text:match("^'(.-)'()", state.pos)
        if not literal then
            error('认不出的字面量：「' .. state.text:sub(state.pos) .. '」')
        end
        state.pos = stop
        return { kind = 'literal', text = literal }
    end
    local number, numberStop = state.text:match('^(%-?%d+%.?%d*)()', state.pos)
    if number then
        state.pos = numberStop
        return { kind = 'literal', text = number, number = true }
    end
    return { kind = 'name', name = takeName(state) }
end

--- 解析后缀：`[]` 数组、`?` 可选
---@param state Proto.Scanner
---@return table
local function parseSuffix(state)
    local node = parsePrimary(state)
    while true do
        skipSpace(state)
        if state.text:sub(state.pos, state.pos + 1) == '[]' then
            state.pos = state.pos + 2
            node = { kind = 'list', inner = node }
        elseif state.text:sub(state.pos, state.pos) == '?' then
            state.pos = state.pos + 1
            node = { kind = 'optional', inner = node }
        else
            return node
        end
    end
end

--- 解析一个类型表达式（含 `a | b` 联合）
---@param state Proto.Scanner
---@return table
parseType = function (state)
    local members = { parseSuffix(state) }
    while true do
        skipSpace(state)
        if state.text:sub(state.pos, state.pos) ~= '|' then
            break
        end
        state.pos = state.pos + 1
        members[#members + 1] = parseSuffix(state)
    end
    if #members == 1 then
        return members[1]
    end
    return { kind = 'union', members = members }
end

--- 某个类的全部字段（含继承来的，基类在前）
---@param classes table<string, Proto.Class>
---@param name string
---@param stack? table<string, true>
---@return Proto.Field[]
local function fieldsOf(classes, name, stack)
    local class = classes[name]
    if not class then
        error('声明里没有类「' .. name .. '」')
    end
    stack = stack or {}
    if stack[name] then
        error('类「' .. name .. '」的继承成了环')
    end
    stack[name] = true
    local out = {}
    for _, baseName in ipairs(class.bases) do
        if not classes[baseName] then
            error('类「' .. name .. '」的基类「' .. baseName .. '」没声明')
        end
        for _, field in ipairs(fieldsOf(classes, baseName, stack)) do
            out[#out + 1] = field
        end
    end
    for _, field in ipairs(class.fields) do
        out[#out + 1] = field
    end
    stack[name] = nil
    return out
end

--- 可选就套一层（叶子拼成 `?`，结构用可选标记）
---@param shaped Shape
---@param optional boolean
---@return Shape
local function optionalShape(shaped, optional)
    if not optional then
        return shaped
    end
    if type(shaped) == 'string' then
        return shaped .. '?'
    end
    return moe.shape.optional(shaped)
end

--- 类型 AST 翻成形状（类引用就地展开，展开时防自己套自己）
---@param classes table<string, Proto.Class>
---@param node table
---@param stack table<string, true>
---@return Shape
local function astShape(classes, node, stack)
    if node.kind == 'optional' then
        return optionalShape(astShape(classes, node.inner, stack), true)
    end
    if node.kind == 'list' then
        local inner = astShape(classes, node.inner, stack)
        if type(inner) == 'string' then
            return inner .. '[]'
        end
        return moe.shape.array(inner)
    end
    if node.kind == 'struct' then
        local shaped = {}
        for _, field in ipairs(node.fields) do
            shaped[field.name] = optionalShape(astShape(classes, field.type, stack), field.optional)
        end
        return shaped
    end
    if node.kind == 'literal' then
        if node.number then
            return 'number'
        end
        return 'string'
    end
    if node.kind == 'union' then
        ---@type string
        local leaf = ''
        for _, one in ipairs(node.members) do
            if one.kind ~= 'literal' then
                error('声明里有认不出的联合类型（目前只支持字面量）')
            end
            local this = one.number and 'number' or 'string'
            if leaf ~= '' and leaf ~= this then
                error('声明里的联合把字符串和数字混在一起了')
            end
            leaf = this
        end
        return leaf
    end
    if LEAF_TYPES[node.name] then
        return node.name
    end
    if not classes[node.name] then
        error('声明里没有类「' .. node.name .. '」')
    end
    if stack[node.name] then
        error('类「' .. node.name .. '」自己套自己，翻不出形状')
    end
    stack[node.name] = true
    local shaped = {}
    for _, field in ipairs(fieldsOf(classes, node.name)) do
        shaped[field.name] = optionalShape(astShape(classes, parseType { text = field.type, pos = 1 }, stack), field.optional)
    end
    stack[node.name] = nil
    return shaped
end

--- 类型写法（原文）翻成形状
---@param classes table<string, Proto.Class>
---@param text string
---@return Shape
local function typeShape(classes, text)
    local state = { text = text, pos = 1 }
    local node = parseType(state)
    skipSpace(state)
    if state.pos <= #state.text then
        error('认不出的类型写法：「' .. text .. '」')
    end
    return astShape(classes, node, {})
end

--- 解析 `proto.d.lua`（读一次，之后用缓存）
---@return table<string, Proto.Class>
function moe.proto.classes()
    local classes = moe.proto._classes
    if not classes then
        local path = (moe.env.ROOT_PATH / DECLARATION):string()
        local text, err = moe.fsu.loadFile(path)
        if not text then
            error('读不到协议声明「' .. path .. '」：' .. tostring(err))
        end
        classes = moe.proto.parse(text)
        moe.proto._classes = classes
    end
    return classes
end

--- 某个类翻成的形状（声明里没有这个类就给空）
---@param name string
---@return Shape?
function moe.proto.shape(name)
    local shapes = moe.proto._shapes
    if not shapes then
        shapes = {}
        moe.proto._shapes = shapes
    end
    local cached = shapes[name]
    if cached ~= nil then
        return cached
    end
    local classes = moe.proto.classes()
    if not classes[name] then
        return nil
    end
    local shaped = typeShape(classes, name)
    shapes[name] = shaped
    return shaped
end

return moe.proto
