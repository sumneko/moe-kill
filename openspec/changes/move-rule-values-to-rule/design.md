# 设计：规则数值搬到 `rule`

## D1 落点

| 面 | 文件 | 改什么 |
| --- | --- | --- |
| 内核 | `server/core/loader/init.lua` | 那一轮建的袋从「只在注入表里」变成同时挂到 `game.rule` |
| 内核 | `server/core/game.lua` | `resetContent` 换一张空的袋（`self.rule = {}`） |
| 内核 | `server/core/loader/env-meta.lua` | `Game` 补 `rule` 字段 + 通用 `setValue` / `setValues` / `getValue` / `getValues` 声明 |
| 内容 | `@基础/配置.lua` / `@基础/回合.lua` / `标准/牌表.lua` / `身份场/配置.lua` | 写点改成 `rule.X = 值` |
| 内容 | `@基础/牌堆.lua` / `@基础/阶段/摸牌阶段.lua` / `@基础/体力.lua` / `@基础/武将.lua` / `身份场/开局.lua` / `身份场/选将.lua` | 读点改成在使用点读 `rule.X` |
| 类型 | `@基础/meta.lua` / `标准/meta.lua` / `身份场/meta.lua` | 具名重载 → `Loader.Rule` 的 `---@field` |
| 用例 | `rule/base.lua` / `rule/identity.lua` / `rule/equip.lua` / `core/game.lua` / `core/reload.lua` | 改读 `game.rule.X` |

## D2 为什么挂在局上

袋是「一轮装载一张」（试跑也照给一张空表 —— 否则内容侧往 `rule` 里写东西会在试跑里假报错），而一轮装载必然属于某一局。挂 `game.rule` 让**局外**也读得到，用例才不用绕进沙箱去看自己写的东西；`resetContent` 换一张空的，与「清空内容后数值没了」的既有口径一致。

## D3 为什么保留 `game:setValue`

它现在有两个身份：① 曾经的「规则数值」（本次搬走）；② **测试探针与临时数据**（`server/test/` 里约 100 处把「回调跑了几次」记在局上）。删掉会让一大批用例改写成闭包变量 —— 与本次目的无关，且用户 2026-10-09 明确「接口留着」。

## D4 为什么不分组

`rule.身份配置` 而不是 `rule.身份场.身份配置`：与「内核只记录、名字是内容名」一致，也省掉一层「包名前缀」的规矩；真撞名了就是同一个字段（后加载的包覆盖先加载的），这正是 mod 想要的语义。

## D5 反向验证（实现后填）

| 拆掉什么 | 结果 |
| --- | --- |
| 不把袋挂到局上（`game.rule = rule` 那行） | **13 红**（用例读 `game.rule` + 两个局的隔离 + 重装） |
| `rule.defaultHp = 5` 改回 `game:setValue('默认体力', 5)` | **3 红**（建局 / 覆盖 / 清空重载） |
| 阶段清单改回文件里硬编码 | **1 红**（「阶段清单从共享袋里读」） |
