import type { Proto } from '../proto';
import type { Agent } from '../state/agent';

/** 花色符号 */
export const SUITS: Record<string, string> = { 黑桃: '♠', 红桃: '♥', 梅花: '♣', 方块: '♦' };

/** 花色是不是红的 */
export function isRed(suit: string | undefined): boolean {
    return suit === '红桃' || suit === '方块';
}

/** 装备四个子区（列装备就按这个顺序） */
export const EQUIP_ZONES = ['武器', '防具', '进攻马', '防御马'];

/** 区域串：`名字#玩家号`（玩家号 0 = 无主） */
export function zoneKey(name: string, owner: number): string {
    return `${name}#${owner}`;
}

/** 一个区里的牌 */
export function zoneCards(agent: Agent, name: string, owner: number): Proto.Card[] {
    const want = zoneKey(name, owner);
    return [...agent.cards.values()].filter((card) => card.zone === want);
}

/** 一位玩家身上的牌：手牌 / 装备四子区 / 判定区 */
export function seatCards(agent: Agent, id: number): { hand: number[]; equip: Map<string, number[]>; judging: number[] } {
    const mine = [...agent.cards.values()].filter((card) => (card.zone ?? '').endsWith(`#${id}`));
    const of = (names: string[]) => mine
        .filter((card) => names.includes((card.zone ?? '').split('#')[0] ?? ''))
        .map((card) => card.id);
    const equip = new Map<string, number[]>();
    for (const name of EQUIP_ZONES) {
        equip.set(name, of([name]));
    }
    return { hand: of(['手牌']), equip, judging: of(['判定']) };
}

/** 一张牌现在长什么样（转化叠在牌自己那份上；看不见牌面就是空） */
export function cardFaceOf(agent: Agent, id: number): Proto.CardFace | undefined {
    const card = agent.cards.get(id);
    if (!card?.face && !card?.modifier) {
        return undefined;
    }
    return {
        name: card.modifier?.name ?? card.face?.name,
        suit: card.modifier?.suit ?? card.face?.suit,
        point: card.modifier?.point ?? card.face?.point,
    };
}

/** 牌面是不是被「转化」改过（同名同花色的那份不算） */
export function isConverted(card: Proto.Card | undefined): boolean {
    const modifier = card?.modifier;
    if (!modifier) {
        return false;
    }
    return (modifier.name !== undefined && modifier.name !== card.face?.name)
        || (modifier.suit !== undefined && modifier.suit !== card.face?.suit)
        || (modifier.point !== undefined && modifier.point !== card.face?.point);
}

/** 一张牌写成一串（看不见牌面就写「背面」） */
export function cardLabel(agent: Agent, id: number): string {
    const face = cardFaceOf(agent, id);
    if (!face) {
        return '背面';
    }
    return `${face.name ?? '?'}${SUITS[face.suit ?? ''] ?? ''}${face.point ?? ''}`;
}

/** 一位玩家的显示名 */
export function playerLabel(agent: Agent, id: number): string {
    const player = agent.players.get(id);
    return player?.base.userName || (player ? `座位 ${player.base.seat}` : `#${id}`);
}

/** 武将名（没同步到就空） */
export function heroName(player: Proto.Player | undefined): string | undefined {
    const hero = player?.custom?.['heroName'];
    return typeof hero === 'string' && hero.length > 0 ? hero : undefined;
}

/** 身份（没同步到就空） */
export function identityOf(player: Proto.Player | undefined): string | undefined {
    const identity = player?.custom?.['identity'];
    return typeof identity === 'string' && identity.length > 0 ? identity : undefined;
}

/** 一条属性的值 */
export function attr(player: Proto.Player | undefined, name: string): number | undefined {
    return player?.attributes.find((one) => one.name === name)?.value;
}

/** 协议层展示串里的 `${suit:红桃}` 这类模板 */
export function renderMark(mark: string): string {
    const match = /^\$\{(\w+):(.+)\}$/.exec(mark);
    const kind = match?.[1];
    const value = match?.[2] ?? '';
    if (kind === 'suit') {
        return SUITS[value] ?? value;
    }
    return match ? value : mark;
}
