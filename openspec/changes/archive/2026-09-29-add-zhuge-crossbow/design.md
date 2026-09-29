# 设计：诸葛连弩与出牌限额账

## D1. 落点 = 阶段对象上的「上限增减」账（用户口径）

- 限制数本来就是**阶段对象**上的两本账之一：`canUse` 的次数内建条目读 `getLimitDelta`，`+1000` = 不限是既有口径（`add-usability-check` 的早期口径也是「连弩这类放宽 = 改数据 / 改账」）。
- 所以连弩不动 `checkCardItself`、不新立事件：**直接改那本账**。

（Decision Log：首版做了「卡牌-次数修正」collect 事件 + `checkCardItself` 收集 Σ，评审时用户指出「阶段对象上有出牌限制数，应该去修改那个限制数」—— 事件整套撤掉，改回阶段账；`game.lua` / `env-meta.lua` / `core.can-use` 的配套改动一并回退。）

## D2. `Phase:addLimit` 补撤销函数

- 「可叠加的操作必须返回撤销函数」（项目铁律）——`addLimit` 之前只加不撤；本批补上：返回的函数精确减掉这一笔、**幂等**（重复调用安全）。
- 连弩的「卸下立即恢复」就靠它；顺带 `core.phase` 的用例看住「精确 + 幂等」。

## D3. 连弩的三段时效（`undoCurrent` 单槽）

```lua
: on('被动', function (card, zone)
    local owner = assert(zone.owner)
    local undoCurrent = nil   -- 当前这个出牌阶段上补记的那笔账

    local unsubscribe = game:on('阶段-开始', function (phase)
        if phase.name == '出牌' and phase.player == owner then
            undoCurrent = phase:addLimit('杀', 1000)
        end
    end)

    local current = game.phase
    if current and current.name == '出牌' and current.player == owner then
        undoCurrent = current:addLimit('杀', 1000)
    end

    return function ()
        unsubscribe()
        if undoCurrent then
            undoCurrent()
            undoCurrent = nil
        end
    end
end)
```

- 三种时效各有落点：① 每个出牌阶段开始 ⇒ 订阅加；② 装上时阶段已开始 ⇒ `game.phase` 补记；③ 卸下 ⇒ 撤 `undoCurrent`。
- **单槽就够**（不是映射表）：当前阶段**不会嵌套**（阶段栈只在将来「额外出牌阶段」才用上），任意时刻最多一个出牌阶段活着，「只留最新一笔」正是要的语义；往表里记反而会把旧阶段对象一直抱着（内存泄漏）。将来真的有了嵌套，这里再补「按阶段逐笔撤」。
- 覆盖丢弃旧引用是无害的：旧阶段的账随阶段消亡，没人再读。

## D4. 用例面

- `core.phase`：`addLimit` 撤销精确 + 幂等。
- `rule.equip`：① 连出两张【杀】（第二张照常结算）② 只帮装备主（别人装着不帮自己）③ 拆下后限制立即回来 ④ **中途装上立即生效**（补记路径）。

## Risks

- 「阶段外不受次数限制」是既有口径 ⇒ 阶段账只在阶段内参与判定（与现状一致，不改）。
- `+1000` 不是真正无穷（实践足够；真要「无限」的语义词再另议）。
