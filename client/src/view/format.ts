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

/** 势力（没选将 / 老服务器就没值） */
export function kingdomOf(player: Proto.Player | undefined): string | undefined {
    const kingdom = player?.custom?.['heroKingdom'];
    return typeof kingdom === 'string' && kingdom.length > 0 ? kingdom : undefined;
}

/** 势力 → 立绘边框的样式名 */
export const KINGDOM_CLASS: Record<string, string> = { 魏: 'wei', 蜀: 'shu', 吴: 'wu', 群: 'qun' };

/** 一条属性的值 */
export function attr(player: Proto.Player | undefined, name: string): number | undefined {
    return player?.attributes.find((one) => one.name === name)?.value;
}

/** 只要纯文本的地方用它（`reason` 之外的展示串）：把片段拼起来、丢掉颜色 */
export function formatPlain(text: string, tables: TextTables = {}): string {
    return formatText(text, tables).map((piece) => piece.text).join('');
}

/** 一段渲染好的文本：内容 + 可选的颜色 */
export interface TextPiece {
    text: string;
    color?: string;
}

/** 文本的两张表：模板函数表（`函数表[函数名][内容]`）与类型样式表（类型 → 色值） */
export interface TextTables {
    func?: Record<string, Record<string, string>>;
    type?: Record<string, string>;
}

/** 内置的模板函数表（`locale` 现在是空的 —— 查不到就用内容原样） */
const DEFAULT_FUNC: Record<string, Record<string, string>> = {
    locale: {},
    suit: SUITS,
};

/** 内置的类型样式表（色值由客户端分配；服务端只给类型） */
const DEFAULT_TYPE: Record<string, string> = {
    card: '#ffcc00',
    skill: '#ffe08a',
    player: '#7fd4ff',
    me: '#7bffa6',
    warn: '#ff7070',
};

/** 按类型取色值（认不出给空 —— 不上色） */
export function colorOf(type: string): string | undefined {
    return DEFAULT_TYPE[type];
}

const COLOR_SHAPE = /^#[0-9a-fA-F]{3,6}$/;

/** 从 `text[start]` 那个 `{` 起找配对的 `}`（算嵌套）；找不到给 -1 */
function matchBrace(text: string, start: number): number {
    let depth = 0;
    for (let i = start; i < text.length; i++) {
        const char = text[i];
        if (char === '{') {
            depth += 1;
        } else if (char === '}') {
            depth -= 1;
            if (depth === 0) {
                return i;
            }
        }
    }
    return -1;
}

/** 一个模板：`${…}` 的范围，以及紧跟其后的参数表（没有就为空） */
interface Template {
    /** `${` 的下标 */
    start: number;
    /** 配对 `}` 的下标 */
    end: number;
    /** `@` 之后那段 JSON（没有、或解析不了就是空） */
    params?: Record<string, unknown>;
    /** 这次要吃掉到哪里（有参数表就是参数表的 `}`） */
    stop: number;
}

/** 从 `at` 起找第一个模板（`${…}`），并看它后面紧跟着没有 `@{…}` 参数表；没有模板给空 */
function takeTemplate(text: string, at: number): Template | null {
    const start = text.indexOf('${', at);
    if (start < 0) {
        return null;
    }
    const end = matchBrace(text, start + 1);
    if (end < 0) {
        return null;
    }
    if (text[end + 1] !== '@' || text[end + 2] !== '{') {
        return { start, end, stop: end };
    }
    const paramsEnd = matchBrace(text, end + 2);
    if (paramsEnd < 0) {
        return { start, end, stop: end };
    }
    let params: Record<string, unknown> | undefined;
    try {
        params = JSON.parse(text.slice(end + 2, paramsEnd + 1)) as Record<string, unknown>;
    } catch {
        params = undefined;
    }
    return params === undefined
        ? { start, end, stop: end }
        : { start, end, params, stop: paramsEnd };
}

/** 展开一个模板：查函数表（查不到用内容本身）；`visited` 里已经有的内容不展开（返回空） */
function expandTemplate(name: string, content: string, func: Record<string, Record<string, string>>, visited: Set<string>): string | null {
    if (visited.has(content)) {
        return null;
    }
    visited.add(content);
    return func[name]?.[content] ?? content;
}

/** 把参数值写成显示的文本（不是字符串就写成 JSON） */
function textOf(value: unknown): string {
    return typeof value === 'string' ? value : JSON.stringify(value) ?? String(value);
}

/** 把模板内容里的 `{键}` / `{键#类型}` 换成参数值（没有该键就保持原文），并按类型上色 */
function fillParams(text: string, params: Record<string, unknown>, types: Record<string, string>): TextPiece[] {
    const out: TextPiece[] = [];
    let at = 0;
    while (at < text.length) {
        const start = text.indexOf('{', at);
        if (start < 0) {
            break;
        }
        const end = matchBrace(text, start);
        if (end < 0) {
            break;
        }
        const inner = text.slice(start + 1, end);
        const hash = inner.indexOf('#');
        const key = hash < 0 ? inner : inner.slice(0, hash);
        const type = hash < 0 ? key : inner.slice(hash + 1);
        const value = params[key];
        out.push({ text: text.slice(at, start) });
        if (value === undefined) {
            out.push({ text: text.slice(start, end + 1) });
        } else {
            out.push({ text: textOf(value), color: types[type] });
        }
        at = end + 1;
    }
    out.push({ text: text.slice(at) });
    return out.filter((piece) => piece.text.length > 0);
}

/** 渲染询问缘由这类带格式的文本：`${函数名:内容}` 模板 + 紧跟其后的 `@{JSON}` 参数表；模板之外原样 */
export function formatText(text: string, tables: TextTables = {}): TextPiece[] {
    const func: Record<string, Record<string, string>> = { ...DEFAULT_FUNC, ...tables.func };
    const types: Record<string, string> = { ...DEFAULT_TYPE, ...tables.type };
    const visited = new Set<string>();
    const out: TextPiece[] = [];
    let at = 0;
    while (at < text.length) {
        const found = takeTemplate(text, at);
        if (!found) {
            out.push({ text: text.slice(at) });
            break;
        }
        out.push({ text: text.slice(at, found.start) });
        const inner = text.slice(found.start + 2, found.end);
        const colon = inner.indexOf(':');
        const name = colon < 0 ? '' : inner.slice(0, colon);
        const content = colon < 0 ? inner : inner.slice(colon + 1);
        const expanded = expandTemplate(name, content, func, visited);
        if (expanded === null) {
            out.push({ text: text.slice(found.start, found.end + 1) });
        } else {
            out.push(...fillParams(expanded, found.params ?? {}, types));
        }
        at = found.stop + 1;
    }
    return out
        .filter((piece) => piece.text.length > 0)
        .map((piece) =>
            piece.color !== undefined && !COLOR_SHAPE.test(piece.color)
                ? { text: piece.text }
                : piece);
}
