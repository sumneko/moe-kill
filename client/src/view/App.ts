import { html } from 'htm/preact';
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'preact/hooks';
import type { Proto } from '../proto';
import type { Agent } from '../state/agent';
import type { GameEvent } from '../state/events';
import { Drawer } from '../debug/Drawer';
import { AskBar } from './Ask';
import { Card } from './Card';
import { EquipList } from './Equip';
import { Hand } from './Hand';
import { HeroCard, type Pop } from './HeroCard';
import { Seat } from './Seat';
import { SettingsCard } from './Settings';
import { MySkills } from './Skills';
import { Stage } from './Stage';
import { DOUBLE_MS, EMPTY, answerOf, canSubmit, candidates, initialSelection, pickCard, pickOne, toggle, type Selection } from './pick';
import { FLY_MS, measureCards, playMoves } from './anim';
import { attr, heroName, seatCards, zoneCards } from './format';
import { seatSlots } from './seats';

/** 一张牌多宽（与 `table.css` 的 `--card-w` 一致） */
const CARD_W = 72;
/** 记录区那条牌列的宽（与 `table.css` 的 `#center` 一致） */
const RECORD_W = 840;
/** 一条牌列里相邻两张的间距（默认不留空隙，与手牌一致） */
const RECORD_GAP = 0;
/** 挤到不能再挤时每张至少露多少 */
const RECORD_MIN_STEP = 16;
/** 换人开回合时，记录区那排影子向左淡出多久（毫秒） */
const RECORD_OUT_MS = 360;
/** 记录区来了新影子：从它右边多远滑进来（画布坐标） */
const RECORD_ENTER_X = 56;
/** 记录区影子挪位 / 进场的时长（毫秒） */
const RECORD_MOVE_MS = 260;
/** 跳字停留多久（毫秒） */
const POP_MS = 900;
/** 箭头两端各让开多少（画布坐标）：从立绘中心出发，别把线盖在立绘上 */
const ARROW_HEAD = 64;
const ARROW_TAIL = 58;
/** 一次使用 / 技能发动的箭头停留多久（毫秒） */
const USE_ARROW_MS = 2500;
/** 判定牌亮出来之后隔多久才打勾 / 叉（毫秒）—— 先让人看清判定牌，再看结果 */
const JUDGE_MARK_DELAY_MS = 1000;
/** 打完勾 / 叉之后还停多久（毫秒） */
const JUDGE_SHOW_MS = 1800;

/** 一支箭头（键用来区分选择期的箭头与各次使用期的箭头） */
interface Arrow {
    key: string;
    x1: number;
    y1: number;
    x2: number;
    y2: number;
    /** 线长（画出来用的 dash 长度） */
    length: number;
    /** 朝向（度） */
    angle: number;
    /** 到点淡出（全场用牌 / 技能那种有寿命的箭头） */
    fade: boolean;
}

/** 把一段线变成一支会射出去的箭头 */
function makeArrow(key: string, line: { x1: number; y1: number; x2: number; y2: number }, fade: boolean): Arrow {
    const dx = line.x2 - line.x1;
    const dy = line.y2 - line.y1;
    return {
        key,
        ...line,
        length: Math.hypot(dx, dy),
        angle: Math.atan2(dy, dx) * 180 / Math.PI,
        fade,
    };
}

/** 一个人往另一个人拉一条线（两端各让开一点） */
function shorten(from: { x: number; y: number }, to: { x: number; y: number }): { x1: number; y1: number; x2: number; y2: number } | null {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const length = Math.hypot(dx, dy);
    if (length <= ARROW_HEAD + ARROW_TAIL) {
        return null;
    }
    const ux = dx / length;
    const uy = dy / length;
    return {
        x1: from.x + ux * ARROW_HEAD,
        y1: from.y + uy * ARROW_HEAD,
        x2: to.x - ux * ARROW_TAIL,
        y2: to.y - uy * ARROW_TAIL,
    };
}

/** 一个元素中心在舞台坐标（1280×720）里的位置 */
function stageCenter(stage: HTMLElement, selector: string): { x: number; y: number } | null {
    const el = document.querySelector<HTMLElement>(selector);
    if (!el) {
        return null;
    }
    const rect = el.getBoundingClientRect();
    const stageRect = stage.getBoundingClientRect();
    const scale = Math.max(stageRect.width, 1) / 1280;
    return {
        x: (rect.left + rect.width / 2 - stageRect.left) / scale,
        y: (rect.top + rect.height / 2 - stageRect.top) / scale,
    };
}

/** 某个玩家的立绘中心（座位坐标；自己那份是 `#meLeft`） */
function playerCenter(stage: HTMLElement, id: number, me: number | null): { x: number; y: number } | null {
    if (id === me) {
        return stageCenter(stage, '#meLeft .portrait') ?? stageCenter(stage, '#meLeft');
    }
    return stageCenter(stage, `[data-fly="seat:${id}"] .portrait`) ?? stageCenter(stage, `[data-fly="seat:${id}"]`);
}

/** 记录区里的一条影子：这个回合打出过 / 弃过这张牌（之后它去哪都不再管） */
interface RecordedCard {
    key: number;
    face: Proto.CardFace;
}

/** 牌列里每张牌的左边缘：区里放得下就按间距排，放不下就重叠；张数越多越挤 */
function recordLefts(count: number): number[] {
    if (count <= 0) {
        return [];
    }
    const room = count > 1 ? (RECORD_W - CARD_W) / (count - 1) : 0;
    const step = Math.max(Math.min(CARD_W + RECORD_GAP, room), RECORD_MIN_STEP);
    const total = CARD_W + step * (count - 1);
    const start = (RECORD_W - total) / 2;
    return Array.from({ length: count }, (_, index) => start + index * step);
}

interface PopRef extends Pop {
    player: number;
}

/** 除我以外的人，按「从我起的座位顺序」排 */
function seatOffset(player: Proto.Player, mySeat: number, total: number): number {
    return ((player.base.seat - mySeat) % total + total) % total;
}

/** 牌桌 */
export function App(props: { agent: Agent; events: GameEvent[] }) {
    const { agent } = props;
    const [selection, setSelection] = useState<Selection>(EMPTY);
    const [records, setRecords] = useState<RecordedCard[]>([]);
    /** 换人开回合了、整排正在向左淡出 */
    const [leaving, setLeaving] = useState(false);
    /** 记录区每条影子算好的位置 */
    const placed = useRef(new Map<number, number>());
    /** 上一轮每条影子蹲在哪儿（用来算出「该滑多远」） */
    const wasLeft = useRef(new Map<number, number>());
    /** 换代号：清空记录区时 +1，用来丢掉那些还在飞、稍后才到的影子 */
    const gen = useRef(0);
    /** 上一眼看过的回合角色（换人就把记录区清掉） */
    const turnSeen = useRef<number | null>(null);
    const [pops, setPops] = useState<PopRef[]>([]);
    const [arrows, setArrows] = useState<Arrow[]>([]);
    /** 全场的使用牌 / 技能发动（画完到点自己消失） */
    const [uses, setUses] = useState<{ key: number; user: number; targets: number[] }[]>([]);
    /** 刚出结果的判定：中央亮一张判定牌，过一秒再打勾 / 叉，到点自己消失 */
    const [judgeShow, setJudgeShow] = useState<{ key: number; face: Proto.CardFace; passed: boolean; marked: boolean; reason?: string } | null>(null);
    const [drawer, setDrawer] = useState(false);
    const [settingsOpen, setSettingsOpen] = useState(false);
    const [raw, setRaw] = useState('');
    /** 调试用：按几个人摆座位（空 = 按实际人数） */
    const [layoutSeats, setLayoutSeats] = useState<number | null>(null);
    const nextKey = useRef(1);
    const ask = agent.asks[0] ?? null;
    /** 我自己的手牌：预选只对它们有意义（装备区的牌、别人的牌都不算） */
    const own = (() => {
        const seat = agent.me === null ? null : seatCards(agent, agent.me);
        return new Set(seat ? seat.hand : []);
    })();
    /** 上一次点的那张牌（判双击：双击一张「选了就能提交」的牌 = 直接用它） */
    const lastPick = useRef<{ id: number | null; at: number }>({ id: null, at: 0 });

    // 换一条询问就把勾的清掉（自己桌上只剩一张可选的那种先替他选上）
    useEffect(() => {
        setSelection(ask ? initialSelection(ask, own) : EMPTY);
        lastPick.current = { id: null, at: 0 };
    }, [ask?.id]);

    // 表现事件：跳字 + 卡牌移动（自己出的那张走「中央展示」那条路）
    useEffect(() => {
        // 同一批里按「从哪到哪」归组：一次移动多张就横排成一组一起飞（洗牌那种超量的由 anim 只飞一张）
        const groups = new Map<string, Proto.CardMove[]>();
        for (const event of props.events) {
            if (event.kind === 'health') {
                const key = nextKey.current++;
                setPops((list) => [...list, { player: event.player, key, delta: event.delta }]);
                window.setTimeout(() => setPops((list) => list.filter((one) => one.key !== key)), POP_MS);
                continue;
            }
            if (event.kind === 'recorded') {
                const key = nextKey.current++;
                const record: RecordedCard = { key, face: event.face };
                if (event.immediate) {
                    // 直接进弃牌堆的（弃置 / 判定后 / 阵亡清算）与中央那段飞行无关：立刻留痕
                    setRecords((list) => [...list, record]);
                    continue;
                }
                // 进临时区的那批还要在中央飞完，等飞行动画播完再出现（影子不跟这张牌的下落）
                const mine = gen.current;
                window.setTimeout(() => {
                    if (gen.current === mine) {
                        setRecords((list) => [...list, record]);
                    }
                }, FLY_MS);
                continue;
            }
            if (event.kind === 'use') {
                const key = nextKey.current++;
                setUses((list) => [...list, { key, user: event.user, targets: event.targets }]);
                window.setTimeout(() => {
                    setUses((list) => list.filter((one) => one.key !== key));
                }, USE_ARROW_MS);
                continue;
            }
            if (event.kind === 'judge') {
                const key = nextKey.current++;
                setJudgeShow({ key, face: event.face, passed: event.passed, marked: false, reason: event.reason });
                // 先亮牌，隔一秒再打勾 / 叉（看清牌面之后才看结果）
                window.setTimeout(() => {
                    setJudgeShow((now) => (now?.key === key ? { ...now, marked: true } : now));
                }, JUDGE_MARK_DELAY_MS);
                window.setTimeout(() => {
                    setJudgeShow((now) => (now?.key === key ? null : now));
                }, JUDGE_MARK_DELAY_MS + JUDGE_SHOW_MS);
                continue;
            }
            if (event.kind !== 'move') {
                continue;
            }
            const key = `${event.move.from}→${event.move.to}`;
            const list = groups.get(key);
            if (list) {
                list.push(event.move);
            } else {
                groups.set(key, [event.move]);
            }
        }
        for (const list of groups.values()) {
            playMoves(agent, list, []);
        }
        measureCards();
    }, [props.events]);

    // 重开一局：记录区的影子跟着清掉
    useEffect(() => {
        gen.current++;
        turnSeen.current = null;
        setLeaving(false);
        setRecords([]);
    }, [agent.over]);

    // 换人开回合：记录区整排向左淡出（那排影子只是「本回合出过 / 弃过哪些牌」的记忆）
    useEffect(() => {
        const now = agent.turnPlayer;
        const before = turnSeen.current;
        turnSeen.current = now;
        if (before === null || before === now) {
            return;
        }
        gen.current++;
        setLeaving(true);
        window.setTimeout(() => {
            setLeaving(false);
            setRecords([]);
        }, RECORD_OUT_MS);
    }, [agent.turnPlayer]);

    const me = agent.me === null ? null : agent.players.get(agent.me) ?? null;
    const meHp = me === null ? 1 : attr(me, '体力') ?? 1;
    const meDead = me !== null && !me.base.alive;
    const total = layoutSeats ?? Math.max(agent.seats, agent.players.size, 1);
    const slots = seatSlots(total);
    const others = [...agent.players.values()]
        .filter((player) => player.base.id !== agent.me)
        .sort((left, right) => seatOffset(left, me?.base.seat ?? 1, total) - seatOffset(right, me?.base.seat ?? 1, total));
    const mine = me ? seatCards(agent, me.base.id) : null;
    const handIds = mine?.hand ?? [];
    /** 我自己的阶段（不在我的回合里就是空） */
    const myPhase = agent.me !== null && agent.turnPlayer === agent.me ? agent.phase : null;
    const cand = candidates(ask ?? undefined, selection);
    /** 要画成「选上了」的牌：出牌阶段选中的那张在 `option` 里（技能的素材另算），一起算上 */
    const pickedCards = selection.option === null ? selection.cards : [...selection.cards, selection.option];

    // 选中的目标：从自己拉一条临时箭头过去（纯本地状态，提交 / 取消就没了）；
    // 另外全场任何人用牌 / 发动技能也画一段，到 `USE_ARROW_MS` 自动消失
    const picked = selection.players.join(',');
    useLayoutEffect(() => {
        const stage = document.querySelector<HTMLElement>('#stage');
        if (!stage) {
            setArrows([]);
            return;
        }
        const list: Arrow[] = [];
        const from = playerCenter(stage, agent.me ?? -1, agent.me);
        if (from) {
            for (const id of selection.players) {
                if (id === agent.me) {
                    continue;
                }
                const to = playerCenter(stage, id, agent.me);
                const line = to ? shorten(from, to) : null;
                if (line) {
                    list.push(makeArrow(`select:${id}`, line, false));
                }
            }
        }
        for (const use of uses) {
            const start = playerCenter(stage, use.user, agent.me);
            if (!start) {
                continue;
            }
            for (const id of use.targets) {
                if (id === use.user) {
                    continue;
                }
                const to = playerCenter(stage, id, agent.me);
                const line = to ? shorten(start, to) : null;
                if (line) {
                    list.push(makeArrow(`use:${use.key}:${id}`, line, true));
                }
            }
        }
        setArrows(list);
    }, [picked, uses, agent.me, agent.players.size, layoutSeats]);

    /** 交一包上去（出牌那张由服务器回推的 `Card.Move` 上处理区） */
    const answer = (result: unknown) => {
        if (!ask) {
            return;
        }
        ask.answer(result);
    };

    const onPickCard = (id: number) => {
        if (!ask) {
            return;
        }
        const now = Date.now();
        const doubled = lastPick.current.id === id && now - lastPick.current.at < DOUBLE_MS;
        lastPick.current = { id, at: now };
        // 双击 = 选上它并且立刻提交（不用自己再挑目标的、数量刚好凑够的那种派得上）
        if (doubled) {
            const only = pickOne(ask, selection, id);
            if (only) {
                setSelection(only);
                if (canSubmit(ask, only)) {
                    answer(answerOf(ask, only));
                }
                return;
            }
        }
        setSelection(pickCard(ask, selection, id));
    };
    const pickPlayer = (id: number) => {
        setSelection({ ...selection, players: toggle(selection.players, id) });
    };

    /** 把调试抽屉里手写的那一包原样交上去（写坏了就当空包） */
    const sendRaw = () => {
        if (!ask) {
            return;
        }
        try {
            answer(JSON.parse(raw || '{}'));
        } catch (err) {
            agent.log(`手写的那包读不出来：${err instanceof Error ? err.message : String(err)}`);
            answer({});
        }
    };

    /** 记录区那条尾巴：按发生先后排（新的靠右、盖住旧卡） */
    const rows = records;

    // 位置要在渲染期就算出来 —— 放 effect 里的话，第一帧会先落在 left:0（看着像从左边滑进来）
    useMemo(() => {
        const lefts = recordLefts(records.length);
        placed.current = new Map(records.map((one, index) => [one.key, lefts[index] ?? 0]));
    }, [records]);

    // 已经在那儿、又换了位子的影子滑过去；刚冒出来的从右侧淡入（与手牌同一种进场）
    useLayoutEffect(() => {
        for (const [id, left] of placed.current) {
            const el = document.querySelector<HTMLElement>(`[data-fly="record:${id}"]`);
            const before = wasLeft.current.get(id);
            if (before === undefined) {
                // 终值写 .45：与 table.css 里 #recordZone .card 的 opacity 一致，否则播完会跳一下
                el?.animate(
                    [
                        { transform: `translateX(${RECORD_ENTER_X}px)`, opacity: 0 },
                        { transform: 'translateX(0px)', opacity: 0.45 },
                    ],
                    { duration: RECORD_MOVE_MS, easing: 'cubic-bezier(.25, 0, .25, 1)' },
                );
                continue;
            }
            if (before === left) {
                continue;
            }
            el?.animate(
                [{ transform: `translateX(${before - left}px)` }, { transform: 'translateX(0px)' }],
                { duration: RECORD_MOVE_MS, easing: 'cubic-bezier(.25, 0, .25, 1)' },
            );
        }
        wasLeft.current = new Map(placed.current);
    });

    return html`<${Stage}>
        <div class="root">
            <div id="topbar">
                <span class=${`tag${agent.connected ? ' ok' : ''}`}>${agent.connected ? '已连接' : '没连上'}</span>
                <span class="spacer"></span>
                ${agent.over ? html`<span class="tag over">终局：${agent.over.side} —— ${agent.over.reason}</span>
                    <button onClick=${() => void agent.restart()}>再来一局</button>` : null}
                <button onClick=${() => setSettingsOpen(!settingsOpen)}>设置</button>
                ${agent.debug ? html`<button onClick=${() => void agent.resync()}>重新同步</button>
                    <button onClick=${() => setDrawer(!drawer)}>调试抽屉</button>` : null}
            </div>
            ${settingsOpen ? html`<${SettingsCard} agent=${agent} onClose=${() => setSettingsOpen(false)} />` : null}

            <div id="corner">
                <div class="pile deck">
                    <div class="stack"></div>
                    <div><div class="num">${zoneCards(agent, '抽牌', 0).length}</div><div class="cap">抽牌堆</div></div>
                </div>
                <div class="pile discard">
                    <div class="stack plain"></div>
                    <div><div class="num">${zoneCards(agent, '弃牌', 0).length}</div><div class="cap">弃牌堆</div></div>
                </div>
            </div>

            ${myPhase ? html`<div id="myPhase">${myPhase}阶段</div>` : null}

            <div id="center">
                <div id="recordZone" class=${leaving ? 'leaving' : undefined}>
                    ${rows.map((one, index) => html`<${Card}
                        key=${one.key}
                        agent=${agent}
                        id=${one.key}
                        face=${one.face}
                        flyKey=${`record:${one.key}`}
                        style=${`left: ${placed.current.get(one.key) ?? 0}px; z-index: ${index}`}
                    />`)}
                </div>
            </div>

            ${judgeShow ? html`<div id="judgeShow" key=${judgeShow.key}>
                <${Card} agent=${agent} id=${-1} face=${judgeShow.face} />
                ${judgeShow.marked
                    ? html`<span class=${`mark ${judgeShow.passed ? 'ok' : 'no'}`}>${judgeShow.passed ? '✓' : '✗'}</span>`
                    : null}
            </div>` : null}

            ${slots.map((slot, index) => {
                const player = others[index];
                if (!player) {
                    return html`<div class="seat" key=${`vacant:${index}`} style=${`left:${slot.left}px;top:${slot.top}px`}>
                        <div class="portrait vacant">空位</div>
                    </div>`;
                }
                return html`<${Seat}
                    key=${player.base.id}
                    agent=${agent}
                    player=${player}
                    left=${slot.left}
                    top=${slot.top}
                    active=${agent.turnPlayer === player.base.id}
                    pickable=${cand.players.includes(player.base.id)}
                    target=${selection.players.includes(player.base.id)}
                    pops=${pops.filter((one) => one.player === player.base.id)}
                    onClick=${cand.players.includes(player.base.id) ? () => pickPlayer(player.base.id) : undefined}
                />`;
            })}

            ${me && mine ? html`<div id="me">
                <div
                    id="meLeft"
                    class=${[
                        cand.players.includes(me.base.id) ? 'pickable' : '',
                        selection.players.includes(me.base.id) ? 'target' : '',
                    ].filter((one) => one.length > 0).join(' ')}
                    onClick=${cand.players.includes(me.base.id) ? () => pickPlayer(me.base.id) : undefined}
                >
                    <div id="meHead">
                        <span class="hero">${heroName(me) ?? '未选将'}</span>
                        <span class="pname">${me.base.userName}</span>
                    </div>
                    <${HeroCard}
                        agent=${agent}
                        player=${me}
                        hand=${handIds.length}
                        judges=${mine.judging}
                        dead=${meDead}
                        dying=${!meDead && meHp <= 0}
                        pops=${pops.filter((one) => one.player === me.base.id)}
                    />
                    <div id="meEquips"><${EquipList}
                        agent=${agent}
                        owner=${me.base.id}
                        equip=${mine.equip}
                        picked=${pickedCards}
                        cand=${ask ? cand.cards : null}
                        onPick=${onPickCard}
                    /></div>
                </div>
                <div id="meRight">
                    <${Hand}
                        agent=${agent}
                        ids=${handIds}
                        picked=${pickedCards}
                        cand=${ask ? cand.cards : null}
                        onPick=${onPickCard}
                    />
                </div>
    </div>` : html`<div id="waiting">正在入座…</div>`}
            <svg id="arrows" viewBox="0 0 1280 720">
                ${arrows.map((one) => html`<g
                    key=${one.key}
                    class=${one.fade ? 'arrow fade' : 'arrow'}
                    style=${`--x1:${one.x1}px;--y1:${one.y1}px;--x2:${one.x2}px;--y2:${one.y2}px;--angle:${one.angle}deg;--len:${one.length}px;--fade-ms:${USE_ARROW_MS}ms`}
                >
                    <line x1=${one.x1} y1=${one.y1} x2=${one.x2} y2=${one.y2} />
                    <polygon class="head" points="0,0 -14,-5.5 -14,5.5" />
                </g>`)}
            </svg>
            <${MySkills} agent=${agent} />
            ${ask ? html`<${AskBar}
                agent=${agent}
                ask=${ask}
                selection=${selection}
                onSelection=${setSelection}
                onPickCard=${onPickCard}
                onAnswer=${answer}
            />` : null}

            ${agent.over ? html`<div id="over">
                <h2>${agent.over.side}</h2>
                <p>${agent.over.reason}</p>
            </div>` : null}

            ${drawer ? html`<${Drawer}
                agent=${agent}
                raw=${raw}
                onRawChange=${setRaw}
                onSend=${sendRaw}
                layoutSeats=${layoutSeats}
                onLayout=${setLayoutSeats}
            />` : null}
        </div>
    <//>`;
}
