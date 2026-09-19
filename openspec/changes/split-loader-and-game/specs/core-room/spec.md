# Spec Delta

## REMOVED Requirements

### Requirement: 场地对象

**Reason**: 「场地」并入「局」（见 `core-game`）：一局除了桌子 / 随机源 / 牌区，还持有这一局的规则内容；`room` 这个名字也不再合适（将来联网时「房间」要留给对局匹配）。同一批改动把装载器从「一局的对象」里拆出去（见 `rule-loading`），所以「场地持有规则实例 + `getRule()`」这层关系一并取消。

**Migration**: 改用 `moe.game.create { desk, random, sources?, packages }` 建局（内部调装载器）。牌区与牌的工厂原样搬到局上：`game:createZone(名字, 有序?)` / `game:getZone(名字)` / `game:getZones()` / `game:createCard(名字)`；桌子和随机源改成公开字段（`game.desk` / `game.random`）。原先从场地读规则实例（`room:getRule()`）改成**直接用局本身**：`game:getValue` / `game:getCard` / `game:on` / `game:fire` / `game:getAttributeSystem` / `game:getPackageMeta`。

### Requirement: 场地的随机源与洗牌

**Reason**: 同上，并入 `core-game` 的「局的随机源与洗牌」。

**Migration**: 行为不变 —— 由局创建且声明了顺序能力的牌区仍然绑定局的随机源，洗牌可省略随机源参数；独立创建又没传随机源的牌区洗牌照旧明确失败。
