# Tasks

## 1. 内核：`kind`（分类，只记录）

- [x] 1.1 `CardDef:kind(名字)`（链式、可多次调、累加去重）+ `isKind(名字)` + `getKinds()`（快照，深拷贝）；验证：用例覆盖累加、同名去重、`isKind` 正反、拿到的列表改不动定义
- [x] 1.2 `server/core/loader/env-meta.lua` 给 `CardDef` 补 `kind` / `isKind` / `getKinds` 类型；验证：问题面板 information 及以上 0

## 2. 内核：`zone`（canUse 的内建判断）

- [x] 2.1 `CardDef:zone(区名)`（单值，重复调后者覆盖）+ `getZone()`；验证：用例覆盖声明与读、重复写覆盖、没声明得到空
- [x] 2.2 `game:canUse` 的内建条目：声明了 `zone` 时要求 `findCard(牌)` 找到的那个区就是 `user:getZone(区名)`；没这个区或牌不在里面 ⇒ 用不了并给原因；**没声明 = 沿用现状**；验证：`server/test/core/can-use.lua` 补三条（声明且在区内 / 声明但不在 / 没声明照样能用在别的区）＋既有用例全绿
- [x] 2.3 `env-meta.lua` 补 `zone` / `getZone` 类型；验证：问题面板 information 及以上 0

## 3. 内核：`extends`（把基类的定义复制过来）

- [x] 3.1 `CardDef:extends(名字)`：经 `game:getCard` 解析基类（支持限定名）、基类不存在就报错（调用只能发生在声明定义的时候，不需要另加检查）；验证：用例覆盖正常继承、限定名、找不到基类报错
- [x] 3.2 复制语义：基类钩子插入到本定义钩子**前面**（基类先跑）、`kind` 累积去重、`zone` 与限额表**深拷贝**（改子定义不影响基类、改基类不影响已复制的子定义）；验证：用例各一条（钩子顺序 / 深拷贝两个方向）
- [x] 3.3 多次 `extends` 依次合并（钩子追加、kind 累积、zone 与限额表后者覆盖）；验证：用例一条
- [x] 3.4 `env-meta.lua` 补 `extends` 类型；验证：问题面板 information 及以上 0

## 4. 内容侧采用

- [x] 4.1 `package/@基础/基本牌.lua`：`kind` 取值改成 `'基本'`（省略「牌」字），保持 `: zone '手牌'`；验证：`server/bin/moe-kill.exe --test rule` 全绿
- [x] 4.2 `package/标准/卡牌/杀.lua`：`: extends '基本牌'` 生效（拿到 `kind` 与 `zone`，自己写的 `limit` 与两个钩子照常）；验证：规则侧用例里【杀】的限额与目标口径不变，且 `game:getCard('杀'):isKind('基本')` 为真、`getZone()` 是 `'手牌'`

## 5. 文档与验收

- [x] 5.1 `moe-kill-dev/references/architecture.md` §12 接口表补三条（`kind` / `zone` / `extends`，含 `canUse` 的 `zone` 内建条目）
- [x] 5.2 `.agents/skills/sanguosha-rules/SKILL.md` §9.2：示例加 `: extends '基本牌'` 与 `kind` / `zone` 的口径（分类取值省略「牌」字）
- [x] 5.3 `moe-kill-dev/references/progress.md`：内核现状补定义三件套与新用例数
- [x] 5.4 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）
