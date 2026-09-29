# 设计：玩家级时机表与效果判定的三段式

## D1. 玩家级时机表 = 同一个 `Event`，挂在玩家实例上

- `Player.__init` 里 `self.events = moe.event.create()`；门面 `player:on / fire / collect` 与 `Game` 同形（校验 + 转发）。
- 载体是**玩家实例字段**（每局一份、随实例生灭）：不挂类表（`Extends` 会复制 / 重载会清，见 `references/architecture.md` 第 8 节）、不挂模块级（热重载要求）。
- 语义与全局表完全一致：注册顺序即执行顺序、疑问式名字返回非 nil 即结论、`on` 返回 disposer（『被动』的启停机制不用动）。
- 重装（`resetContent`）现在清局的事件表、**玩家事件表不跟随** —— 重装整块即将随 `add-worker-mode` 退役（一局一 VM），不为它写一次性清理。

## D2. 事件命名：三段的「身份」进名字

- `'效果-能否生效'`（全局）/ `'效果-来源-能否生效'`（来源）/ `'效果-目标-能否生效'`（目标）。
- 与既有两条约定合拍：「分类-动作」命名、疑问式名字 ⇒ 看返回值。
- 三段前缀都是 `效果-`、后缀都是 `-能否生效`，聚合 grep / 读日志整齐。
- **身份编码进时机名**（而不是靠 fire 参数或订阅者自知）：同一个人既是来源又是目标（自伤）时两段各自可辨。
- 备选（否决）：三段统一叫 `'效果-能否生效'`、只是 fire 到不同对象 —— 省一个名字，但身份丢了，回调要自己认领、日志分不清是哪段拦的。

## D3. 依次问的写法：`fireVeto` + or 链 + 可选链

```lua
local refusal = self:fireVeto(self.game, '效果-能否生效')
             or self:fireVeto(self.from, '效果-来源-能否生效')
             or self:fireVeto(self.to, '效果-目标-能否生效')
```

- `fireVeto(owner, name)` 是 Effect 的私有小函数：`owner?:fire(name, self)`（可选链：没有来源 / 没有目标就跳过），并把 `false` 归一成「这次生效被阻止」。名字与 `fire` 同族（评审时先叫 `ask` / `askVeto`，用户定了 `fireVeto`）。
- **为什么归一化必须提前**：`or` 按 **truthy** 短路，而约定是「返回**非 nil** 即阻止」—— `false` 是合法应答，若留到链尾统一归一，`false or 下一段` 会把它当成「没拦」继续问（甚至最后把拦截丢掉）。
- 顺序与短路由 `or` 的求值顺序天然表达（全局 → 来源 → 目标；谁先给原因就停）。
- 对齐：`or` 悬挂、让三行的 `self:fireVeto(...)` 竖直一条线（首版落成「`or` 顶格」，用户评审时纠回悬挂）；可选链按 `code-style.md` §12（`server/tools/` 之外可用）。

## D4. `Effect.from` / `Effect.to` 的读法

- 名字沿用伤害的先例（`Damage.from?` / `Damage.to`、`Heal.to`、询问的 `to`）。
- 转发用 `__getter`（与 `player.acting` 同风格，单一真相）：
  - `CardEffect.from = user`（判定阶段没有 ⇒ 可空）、`.to = target`；
  - `UseCard.from = user`、`UseCardToCard.from = user`、`CardEffectToCard.from = user`；
  - `Damage` / `Heal` 是原生字段，不动。
- 三段对**所有**效果都跑：凡是读得出 `from` / `to` 的效果就进对应段。**询问类（`Ask*`）的 `to` 是「被问者」，会照此进目标段** —— 接受（对称于它们本来就在全局段被问）；将来真有「不能被询问」类技能时正好用得上。

## D5. 迁移【仁王盾】

- `owner:on('效果-目标-能否生效', …)`，删掉回调里的 `effect.target ~= owner`（被问的必然冲他来的）。
- 行为不变：黑【杀】对装备主无效、连【闪】都不问（既有 3 条用例回归）。

## Risks

- 三段顺序（全局 → 来源 → 目标）是全内容可见的约定；没外部消费者，有实际案例再调（改动便宜）。
- 「来源段」暂时没有消费者（留给将来的来源侧技能，如青釭剑类）；形状一起立好，不二次改。
- `false` 归一的行为靠既有用例（`core.effect.init`「只返回 false ⇒ 归一」）守住；新增「目标段返回 false 不被 or 链跳过」的回归用例。
