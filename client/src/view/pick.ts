import type { Proto } from '../proto';
import type { Ask } from '../state/agent';

/** 这次询问勾了些什么（换一条询问就清空） */
export interface Selection {
    /** 选中的牌 */
    cards: number[];
    /** 选中的玩家 */
    players: number[];
    /** 选中的武将全名（`Ask.Hero`） */
    heroes: string[];
    /** 选中的技能（`Ask.UseSkill`） */
    skill: number | null;
    /** `Ask.Use`：选中的那张选项牌（决定目标候选） */
    option: number | null;
    /** `Ask.Use`：选中的「视为」（在下标处；与 `option` 互斥） */
    viewAs: number | null;
}

export const EMPTY: Selection = { cards: [], players: [], heroes: [], skill: null, option: null, viewAs: null };

/** 候选要几个 */
export function planText(plan: { min: number; max: number } | undefined): string {
    if (!plan) {
        return '0 个';
    }
    return plan.min === plan.max ? `${plan.min} 个` : `${plan.min}~${plan.max} 个`;
}

/** 这次询问里能点的牌与能点的座位 */
export function candidates(ask: Ask | undefined, selection: Selection): { cards: number[]; players: number[] } {
    const params = ask?.params as any;
    if (!ask || !params) {
        return { cards: [], players: [] };
    }
    if (ask.method === 'Ask.Select') {
        return {
            cards: (params.card?.ids ?? []) as number[],
            players: (params.player?.ids ?? []) as number[],
        };
    }
    if (ask.method === 'Ask.Use') {
        const options = (params.card ?? []) as Proto.CardWithPlan[];
        const views = (params.viewAs ?? []) as Proto.ViewAs[];
        const skills = (params.skill ?? []) as Proto.SkillPlan[];
        if (selection.skill !== null) {
            const skill = skills.find((one) => one.id === selection.skill);
            return { cards: skill?.cards?.ids ?? [], players: skill?.targets?.ids ?? [] };
        }
        if (selection.viewAs !== null) {
            const view = views[selection.viewAs];
            return { cards: view?.card?.ids ?? [], players: view?.target?.ids ?? [] };
        }
        const option = options.find((one) => one.id === selection.option);
        // 选项的 `ids` 是**合法目标**、`id` 才是牌号（`CardWithPlan` inherit 的是 `Plan.Player`）
        return { cards: options.map((one) => one.id), players: option?.ids ?? [] };
    }
    return { cards: [], players: [] };
}

/** 这次询问够不够格提交了 */
export function canSubmit(ask: Ask | undefined, selection: Selection): boolean {
    const params = ask?.params as any;
    if (!ask || !params) {
        return false;
    }
    if (ask.method === 'Ask.Select') {
        const needPlayer = (params.player?.min ?? 0) as number;
        const needCard = (params.card?.min ?? 0) as number;
        const onPlayer = params.player ? selection.players.length >= needPlayer : true;
        const onCard = params.card ? selection.cards.length >= needCard : true;
        return onPlayer && onCard && (selection.players.length > 0 || selection.cards.length > 0);
    }
    if (ask.method === 'Ask.Use') {
        const options = (params.card ?? []) as Proto.CardWithPlan[];
        const views = (params.viewAs ?? []) as Proto.ViewAs[];
        const skills = (params.skill ?? []) as Proto.SkillPlan[];
        if (selection.skill !== null) {
            const skill = skills.find((one) => one.id === selection.skill);
            if (!skill) {
                return false;
            }
            return selection.cards.length >= (skill.cards?.min ?? 0)
                && selection.players.length >= (skill.targets?.min ?? 0);
        }
        if (selection.viewAs !== null) {
            const view = views[selection.viewAs];
            return selection.cards.length >= (view?.card?.min ?? 0);
        }
        const option = options.find((one) => one.id === selection.option);
        return option ? selection.players.length >= option.min : false;
    }
    if (ask.method === 'Ask.Hero') {
        return selection.heroes.length >= ((params.min as number | undefined) ?? 1);
    }
    return false;
}

/** 交上去的那一包（形状照 `Proto.Result.<方法>`） */
export function answerOf(ask: Ask, selection: Selection): unknown {
    const params = ask.params as any;
    if (ask.method === 'Ask.Select') {
        const result: Record<string, number[]> = {};
        if (params.player && selection.players.length > 0) {
            result.player = selection.players;
        }
        if (params.card && selection.cards.length > 0) {
            result.card = selection.cards;
        }
        return result;
    }
    if (ask.method === 'Ask.Use') {
        const result: Record<string, unknown> = {};
        if (selection.skill !== null) {
            result.usedSkill = selection.skill;
        } else if (selection.viewAs !== null) {
            result.usedViewAs = selection.viewAs + 1;
        } else if (selection.option !== null) {
            result.usedCard = selection.option;
        }
        if (selection.cards.length > 0) {
            result.cards = selection.cards;
        }
        if (selection.players.length > 0) {
            result.targets = selection.players;
        }
        return result;
    }
    if (ask.method === 'Ask.Hero') {
        return selection.heroes.length > 0 ? { heroes: selection.heroes } : {};
    }
    if (ask.method === 'Ask.Panel') {
        return selection.cards.length > 0 ? { card: selection.cards } : {};
    }
    return {};
}

/** 提交之后要摆到桌面正中的那张牌（`Ask.Use` 才有） */
export function shownCardOf(ask: Ask, selection: Selection): number | null {
    if (ask.method !== 'Ask.Use') {
        return null;
    }
    return selection.option;
}

/** 勾选 / 取消勾选 */
export function toggle(list: number[], id: number): number[] {
    return list.includes(id) ? list.filter((one) => one !== id) : [...list, id];
}

/** 「没得挑」的目标 / 素材：候选全都能选（最多能选到所有候选）就直接全选，省得逐个点（【南蛮入侵】这类） */
export function autoPick(plan: { ids: number[]; min: number; max: number } | undefined): number[] {
    if (!plan || plan.ids.length === 0) {
        return [];
    }
    if (plan.max >= plan.ids.length) {
        return [...plan.ids];
    }
    if (plan.min > 0 && plan.min >= plan.ids.length) {
        return [...plan.ids];
    }
    return [];
}

/** 点一张牌（选项牌 / 素材牌 / 选牌）之后的新选择 */
export function pickCard(ask: Ask, selection: Selection, id: number): Selection {
    const params = ask.params as any;
    if (selection.viewAs !== null) {
        const views = (params.viewAs ?? []) as Proto.ViewAs[];
        const view = views[selection.viewAs];
        const cards = autoPick(view?.card);
        return {
            ...selection,
            cards: cards.length > 0 ? cards : toggle(selection.cards, id),
            players: autoPick(view?.target),
        };
    }
    if (ask.method === 'Ask.Use') {
        if (selection.skill !== null) {
            return { ...selection, cards: toggle(selection.cards, id) };
        }
        const options = (params.card ?? []) as Proto.CardWithPlan[];
        return { ...selection, option: id, skill: null, players: autoPick(options.find((one) => one.id === id)) };
    }
    if (ask.method === 'Ask.Select') {
        const auto = autoPick(params.player);
        return {
            ...selection,
            cards: toggle(selection.cards, id),
            ...(auto.length > 0 ? { players: auto } : {}),
        };
    }
    return { ...selection, cards: toggle(selection.cards, id) };
}

/** 点一个技能（`Ask.Use` 的技能那里）之后的新选择 */
export function pickSkill(ask: Ask, selection: Selection, id: number): Selection {
    const skills = ((ask.params as any).skill ?? []) as Proto.SkillPlan[];
    const skill = skills.find((one) => one.id === id);
    return { ...selection, skill: id, option: null, viewAs: null, cards: [], players: autoPick(skill?.targets) };
}
