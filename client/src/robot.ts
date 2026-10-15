import type { Agent, Ask } from './agent';

/** 后端默认听这个口 */
const DEFAULT_PORT = 31415;

/** 兜底看一问的间隔（毫秒）—— 主路径是「询问一到就答」，这个只在漏掉重画时兜底 */
const FALLBACK_MS = 1000;

/** 一次泵最多处理几条（防某条答复又立刻引来新询问时占住不放） */
const PUMP_LIMIT = 50;

/** 同一份候选连着问这么多次，就改答「不选」（防「答复不前进」的死循环） */
const REPEAT_LIMIT = 3;

/** 上一份候选的指纹与它被连着问了几次 */
let lastPrint = '';
let repeats = 0;
let busy = false;
let done = false;

/** 一份候选计划里的目标 */
type Plan = { ids: number[]; min: number; max: number };

/** 一份「视为」候选 */
type ViewOption = { name: string; card?: Plan; target?: Plan };

/** 候选里取前几个 */
function take<T>(list: T[], count: number): T[] {
    return list.slice(0, Math.max(count, 0));
}

/** 有目标才带上那个键（缺键才是「没选」） */
function withTargets(result: Record<string, unknown>, ids: number[]): Record<string, unknown> {
    if (ids.length > 0) {
        result.targets = ids;
    }
    return result;
}

/** 把一份候选压成短串：可能是计划对象（`min` + `ids`），也可能是一列带 id 的选项 */
function outline(one: unknown): string {
    if (Array.isArray(one)) {
        return one.map((item) => `${(item as { id?: number; name?: string }).id ?? (item as { name?: string }).name ?? item}`).join(',');
    }
    const plan = one as Plan | undefined;
    return plan ? `${plan.min ?? ''}:${(plan.ids ?? []).join(',')}` : '';
}

/** 这次询问的指纹：方法 + 缘由 + 候选 —— 用来认出「同一份候选反复问」 */
function fingerprint(ask: Ask): string {
    const params = ask.params as any;
    return [
        ask.method,
        params.reason ?? '',
        outline(params.player),
        outline(params.card),
        outline(params.viewAs),
        outline(params.skills),
        outline(params.heroes),
    ].join('|');
}

/** 按询问给一份答复（`{}` = 不选、不表态） */
function reply(agent: Agent, ask: Ask): Record<string, unknown> {
    const params = ask.params as any;
    switch (ask.method) {
        case 'Ask.Choice':
            return { choice: 1 };
        case 'Ask.Hero':
            return { heroes: take((params.heroes ?? []) as string[], (params.min as number | undefined) ?? 1) };
        case 'Ask.Select': {
            const result: Record<string, number[]> = {};
            const player = params.player as Plan | undefined;
            const card = params.card as Plan | undefined;
            if (player) {
                result.player = take(player.ids, player.min);
            }
            if (card) {
                result.card = take(card.ids, card.min);
            }
            return result;
        }
        case 'Ask.Use': {
            const options = (params.card ?? []) as (Plan & { id: number })[];
            const views = (params.viewAs ?? []) as ViewOption[];
            const first = options[0];
            if (first) {
                return withTargets({ usedCard: first.id }, take(first.ids, first.min));
            }
            const view = views.find((one) => (one.card?.min ?? 0) <= (one.card?.ids.length ?? 0));
            if (view) {
                const result: Record<string, unknown> = { usedViewAs: views.indexOf(view) + 1 };
                const materials = take(view.card?.ids ?? [], view.card?.min ?? 0);
                if (materials.length > 0) {
                    result.cards = materials;
                }
                return withTargets(result, take(view.target?.ids ?? [], view.target?.min ?? 0));
            }
            return {};
        }
        case 'Ask.UseSkill': {
            const skills = (params.skills ?? []) as { id: number; cards?: Plan; targets?: Plan }[];
            const skill = skills[0];
            if (!skill) {
                return {};
            }
            const result: Record<string, unknown> = { usedSkill: skill.id };
            const cards = take(skill.cards?.ids ?? [], skill.cards?.min ?? 0);
            if (cards.length > 0) {
                result.cards = cards;
            }
            return withTargets(result, take(skill.targets?.ids ?? [], skill.targets?.min ?? 0));
        }
        case 'Ask.Panel': {
            const panel = agent.panels.get(params.id as number);
            if (!panel || panel.min <= 0) {
                return {};
            }
            const cards = panel.rows.flatMap((row) => row.cards).filter((id) => !panel.disabled.includes(id));
            return { card: take(cards, panel.min) };
        }
        default:
            return {};
    }
}

/** 答一条询问：同一份候选反复问就改答「不选」 */
function handle(agent: Agent, ask: Ask): void {
    const print = fingerprint(ask);
    if (print === lastPrint) {
        repeats += 1;
    } else {
        lastPrint = print;
        repeats = 0;
    }
    if (repeats >= REPEAT_LIMIT) {
        agent.log('同一份候选问太多次，机器玩家不选了');
        ask.answer({});
        return;
    }
    try {
        const result = reply(agent, ask);
        agent.log(`机器玩家答复：${ask.method}${ask.params?.reason ? `（${ask.params.reason}）` : ''} → ${JSON.stringify(result)}`);
        ask.answer(result);
    } catch (err) {
        agent.log(`机器玩家答不了（${ask.method}）：${err instanceof Error ? err.message : String(err)}`);
        ask.answer({});
    }
}

/** 把手上攒着的询问一口气答完（答复会引来新询问，所以循环到没有为止） */
function pump(agent: Agent): void {
    if (busy) {
        return;
    }
    if (agent.over) {
        if (!done) {
            done = true;
            agent.log('机器玩家收工：这一局完了');
        }
        return;
    }
    busy = true;
    try {
        for (let i = 0; i < PUMP_LIMIT; i += 1) {
            const ask = agent.asks[0];
            if (!ask) {
                return;
            }
            handle(agent, ask);
            if (agent.asks[0] === ask) {
                // 这条没被答出去（比如答复抛错），别在这里死转
                return;
            }
        }
    } finally {
        busy = false;
    }
}

/** 挂一个自动应答的机器玩家：连上后端、坐进来、把每条询问都答掉 */
export function attachRobot(agent: Agent, name: string): void {
    const url = `ws://${location.hostname || 'localhost'}:${DEFAULT_PORT}`;
    // 询问一到就答（不靠定时器：后台标签会把定时器节流到 1 秒一次）
    const previous = agent.onChange;
    agent.onChange = () => {
        previous?.();
        pump(agent);
    };
    window.setInterval(() => pump(agent), FALLBACK_MS);
    void (async () => {
        await agent.connect(url);
        await agent.join(name);
        agent.log(`机器玩家「${name}」就位`);
    })().catch((err: unknown) => {
        agent.log(`机器玩家起不来：${err instanceof Error ? err.message : String(err)}`);
    });
}
