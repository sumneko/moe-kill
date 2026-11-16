import type { Proto } from '../proto';
import type { Agent } from '../state/agent';
import { EQUIP_ZONES, SUITS, isRed } from './format';

/** 舞台宽度（画布坐标的基准） */
const STAGE_W = 1280;

/** 一张牌在画布里的尺寸（起点是「某个区域」时拿它摆牌） */
const CARD_W = 72;
const CARD_H = 100;

/** 舞台缩放（画布 → 屏幕） */
function stageScale(): number {
    const stage = document.querySelector<HTMLElement>('#stage');
    return stage ? Math.max(stage.getBoundingClientRect().width, 1) / STAGE_W : 1;
}

/** 把一块区域矩形换成「牌站在它中间」的矩形（屏幕坐标）；`count` 张时按横排的总宽居中，整组夹在舞台里 */
function inZone(zone: DOMRect, count = 1): DOMRect {
    const stage = document.querySelector<HTMLElement>('#stage');
    const w = CARD_W * count * stageScale();
    const h = CARD_H * stageScale();
    const room = Math.max((stage?.getBoundingClientRect().width ?? STAGE_W) - w, 0);
    const left = Math.min(Math.max(zone.left + zone.width / 2 - w / 2, 0), room);
    return new DOMRect(left, zone.top + zone.height / 2 - h / 2, w, h);
}

/** 上一帧每张牌在屏幕上的位置（飞行起点） */
const prev = new Map<number, DOMRect>();

/** 取一个选择器的位置 */
function rectOf(selector: string): DOMRect | null {
    return document.querySelector<HTMLElement>(selector)?.getBoundingClientRect() ?? null;
}

/** 我的手牌区：真手牌贴着武将卡右侧，落点要按「水平居中的虚拟手牌区」算 */
function handRect(): DOMRect | null {
    const hand = rectOf('#meHand');
    const stage = document.querySelector<HTMLElement>('#stage')?.getBoundingClientRect();
    if (!hand || !stage) {
        return null;
    }
    const center = stage.left + stage.width / 2;
    return new DOMRect(hand.left + center - (hand.left + hand.width / 2), hand.top, hand.width, hand.height);
}

/** 一个区域在屏幕上长什么样；`slot` = 一格牌位（中心对齐），否则按区域边贴 */
export interface ZonePlace {
    rect: DOMRect;
    slot: boolean;
}

/** 一个区域在屏幕上的位置（区域串 = `名字#玩家号`） */
export function locateZone(agent: Agent, zone: string): ZonePlace | null {
    const [name, owner] = zone.split('#');
    const id = Number(owner);
    if (name === '抽牌') {
        return asArea(rectOf('#corner .deck'));
    }
    if (name === '弃牌') {
        return asArea(rectOf('#corner .discard'));
    }
    if (name === '手牌' && id === agent.me) {
        return asArea(handRect());
    }
    if (name === '判定') {
        return asArea(rectOf(`[data-fly="seat:${id}"] .judge-col`) ?? rectOf(`[data-fly="seat:${id}"]`));
    }
    if (EQUIP_ZONES.includes(name)) {
        return asArea(rectOf(`[data-fly="zone:${zone}"]`) ?? rectOf(`[data-fly="seat:${id}"] .equips`));
    }
    if (name === '') {
        const judge = rectOf('#judgeShow');
        if (judge) {
            return { rect: judge, slot: true };
        }
    }
    return asArea(rectOf(`[data-fly="seat:${id}"]`) ?? rectOf('#recordZone'));
}

/** 包成「一片区域」 */
function asArea(rect: DOMRect | null): ZonePlace | null {
    return rect ? { rect, slot: false } : null;
}

/** 记下这一帧每张牌的位置（渲染后叫 —— 动画的起点靠它） */
export function measureCards(): void {
    prev.clear();
    for (const el of document.querySelectorAll<HTMLElement>('[data-fly^="card:"]')) {
        const id = Number(el.dataset.fly?.slice('card:'.length));
        if (Number.isFinite(id)) {
            prev.set(id, el.getBoundingClientRect());
        }
    }
}

/** 照牌面造一张浮层的牌（没牌面就是背面） */
function ghostOf(face: Proto.CardFace | undefined): HTMLElement {
    const ghost = document.createElement('div');
    ghost.className = face ? 'card' : 'card back';
    if (face) {
        if (isRed(face.suit ?? '')) {
            ghost.setAttribute('data-red', '');
        }
        const title = document.createElement('div');
        title.className = 'title';
        const who = document.createElement('span');
        who.textContent = `${SUITS[face.suit ?? ''] ?? ''}${face.point ?? ''}`;
        const what = document.createElement('span');
        what.textContent = face.name ?? '';
        title.append(who, what);
        const art = document.createElement('div');
        art.className = 'art';
        ghost.append(title, art);
    }
    return ghost;
}

/** 一次横排最多摊几张；再多（比如洗牌那种上百张）就不是「一次移动多张」，只飞一张 */
const GROUP_MAX = 5;

/** 把几张牌横排成一组（整体当成一张牌来飞） */
function ghostGroup(faces: (Proto.CardFace | undefined)[]): HTMLElement {
    const group = document.createElement('div');
    group.className = 'fly-group';
    for (const face of faces) {
        group.append(ghostOf(face));
    }
    return group;
}

/** 飞到目标位置用多久（毫秒） */
const FLY_MOVE_MS = 700;
/** 到位后淡出用多久（毫秒） */
const FLY_FADE_MS = 300;
/** 一次飞行的总时长（毫秒） */
export const FLY_MS = FLY_MOVE_MS + FLY_FADE_MS;

/** 起步马上提速（加速段短）、之后一路减速（减速段长），到点速度正好为 0 */
const FLY_EASING = 'cubic-bezier(.25, 0, .25, 1)';

/** 长宽比超过这个数就算「又长又扁」的条状区 */
const THIN_RATIO = 3;

/** 收起来（飞向牌区）时的缩放 */
const SHRINK = 0.75;

/** 贴边留的空隙（画布坐标）：一张牌缩到 `SHRINK` 后会内缩那么多，两条边就按它留缝（用户 2026-10-16 定） */
const EDGE_GAP = CARD_W * (1 - SHRINK) / 2;

/** 条状区（长宽比 > 3）只认它那对长边：横向长的用上下边（纵向对接），纵向长的用左右边（横向对接） */
function thinAxis(to: DOMRect): 'x' | 'y' | null {
    const long = Math.max(to.width, to.height);
    const short = Math.max(Math.min(to.width, to.height), 1);
    if (long / short <= THIN_RATIO) {
        return null;
    }
    return to.width > to.height ? 'y' : 'x';
}

/** 让牌的最近那条边与目标区域的最近那条边接上（两条边的中点对接），返回位移与缩放的支点；`slot` = 直接盖在那一格牌上 */
function meetOffset(from: DOMRect, to: DOMRect, slot: boolean): { x: number; y: number; origin: string } {
    const fromX = from.left + from.width / 2;
    const fromY = from.top + from.height / 2;
    const toX = to.left + to.width / 2;
    const toY = to.top + to.height / 2;
    const scale = stageScale();
    if (slot) {
        return { x: toX - fromX, y: toY - fromY, origin: 'center center' };
    }
    const dx = toX - fromX;
    const dy = toY - fromY;
    const gap = EDGE_GAP * scale;
    const axis = thinAxis(to);
    if (axis === 'x' || (axis === null && Math.abs(dx) > Math.abs(dy))) {
        // 横向：往右飞就用组里最右侧那条边贴近目标左边，往左飞就用最左侧那条边贴近目标右边
        const cardX = dx > 0 ? from.left + from.width : from.left;
        const zoneX = dx > 0 ? to.left - gap : to.left + to.width + gap;
        // 缩放支点钉在贴上去的那条边上：否则缩小会把这条边拉回来，且牌越多拉得越多
        return { x: zoneX - cardX, y: toY - fromY, origin: dx > 0 ? 'right center' : 'left center' };
    }
    // 纵向：牌在上 ⇒ 牌的下边贴近目标上边，牌在下 ⇒ 上边贴近下边
    const cardY = dy > 0 ? from.top + from.height : from.top;
    const zoneY = dy > 0 ? to.top - gap : to.top + to.height + gap;
    return { x: toX - fromX, y: zoneY - cardY, origin: dy > 0 ? 'center bottom' : 'center top' };
}

/** 让一张浮层的牌从 from 沿这条曲线飞到 to（`slot` = 盖在那一格牌上，否则贴到区域的边上） */
export function flyGhost(el: HTMLElement, from: DOMRect, to: DOMRect, endScale = 0.75, slot = false): void {
    const stage = document.querySelector<HTMLElement>('#stage');
    if (!stage) {
        return;
    }
    const stageRect = stage.getBoundingClientRect();
    const scale = Math.max(stageRect.width, 1) / STAGE_W;
    el.style.position = 'absolute';
    el.style.left = `${(from.left - stageRect.left) / scale}px`;
    el.style.top = `${(from.top - stageRect.top) / scale}px`;
    el.style.margin = '0';
    el.style.pointerEvents = 'none';
    el.style.zIndex = '30';
    stage.appendChild(el);
    const meet = meetOffset(from, to, slot);
    el.style.transformOrigin = meet.origin;
    const arrive = `translate(${meet.x / scale}px, ${meet.y / scale}px) scale(${endScale})`;
    const anim = el.animate([
        { transform: 'translate(0px, 0px) scale(1)', opacity: 1, offset: 0, easing: FLY_EASING },
        { transform: arrive, opacity: 1, offset: FLY_MOVE_MS / FLY_MS },
        { transform: arrive, opacity: 0, offset: 1 },
    ], { duration: FLY_MS });
    anim.addEventListener('finish', () => el.remove());
}

/** 这一组的起点矩形：第一张牌上一帧在哪儿，往右摊成 `count` 张的总宽；没记过就看来处那个区 */
function sourceRect(agent: Agent, move: Proto.CardMove, count: number): DOMRect | null {
    const cached = move.id === undefined ? undefined : prev.get(move.id);
    if (cached) {
        return new DOMRect(cached.left, cached.top, cached.width * count, cached.height);
    }
    const place = locateZone(agent, move.from);
    return place ? inZone(place.rect, count) : null;
}

/** 播一批同向的卡牌移动（`skip` 里的牌另有专门的表现，就不重复飞了）；多张就横排成一组一起飞 */
export function playMoves(agent: Agent, moves: Proto.CardMove[], skip: number[]): void {
    const list = moves.filter((move) => move.id === undefined || !skip.includes(move.id));
    if (list.length === 0) {
        return;
    }
    const flying = list.length > GROUP_MAX ? list.slice(0, 1) : list;
    const from = sourceRect(agent, flying[0], flying.length);
    const to = locateZone(agent, flying[0].to);
    if (!from || !to) {
        return;
    }
    // 落到哪儿用的是「整组的边」，所以多张的落点是整条排贴住目标
    const ghost = flying.length === 1 ? ghostOf(flying[0].face) : ghostGroup(flying.map((move) => move.face));
    ghost.dataset.move = `${flying[0].from} → ${flying[0].to}${flying.length > 1 ? ` ×${flying.length}` : ''}`;
    // 打到桌上（无主区）的牌是「放大摆出来」，别的都是「收起来」
    flyGhost(ghost, from, to.rect, flying[0].to === '#0' ? 1.4 : SHRINK, to.slot);
}
