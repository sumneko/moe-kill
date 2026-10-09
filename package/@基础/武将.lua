-- 装配：把一张武将装到角色身上（牌面数据进字段、体力进属性；技能等技能系统那一批再接）
-- 牌面数据的**声明与读法**都在这里：势力 / 性别 / 体力（体力依次从定义、「默认体力」、5 上取）
-- 体力在**角色**上的便捷读法也在本文件：getHp / getMaxHp / getLostHp

---@class HeroDef
---@field private kingdomName? 基础.势力 # 势力
---@field private sexName? 基础.性别 # 性别
---@field private maxHp? integer # 初始体力上限的声明值（牌面的勾玉数）
---@field private initialHp? integer # 初始体力值的声明值（没写就是空 —— 「与上限相同」由读的地方兜）
local HeroDef = Class 'HeroDef'

--- 声明势力（魏 / 蜀 / 吴 / 群）
---@param name 基础.势力
---@return HeroDef
function HeroDef:kingdom(name)
    self.kingdomName = name
    return self
end

---@return 基础.势力? # 势力
function HeroDef:getKingdom()
    return self.kingdomName
end

--- 声明性别（男 / 女）
---@param name 基础.性别
---@return HeroDef
function HeroDef:sex(name)
    self.sexName = name
    return self
end

---@return 基础.性别? # 性别
function HeroDef:getSex()
    return self.sexName
end

--- 声明体力：上限必给，初始体力值不给就不写（「与上限相同」由读的地方兜）
---@param maxHp integer # 初始体力上限（牌面的勾玉数）
---@param hp? integer # 初始体力值（省略 = 与上限相同）
---@return HeroDef
function HeroDef:hp(maxHp, hp)
    self.maxHp     = maxHp
    self.initialHp = hp
    return self
end

--- 这张武将的初始体力上限与初始体力值（依次取：定义 → `rule.defaultHp` → 5）
---@return integer # 初始体力上限
---@return integer # 初始体力值
function HeroDef:getHp()
    local maxHp = self.maxHp or rule.defaultHp or 5
    return maxHp, self.initialHp or maxHp
end

---@class Player
local M = Class 'Player'

--- 让这名角色用上某张武将（写武将 / 性别 / 势力 / 体力，并把他的技能挂上）
---@param hero HeroDef
function M:setHero(hero)
    local maxHp, hp = hero:getHp()
    self.hero    = hero
    self.sex     = hero:getSex()
    self.kingdom = hero:getKingdom()
    self:setAttr('体力上限', maxHp)
    self:setAttr('体力', hp)
    local custom = self.custom
    custom:setVisible('heroName', true)
    custom:setVisible('heroSex', true)
    custom.proxy.heroName = hero.name
    custom.proxy.heroSex  = hero:getSex()
    self:refreshSkills()
end

--- 按当前武将 + 当前身份重算该有的技能（挂上缺的、摘掉不该有的；**主公技只在是主公时才挂**）
function M:refreshSkills()
    local hero = self.hero
    if not hero then
        return
    end
    ---@type table<string, true>
    local wanted = {}
    for _, name in ipairs(hero:getSkills()) do
        local def = assert(game:getSkill(name), '没有叫「{}」的技能定义' % { name })
        if not def:hasTag('主公技') or self.identity == '主公' then
            wanted[name] = true
        end
    end
    -- 挂上缺的（按武将声明的顺序，技能之间的时机顺序才有保证）
    for _, name in ipairs(hero:getSkills()) do
        if wanted[name] and not self:hasSkill(name) then
            self:addSkill(name)
        end
    end
    for _, skill in ipairs(self:getSkills()) do
        if not wanted[skill.name] then
            skill:remove()
        end
    end
end

--- 这名角色当前的体力
---@return number
function M:getHp()
    return self:getAttr('体力')
end

--- 这名角色当前的体力上限
---@return number
function M:getMaxHp()
    return self:getAttr('体力上限')
end

--- 这名角色缺失的生命（体力上限 − 当前体力；官方「已损失体力值」）
---@return number
function M:getLostHp()
    return self:getMaxHp() - self:getHp()
end
