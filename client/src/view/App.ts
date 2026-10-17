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
import { Stage } from './Stage';
import { EMPTY, candidates, pickCard, toggle, type Selection } from './pick';
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
    const [drawer, setDrawer] = useState(false);
    const [settingsOpen, setSettingsOpen] = useState(false);
    const [raw, setRaw] = useState('');
    /** 调试用：按几个人摆座位（空 = 按实际人数） */
    const [layoutSeats, setLayoutSeats] = useState<number | null>(null);
    const nextKey = useRef(1);
    const ask = agent.asks[0] ?? null;

    // 换一条询问就把勾的清掉
    useEffect(() => {
        setSelection(EMPTY);
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

    const onPickCard = (id: number) => {
        if (ask) {
            setSelection(pickCard(ask, selection, id));
        }
    };
    const pickPlayer = (id: number) => {
        setSelection({ ...selection, players: toggle(selection.players, id) });
    };

    /** 交一包上去（出牌那张由服务器回推的 `Card.Move` 上处理区） */
    const answer = (result: unknown) => {
        if (!ask) {
            return;
        }
        ask.answer(result);
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
                        picked=${selection.cards}
                        cand=${ask ? cand.cards : null}
                        onPick=${onPickCard}
                    /></div>
                </div>
                <div id="meRight">
                    <${Hand}
                        agent=${agent}
                        ids=${handIds}
                        picked=${selection.cards}
                        cand=${ask ? cand.cards : null}
                        onPick=${onPickCard}
                    />
                </div>
    </div>` : html`<div id="waiting">正在入座…</div>`}
            ${ask ? html`<${AskBar}
                agent=${agent}
                ask=${ask}
                selection=${selection}
                onSelection=${setSelection}
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
