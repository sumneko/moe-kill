# Tasks

## 1. 内核：`Card:withZone` 加回

- [x] 1.1 `server/core/card.lua`：加回 `Card:withZone(disposer, keep?)` —— 「这张牌离开它现在所在的牌区时撤销」；**判据 `keep(新位置)` 返回真就算「没离开」**（省略 = 换区就算离开），**多条绑定各判各的**（逐条记 `{ disposer, keep }`）
- [x] 1.2 `Card:bindZone(zone)`：真换区（`self.zone ~= zone`）时逐条问 `keep(新位置)`，说不留的就撤掉并移出名单
- [x] 1.3 `server/core/zone.lua`：`takeIn` **去掉中间那次 `card:unbindZone()`**（否则一次搬牌看起来像「先变无主、再进新区」两次离区，`keep` 会读到空位置而误撤）；真摘下（`remove` / `clear` / `draw`）仍然只 `unbindZone`
- [x] 1.4 `server/core/zone.lua` + `player.lua` + `game.lua`：**区记自己的名字**（`Zone.name` + `Zone:bindName(名字)`，`player:addZone` / `game:createZone` 自动登记，自留地没名字）—— 判据因此直接写 `zone?.name == '判定'`，不必绕 `owner:getZone(...)`（用户 2026-10-09 点出）

## 2. 内核：`addModifier` / `withZone` 在虚拟牌上转发给素材

- [x] 2.1 `Card:addModifier`：虚拟牌 ⇒ 自己也挂一份，并给每张素材各挂一份；返回的撤销函数把这几份一起撤掉（幂等）
- [x] 2.2 `Card:withZone`：虚拟牌 ⇒ 转给每张素材（虚拟牌不进牌区，自己那份没有意义）

## 3. 内容：延时锦囊模板带身份

- [x] 3.1 `package/@基础/卡牌/锦囊牌.lua` 的「延时锦囊牌」：`'使用'` 里**置入判定区之后** `card:withZone(card:addModifier { name = card.name }, function (zone) return zone?.name == '判定' end)`（判据 = 进的还是判定区就留；普通牌同名、行为不变；进别的区自动撤身份）

## 4. 内容：大乔【国色】

- [x] 4.1 `package/标准/武将/大乔.lua`：`skills { '流离', '国色' }` + 文件顶部补【国色】的官方描述（去掉「待机制」那句）
- [x] 4.2 `Skill '国色'`：`: viewAs('乐不思蜀', { condition = { suit = '方块', zone = rule.ownZones } })`

## 5. 用例

- [x] 5.1 `server/test/core/card.lua`：虚拟牌上 `addModifier` ⇒ 虚拟牌与每张素材都改；撤销后都恢复；重复撤销安全
- [x] 5.2 `server/test/core/card.lua`：`withZone` —— 换区（离开）时撤销、清空也撤；判据说「还算没离开」就不撤（直到再换到别处）；多条绑定各判各的；虚拟牌上调用 ⇒ 素材离开那个区时撤销
- [x] 5.3 `server/test/rule/hero-skill.lua`：【国色】—— 方块手牌当【乐不思蜀】用出去（进对方判定区、那张实体牌此刻读作【乐不思蜀】、花色点数照旧）；离开判定区后身份撤销；黑桃牌进不了选项；装备区的方块牌也能当素材；判定区里那张转化的牌也算「已有同名」。`server/test/rule/delayed-trick.lua`：判定期跑的是【乐不思蜀】的效果（跳过出牌阶段）、判完送弃牌堆后身份撤销；**挪到别人的判定区，身份跟着走**
- [x] 5.4 反向验证五轮：关掉 `addModifier` 的虚拟牌转发 ⇒ 4 条红；拆掉模板里「挂身份 + 绑寿命」整句 ⇒ 3 条红；只去掉 `keep` 判据（退化成「换区就撤」）⇒ 恰好 1 条红（「挪到别人的判定区」）；把 `takeIn` 中间的 `unbindZone` 加回去 ⇒ 恰好 3 条红（两条内核判据用例 + 那条转移）；拿掉两处 `bindName` 登记 ⇒ 恰好 2 条红（「牌区：记着自己叫什么名字」+「国色：挪到别人的判定区」）
- [x] 5.5 `server/test/core/zone.lua`：**区记着自己的名字** —— 玩家建区 / 内核建区 / 局上建区都带名字，`moe.zone.create` 出来的自留地没有，`bindName` 可以单独登记
- [x] 5.6 `server/bin/moe-kill.exe --test` 全绿（1044 用例 0 失败）、问题面板 information 及以上 0

## 6. 文档

- [x] 6.1 `moe-kill-dev/references/architecture.md`：`Card` 行补 `addModifier` 的转发与 `withZone` 行（含「先置入后挂」的用法）
- [x] 6.2 `sanguosha-rules`：§9.31 补官方原文（虚拟牌 / 实体牌、转化判据、「X 对应的实体牌」三处）与**两层寿命**表；§9.30 大乔补【国色】；§9.12 延时锦囊段说明判定期为什么需要身份
- [x] 6.3 `moe-kill-dev/references/progress.md`：基线、本批条目、缺口表（【国色】划掉）、§3 方向补「这次使用的信息」缺口
