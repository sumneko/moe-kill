import { WsLink } from '../net/link';
import { Rpc, RpcError } from '../net/rpc';
import type { Proto } from '../proto';
import type { GameEvent } from './events';

/** 服务端在问一件事（`Ask.*`）：答上来就回包，不表态就取消 */
export interface Ask {
    /** 服务端给的号（回包用） */
    id: number;
    /** 哪个方法（`Ask.Select` / `Ask.Choice` / `Ask.Use` …） */
    method: string;
    /** 原样的参数（形状照 `Proto.Request.<方法>`） */
    params: any;
    /** 取消用的号（有才说明服务端留了取消的可能） */
    cancelToken: number | null;
    /** 答一包（形状照 `Proto.Result.<方法>`） */
    answer(result: unknown): void;
    /** 不表态（回 `CANCELED` 那个错误） */
    cancel(): void;
}

/** 会下发给客户端的那些询问 */
const ASK_METHODS = ['Ask.Select', 'Ask.Choice', 'Ask.Use', 'Ask.UseSkill', 'Ask.Hero', 'Ask.Panel'];

/** 最近记几条日志 */
const LOG_LIMIT = 200;

/** 防抖窗口（同一把键上的连点 / 连拖攒这么久，只发最后一次） */
const DEBOUNCE_MS = 150;

/** 同一把键上的动作攒一小会儿再跑（后来的顶掉先前的）—— 给乐观更新的发送端防抖 */
class Debounce {
    private readonly timers = new Map<string, number>();
    private readonly pending = new Map<string, () => void>();

    /** 记下这次的动作（同键后来的顶掉先前的），静默一小段再跑 */
    run(key: string, action: () => void): void {
        this.pending.set(key, action);
        const last = this.timers.get(key);
        if (last !== undefined) {
            clearTimeout(last);
        }
        this.timers.set(key, window.setTimeout(() => {
            this.timers.delete(key);
            const next = this.pending.get(key);
            this.pending.delete(key);
            next?.();
        }, DEBOUNCE_MS));
    }
}

/** 一局在浏览器这边的镜像：连接、局面、下发的询问 */
export class Agent {
    /** 局面上的玩家（按号索引） */
    readonly players = new Map<number, Proto.Player>();
    /** 局面上的牌（按号索引） */
    readonly cards = new Map<number, Proto.Card>();
    /** 局面上的技能（按号索引） */
    readonly skills = new Map<number, Proto.Skill>();
    /** 局面上的面板（按号索引） */
    readonly panels = new Map<number, Proto.Panel>();
    /** 展示用文本（key = 裸名：牌名 / 技能名） */
    readonly texts = new Map<string, string>();
    /** 最近发生的那些事（给界面看） */
    readonly logs: string[] = [];
    /** 还在等的询问（通常就一个） */
    readonly asks: Ask[] = [];
    /** 攒着还没播的表现事件（视图每帧取走） */
    readonly events: GameEvent[] = [];

    /** 这一局一共几个座 */
    seats = 0;
    /** 我坐哪（还没入座就是空） */
    me: number | null = null;
    /** 当前回合角色 */
    turnPlayer: number | null = null;
    /** 当前阶段名 */
    phase: string | null = null;
    /** 终局了没有 */
    over: { side: string; reason: string } | null = null;
    /** 连上了没有 */
    connected = false;
    /** 服务器是不是调试模式（只有它才允许调动画倍率） */
    debug = false;
    /** 动画等待的倍率（0 = 完全不等） */
    animScale = 1;

    /** 局面变了就叫一下 */
    onChange: (() => void) | null = null;

    private rpc: Rpc | null = null;
    private readonly tokenToAsk = new Map<number, Ask>();
    private readonly askRejects = new Map<number, (err: unknown) => void>();
    private readonly debounce = new Debounce();
    /** 防抖期间「这批改动还没落服务器」的原来长什么样（失败时用它恢复） */
    private readonly rollback = new Map<string, () => void>();

    /** 连上后端并起读循环 */
    async connect(url: string): Promise<void> {
        this.close();
        const link = new WsLink(url);
        await link.open();
        const rpc = new Rpc(link);
        this.rpc = rpc;
        this.connected = true;
        this.bind(rpc);
        this.log(`连上了 ${url}`);
        this.changed();
        void rpc.run().then(() => {
            this.connected = false;
            this.log('连接断了');
            this.changed();
        });
    }

    /** 坐进来（拿一份全量快照） */
    async join(name: string): Promise<void> {
        const snapshot = (await this.requireRpc().request('Game.Join', { name })) as Proto.SnapShot;
        this.applySnapshot(snapshot);
    }

    /** 重新要一份快照（重连用） */
    async resync(): Promise<void> {
        const snapshot = (await this.requireRpc().request('Game.SnapShot', {})) as Proto.SnapShot;
        this.applySnapshot(snapshot);
    }

    /** 局终后原班人马重开一局（重建走 `Game.Restarted` 通知，不靠回包） */
    async restart(): Promise<void> {
        await this.requireRpc().request('Game.Restart', {});
    }

    /** 改动画等待的倍率（只有服务器是调试模式时才允许；改完服务器会通知全体） */
    async setAnimScale(scale: number): Promise<void> {
        await this.requireRpc().request('Game.SetAnimScale', { scale });
    }

    /** 把面板上的一张牌挪到某行某位：本地先挪（乐观），同一张牌的连续挪动防抖成最后一次 */
    async movePanelCard(panelId: number, card: number, row: number, col: number): Promise<void> {
        const panel = this.panels.get(panelId);
        const key = `panel:${panelId}:${card}`;
        if (panel && !this.rollback.has(key)) {
            const before = panel.rows.map((one) => [...one.cards]);
            this.rollback.set(key, () => this.restoreRows(panel, before));
        }
        if (panel) {
            this.movePanelCardLocally(panel, card, row, col);
            this.changed();
        }
        this.debounce.run(key, () => void this.sendPanelMove(key, panelId, card, row, col));
    }

    /** 切一个技能的自动开关（只能切自己的）：本地先改（乐观），同一技能的连点防抖成最后一次 */
    async changeSkillAuto(skillId: number, auto: boolean): Promise<void> {
        const skill = this.skills.get(skillId);
        const key = `skill:${skillId}`;
        if (skill && !this.rollback.has(key)) {
            const before = skill.auto;
            this.rollback.set(key, () => {
                if (skill) {
                    skill.auto = before;
                    this.changed();
                }
            });
        }
        if (skill) {
            skill.auto = auto;
            this.changed();
        }
        this.debounce.run(key, () => void this.sendSkillAuto(key, skill, skillId, auto));
    }

    /** 真发一次面板挪动（防抖后）—— 失败就把这批改动之前的那份恢复回来 */
    private async sendPanelMove(key: string, panelId: number, card: number, row: number, col: number): Promise<void> {
        try {
            const result = (await this.requireRpc().request('Panel.Move', { id: panelId, card, row, col })) as Proto.Result.Panel.Move;
            if (!result.success) {
                this.recover(key);
                return;
            }
            this.rollback.delete(key);
        } catch (err) {
            this.recover(key);
            this.log(`挪不动：${err instanceof Error ? err.message : String(err)}`);
        }
    }

    /** 真发一次技能开关（防抖后）—— 回包不对就按回包改，失败就把这批改动之前的那份恢复回来 */
    private async sendSkillAuto(key: string, skill: Proto.Skill | undefined, skillId: number, auto: boolean): Promise<void> {
        try {
            const result = (await this.requireRpc().request('Skill.ChangeAuto', { id: skillId, auto })) as Proto.Result.Skill.ChangeAuto;
            if (skill && result.auto !== undefined && result.auto !== auto) {
                skill.auto = result.auto;
                this.changed();
            }
        } catch (err) {
            this.recover(key);
            this.log(`改不了自动：${err instanceof Error ? err.message : String(err)}`);
        } finally {
            this.rollback.delete(key);
        }
    }

    /** 断开 */
    close(): void {
        this.rpc?.close('客户端主动断开');
        this.rpc = null;
        this.connected = false;
        this.reset();
        this.changed();
    }

    /** 记一条日志 */
    log(text: string): void {
        this.logs.push(text);
        if (this.logs.length > LOG_LIMIT) {
            this.logs.splice(0, this.logs.length - LOG_LIMIT);
        }
    }

    /** 取走攒着的表现事件 */
    drainEvents(): GameEvent[] {
        return this.events.splice(0, this.events.length);
    }

    private requireRpc(): Rpc {
        if (!this.rpc) {
            throw new Error('还没连上');
        }
        return this.rpc;
    }

    private changed(): void {
        this.onChange?.();
    }

    /** 按服务端的 `moveTo` 把一张牌本地挪一下（先摘掉，再插到 `col` 处；`col` 是 1 起的插入位） */
    private movePanelCardLocally(panel: Proto.Panel, card: number, row: number, col: number): void {
        for (const one of panel.rows) {
            const at = one.cards.indexOf(card);
            if (at >= 0) {
                one.cards.splice(at, 1);
                break;
            }
        }
        const target = panel.rows[row - 1];
        if (!target) {
            return;
        }
        const at = Math.min(Math.max(col, 1), target.cards.length + 1) - 1;
        target.cards.splice(at, 0, card);
    }

    /** 乐观更新回退：把各行换回上次那份 */
    private restoreRows(panel: Proto.Panel | undefined, before: number[][] | undefined): void {
        if (!panel || !before) {
            return;
        }
        panel.rows.forEach((one, index) => {
            one.cards = before[index] ?? one.cards;
        });
        this.changed();
    }

    /** 这批改动没成：恢复成它之前的样子 */
    private recover(key: string): void {
        this.rollback.get(key)?.();
        this.rollback.delete(key);
    }

    /** 一个名字的展示文本（服务端下发的；没声明过就是空） */
    text(name: string): string | undefined {
        return this.texts.get(name);
    }

    private reset(): void {
        this.players.clear();
        this.cards.clear();
        this.skills.clear();
        this.panels.clear();
        this.texts.clear();
        this.asks.length = 0;
        this.events.length = 0;
        this.tokenToAsk.clear();
        this.askRejects.clear();
        this.seats = 0;
        this.me = null;
        this.turnPlayer = null;
        this.phase = null;
        this.over = null;
        this.debug = false;
        this.animScale = 1;
    }

    private applySnapshot(snapshot: Proto.SnapShot): void {
        this.players.clear();
        this.cards.clear();
        this.skills.clear();
        this.panels.clear();
        this.texts.clear();
        for (const player of snapshot.players) {
            this.players.set(player.base.id, player);
        }
        for (const card of snapshot.cards) {
            this.cards.set(card.id, card);
        }
        for (const skill of snapshot.skills ?? []) {
            this.skills.set(skill.id, skill);
        }
        for (const panel of snapshot.panels ?? []) {
            this.panels.set(panel.id, panel);
        }
        for (const one of snapshot.texts) {
            this.texts.set(one.name, one.text);
        }
        this.me = snapshot.me ?? null;
        this.turnPlayer = snapshot.turnPlayer ?? null;
        this.phase = snapshot.phase ?? null;
        this.debug = snapshot.debug;
        this.animScale = snapshot.animScale;
        this.log(`拿到快照：${snapshot.players.length} 个玩家 / ${snapshot.cards.length} 张牌`);
        this.changed();
    }

    private bind(rpc: Rpc): void {
        rpc.onNotify('Room.Update', (params: Proto.Notify.Room.Update) => {
            this.seats = params.seats;
            for (const base of params.players) {
                const player = this.players.get(base.id);
                if (player) {
                    player.base = base;
                } else {
                    this.players.set(base.id, { base, custom: {}, attributes: [] });
                }
            }
            this.log(`房间里现在 ${params.players.length}/${params.seats} 个人`);
            this.changed();
        });
        rpc.onNotify('Player.Update', (params: Proto.Notify.Player.Update) => {
            for (const base of params.players) {
                const player = this.players.get(base.id);
                if (player) {
                    player.base = base;
                }
            }
            this.changed();
        });
        rpc.onNotify('Player.UpdateCustom', (params: Proto.Notify.Player.UpdateCustom) => {
            for (const one of params.players) {
                const player = this.players.get(one.id);
                if (player) {
                    player.custom = one.custom;
                }
            }
            this.changed();
        });
        rpc.onNotify('Player.UpdateAttribute', (params: Proto.Notify.Player.UpdateAttribute) => {
            for (const one of params.players) {
                const player = this.players.get(one.id);
                if (!player) {
                    continue;
                }
                const before = player.attributes.find((each) => each.name === '体力')?.value;
                player.attributes = one.attributes;
                const after = one.attributes.find((each) => each.name === '体力')?.value;
                if (before !== undefined && after !== undefined && before !== after) {
                    this.events.push({ kind: 'health', player: one.id, delta: after - before });
                }
            }
            this.changed();
        });
        rpc.onNotify('Card.Create', (params: Proto.Notify.Card.Create) => {
            for (const group of params.show ?? []) {
                for (const card of group.cards) {
                    this.cards.set(card.id, card);
                }
            }
            for (const group of params.hide ?? []) {
                for (const id of group.cards) {
                    this.cards.set(id, { id, zone: group.zone });
                }
            }
            this.changed();
        });
        rpc.onNotify('Card.Update', (params: Proto.Notify.Card.Update) => {
            for (const card of params.cards) {
                const known = this.cards.get(card.id);
                this.cards.set(card.id, known ? { ...known, ...card } : card);
            }
            this.changed();
        });
        rpc.onNotify('Card.Remove', (params: Proto.Notify.Card.Remove) => {
            for (const id of params.ids) {
                const card = this.cards.get(id);
                // 处理区里那张被收掉了：前端要在原位上留个影子（这时账里还没删掉，问得到它在哪个区）
                if (card?.zone === '#0') {
                    this.events.push({ kind: 'gone', id, face: card.face ?? {} });
                }
                this.cards.delete(id);
            }
            this.changed();
        });
        rpc.onNotify('Card.Move', (params: Proto.Notify.Card.Move) => {
            for (const move of params.moves) {
                this.log(`挪牌：${move.from} → ${move.to}`);
                this.events.push({ kind: 'move', move });
            }
            this.changed();
        });
        rpc.onNotify('Skill.Update', (params: Proto.Notify.Skill.Update) => {
            this.skills.set(params.skill.id, params.skill);
            this.changed();
        });
        rpc.onNotify('Skill.Remove', (params: Proto.Notify.Skill.Remove) => {
            this.skills.delete(params.id);
            this.changed();
        });
        rpc.onNotify('Panel.Create', (params: Proto.Notify.Panel.Create) => {
            this.panels.set(params.panel.id, params.panel);
            this.log(`来了块面板：${params.panel.name}`);
            this.changed();
        });
        rpc.onNotify('Panel.Update', (params: Proto.Notify.Panel.Update) => {
            this.applyPanelUpdate(params.panel);
            this.changed();
        });
        rpc.onNotify('Panel.Remove', (params: Proto.Notify.Panel.Remove) => {
            this.panels.delete(params.id);
            this.changed();
        });
        rpc.onNotify('Turn.Begin', (params: Proto.Notify.Turn.Begin) => {
            this.turnPlayer = params.player;
            this.log(`轮到他了：${this.playerLabel(params.player)}`);
            this.events.push({ kind: 'turn', player: params.player });
            this.changed();
        });
        rpc.onNotify('Turn.End', (params: Proto.Notify.Turn.End) => {
            if (this.turnPlayer === params.player) {
                this.turnPlayer = null;
            }
            this.changed();
        });
        rpc.onNotify('Phase.Begin', (params: Proto.Notify.Phase.Begin) => {
            this.phase = params.name;
            this.events.push({ kind: 'phase', player: params.player, name: params.name });
            this.changed();
        });
        rpc.onNotify('Phase.End', (params: Proto.Notify.Phase.End) => {
            if (this.phase === params.name) {
                this.phase = null;
            }
            this.changed();
        });
        rpc.onNotify('Game.Over', (params: Proto.Notify.Game.Over) => {
            this.over = params;
            this.log(`这一局完了：${params.side}（${params.reason}）`);
            this.events.push({ kind: 'over', side: params.side, reason: params.reason });
            this.changed();
        });
        rpc.onNotify('Game.Restarted', (params: Proto.Notify.Game.Restarted) => {
            this.reset();
            this.applySnapshot(params);
            this.log('这一局重开了');
            this.changed();
        });
        rpc.onNotify('Game.AnimScale', (params: Proto.Notify.Game.AnimScale) => {
            this.animScale = params.scale;
            this.log(`动画倍率改成 ${params.scale}`);
            this.changed();
        });
        rpc.onNotify('Cancel', (params: Proto.Notify.Cancel) => {
            this.cancelAsk(params.cancelToken);
        });
        for (const method of ASK_METHODS) {
            rpc.onRequest(method, (params: any, id: number) => this.openAsk(method, params, id));
        }
    }

    private applyPanelUpdate(update: Proto.PanelUpdate): void {
        const panel = this.panels.get(update.id);
        if (!panel) {
            return;
        }
        for (const row of update.rows ?? []) {
            const target = panel.rows[row.row - 1];
            if (target) {
                target.cards = row.cards;
            }
        }
        if (update.disabled) {
            panel.disabled = panel.disabled.concat(update.disabled);
        }
        if (update.enabled) {
            panel.disabled = panel.disabled.filter((id) => !update.enabled?.includes(id));
        }
        panel.marks = panel.marks
            .filter((mark) => !(update.removeMark ?? []).some((one) => one.card === mark.card && one.mark === mark.mark))
            .concat(update.addMark ?? []);
    }

    private cancelAsk(token: number): void {
        const ask = this.tokenToAsk.get(token);
        if (!ask) {
            return;
        }
        const reject = this.askRejects.get(ask.id);
        this.dropAsk(ask);
        this.log('服务端把询问叫停了');
        // 叫停之后要回那一包（协议里说的 `REQUEST_CANCELED`）
        reject?.(new RpcError(-1, 'request canceled'));
    }

    private openAsk(method: string, params: any, id: number): Promise<unknown> {
        return new Promise((resolve, reject) => {
            const cancelToken = typeof params.cancelToken === 'number' ? params.cancelToken : null;
            const ask: Ask = {
                id,
                method,
                params,
                cancelToken,
                answer: (result: unknown) => {
                    this.dropAsk(ask);
                    resolve(result);
                },
                cancel: () => {
                    this.dropAsk(ask);
                    reject(new RpcError(-2, 'canceled'));
                },
            };
            if (cancelToken !== null) {
                this.tokenToAsk.set(cancelToken, ask);
            }
            this.askRejects.set(id, reject);
            this.asks.push(ask);
            this.log(`收到询问：${params.reason ?? method}`);
            this.changed();
        });
    }

    private dropAsk(ask: Ask): void {
        const index = this.asks.indexOf(ask);
        if (index >= 0) {
            this.asks.splice(index, 1);
        }
        if (ask.cancelToken !== null) {
            this.tokenToAsk.delete(ask.cancelToken);
        }
        this.askRejects.delete(ask.id);
        this.changed();
    }

    /** 玩家名（认不出就给号） */
    playerLabel(id: number): string {
        const player = this.players.get(id);
        if (!player) {
            return `#${id}`;
        }
        return `${player.base.userName}（#${id}）`;
    }
}
