# Tasks

## 1. 内核：`kind` 改成覆盖 + 列表入参

- [x] 1.1 `server/core/game.lua` 的 `CardDef:kind(name)`：入参放宽成 `string|string[]`（单值包成一张表，判别用 `Type(name) ~= nil`）、**一次调用覆盖**（换新表，不再往旧表上追加）、列表内去重、顺序按列表；顶部注释改成「一次调用就把分类定下来；重复调以后写的为准；要多个就给一张列表」；验证：`--test core.card-def` 全绿
- [x] 1.2 `CardDef:extends` 里抄分类的两行改成 `if #base.kinds > 0 then self:kind(base.kinds) end`（基类有分类就覆盖，没有就不动子定义自己的）；验证：`--test core.card-def` / `--test core.game` 全绿
- [x] 1.3 `server/core/loader/env-meta.lua`：`CardDef:kind` 的签名改成 `fun(self: CardDef, name: string|string[]): CardDef`（注释同步「一次调用定下分类」）；验证：问题面板 information 及以上 0

## 2. 用例

- [x] 2.1 `server/test/core/card-def.lua`：把旧口径那条「分类可多条、重复写只算一次」改成**新口径** —— `: kind { '锦囊', '延时锦囊' }` 得到两类（顺序按列表、列表内重名只算一次）、再 `: kind '基本'` **覆盖**成只有基本、`isKind` 正反两面、`getKinds()` 是快照（改动副本不影响定义）；验证：`--test core.card-def` 全绿
- [x] 2.2 `server/test/core/card-def.lua` 里涉及 `extends` 的两条：把「分类累积」改成「**基类的分类覆盖子定义自己的**」（子定义先 `: kind '测试'`、再 `: extends '基类'` ⇒ 只剩基类那类；`extends` 之后再 `: kind` ⇒ 只剩后写的）；并补一条「**基类没声明分类时不清空子定义自己的**」；验证：`--test core.card-def` 全绿
- [x] 2.3 回归：`--test core.game`（【杀】/【闪】从基本牌模板继承分类两条）与 `--test rule` 全量；验证：全量 0 失败

## 3. 文档与验收

- [x] 3.1 `.agents/skills/sanguosha-rules/SKILL.md`：「定义上的三件套」（§9.3 一带）里的 `kind` 口径改成「一次调用覆盖、多个分类给一张列表」，并写上锦囊两类的例子（`{ '锦囊', '非延时锦囊' }` / `{ '锦囊', '延时锦囊' }`）
- [x] 3.2 `moe-kill-dev/references/architecture.md` §12 的 `CardDef:kind` 行：口径改成「入参 `string|string[]`、重复调以后写的为准」，`extends` 那行的「分类累积」改成「分类覆盖（基类没分类就不动）」
- [x] 3.3 `moe-kill-dev/references/progress.md`：定义三件套那条同步新口径
- [x] 3.4 验收：`server/bin/moe-kill.exe --test` 全量 0 失败、问题面板 information 及以上 0；提交（`【AI】` 前缀）
