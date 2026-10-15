import { html } from 'htm/preact';
import { useEffect, useState } from 'preact/hooks';
import type { Agent, Ask } from './agent';
import type { Proto } from './proto';

/** 花色符号 */
const SUITS: Record<string, string> = { 黑桃: '♠', 红桃: '♥', 梅花: '♣', 方块: '♦' };

/** 后端默认听这个口 */
const DEFAULT_PORT = 31415;

/** 这次询问勾了些什么（换一条询问就清空） */
export interface Selection {
    /** 选中的牌（候选里那些） */
    cards: number[];
    /** 选中的玩家 */
    players: number[];
    /** 选中的武将全名（Ask.Hero） */
    heroes: string[];
    /** 选中的技能（Ask.UseSkill） */
    skill: number | null;
    /** Ask.Use：选中的那张选项牌（决定目标候选） */
    option: number | null;
}

const EMPTY: Selection = { cards: [], players: [], heroes: [], skill: null, option: null };

/** 装备子区（列装备牌的顺序就是这个顺序） */
const EQUIP_ZONES = ['武器', '防具', '进攻马', '防御马'];

/** 按区域串取一叠牌（区域串给名字与主人号，主人号 0 = 无主） */
function zoneCards(agent: Agent, name: string, owner: number): number[] {
    const want = `${name}#${owner}`;
    return [...agent.cards.values()].filter((card) => card.zone === want).map((card) => card.id);
}

/** 一个座位身上的牌：手牌 / 装备四子区 / 判定区 */
function seatCards(agent: Agent, id: number) {
    const mine = [...agent.cards.values()].filter((card) => (card.zone ?? '').endsWith(`#${id}`));
    const of = (names: string[]) => mine.filter((card) => names.includes((card.zone ?? '').split('#')[0] ?? '')).map((card) => card.id);
    const equip: Record<string, number[]> = {};
    for (const name of EQUIP_ZONES) {
        equip[name] = of([name]);
    }
    return {
        hand: of(['手牌']),
        equip,
        judging: of(['判定']),
    };
}

/** 一张牌现在的牌面：「转化」(`modifier`) 叠在牌自己那份 (`face`) 上；看不见牌面就没值 */
function cardFace(agent: Agent, id: number): Proto.CardFace | undefined {
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

/** 牌面是不是被「转化」改过（同名同花色的那份 modifier —— 比如延时锦囊给实体牌挂的那份 —— 不算） */
function isConverted(card: Proto.Card | undefined): boolean {
    const modifier = card?.modifier;
    if (!modifier) {
        return false;
    }
    return (modifier.name !== undefined && modifier.name !== card.face?.name)
        || (modifier.suit !== undefined && modifier.suit !== card.face?.suit)
        || (modifier.point !== undefined && modifier.point !== card.face?.point);
}

/** 一张牌的写法（看不见牌面就写「背面」） */
function cardLabel(agent: Agent, id: number): string {
    const face = cardFace(agent, id);
    if (!face) {
        return '背面';
    }
    const suit = SUITS[face.suit ?? ''] ?? face.suit ?? '';
    return `${face.name ?? '?'}${suit}${face.point ?? ''}`;
}

/** 协议层的展示模板串（`${suit:红桃}` ⇒ ♥、`${hero:刘备}` ⇒ 刘备）；认不出的原样显示 */
function renderMark(mark: string): string {
    const match = /^\$\{(\w+):(.+)\}$/.exec(mark);
    const kind = match?.[1];
    const value = match?.[2] ?? '';
    if (kind === 'suit') {
        return SUITS[value] ?? value;
    }
    return match ? value : mark;
}

/** 牌面：花色红黑分开上色；`marks` 是挂在它身上的展示标记 */
function CardView(props: {
    agent: Agent;
    id: number;
    picked?: boolean;
    off?: boolean;
    marks?: string[];
    draggable?: boolean;
    onClick?: () => void;
    onDragStart?: () => void;
    onDrop?: (event: DragEvent) => void;
}) {
    const card = props.agent.cards.get(props.id);
    const face = cardFace(props.agent, props.id);
    const suit = face?.suit ?? '';
    const red = suit === '红桃' || suit === '方块';
    const converted = isConverted(card);
    return html`<button
        class=${'card' + (props.picked ? ' picked' : '') + (props.off ? ' off' : '') + (face ? '' : ' hidden')}
        disabled=${props.onClick ? undefined : true}
        draggable=${props.draggable ? true : undefined}
        title=${converted ? `转化自「${card?.face?.name ?? '背面'}」` : undefined}
        onClick=${props.onClick}
        onDragStart=${props.onDragStart}
        onDrop=${props.onDrop}
    >
        <span class="suit ${red ? 'red' : 'black'}">${SUITS[suit] ?? ''}</span>
        <span class="name">${face?.name ?? '背面'}</span>
        <span class="point">${face?.point ?? ''}</span>
        ${converted ? html`<span class="mark convert">转</span>` : null}
        ${(props.marks ?? []).map((mark, index) => html`<span class="mark" key=${index}>${renderMark(mark)}</span>`)}
    </button>`;
}

/** 一排牌 */
function Cards(props: { agent: Agent; ids: number[]; picked?: number[]; onPick?: (id: number) => void }) {
    if (props.ids.length === 0) {
        return html`<span class="muted">——</span>`;
    }
    return html`<div class="cards">
        ${props.ids.map((id) => html`<${CardView}
            key=${id}
            agent=${props.agent}
            id=${id}
            picked=${props.picked?.includes(id)}
            onClick=${props.onPick ? () => props.onPick?.(id) : undefined}
        />`)}
    </div>`;
}

/** 一个座位：名字、武将、身份、体力、技能、装备四子区与判定区的牌 */
function Seat(props: {
    agent: Agent;
    player: Proto.Player;
    isTurn: boolean;
    isMe: boolean;
    picked: boolean;
    onPick?: () => void;
}) {
    const { agent, player } = props;
    const zoned = seatCards(agent, player.base.id);
    const identity = player.custom?.['identity'];
    const hero = player.custom?.['heroName'];
    const skills = [...agent.skills.values()]
        .filter((one) => one.player === player.base.id)
        .sort((left, right) => left.id - right.id);
    const health = player.attributes.find((one) => one.name === '体力')?.value;
    const maxHealth = player.attributes.find((one) => one.name === '体力上限')?.value;
    return html`<div
        class=${'seat' + (props.isTurn ? ' turn' : '') + (props.isMe ? ' me' : '') + (props.picked ? ' picked' : '')}
        onClick=${props.onPick}
    >
        <div class="who">
            <b>${player.base.userName || `座位 ${player.base.seat}`}</b>
            ${hero ? html`<span class="hero">${String(hero)}</span>` : null}
            ${identity ? html`<span class="tag">${String(identity)}</span>` : null}
            ${props.isMe ? html`<span class="tag">我</span>` : null}
        </div>
        <div class="hp">
            体力 ${health ?? '?'}${maxHealth === undefined ? '' : ` / ${maxHealth}`} · 手牌 ${zoned.hand.length}
        </div>
        ${skills.length > 0 ? html`<div class="skills">${skills.map((skill) => html`<span
            key=${skill.id}
            class=${'skill' + (skill.auto ? ' auto' : '') + (skill.disabled ? ' off' : '')}
        >${skill.name}</span>`)}</div>` : null}
        <div class="zones">
            ${EQUIP_ZONES.map((name) => html`<div class="zone" key=${name}>
                <span class="zone-name">${name}</span>
                <${Cards} agent=${agent} ids=${zoned.equip[name] ?? []} />
            </div>`)}
            <div class="zone">
                <span class="zone-name">判定</span>
                <${Cards} agent=${agent} ids=${zoned.judging} />
            </div>
        </div>
    </div>`;
}

/** 棋盘：四周座位 + 中间牌堆 / 弃牌堆 + 我自己的手牌 */
function Board(props: { agent: Agent; selection: Selection; setSelection: (next: Selection) => void; pickable: boolean }) {
    const { agent, selection, setSelection } = props;
    const players = [...agent.players.values()].sort((left, right) => left.base.seat - right.base.seat);
    const me = agent.me === null ? null : agent.players.get(agent.me) ?? null;
    const myHand = me ? seatCards(agent, me.base.id).hand : [];

    const togglePlayer = (id: number) => {
        if (!props.pickable) {
            return;
        }
        setSelection({
            ...selection,
            players: selection.players.includes(id)
                ? selection.players.filter((one) => one !== id)
                : [...selection.players, id],
        });
    };

    return html`<section class="board">
        <div class="seats">
            ${players.map((player) => html`<${Seat}
                key=${player.base.id}
                agent=${agent}
                player=${player}
                isTurn=${agent.turnPlayer === player.base.id}
                isMe=${agent.me === player.base.id}
                picked=${selection.players.includes(player.base.id)}
                onPick=${() => togglePlayer(player.base.id)}
            />`)}
        </div>
        <div class="middle">
            <div class="pile">抽牌堆 ${zoneCards(agent, '抽牌', 0).length}</div>
            <div class="pile">弃牌堆 ${zoneCards(agent, '弃牌', 0).length}</div>
            <div class="turn">
                回合 ${agent.turnPlayer === null ? '——' : agent.playerLabel(agent.turnPlayer)} · 阶段 ${agent.phase ?? '——'}
                ${agent.over ? html`<div class="over">终局：${agent.over.side} —— ${agent.over.reason}</div>` : null}
            </div>
        </div>
        <div class="mine">
            <div class="label">我的手牌</div>
            <${Cards}
                agent=${agent}
                ids=${myHand}
                picked=${selection.cards}
                onPick=${props.pickable ? (id: number) => setSelection({
                    ...selection,
                    cards: selection.cards.includes(id)
                        ? selection.cards.filter((one) => one !== id)
                        : [...selection.cards, id],
                }) : undefined}
            />
        </div>
    </section>`;
}

/** 候选（`ids` 里挑 `min~max` 个）用一句话说清 */
function planText(plan: { min: number; max: number }): string {
    return plan.min === plan.max ? `${plan.min} 个` : `${plan.min}~${plan.max} 个`;
}

/** 选项按钮（点一下勾上 / 取消） */
function Chips(props: { agent: Agent; ids: number[]; picked: number[]; onPick: (id: number) => void; cards?: boolean }) {
    return html`<div class="chips">
        ${props.ids.map((id) => {
            const on = props.picked.includes(id);
            return html`<button
                key=${id}
                class=${'chip' + (on ? ' on' : '')}
                onClick=${() => props.onPick(id)}
            >${props.cards ? cardLabel(props.agent, id) : props.agent.playerLabel(id)}</button>`;
        })}
    </div>`;
}

/** 询问面板：按询问类型给控件（不认识的类型给一串手写兜底，别静默） */
function AskPanel(props: { agent: Agent; selection: Selection; setSelection: (next: Selection) => void }) {
    const { agent, selection, setSelection } = props;
    const ask: Ask | undefined = agent.asks[0];
    const [left, setLeft] = useState(0);
    const [dragCard, setDragCard] = useState<number | null>(null);

    // 限时倒计时（从收到询问那一刻算）
    useEffect(() => {
        if (!ask) {
            return;
        }
        const limit = (ask.params as any).timeLimit as number | undefined;
        if (!limit) {
            setLeft(0);
            return;
        }
        const until = Date.now() + limit * 1000;
        setLeft(Math.ceil(limit));
        const tick = window.setInterval(() => {
            setLeft(Math.max(0, Math.ceil((until - Date.now()) / 1000)));
        }, 250);
        return () => window.clearInterval(tick);
    }, [ask?.id]);

    // 换一条询问就把勾的全清掉
    useEffect(() => {
        setSelection(EMPTY);
    }, [ask?.id]);

    if (!ask) {
        return html`<section class="ask"><h2>询问</h2><p class="muted">没有在问什么</p></section>`;
    }

    const params = ask.params as any;
    const cancelable = params.cancelable !== false;
    const panel = ask.method === 'Ask.Panel'
        ? agent.panels.get(params.id as number) ?? null
        : null;
    const picked = selection.cards.length + selection.players.length + selection.heroes.length;
    const toggle = (list: number[], id: number) => (list.includes(id) ? list.filter((one) => one !== id) : [...list, id]);
    const body = () => {
        switch (ask.method) {
            case 'Ask.Choice':
                return html`<div class="chips">${(params.options as string[]).map((text, index) => html`<button
                    key=${index}
                    class="chip"
                    onClick=${() => ask.answer({ choice: index + 1 })}
                >${text}</button>`)}</div>`;
            case 'Ask.Select':
                return html`<div>
                    ${params.player ? html`<p>选玩家（${planText(params.player)}）</p>
                        <${Chips} agent=${agent} ids=${params.player.ids} picked=${selection.players}
                            onPick=${(id: number) => setSelection({ ...selection, players: toggle(selection.players, id) })} />` : null}
                    ${params.card ? html`<p>选牌（${planText(params.card)}）</p>
                        <${Chips} agent=${agent} ids=${params.card.ids} picked=${selection.cards} cards
                            onPick=${(id: number) => setSelection({ ...selection, cards: toggle(selection.cards, id) })} />` : null}
                </div>`;
            case 'Ask.Hero':
                return html`<div>
                    <p>选武将（${planText(params)}）</p>
                    <div class="chips">${((params.heroes as string[]) ?? []).map((name) => html`<button
                        key=${name}
                        class=${'chip' + (selection.heroes.includes(name) ? ' on' : '')}
                        onClick=${() => setSelection({
                            ...selection,
                            heroes: selection.heroes.includes(name)
                                ? selection.heroes.filter((one) => one !== name)
                                : [...selection.heroes, name],
                        })}
                    >${name}</button>`)}</div>
                </div>`;
            case 'Ask.Use': {
                const options = (params.card ?? []) as { id: number; ids: number[]; min: number; max: number }[];
                const option = options.find((one) => one.id === selection.option) ?? null;
                const viewAs = (params.viewAs ?? []) as unknown[];
                return html`<div>
                    <p>用哪张牌（点一张，再用下面的目标）</p>
                    <div class="chips">${options.map((one) => html`<button
                        key=${one.id}
                        class=${'chip' + (selection.option === one.id ? ' on' : '')}
                        onClick=${() => setSelection({ ...selection, option: one.id, players: [] })}
                    >${cardLabel(agent, one.id)}</button>`)}</div>
                    ${option && option.max > 0 ? html`<p>给它选目标（${planText(option)}）</p>
                        <${Chips} agent=${agent} ids=${option.ids} picked=${selection.players}
                            onPick=${(id: number) => setSelection({ ...selection, players: toggle(selection.players, id) })} />` : null}
                    ${viewAs.length > 0 ? html`<p class="muted">「视为」的控件还没做（批三），先用下面那串手写。</p>` : null}
                </div>`;
            }
            case 'Ask.UseSkill': {
                const skills = (params.skills ?? []) as { id: number; cards?: { ids: number[]; min: number; max: number }; targets?: { ids: number[]; min: number; max: number } }[];
                const skill = skills.find((one) => one.id === selection.skill) ?? null;
                return html`<div>
                    <p>发动哪个技能</p>
                    <div class="chips">${skills.map((one) => html`<button
                        key=${one.id}
                        class=${'chip' + (selection.skill === one.id ? ' on' : '')}
                        onClick=${() => setSelection({ ...selection, skill: one.id, cards: [], players: [] })}
                    >${agent.skills.get(one.id)?.name ?? `技能 ${one.id}`}</button>`)}</div>
                    ${skill?.cards ? html`<p>要用的牌</p>
                        <${Chips} agent=${agent} ids=${skill.cards.ids} picked=${selection.cards} cards
                            onPick=${(id: number) => setSelection({ ...selection, cards: toggle(selection.cards, id) })} />` : null}
                    ${skill?.targets ? html`<p>目标</p>
                        <${Chips} agent=${agent} ids=${skill.targets.ids} picked=${selection.players}
                            onPick=${(id: number) => setSelection({ ...selection, players: toggle(selection.players, id) })} />` : null}
                </div>`;
            }
            case 'Ask.Panel': {
                if (!panel) {
                    return html`<p class="muted">面板 ${params.id} 还没同步到（等下一条消息）。</p>`;
                }
                const board = panel;
                const dropAt = (row: number, col: number) => (event: DragEvent) => {
                    event.preventDefault();
                    event.stopPropagation();
                    if (dragCard === null) {
                        return;
                    }
                    setDragCard(null);
                    void agent.movePanelCard(board.id, dragCard, row, col)
                        .catch((err: unknown) => agent.log(`挪不动：${err instanceof Error ? err.message : String(err)}`));
                };
                return html`<div class="panel">
                    <p>${board.name}${board.moveable ? ' · 拖到别的行就能摆位' : ''}${board.min > 0 ? ` · 选中 ${planText(board)}` : ''}</p>
                    ${board.rows.map((row, rowIndex) => html`<div
                        key=${rowIndex}
                        class="panel-row"
                        onDragOver=${(event: DragEvent) => {
                            if (dragCard !== null && board.moveable) {
                                event.preventDefault();
                            }
                        }}
                        onDrop=${dropAt(rowIndex + 1, row.cards.length + 1)}
                    >
                        <span class="panel-title">${row.title ?? `第 ${rowIndex + 1} 行`}</span>
                        ${row.cards.length === 0 ? html`<span class="muted">（空行）</span>` : null}
                        ${row.cards.map((id, colIndex) => html`<${CardView}
                            key=${id}
                            agent=${agent}
                            id=${id}
                            picked=${selection.cards.includes(id)}
                            off=${board.disabled.includes(id)}
                            marks=${board.marks.filter((one) => one.card === id).map((one) => one.mark)}
                            draggable=${board.moveable && !board.disabled.includes(id)}
                            onDragStart=${() => setDragCard(id)}
                            onDrop=${dropAt(rowIndex + 1, colIndex + 1)}
                            onClick=${() => {
                                if (board.disabled.includes(id) || board.moveable || board.max <= 0) {
                                    return;
                                }
                                setSelection({
                                    ...selection,
                                    cards: board.max <= 1
                                        ? (selection.cards.includes(id) ? [] : [id])
                                        : toggle(selection.cards, id),
                                });
                            }}
                        />`)}
                    </div>`)}
                </div>`;
            }
            default:
                return html`<p class="muted">这条询问（${ask.method}）界面还没做控件。</p>`;
        }
    };

    const submit = () => {
        if (ask.method === 'Ask.Hero') {
            ask.answer(selection.heroes.length > 0 ? { heroes: selection.heroes } : {});
            return;
        }
        if (ask.method === 'Ask.Select') {
            const result: Record<string, number[]> = {};
            if (params.player && selection.players.length > 0) {
                result.player = selection.players;
            }
            if (params.card && selection.cards.length > 0) {
                result.card = selection.cards;
            }
            ask.answer(result);
            return;
        }
        if (ask.method === 'Ask.Use') {
            const result: Record<string, unknown> = {};
            if (selection.option !== null) {
                result.usedCard = selection.option;
            }
            if (selection.players.length > 0) {
                result.targets = selection.players;
            }
            ask.answer(result);
            return;
        }
        if (ask.method === 'Ask.UseSkill') {
            const result: Record<string, unknown> = {};
            if (selection.skill !== null) {
                result.usedSkill = selection.skill;
            }
            if (selection.cards.length > 0) {
                result.cards = selection.cards;
            }
            if (selection.players.length > 0) {
                result.targets = selection.players;
            }
            ask.answer(result);
            return;
        }
        if (ask.method === 'Ask.Panel') {
            ask.answer(selection.cards.length > 0 ? { card: selection.cards } : {});
            return;
        }
        ask.answer({});
    };

    const needsSubmit = ask.method === 'Ask.Select' || ask.method === 'Ask.Use'
        || ask.method === 'Ask.UseSkill' || ask.method === 'Ask.Hero' || ask.method === 'Ask.Panel';
    return html`<section class="ask">
        <h2>询问</h2>
        <h3>${params.reason ?? ask.method}</h3>
        <p class="muted">
            ${ask.method}${left > 0 ? ` · 还剩 ${left} 秒` : ''}
            · 勾了 ${picked} 个${selection.option !== null ? ' + 一张牌' : ''}
        </p>
        ${body()}
        <div class="bar">
            ${needsSubmit ? html`<button disabled=${picked < (panel?.min ?? 0)} onClick=${submit}>确定</button>` : null}
            ${cancelable ? html`<button onClick=${() => ask.answer({})}>不选</button>` : null}
            <button onClick=${() => ask.cancel()}>取消</button>
            <button onClick=${() => ask.answer(JSON.parse((document.getElementById('raw') as HTMLTextAreaElement | null)?.value || '{}'))}>手写发送</button>
        </div>
        <textarea id="raw" rows="2" placeholder='{"usedViewAs":1,"cards":[12],"targets":[3]}'></textarea>
    </section>`;
}

/** 顶栏：服务器 / 名字 / 连接 / 加入 / 重新同步 */
function Head(props: { agent: Agent }) {
    const [url, setUrl] = useState(`ws://${location.hostname || 'localhost'}:${DEFAULT_PORT}`);
    const [name, setName] = useState('玩家');
    const { agent } = props;
    const run = (action: () => Promise<void>) => {
        void action().catch((err: unknown) => {
            agent.log(`做不了：${err instanceof Error ? err.message : String(err)}`);
        });
    };
    return html`<header>
        <label>服务器 <input size="26" value=${url} onInput=${(event: Event) => setUrl((event.target as HTMLInputElement).value)} /></label>
        <button onClick=${() => run(() => agent.connect(url.trim()))}>连接</button>
        <button onClick=${() => agent.close()}>断开</button>
        <span class="muted">${agent.connected ? '已连接' : '没连上'}</span>
        <label>名字 <input size="12" value=${name} onInput=${(event: Event) => setName((event.target as HTMLInputElement).value)} /></label>
        <button onClick=${() => run(() => agent.join(name.trim()))}>加入</button>
        <button onClick=${() => run(() => agent.resync())}>重新同步</button>
        ${agent.over ? html`<span class="over">终局：${agent.over.side} —— ${agent.over.reason}</span>` : null}
    </header>`;
}

/** 事件流（最新的在上） */
function Log(props: { agent: Agent }) {
    const lines = props.agent.logs.slice(-60).reverse();
    return html`<aside><h2>事件</h2>
        ${lines.map((line, index) => html`<div key=${index}>${line}</div>`)}
    </aside>`;
}

/** 整个界面 */
export function Shell(props: { agent: Agent }) {
    const { agent } = props;
    const [selection, setSelection] = useState<Selection>(EMPTY);
    const ask = agent.asks[0];
    const needsPick = ask !== undefined && ask.method !== 'Ask.Choice';
    return html`<div class="app">
        <${Head} agent=${agent} />
        <main>
            <${Board} agent=${agent} selection=${selection} setSelection=${setSelection} pickable=${needsPick} />
            <${AskPanel} agent=${agent} selection=${selection} setSelection=${setSelection} />
            <${Log} agent=${agent} />
        </main>
    </div>`;
}
