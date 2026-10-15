import { html } from 'htm/preact';
import { useEffect, useRef, useState } from 'preact/hooks';
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
import { EMPTY, candidates, toggle, type Selection } from './pick';
import { attr, cardFaceOf, heroName, seatCards, zoneCards } from './format';
import { seatSlots } from './seats';

/** 桌面正中那张牌摆多久（毫秒） */
const SHOWN_MS = 2200;
/** 跳字停留多久（毫秒） */
const POP_MS = 900;

/** 桌面正中展示的那张牌 */
interface Shown {
    /** 实体牌的号（已经出掉的，用来把手牌里那张先藏起来） */
    ids: number[];
    /** 牌面（出牌那一刻抄下来的） */
    face: Proto.CardFace;
    /** 飞过来的起点（屏幕上量的；量不到就不飞） */
    from: DOMRect | null;
    /** 打给谁 */
    to: number[];
    /** 这批展示的记号（到点清空时认一下） */
    key: number;
}

interface PopRef extends Pop {
    player: number;
}

/** 除我以外的人，按「从我起的座位顺序」排 */
function seatOffset(player: Proto.Player, mySeat: number, total: number): number {
    return ((player.base.seat - mySeat) % total + total) % total;
}

/** 舞台元素（量坐标用） */
function stageEl(): HTMLElement | null {
    return document.querySelector<HTMLElement>('#stage');
}

/** 牌桌 */
export function App(props: { agent: Agent; events: GameEvent[] }) {
    const { agent } = props;
    const [selection, setSelection] = useState<Selection>(EMPTY);
    const [shown, setShown] = useState<Shown | null>(null);
    const [pops, setPops] = useState<PopRef[]>([]);
    const [drawer, setDrawer] = useState(false);
    const nextKey = useRef(1);
    const ask = agent.asks[0] ?? null;

    // 换一条询问就把勾的清掉
    useEffect(() => {
        setSelection(EMPTY);
    }, [ask?.id]);

    // 表现事件：现在只有跳字（牌的位置由状态自己更新）
    useEffect(() => {
        for (const event of props.events) {
            if (event.kind !== 'health') {
                continue;
            }
            const key = nextKey.current++;
            setPops((list) => [...list, { player: event.player, key, delta: event.delta }]);
            window.setTimeout(() => setPops((list) => list.filter((one) => one.key !== key)), POP_MS);
        }
    }, [props.events]);

    // 桌面正中那张牌：从手里飞过来
    useEffect(() => {
        if (!shown?.from) {
            return;
        }
        const el = document.querySelector<HTMLElement>('[data-fly="shown"]');
        const stage = stageEl();
        if (!el || !stage) {
            return;
        }
        const to = el.getBoundingClientRect();
        const scale = Math.max(stage.getBoundingClientRect().width, 1) / 1280;
        el.animate([
            { transform: `translate(${(shown.from.left - to.left) / scale}px, ${(shown.from.top - to.top) / scale}px)` },
            { transform: 'translate(0px, 0px)' },
        ], { duration: 300, easing: 'cubic-bezier(.35,.7,.35,1)' });
    }, [shown]);

    const me = agent.me === null ? null : agent.players.get(agent.me) ?? null;
    const total = Math.max(agent.seats, agent.players.size, 1);
    const slots = seatSlots(total);
    const others = [...agent.players.values()]
        .filter((player) => player.base.id !== agent.me)
        .sort((left, right) => seatOffset(left, me?.base.seat ?? 1, total) - seatOffset(right, me?.base.seat ?? 1, total));
    const mine = me ? seatCards(agent, me.base.id) : null;
    const handIds = (mine?.hand ?? []).filter((id) => !(shown?.ids ?? []).includes(id));
    const cand = candidates(ask ?? undefined, selection);

    const pickCard = (id: number) => {
        if (!ask) {
            return;
        }
        if (ask.method === 'Ask.Select' || ask.method === 'Ask.UseSkill' || selection.viewAs !== null) {
            setSelection({ ...selection, cards: toggle(selection.cards, id) });
            return;
        }
        setSelection({ ...selection, option: id, players: [] });
    };
    const pickPlayer = (id: number) => {
        setSelection({ ...selection, players: toggle(selection.players, id) });
    };

    /** 交一包上去：出牌的话顺带把牌摆到桌面正中 */
    const answer = (result: unknown) => {
        if (!ask) {
            return;
        }
        if (ask.method === 'Ask.Use' && selection.option !== null) {
            const key = nextKey.current++;
            const cardId = selection.option;
            const from = document
                .querySelector<HTMLElement>(`[data-fly="card:${cardId}"]`)
                ?.getBoundingClientRect() ?? null;
            setShown({
                ids: [cardId],
                face: cardFaceOf(agent, cardId) ?? {},
                from,
                to: selection.players,
                key,
            });
            window.setTimeout(() => setShown((now) => (now?.key === key ? null : now)), SHOWN_MS);
        }
        ask.answer(result);
    };

    const myName = me?.base.userName ?? '我';
    const shownTo = shown && shown.to.length > 0
        ? `${myName} → ${shown.to.map((id) => agent.playerLabel(id)).join('、')}`
        : '';

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
                <div class="pile">
                    <div class="stack"></div>
                    <div><div class="num">${zoneCards(agent, '抽牌', 0).length}</div><div class="cap">抽牌堆</div></div>
                </div>
                <div class="pile">
                    <div class="stack plain"></div>
                    <div><div class="num">${zoneCards(agent, '弃牌', 0).length}</div><div class="cap">弃牌堆</div></div>
                </div>
            </div>

            <div id="center">
                <div id="skillTip">
                    ${agent.turnPlayer === null ? '' : `轮到 ${agent.playerLabel(agent.turnPlayer)}${agent.phase ? ` · ${agent.phase}` : ''}`}
                </div>
                <div id="playedWrap">
                    ${shown ? html`<${Card}
                        agent=${agent}
                        id=${0}
                        face=${shown.face}
                        flyKey="shown"
                        big
                        glow
                    />` : null}
                </div>
                <div id="playedTo">${shownTo}</div>
            </div>

            ${others.map((player, index) => html`<${Seat}
                key=${player.base.id}
                agent=${agent}
                player=${player}
                left=${slots[index]?.left ?? 0}
                top=${slots[index]?.top ?? 0}
                active=${agent.turnPlayer === player.base.id}
                pickable=${cand.players.includes(player.base.id)}
                target=${selection.players.includes(player.base.id)}
                pops=${pops.filter((one) => one.player === player.base.id)}
                onClick=${cand.players.includes(player.base.id) ? () => pickPlayer(player.base.id) : undefined}
            />`)}

            ${me && mine ? html`<div id="me">
                <div id="meLeft">
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
                    <div id="meEquips"><${EquipList} agent=${agent} equip=${mine.equip} /></div>
                </div>
                <div id="meRight">
                    <${Hand}
                        agent=${agent}
                        ids=${handIds}
                        picked=${selection.cards}
                        pickable=${cand.cards.length > 0}
                        onPick=${pickCard}
                    />
                </div>
            </div>
            <div id="meSkills">
                ${[...agent.skills.values()]
                    .filter((skill) => skill.player === agent.me)
                    .sort((left, right) => left.id - right.id)
                    .map((skill) => html`<button
                        key=${skill.id}
                        class=${skill.auto ? 'auto' : ''}
                        title=${skill.auto ? '自动（点一下改手动）' : '手动（点一下改自动）'}
                        onClick=${() => void agent.changeSkillAuto(skill.id, !skill.auto)}
                    >${skill.name}</button>`)}
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

            ${drawer ? html`<${Drawer} agent=${agent} />` : null}
        </div>
    <//>`;
}
