# 提议：规则数值的落点从 `game:setValue` 换成共享袋 `rule`

## 为什么

`rule` 是装载器**每轮装载建的一张共享袋**（注入给所有内容文件），本来就是干这个的落点（`rule.equipZones` 已经这么用）。而「规则数值」现在走 `game:setValue` / `getValue` —— 两套并存：字段名与类型要在各包的 `meta.lua` 里给 `Game` 写具名重载，读的时候还得知道「哪个名字是哪个包写的」。

改成全挂 `rule` 以后：**字段名即落点**（`rule.cardTable` 一眼看出是内容数据）、`rule.X = 值` 就能覆盖（mod 改字段即可，也能就地改表内容）、类型在 `Loader.Rule` 上声明一次、内核那条 API 不再承担「传规则数值」的职责。

## 改什么

- **内核**：装载器把这一轮建的共享袋同时挂到局上（`game.rule`）—— 局外（内核 / 用例 / 将来的房间）读得到；`resetContent` 跟着换一张空的。
- **内容**：7 个字段搬家（**英文名、扁平**）：

  | 现在 | 改成 | 谁写 |
  | --- | --- | --- |
  | `默认体力` | `rule.defaultHp` | `@基础/配置.lua`（5） |
  | `主公额外体力` | `rule.lordHpBonus` | `@基础/配置.lua`（1） |
  | `默认摸牌数` | `rule.defaultDrawCount` | `@基础/配置.lua`（2） |
  | （文件里的 `local PHASES`） | `rule.phases` | `@基础/回合.lua` |
  | `牌表` | `rule.cardTable` | `标准/牌表.lua` |
  | `选将备选数` | `rule.heroCandidateCount` | `身份场/配置.lua`（5） |
  | `身份配置` | `rule.identityConfig` | `身份场/配置.lua` |

  读的一侧一律**在使用点读** `rule.X`（不在加载期抄一份）⇒ 改表内容、换整张表都当场生效。
- **类型**：各包 `meta.lua` 里给 `Game:getValue` / `setValue` 写的具名重载删掉，改成 `Loader.Rule` 的 `---@field`（一行中文说明）；**通用**那几条挪到内核 `env-meta.lua`（它们现在没有别的落点，删了测试里的探针会报 `undefined-field`）。
- **注释**：每个字段旁留一行中文说明（写在赋值那一行之前，照 `code-style.md` 第 3 节）。

## 不做什么

- **一个内核 API 都不删**：`Game:setValue` / `setValues` / `getValue` / `getValues` 保留（用例里的探针与将来的临时数据还要用），只是不再用来传规则数值。
- 不做字段分组（保持扁平）、不加校验（拿不到就报错 / 给默认值，口径照旧）。
- 不动对外契约（JSON-RPC 尚未实现；本次只改内容侧的落点约定）。
