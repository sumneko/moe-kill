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
import { Stage } from './Stage';
import { EMPTY, candidates, pickCard, pickSkill, toggle, type Selection } from './pick';
import { FLY_MS, measureCards, playMoves } from './anim';
import { attr, heroName, seatCards, zoneCards } from './format';
import { seatSlots } from './seats';

/** 一张牌多宽（与 `table.css` 的 `--card-w` 一致） */
const CARD_W = 72;
/** 处理区那条牌列的宽（与 `table.css` 的 `#center` 一致） */
const PLAYED_W = 840;
/** 一条牌列里相邻两张的间距（默认不留空隙，与手牌一致） */
const PLAYED_GAP = 0;
/** 挤到不能再挤时每张至少露多少 */
const PLAYED_MIN_STEP = 16;
/** 换人开回合时，处理区那排影子向左淡出多久（毫秒） */
const PLAYED_OUT_MS = 360;
/** 处理区来了新影子：从它右边多远滑进来（画布坐标） */
const PLAYED_ENTER_X = 56;
/** 处理区影子挪位 / 进场的时长（毫秒） */
const PLAYED_MOVE_MS = 260;
/** 跳字停留多久（毫秒） */
const POP_MS = 900;

/** 处理区里的一条影子：这个回合有人打出过这张牌（之后它去哪都不再管） */
interface Ghost {
    key: number;
    face: Proto.CardFace;
}

/** 牌列里每张牌的左边缘：区里放得下就按间距排，放不下就重叠；张数越多越挤 */
function placedLefts(count: number): number[] {
    if (count <= 0) {
        return [];
    }
    const room = count > 1 ? (PLAYED_W - CARD_W) / (count - 1) : 0;
    const step = Math.max(Math.min(CARD_W + PLAYED_GAP, room), PLAYED_MIN_STEP);
    const total = CARD_W + step * (count - 1);
    const start = (PLAYED_W - total) / 2;
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
    const [ghosts, setGhosts] = useState<Ghost[]>([]);
    /** 换人开回合了、整排正在向左淡出 */
    const [leaving, setLeaving] = useState(false);
    /** 处理区每条影子算好的位置 */
    const placedLeft = useRef(new Map<number, number>());
    /** 上一轮每条影子蹲在哪儿（用来算出「该滑多远」） */
    const wasLeft = useRef(new Map<number, number>());
    /** 换代号：清空处理区时 +1，用来丢掉那些还在飞、稍后才到的影子 */
    const gen = useRef(0);
    /** 上一眼看过的回合角色（换人就把处理区清掉） */
    const turnSeen = useRef<number | null>(null);
    const [pops, setPops] = useState<PopRef[]>([]);
    const [drawer, setDrawer] = useState(false);
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
            if (event.kind === 'entered') {
                // 牌搬进处理区：等飞行动画播完，再在原位留一条影子（影子不跟这张牌的下落）
                const key = nextKey.current++;
                const ghost: Ghost = { key, face: event.face };
                const mine = gen.current;
                window.setTimeout(() => {
                    if (gen.current === mine) {
                        setGhosts((list) => [...list, ghost]);
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

    // 重开一局：处理区的影子跟着清掉
    useEffect(() => {
        gen.current++;
        turnSeen.current = null;
        setLeaving(false);
        setGhosts([]);
    }, [agent.over]);

    // 换人开回合：处理区整排向左淡出（那排影子只是「本回合出过哪些牌」的记忆）
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
            setGhosts([]);
        }, PLAYED_OUT_MS);
    }, [agent.turnPlayer]);

    const me = agent.me === null ? null : agent.players.get(agent.me) ?? null;
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

    /** 这条询问里能不能发动这个技能（能就返回「选中它」的点击处理器，不能就空） */
    const fireable = (skillId: number): (() => void) | null => {
        if (ask?.method !== 'Ask.UseSkill') {
            return null;
        }
        const plans = ((ask.params as any).skills ?? []) as Proto.SkillPlan[];
        if (!plans.some((one) => one.id === skillId)) {
            return null;
        }
        return () => setSelection(pickSkill(ask, selection, skillId));
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

    /** 处理区那条尾巴：按出牌先后排（新的靠右、盖住旧卡） */
    const rows = ghosts;

    // 位置要在渲染期就算出来 —— 放 effect 里的话，第一帧会先落在 left:0（看着像从左边滑进来）
    useMemo(() => {
        const lefts = placedLefts(ghosts.length);
        placedLeft.current = new Map(ghosts.map((one, index) => [one.key, lefts[index] ?? 0]));
    }, [ghosts]);

    // 已经在那儿、又换了位子的影子滑过去；刚冒出来的从右侧淡入（与手牌同一种进场）
    useLayoutEffect(() => {
        for (const [id, left] of placedLeft.current) {
            const el = document.querySelector<HTMLElement>(`[data-fly="played:${id}"]`);
            const before = wasLeft.current.get(id);
            if (before === undefined) {
                // 终值写 .45：与 table.css 里 #playedZone .card 的 opacity 一致，否则播完会跳一下
                el?.animate(
                    [
                        { transform: `translateX(${PLAYED_ENTER_X}px)`, opacity: 0 },
                        { transform: 'translateX(0px)', opacity: 0.45 },
                    ],
                    { duration: PLAYED_MOVE_MS, easing: 'cubic-bezier(.25, 0, .25, 1)' },
                );
                continue;
            }
            if (before === left) {
                continue;
            }
            el?.animate(
                [{ transform: `translateX(${before - left}px)` }, { transform: 'translateX(0px)' }],
                { duration: PLAYED_MOVE_MS, easing: 'cubic-bezier(.25, 0, .25, 1)' },
            );
        }
        wasLeft.current = new Map(placedLeft.current);
    });

    return html`<${Stage}>
        <div class="root">
            <div id="topbar">
                <span class=${`tag${agent.connected ? ' ok' : ''}`}>${agent.connected ? '已连接' : '没连上'}</span>
                <button onClick=${() => void agent.resync()}>重新同步</button>
                <span class="spacer"></span>
                ${agent.over ? html`<span class="tag over">终局：${agent.over.side} —— ${agent.over.reason}</span>
                    <button onClick=${() => void agent.restart()}>再来一局</button>` : null}
                <button onClick=${() => setDrawer(!drawer)}>调试抽屉</button>
            </div>

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
                <div id="playedZone" class=${leaving ? 'leaving' : undefined}>
                    ${rows.map((one, index) => html`<${Card}
                        key=${one.key}
                        agent=${agent}
                        id=${one.key}
                        face=${one.face}
                        flyKey=${`played:${one.key}`}
                        style=${`left: ${placedLeft.current.get(one.key) ?? 0}px; z-index: ${index}`}
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
                        dead=${(attr(me, '体力') ?? 1) <= 0}
                        pops=${pops.filter((one) => one.player === me.base.id)}
                    />
                    <div id="meEquips"><${EquipList}
                        agent=${agent}
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
            </div>
            <div id="meSkills">
                ${[...agent.skills.values()]
                    .filter((skill) => skill.player === agent.me)
                    .sort((left, right) => left.id - right.id)
                    .map((skill) => {
                        const fire = fireable(skill.id);
                        const cls = [
                            skill.auto ? 'auto' : '',
                            fire ? 'fire' : '',
                            selection.skill === skill.id ? 'on' : '',
                        ].filter((one) => one.length > 0).join(' ');
                        return html`<button
                            key=${skill.id}
                            class=${cls}
                            title=${fire
                                ? `发动「${skill.name}」`
                                : (skill.auto ? '自动（点一下改手动）' : '手动（点一下改自动）')}
                            onClick=${fire ?? (() => void agent.changeSkillAuto(skill.id, !skill.auto))}
                        >${skill.name}</button>`;
                    })}
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
