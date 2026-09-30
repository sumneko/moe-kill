# Design

## 形状：给回调一个 `GCHost`，而不是要它返回 disposer

```lua
: on('被动', function (card, zone, host)
    local owner = zone.owner
    if not owner then
        return
    end
    host:bindGC(owner:addLimit('杀', '出牌', 1000))
end)
```

- **host 放第 3 个参数**（用户 2026-09-30 定）：不动既有的 `(card, zone)` 读法。
- 内核：`applyPassive()` 懒建 `moe.gc.host()` 并记在 `Card.passiveHost` 上、逐个跑回调；`removePassive()` 先摘字段再 `Delete(host)`（幂等）。
- 判据写进规则：**钩子只有在"内核要记下撤销、将来替你回滚"时才返回 disposer** —— 现在这条一个都不剩了；要挂资源就用 `bindGC`。

## 释放顺序变了（要知道）

原来是「内核收集各回调的撤销函数、**逆序**调用」；`GCHost` / `GC:__del` 是**按注册序** `Delete`。现有装备的被动都只挂一样东西 ⇒ 无影响；将来一个被动挂多份、又在乎顺序时，再单独定。

## 为什么连 `withZone` 一起删

`Card:withZone` 是「懒建 `GCHost` → `bindGC` → 牌换区时 `Delete`」的老机制，**内容侧零用户**（装备 2026-09-29 起改用被动），而被动现在自带同形的容器 ⇒ 两套重复的机制只留一套（用户 2026-09-30 定）。它的两条用例（"换区 / 清空就跑一次"、"懒建"）随 API 一起删。

## 不做

- 给别的钩子加 host（`'进入区域'` / `'使用'` 等按需再加）；
- 把 `bindGC` 的释放顺序改成逆序（先按现状用注册序）。
