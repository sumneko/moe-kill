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

/** 文本的两张表：模板函数表（`函数表[函数名][内容]`）与颜色表（代码 → 色值） */
export interface TextTables {
    func?: Record<string, Record<string, string>>;
    color?: Record<string, string>;
}

/** 内置的模板函数表（`locale` 现在是空的 —— 查不到就用内容原样） */
const DEFAULT_FUNC: Record<string, Record<string, string>> = {
    locale: {},
    suit: SUITS,
};

/** 内置的颜色表（色值由客户端分配；内容侧只写代码） */
const DEFAULT_COLOR: Record<string, string> = {
    card: '#ffcc00',
    player: '#7fd4ff',
    me: '#7bffa6',
    warn: '#ff7070',
};

/** 按颜色代码取色值（认不出给空 —— 不上色） */
export function colorOf(code: string): string | undefined {
    return DEFAULT_COLOR[code];
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

/** 找第一个 `@{名字:值}`：返回它拆开的四段；没有就给空 */
function takeParam(text: string): { name: string; value: string; before: string; after: string } | null {
    for (let i = 0; i + 1 < text.length; i++) {
        if (text[i] !== '@' || text[i + 1] !== '{') {
            continue;
        }
        const end = matchBrace(text, i + 1);
        if (end < 0) {
            return null;
        }
        const inner = text.slice(i + 2, end);
        const colon = inner.indexOf(':');
        if (colon < 0) {
            return null;
        }
        return {
            name: inner.slice(0, colon),
            value: inner.slice(colon + 1),
            before: text.slice(0, i),
            after: text.slice(end + 1),
        };
    }
    return null;
}

/** 把模板展开成纯文本：`${函数名:内容}` 查表（查不到用内容），`visited` 记已展开过的内容 */
function expandTemplates(text: string, tables: Required<TextTables>, visited: Set<string>): string {
    let out = '';
    let at = 0;
    while (at < text.length) {
        const start = text.indexOf('${', at);
        if (start < 0) {
            out += text.slice(at);
            break;
        }
        const end = matchBrace(text, start + 1);
        if (end < 0) {
            out += text.slice(at);
            break;
        }
        const inner = text.slice(start + 2, end);
        const colon = inner.indexOf(':');
        const name = colon < 0 ? '' : inner.slice(0, colon);
        const content = colon < 0 ? inner : inner.slice(colon + 1);
        out += text.slice(at, start);
        if (visited.has(content)) {
            out += text.slice(start, end + 1);
        } else {
            visited.add(content);
            out += tables.func[name]?.[content] ?? content;
        }
        at = end + 1;
    }
    return out;
}

/** 把 `{名字}` / `{名字#代码}` 换成参数值（没有对应参数就保持原文），并按名字或代码上色 */
function fillParams(text: string, params: Map<string, string>, colors: Record<string, string>): TextPiece[] {
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
        const name = hash < 0 ? inner : inner.slice(0, hash);
        const code = hash < 0 ? name : inner.slice(hash + 1);
        const value = params.get(name);
        out.push({ text: text.slice(at, start) });
        if (value === undefined) {
            out.push({ text: text.slice(start, end + 1) });
        } else {
            out.push({ text: value, color: colors[code] });
        }
        at = end + 1;
    }
    out.push({ text: text.slice(at) });
    return out.filter((piece) => piece.text.length > 0);
}

/** 渲染询问缘由这类带格式的文本：`${函数名:内容}` 模板 + 只认第一个 `@{名字:值}` 参数 */
export function formatText(text: string, tables: TextTables = {}): TextPiece[] {
    const merged: Required<TextTables> = {
        func: { ...DEFAULT_FUNC, ...tables.func },
        color: { ...DEFAULT_COLOR, ...tables.color },
    };
    const param = takeParam(text);
    const body = param ? param.before + param.after : text;
    const visited = new Set<string>();
    const expanded = expandTemplates(body, merged, visited);
    const params = new Map<string, string>();
    if (param) {
        params.set(param.name, expandTemplates(param.value, merged, visited));
    }
    return fillParams(expanded, params, merged.color).map((piece) =>
        piece.color !== undefined && !COLOR_SHAPE.test(piece.color)
            ? { text: piece.text }
            : piece);
}
