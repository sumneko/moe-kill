# mount-hero-skills

## 1 内容侧

- [x] 1.1 `package/@基础/武将.lua`：新增 `Player:refreshSkills()`（按当前武将 + 当前身份重算：挂缺的（**按武将声明顺序**）、摘多的；主公技只在 `identity == '主公'` 时挂）；`setHero` 末尾调它
- [x] 1.2 `package/身份场/身份.lua`：`setIdentity` 末尾调 `refreshSkills()`
- [x] 1.3 `package/标准/武将/曹操.lua`：【护驾】建最小定义（名字 + `tags '主公技'`，描述与效果待文本）

## 2 用例

- [x] 2.1 `server/test/rule/hero.lua` +1：装上就把他的技能挂上（没装身份场 ⇒ 主公技不挂）
- [x] 2.2 `server/test/rule/identity.lua` +1：选将在身份之前也照样对（4 人局装身份场：主公补挂、非主公不挂、两边都有【奸雄】）

## 3 验收

- [x] 3.1 `server/bin/moe-kill.exe --test` 全绿（**816 用例 0 失败**）
- [x] 3.2 问题面板 information 及以上 0
- [x] 3.3 文档同步：`architecture.md`（`addSkill` 行）、`sanguosha-rules` §9.14/§9.15、`progress.md`
