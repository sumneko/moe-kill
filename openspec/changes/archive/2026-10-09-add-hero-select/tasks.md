# Tasks

## 1. 内核：武将分类

- [x] 1.1 `server/core/hero.lua`：`HeroDef` 加 `kinds` / `kindSet` 字段 + `kind` / `addKind` / `isKind` / `getKinds`（照 `CardDef`，**不加** `extends`）
- [x] 1.2 内容：曹操 / 刘备 / 孙权 声明 `: addKind('君主')`

## 2. 内核：`AskHero`

- [x] 2.1 `server/core/effect/ask-hero.lua`（新）：`AskHero : Effect`（`kind` = `askHero`）+ 条件归一化（`hero`：一名 / 一批 / 不给 = 不做限制）+ `collectOptions` / `checkAnswer`（复用 `moe.askCard.checkTargets`）/ `allowNone` / `.hero` / `.heroes` / `moe.askHero` 门面
- [x] 2.2 时机 `'武将-询问'` / `'武将-答复'`（单开，照 `'技能-询问'` 的先例）
- [x] 2.3 `server/core/game.lua`：`game:askHero(被问者, 缘由, 条件?)`
- [x] 2.4 `env-meta`：两个时机声明 + `effect/init.lua` 加 include

## 3. 内核：`'游戏-准备'`

- [x] 3.1 `env-meta`：给 `Game` 声明 `'游戏-准备'` 的 `on` / `fire`（**由装配侧 fire**，照 `'游戏-开始'` 的先例；本批不加内核入口）

## 4. 协议（`specs/` 增量）

- [x] 4.1 `specs/hero-select/spec.md`：`askHero` 的条件 / 答复形状与拒收口径
- [x] 4.2 同文件：`'游戏-准备'` 与 `'游戏-开始'` 的先后（身份 → 选将 → 开局）

## 5. 用例

- [x] 5.1 `server/test/core/hero.lua`：`kind` 定下 / `addKind` 追加 / `isKind` / `getKinds` 快照
- [x] 5.2 新套件 `server/test/core/effect/ask-hero.lua`：往返 / 候选校验（不在名单 / 重复 / 个数区间）/ 不给条件不限制 / `min` 为 0 的空答复 / 没人表态

## 6. 收尾

- [x] 6.1 测试全绿（**1092**）
- [x] 6.2 问题面板 information 及以上 0
- [x] 6.3 反向验证：`isKind` 判据 ⇒ 1 红；`checkAnswer` 变空 ⇒ 3 红；`allowNone` 钉死 ⇒ 1 红
- [x] 6.4 `openspec validate --all --strict`
- [x] 6.5 停在待确认状态，等「提交」

## 7. 下一批（本变更的剩余部分）

- [x] 7.1 `package/身份场/选将.lua`：备选（主公 = 全部君主 + 随机 N；其余 = 随机 N）/ 互斥 / 武将牌堆 / 跳过选项（`{ skip = true }` / `{ heroes = {…} }`）/ 身份可见性读法
- [x] 7.2 `身份场/开局.lua`：发身份挪到 `'游戏-准备'`（`config.identities` 要么不给、要么给全；给全了不校验「身份配置」）
- [x] 7.3 用例（`rule/select-hero` 8 条）+ 文档（`architecture.md` / `sanguosha-rules` / `progress.md`）

## 8. 坐次与身份给全（本变更第二批）

- [x] 8.1 内核 `server/core/desk.lua`：`Desk:swap(a, b)`（同座位直接返回；两个座位号都要在 1..人数 内）
- [x] 8.2 `身份场/开局.lua`：`config.identities` 要么不给、要么**给全**（给全了**不校验「身份配置」**，全是主公也接受）
- [x] 8.3 同文件：坐次 —— `config.seats` 给了就照列表排（**必须给全**；**不挪主公**）；没给就**经典洗牌**（从后往前、每次与随机座位交换）再把**主公换到 1 号位**
- [x] 8.4 选将的主公先选**按身份判定**（主公不在 1 号位也先问他）
- [x] 8.5 用例 `rule/select-hero`（14 条：身份给全 / 给不全报错 / 坐次洗 + 主公到 1 号位 / 坐次照列表 / 同时给身份与坐次时主公不必在 1 号位 / 主公先选按身份）
- [x] 8.6 反向验证：照列表排 ⇒ 1 红；给了坐次也挪主公 ⇒ 6 红；洗坐次 ⇒ 1 红
- [x] 8.7 测试全绿（**1107**）+ 问题面板 0 + `openspec validate --all --strict`
- [x] 8.8 停在待确认状态，等「提交」
