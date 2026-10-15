--- 协议类型的前端产物：从 `server/proto.d.lua` 的声明翻出 TypeScript（给 `client/` 用）

--- 产物落在前端工程里（相对仓库根）—— 进 git，改完声明要重跑
local OUTPUT = 'client/src/proto.d.ts'

--- 叶子类型名换成 TS 写法（不在这里的名字都当类名，原样写）
local LEAF = {
    integer = 'number',
    number  = 'number',
    string  = 'string',
    boolean = 'boolean',
    table   = 'unknown',
    any     = 'unknown',
}

--- 树上的一个节点：同一个名字可以既有自己的类、又有更深的命名空间（TS 的 interface 与 namespace 会合并）
---@class ProtoType.Node
---@field class? Proto.Class # 这个节点自己的类（可能没有）
---@field children table<string, ProtoType.Node> # 更深的命名空间

---@class ProtoType.API
moe.protoType = {}

---@param depth integer
---@return string
local function indentOf(depth)
    return string.rep('    ', depth)
end

--- 往下写一段 TS 注释
---@param comment string
---@param depth integer
---@param out string[]
local function pushComment(comment, depth, out)
    if comment == '' then
        return
    end
    local prefix = indentOf(depth)
    out[#out + 1] = prefix .. '/**'
    for line in comment:gmatch('[^\n]+') do
        out[#out + 1] = prefix .. ' * ' .. line
    end
    out[#out + 1] = prefix .. ' */'
end

---@type fun(name: string, optional: boolean, node: Proto.Node): string
local memberText

--- 一个类型节点翻成 TS 写法
---@param node Proto.Node
---@return string
local function typeText(node)
    local kind = node.kind
    if kind == 'name' then
        return LEAF[node.name] or node.name
    end
    if kind == 'literal' then
        if node.number then
            return node.text
        end
        return "'" .. node.text .. "'"
    end
    if kind == 'list' then
        local inner = node.inner
        local text  = typeText(inner)
        if inner.kind == 'union' or inner.kind == 'optional' then
            return '(' .. text .. ')[]'
        end
        return text .. '[]'
    end
    if kind == 'optional' then
        return typeText(node.inner) .. ' | null'
    end
    if kind == 'struct' then
        local parts = {}
        for _, field in ipairs(node.fields) do
            parts[#parts + 1] = memberText(field.name, field.optional, field.type)
        end
        return '{ ' .. table.concat(parts, '; ') .. ' }'
    end
    if kind == 'union' then
        local parts = {}
        for _, one in ipairs(node.members) do
            parts[#parts + 1] = typeText(one)
        end
        return table.concat(parts, ' | ')
    end
    error('认不出的类型节点：' .. tostring(kind))
end

--- 一个成员（字段 / 内联结构里的字段）的写法
---@param name string
---@param optional boolean
---@param node Proto.Node
---@return string
memberText = function (name, optional, node)
    if optional then
        name = name .. '?'
    end
    return name .. ': ' .. typeText(node)
end

---@return ProtoType.Node
local function newNode()
    return { children = {} }
end

---@param parent ProtoType.Node
---@param name string
---@return ProtoType.Node
local function childOf(parent, name)
    local child = parent.children[name]
    if not child then
        child = newNode()
        parent.children[name] = child
    end
    return child
end

--- 类名按点摊成一棵树（名字排过序，产物才稳定）
---@param classes table<string, Proto.Class>
---@return ProtoType.Node
local function buildTree(classes)
    local names = {}
    for name in pairs(classes) do
        names[#names + 1] = name
    end
    table.sort(names)
    local root = newNode()
    for _, name in ipairs(names) do
        local parts = {}
        for one in name:gmatch('[^.]+') do
            parts[#parts + 1] = one
        end
        local node = root
        for i = 1, #parts - 1 do
            node = childOf(node, parts[i])
        end
        childOf(node, parts[#parts]).class = classes[name]
    end
    return root
end

--- 写一个 interface（没字段也没下层的类当「一张自由表」）
---@param node ProtoType.Node
---@param name string
---@param depth integer
---@param out string[]
local function emitInterface(node, name, depth, out)
    local class = node.class
    ---@cast class Proto.Class
    local indent = indentOf(depth)
    pushComment(class.comment, depth, out)
    if #class.fields == 0
    and #class.bases == 0
    and next(node.children) == nil then
        out[#out + 1] = indent .. 'export type ' .. name .. ' = Record<string, unknown>;'
        return
    end
    local head = indent .. 'export interface ' .. name
    if #class.bases > 0 then
        head = head .. ' extends ' .. table.concat(class.bases, ', ')
    end
    out[#out + 1] = head .. ' {'
    for _, field in ipairs(class.fields) do
        pushComment(field.comment, depth + 1, out)
        out[#out + 1] = indentOf(depth + 1) .. memberText(field.name, field.optional, moe.proto.parseType(field.type)) .. ';'
    end
    out[#out + 1] = indent .. '}'
end

--- 一个节点连同它下面的命名空间一起写出来
---@param node ProtoType.Node
---@param name string
---@param depth integer
---@param out string[]
local function emitNode(node, name, depth, out)
    if node.class then
        emitInterface(node, name, depth, out)
    end
    local children = {}
    for child in pairs(node.children) do
        children[#children + 1] = child
    end
    if #children == 0 then
        return
    end
    table.sort(children)
    if node.class then
        out[#out + 1] = ''
    end
    out[#out + 1] = indentOf(depth) .. 'export namespace ' .. name .. ' {'
    for i, child in ipairs(children) do
        if i > 1 then
            out[#out + 1] = ''
        end
        emitNode(node.children[child], child, depth + 1, out)
    end
    out[#out + 1] = indentOf(depth) .. '}'
end

--- 全部声明翻成一份 TS（纯函数）
---@return string
function moe.protoType.text()
    local out = {
        '// 由 `server/proto.d.lua` 的声明生成 —— 不要手改',
        '// 改完声明重跑：server/bin/moe-kill.exe --gen-proto',
        '',
    }
    local tree = buildTree(moe.proto.classes())
    local roots = {}
    for name in pairs(tree.children) do
        roots[#roots + 1] = name
    end
    table.sort(roots)
    for i, name in ipairs(roots) do
        if i > 1 then
            out[#out + 1] = ''
        end
        emitNode(tree.children[name], name, 0, out)
    end
    out[#out + 1] = ''
    return table.concat(out, '\n')
end

--- 产物的默认路径
---@return string
function moe.protoType.path()
    return ((moe.env.ROOT_PATH:parent_path()) / OUTPUT):string()
end

--- 写产物，返回写到哪儿了
---@return string
function moe.protoType.write()
    local path = moe.protoType.path()
    moe.fsu.saveFile(path, moe.protoType.text())
    return path
end

return moe.protoType
