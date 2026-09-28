# Design

## 1）默认值反过来：`getTempZone()` = 自己这块

**现状**（`inherit-temp-zone`，2026-09-24 落地）：

```lua
function M:getTempZone()
    local zone = self.tempZone
    if zone then return zone end
    local parent = self.parent
    if parent then return parent:getTempZone() end
    return self:createTempZone()
end
```

**改后**：

```lua
function M:getTempZone()
    local zone = self.tempZone
    if not zone then
        zone = moe.zone.create(self.game)
        self.tempZone = zone
    end
    return zone
end
```

**判据**：数用法比数说法可靠 —— 「我是结算单位，要一块自己的区」是 5 处（内核 4 + 内容侧判定 1，将来还会随新结算单位增加）；「借外层那块」是 1 处（`AskPlayCard`）。默认值该给多数派，少数派显式写出来（`parent:getTempZone()`），这也正好符合「`parent` 只表示嵌套关系」这个更干净的语义。

**顺带的收益**：内容侧写「一次结算」（`package/@基础/判定.lua`）不再需要抄内核的「重写 `getTempZone()` + `createTempZone()`」样板 —— 它拿到的 `Effect` 基类默认行为就是它要的。这一点是用户提出本次改动的直接动因。

## 2）`createTempZone()` 删掉

它存在的唯一理由是「重写 `getTempZone()` 时用它」。默认自建后**没有任何地方需要重写 `getTempZone()`**，于是这个公开方法没有消费者 ⇒ 删。`tempZone` 字段保留：它同时承担两件事 —— **无参读取**（`effect.tempZone` 直接看有没有区，符合「不传参数的读取用字段」）与**判归属**（非空 = 这块区归我、结完时由我收尾）。

`moe.zone.create(self.game)` 的调用点从 `createTempZone()` 挪进 `getTempZone()`，语义与懒建时机都不变（仍然只在这一处建区；`tempZone` 仍是「自己建的那块」）。

## 3）`AskPlayCard` 改显式点名

```lua
function M:onAnswered()
    local card = self.card
    if card and self.parent then
        self.game:moveCard(card, self.parent:getTempZone())
    end
end
```

`self.parent` 的存在性判断**本来就有**（顶层发起询问时不动那张牌），所以只有取区那一句变了。行为完全不变：牌仍落在「发起这次询问的那次结算」的区里，仍由那次结算的收尾统一送 `弃牌`。

**要认下来的代价**：漏点名的后果是**静默**的 —— 子效果调 `self:getTempZone()` 会拿到自己一块，牌随后被自己的收尾提前送进弃牌堆（正是 `inherit-temp-zone` 的 design 里记下的【五谷丰登】那个 bug 形状）。所以本次在用例里补一条「子效果显式点名 `parent:getTempZone()` 拿到外层那块」，把这个写法固化下来。

## 4）收尾与归属：判据不变

`bindFinish()` 的 `finish()` 仍然只在 `self.tempZone` 非空时 fire `'效果-收尾'` 并清牌。改后「非空」的含义更直白：**谁碰过自己这块区，这块区就归谁收尾**。子效果不再可能「身上没区却拿到了区」（继承那条路没了），所以「继承来的区由归属者清」这种需要解释的情况也一起消失。

## 5）备选（已否）

- **保留继承、只把 `createTempZone` 内联进 `getTempZone`**：5 处重写与「内容侧抄内核样板」的问题一个都没解决。
- **加标记字段区分主 / 次要效果**：用户在 `inherit-temp-zone` 时已明确不加字段，且本次改动不需要它（`parent` 只管嵌套）。
- **把 `tempZone` 做成递归 getter**：只在这里过一次 —— 递归 getter 会让子效果的收尾读到共享的那块、提前清牌，是 `inherit-temp-zone` 明确否掉的方案。
- **让 `getTempZone()` 可以传参数（`getTempZone(source?)`）**：给「偶尔要借父层」加参数，等于把两套语义塞进一个方法；显式写 `parent:getTempZone()` 更好读。

## 6）后续（本次不做，用户 2026-09-28 提）

「后面看看向 `parent` 借用 `tempZone` 的情况多不多，多的话甚至可以直接用一个字段来表示」 —— 即如果「借外层那块区」的写法多起来（不止 `AskPlayCard`），就考虑把它收成一个字段 / 读取接口（例如基类给一个现成的「外层结算那块区」读法），而不是让每个调用点自己写 `parent:getTempZone()`。

本次**不实施**：现在只有 1 处，收成字段反而多一个概念。这一条记进 `progress.md` 的待办。
