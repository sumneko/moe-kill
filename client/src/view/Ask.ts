import { html } from 'htm/preact';
import { useEffect, useState } from 'preact/hooks';
import type { Proto } from '../proto';
import type { Agent, Ask } from '../state/agent';
import { Card } from './Card';
import { answerOf, autoPick, canSubmit, pickCard, pickSkill, planText, toggle, type Selection } from './pick';
import { cardLabel, colorOf, formatText, heroName, seatCards, type TextPiece } from './format';

/** 一条询问要摆些什么、交上去什么 */
export interface AskHandlers {
    /** 勾选变了 */
    onSelection(next: Selection): void;
    /** 交一包上去（App 负责记表现并回包） */
    onAnswer(result: unknown): void;
}

/** 询问条：按询问类型给控件 */
export function AskBar(props: { agent: Agent; ask: Ask; selection: Selection } & AskHandlers) {
    const { agent, ask, selection, onSelection, onAnswer } = props;
    const params = ask.params as any;
    const [left, setLeft] = useState(0);
    const [dragCard, setDragCard] = useState<number | null>(null);

    // 限时倒计时（从收到询问那一刻算）：只拿来画进度条
    useEffect(() => {
        const limit = (ask.params as any).timeLimit as number | undefined;
        if (!limit) {
            setLeft(0);
            return;
        }
        const until = Date.now() + limit * 1000;
        setLeft(limit);
        const tick = window.setInterval(() => setLeft(Math.max(0, (until - Date.now()) / 1000)), 250);
        return () => window.clearInterval(tick);
    }, [ask.id]);

    const cancelable = params.cancelable !== false;
    const timeLimit = (params.timeLimit as number | undefined) ?? 0;
    const picked = selection.cards.length + selection.players.length + selection.heroes.length;
    const pickCards = (id: number) => onSelection(pickCard(ask, selection, id));
    const pickPlayers = (id: number) => onSelection({ ...selection, players: toggle(selection.players, id) });
    const own = mineCardIds(agent);
    /** 一排可点的按钮；`asCard` 的那些要略掉自己手上 / 装备着的牌，一个都不剩就整排不摆 */
    const chips = (ids: number[], pickedList: number[], onPick: (id: number) => void, asCard = false) => {
        const shown = asCard ? ids.filter((id) => !own.has(id)) : ids;
        if (shown.length === 0) {
            return null;
        }
        return html`<div class="chips">
            ${shown.map((id) => html`<button
                key=${id}
                class=${pickedList.includes(id) ? 'on' : ''}
                onClick=${() => onPick(id)}
            >${asCard ? cardLabel(agent, id) : nameOf(agent, id)}</button>`)}
        </div>`;
    };

    const body = () => {
        switch (ask.method) {
            case 'Ask.Choice': {
                const options = (params.options ?? []) as string[];
                if (options.length === 0) {
                    return null;
                }
                return html`<div class="chips">${options.map((text, index) => html`<button
                    key=${index}
                    onClick=${() => onAnswer({ choice: index + 1 })}
                >${text}</button>`)}</div>`;
            }
            case 'Ask.Select': {
                const cardChips = params.card
                    ? chips(params.card.ids, selection.cards, (id) => onSelection({ ...selection, cards: toggle(selection.cards, id) }), true)
                    : null;
                const playerChips = params.player ? chips(params.player.ids, selection.players, pickPlayers) : null;
                if (!cardChips && !playerChips) {
                    return null;
                }
                return html`<div>
                    ${playerChips ? html`<p class="hint">选玩家（${planText(params.player)}）</p>${playerChips}` : null}
                    ${cardChips ? html`<p class="hint">选牌（${planText(params.card)}）</p>${cardChips}` : null}
                </div>`;
            }
            case 'Ask.Use': {
                const options = (params.card ?? []) as Proto.CardWithPlan[];
                const views = (params.viewAs ?? []) as Proto.ViewAs[];
                const option = options.find((one) => one.id === selection.option);
                const view = selection.viewAs === null ? null : views[selection.viewAs];
                const target = view ? view.target : option;
                const optionChips = chips(options.map((one) => one.id), selection.option === null ? [] : [selection.option], pickCards, true);
                const materialChips = view?.card
                    ? chips(view.card.ids, selection.cards, (id) => onSelection({ ...selection, cards: toggle(selection.cards, id) }), true)
                    : null;
                if (!optionChips && views.length === 0 && !materialChips) {
                    return null;
                }
                return html`<div>
                    ${optionChips ? html`<p class="hint">用哪张牌（点手牌，或者点这里）</p>${optionChips}` : null}
                    ${views.length > 0 ? html`<p class="hint">「视为」（用技能 / 装备把牌转成别的）</p>
                        <div class="chips">${views.map((one, index) => html`<button
                            key=${index}
                            class=${selection.viewAs === index ? 'on' : ''}
                            onClick=${() => onSelection({ ...selection, viewAs: index, option: null, cards: [], players: autoPick(views[index]?.target) })}
                        >${viewLabel(agent, one)}</button>`)}</div>` : null}
                    ${materialChips ? html`<p class="hint">素材（${planText(view?.card)}）</p>${materialChips}` : null}
                    ${target && target.max > 0 ? html`<p class="hint">给它选目标（${planText(target)}）</p>` : null}
                </div>`;
            }
            case 'Ask.UseSkill': {
                const skills = (params.skills ?? []) as Proto.SkillPlan[];
                const skill = skills.find((one) => one.id === selection.skill) ?? null;
                const materialChips = skill?.cards
                    ? chips(skill.cards.ids, selection.cards, (id) => onSelection({ ...selection, cards: toggle(selection.cards, id) }), true)
                    : null;
                const targetChips = skill?.targets ? chips(skill.targets.ids, selection.players, pickPlayers) : null;
                if (skills.length === 0 && !materialChips && !targetChips) {
                    return null;
                }
                return html`<div>
                    ${skills.length > 0 ? html`<p class="hint">发动哪个技能</p>
                        <div class="chips">${skills.map((one) => html`<button
                            key=${one.id}
                            class=${selection.skill === one.id ? 'on' : ''}
                            onClick=${() => onSelection(pickSkill(ask, selection, one.id))}
                        >${agent.skills.get(one.id)?.name ?? `技能 ${one.id}`}</button>`)}</div>` : null}
                    ${materialChips ? html`<p class="hint">要用的牌（${planText(skill?.cards)}）</p>${materialChips}` : null}
                    ${targetChips ? html`<p class="hint">目标（${planText(skill?.targets)}）</p>${targetChips}` : null}
                </div>`;
            }
            case 'Ask.Hero': {
                const heroes = (params.heroes ?? []) as string[];
                if (heroes.length === 0) {
                    return null;
                }
                return html`<div>
                    <p class="hint">选武将（${planText(params)}）</p>
                    <div class="chips">${heroes.map((name) => html`<button
                        key=${name}
                        class=${selection.heroes.includes(name) ? 'on' : ''}
                        onClick=${() => onSelection({
                            ...selection,
                            heroes: selection.heroes.includes(name)
                                ? selection.heroes.filter((one) => one !== name)
                                : [...selection.heroes, name],
                        })}
                    >${name}</button>`)}</div>
                </div>`;
            }
            case 'Ask.Panel': {
                const panel = agent.panels.get(params.id as number);
                if (!panel) {
                    return html`<p class="hint">面板 ${params.id} 还没同步到（等下一条消息）</p>`;
                }
                const dropAt = (row: number, col: number) => (event: DragEvent) => {
                    event.preventDefault();
                    event.stopPropagation();
                    if (dragCard === null) {
                        return;
                    }
                    setDragCard(null);
                    void agent.movePanelCard(panel.id, dragCard, row, col);
                };
                return html`<div class="panel">
                    <p class="hint">
                        ${panel.name}${panel.moveable ? ' · 拖到别的行 / 别的牌前面就能摆位' : ''}${panel.min > 0 ? ` · 选 ${planText(panel)}` : ''}
                    </p>
                    ${panel.rows.map((row, rowIndex) => html`<div
                        class="panel-row"
                        key=${rowIndex}
                        onDragOver=${(event: DragEvent) => {
                            if (dragCard !== null && panel.moveable) {
                                event.preventDefault();
                            }
                        }}
                        onDrop=${dropAt(rowIndex + 1, row.cards.length + 1)}
                    >
                        ${row.title ? html`<span class="hint">${row.title}</span>` : null}
                        ${row.cards.map((id, colIndex) => html`<${Card}
                            key=${id}
                            agent=${agent}
                            id=${id}
                            picked=${selection.cards.includes(id)}
                            off=${panel.disabled.includes(id)}
                            pick=${!panel.disabled.includes(id) && !panel.moveable}
                            draggable=${panel.moveable && !panel.disabled.includes(id)}
                            onDragStart=${() => setDragCard(id)}
                            onDrop=${dropAt(rowIndex + 1, colIndex + 1)}
                            onClick=${() => {
                                if (panel.disabled.includes(id) || panel.moveable || panel.max <= 0) {
                                    return;
                                }
                                onSelection({
                                    ...selection,
                                    cards: panel.max <= 1
                                        ? (selection.cards.includes(id) ? [] : [id])
                                        : toggle(selection.cards, id),
                                });
                            }}
                        />`)}
                    </div>`)}
                </div>`;
            }
            default:
                return html`<p class="hint">这条询问（${ask.method}）还没有控件</p>`;
        }
    };

    const needSubmit = ask.method !== 'Ask.Choice';
    const content = body();
    return html`<div id="askWrap">
        ${content ? html`<div id="ask">${content}</div>` : null}
        <div id="askBar">
            ${timeLimit > 0 ? html`<div class="timeout">
                <div class="left" style=${`width: ${Math.max(0, Math.min(100, (left / timeLimit) * 100))}%`}></div>
            </div>` : null}
            <div class="head">
                <span class="title">${askTitle(agent, ask, params).map((piece, index) => html`<span
                    key=${index}
                    style=${piece.color ? `color:${piece.color}` : undefined}
                >${piece.text}</span>`)}</span>
                <span class="hint">勾了 ${picked} 个${selection.option !== null ? ' + 一张牌' : ''}</span>
            </div>
            <div class="bar">
                ${needSubmit ? html`<button
                    disabled=${!canSubmit(ask, selection)}
                    onClick=${() => onAnswer(answerOf(ask, selection))}
                >确定</button>` : null}
                <button
                    disabled=${!cancelable}
                    title=${cancelable ? '这一问可以不答' : '这一问必须给出答复'}
                    onClick=${() => onAnswer({})}
                >取消</button>
            </div>
        </div>
    </div>`;
}

/** 我自己的牌（手牌 + 四个装备子区）：它们已经摆在牌桌上，询问里不重复列 */
function mineCardIds(agent: Agent): Set<number> {
    const mine = agent.me === null ? null : seatCards(agent, agent.me);
    if (!mine) {
        return new Set();
    }
    return new Set([...mine.hand, ...[...mine.equip.values()].flat()]);
}

/** 角色怎么称呼：优先武将名，还没选将就用户名 */
function whoOf(agent: Agent, id: number): string {
    return heroName(agent.players.get(id)) ?? agent.playerLabel(id);
}

/** 一个角色怎么显示：自己就是「你」（高亮），否则武将名或用户名 */
function whoPiece(agent: Agent, id: number): TextPiece {
    if (agent.me === id) {
        return { text: '你', color: colorOf('me') };
    }
    return { text: whoOf(agent, id), color: colorOf('player') };
}

/** 这次询问的抬头：`reason` 是带格式的文本（走 `formatText`），响应类再拼上「响应谁的那张牌」 */
function askTitle(agent: Agent, ask: Ask, params: any): TextPiece[] {
    const title = formatText((params.reason as string | undefined) ?? ask.method);
    const responseTo = params.responseTo as Proto.ResponseTo | undefined;
    if (!responseTo) {
        return title;
    }
    const who: TextPiece[] = [];
    for (const [index, id] of [responseTo.player, ...responseTo.targets].entries()) {
        if (index > 0) {
            who.push({ text: ' → ' });
        }
        who.push(whoPiece(agent, id));
    }
    return [
        ...title,
        { text: ' → ' },
        { text: responseTo.card, color: colorOf('card') },
        { text: '（' },
        ...who,
        { text: '）' },
    ];
}

/** 玩家名（认不出就给号） */
function nameOf(agent: Agent, id: number): string {
    return agent.playerLabel(id);
}

/** 一个「视为」选项怎么写 */
function viewLabel(agent: Agent, view: Proto.ViewAs): string {
    const source = view.sourceSkill !== undefined
        ? agent.skills.get(view.sourceSkill)?.name ?? `技能 ${view.sourceSkill}`
        : view.sourceCard === undefined ? null : cardLabel(agent, view.sourceCard);
    return source === null ? `视为${view.name}` : `${source} ⇒ ${view.name}`;
}
