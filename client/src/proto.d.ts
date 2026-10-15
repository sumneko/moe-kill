// 由 `server/proto.d.lua` 的声明生成 —— 不要手改
// 改完声明重跑：server/bin/moe-kill.exe --gen-proto

export namespace JSONRPC {
    export interface Error {
        jsonrpc: '2.0';
        id: number;
        error: Proto.Error;
    }

    export interface Notify {
        jsonrpc: '2.0';
        method: string;
        params: unknown;
    }

    export interface Request {
        jsonrpc: '2.0';
        method: string;
        id: number;
        params: unknown;
    }

    export interface Result {
        jsonrpc: '2.0';
        id: number;
        result: unknown;
    }
}

export namespace Proto {
    /**
     * 一条属性：名字 + 当前值
     */
    export interface Attribute {
        /**
         * 属性名（内容侧起的名字）
         */
        name: string;
        /**
         * 当前值
         */
        value: number;
    }

    /**
     * 可取消请求的基类
     */
    export interface Cancelable {
        cancelToken?: number;
    }

    export interface Card {
        /**
         * 卡牌当前ID，每当进入区域会分配一个新的，离开区域会销毁
         */
        id: number;
        /**
         * 原始牌信息，如果没有说明是背面朝上
         */
        face?: Proto.CardFace;
        /**
         * 转化牌信息
         */
        modifier?: Proto.CardFace;
        /**
         * 卡牌所在的区域（`名字#玩家号`；玩家号 0 = 无主）
         */
        zone?: string;
    }

    export interface CardFace {
        /**
         * 卡牌名称，没有说明是背面朝上
         */
        name?: string;
        /**
         * 花色
         */
        suit?: '黑桃' | '红桃' | '梅花' | '方块';
        /**
         * 卡牌点数
         */
        point?: number;
    }

    export interface CardMove {
        /**
         * 移动的卡牌ID，方便播放动画确定起始位置
         */
        id?: number;
        /**
         * 移动的卡牌模板信息，没有说明是背面朝上
         */
        face?: Proto.CardFace;
        /**
         * 来源区域（`名字#玩家号`）
         */
        from: string;
        /**
         * 目标区域（`名字#玩家号`）
         */
        to: string;
    }

    export interface CardWithPlan extends Proto.Plan.Player {
        /**
         * 卡牌ID
         */
        id: number;
    }

    /**
     * 自定义数据：字段由各包自己的 meta.lua 补（内核只认「有这么一张自由表」）
     */
    export type Custom = Record<string, unknown>;

    export interface Error {
        code: number;
        message: string;
        data?: unknown;
    }

    export namespace Error {
        /**
         * 客户端自己不想答（它直接回这个错误）
         */
        export interface CANCELED {
            code: -2;
            message: 'canceled';
        }

        /**
         * 请求里带了认不出的号（牌号 / 面板号 …）
         */
        export interface INVALID_PARAMS {
            code: -32602;
            message: string;
        }

        /**
         * 这条请求现在做不了（处理器返回它 —— 失败的原因写在 `message` 里：还没开局 / 这条连接还没入座 / 这块面板现在没开着询问 …）
         */
        export interface INVALID_REQUEST {
            code: -32600;
            message: string;
        }

        /**
         * 请求方取消了请求
         */
        export interface REQUEST_CANCELED {
            code: -1;
            message: 'request canceled';
        }

        /**
         * 这次请求等超时了（服务端比时限多等 1 秒，客户端还没回）
         */
        export interface TIMEOUT {
            code: -3;
            message: 'timeout';
        }
    }

    export namespace Notify {
        /**
         * 取消一个请求。取消后那个请求应当返回： error: Proto.Error.REQUEST_CANCELED
         */
        export interface Cancel {
            cancelToken: number;
        }

        export namespace Card {
            export interface Create {
                /**
                 * 正面朝上的部分，按区域划分
                 */
                show?: { zone: string; cards: Proto.Card[] }[];
                /**
                 * 背面朝上的部分，按区域划分
                 */
                hide?: { zone: string; cards: number[] }[];
            }

            /**
             * 仅仅是用于播放移动动画，会确保在 `Card.Remove` 之前通知
             */
            export interface Move {
                moves: Proto.CardMove[];
            }

            export interface Remove {
                /**
                 * 被移除的卡牌ID列表
                 */
                ids: number[];
            }

            export interface Update {
                /**
                 * 被更新的卡牌列表
                 */
                cards: Proto.Card[];
            }
        }

        export namespace Game {
            /**
             * 这一局结束了（**收到它就是终局**：此后不会再来回合 / 阶段）
             */
            export interface Over {
                /**
                 * 胜方阵营：主公方 / 反贼 / 内奸 / 平局
                 */
                side: string;
                /**
                 * 胜负依据（中文短句，前端可直接显示）
                 */
                reason: string;
            }

            /**
             * 这一局重开了（**收到它就是新的一局**）：params 是一份按你视角裁过的完整快照
             */
            export interface Restarted extends Proto.SnapShot {
            }
        }

        export namespace Panel {
            /**
             * 一块面板出现了（发给所有人；此后它只是展示，不能操作）
             */
            export interface Create {
                panel: Proto.Panel;
            }

            export interface Remove {
                /**
                 * 拆掉的面板ID
                 */
                id: number;
            }

            /**
             * 面板变了（增量）
             */
            export interface Update {
                panel: Proto.PanelUpdate;
            }
        }

        export namespace Phase {
            /**
             * 进了一个阶段
             */
            export interface Begin {
                /**
                 * 谁的阶段
                 */
                player: number;
                /**
                 * 阶段名（准备 / 判定 / 摸牌 / 出牌 / 弃牌 / 结束）
                 */
                name: string;
            }

            /**
             * 这个阶段结束了
             */
            export interface End {
                /**
                 * 谁的阶段
                 */
                player: number;
                /**
                 * 阶段名
                 */
                name: string;
            }
        }

        export namespace Player {
            /**
             * 基础信息变了（一条里带一批玩家）
             */
            export interface Update {
                /**
                 * 基础信息变了的那些玩家
                 */
                players: Proto.Player.Base[];
            }

            /**
             * 属性变了（一条里带一批玩家）
             */
            export interface UpdateAttribute {
                /**
                 * 属性变了的那些玩家
                 */
                players: Proto.Player.Attribute[];
            }

            /**
             * custom 变了（一条里带一批玩家）
             */
            export interface UpdateCustom {
                /**
                 * custom 变了的那些玩家
                 */
                players: Proto.Player.Custom[];
            }
        }

        export namespace Room {
            /**
             * 房间状态（谁进来了 / 还差几个人）：开局之前每次有人入座都发一次
             */
            export interface Update {
                /**
                 * 这一局一共几个座
                 */
                seats: number;
                /**
                 * 已经坐下的人（按座位号排）
                 */
                players: Proto.Player.Base[];
            }
        }

        export namespace Skill {
            export interface Remove {
                /**
                 * 被移除的技能ID
                 */
                id: number;
            }

            export interface Update {
                /**
                 * 被更新的技能
                 */
                skill: Proto.Skill;
            }
        }

        export namespace Turn {
            /**
             * 轮到他开始回合了
             */
            export interface Begin {
                /**
                 * 哪个角色
                 */
                player: number;
            }

            /**
             * 他的回合结束了
             */
            export interface End {
                /**
                 * 哪个角色
                 */
                player: number;
            }
        }
    }

    /**
     * 一块面板（创建与更新都发整块；属性按卡牌ID索引）
     */
    export interface Panel {
        /**
         * 面板ID（客户端靠它指认这块面板）
         */
        id: number;
        /**
         * 面板名（内容侧定）
         */
        name: string;
        /**
         * 允不允许移动牌
         */
        moveable: boolean;
        /**
         * 确定时至少要选中几张
         */
        min: number;
        /**
         * 确定时至多选中几张
         */
        max: number;
        rows: Proto.PanelRow[];
        /**
         * 被禁用的卡牌ID
         */
        disabled: number[];
        /**
         * 挂标记的那些牌（没标记的不列）
         */
        marks: Proto.PanelMark[];
    }

    /**
     * 一位牌挂着的一条展示用标记
     */
    export interface PanelMark {
        /**
         * 卡牌ID
         */
        card: number;
        /**
         * 挂着的那条标记（一张牌挂多条就发多份）
         */
        mark: string;
    }

    /**
     * 面板上的一行（行内有序）
     */
    export interface PanelRow {
        /**
         * 给客户端排版用的行标题
         */
        title?: string;
        /**
         * 这一行的卡牌ID（按顺序）
         */
        cards: number[];
    }

    /**
     * 一行变了的完整新状态
     */
    export interface PanelRowUpdate {
        /**
         * 第几行（1 起）
         */
        row: number;
        /**
         * 这一行的完整新形状
         */
        cards: number[];
    }

    /**
     * 一块面板的增量变化（只发这次动到的部分）
     */
    export interface PanelUpdate {
        /**
         * 哪块面板
         */
        id: number;
        /**
         * 变了的行（完整新状态）
         */
        rows?: Proto.PanelRowUpdate[];
        /**
         * 新被禁用的卡牌ID
         */
        disabled?: number[];
        /**
         * 被恢复的卡牌ID
         */
        enabled?: number[];
        /**
         * 新挂上的标记
         */
        addMark?: Proto.PanelMark[];
        /**
         * 被摘掉的标记
         */
        removeMark?: Proto.PanelMark[];
    }

    export namespace Plan {
        export interface Card {
            /**
             * 候选卡牌ID列表
             */
            ids: number[];
            /**
             * 最少需要的卡牌数量
             */
            min: number;
            /**
             * 最多允许的卡牌数量
             */
            max: number;
        }

        export interface Player {
            /**
             * 候选玩家ID列表
             */
            ids: number[];
            /**
             * 最少需要的玩家数量
             */
            min: number;
            /**
             * 最多允许的玩家数量
             */
            max: number;
        }
    }

    export interface Player {
        base: Proto.Player.Base;
        /**
         * 自定义数据，由 package 组装
         */
        custom: Proto.Custom;
        /**
         * 按收件人视角裁过的属性（没声明过可见性的不下发）
         */
        attributes: Proto.Attribute[];
    }

    export namespace Player {
        export interface Attribute {
            /**
             * 玩家ID
             */
            id: number;
            /**
             * 他这次可见的属性（按名字排序）
             */
            attributes: Proto.Attribute[];
        }

        export interface Base {
            /**
             * 唯一ID
             */
            id: number;
            /**
             * 用户名
             */
            userName: string;
            /**
             * 座位号
             */
            seat: number;
        }

        export interface Custom {
            /**
             * 玩家ID
             */
            id: number;
            /**
             * 他的自定义数据（全量）
             */
            custom: Proto.Custom;
        }
    }

    export namespace Request {
        export namespace Ask {
            export interface Choice extends Proto.Cancelable, Proto.Timelimit {
                /**
                 * 这次确认的原因
                 */
                reason: string;
                /**
                 * 可选项列表
                 */
                options: string[];
                /**
                 * 是否可以主动取消
                 */
                cancelable?: boolean;
            }

            /**
             * 要在若干武将里挑：候选是一份武将全名（`包名.定义名`；不给 = 不做限制）
             */
            export interface Hero extends Proto.Cancelable, Proto.Timelimit {
                /**
                 * 这次为什么问
                 */
                reason: string;
                /**
                 * 候选武将全名（`包名.定义名`；不给 = 不做限制）
                 */
                heroes?: string[];
                /**
                 * 最少选几个
                 */
                min: number;
                /**
                 * 最多选几个
                 */
                max: number;
            }

            /**
             * 要他在某块面板上操作（面板的形状与能怎么操作早在 `Panel.Create` / `Update` 里给过）
             */
            export interface Panel extends Proto.Cancelable, Proto.Timelimit {
                /**
                 * 这次为什么问
                 */
                reason: string;
                /**
                 * 是否可以主动取消
                 */
                cancelable?: boolean;
                /**
                 * 在哪块面板上操作
                 */
                id: number;
            }

            /**
             * 要求客户端选择卡牌和玩家（可能是多选）
             */
            export interface Select extends Proto.Cancelable, Proto.Timelimit {
                reason: string;
                /**
                 * 是否可以主动取消
                 */
                cancelable?: boolean;
                player?: Proto.Plan.Player;
                card?: Proto.Plan.Card;
            }

            export interface Use extends Proto.Cancelable, Proto.Timelimit {
                /**
                 * 这次使用的原因
                 */
                reason: string;
                /**
                 * 是否可以主动取消
                 */
                cancelable?: boolean;
                /**
                 * 被使用的卡牌列表
                 */
                card: Proto.CardWithPlan[];
                /**
                 * 可用的视为技列表
                 */
                viewAs: Proto.ViewAs[];
            }

            export interface UseSkill extends Proto.Cancelable, Proto.Timelimit {
                reason: string;
                /**
                 * 恒 true：内核里「不表态 = 取消」
                 */
                cancelable?: boolean;
                skills: Proto.SkillPlan[];
            }
        }

        export namespace Game {
            /**
             * 一条连接坐进来（座位由服务端分配；坐满就开局）
             */
            export interface Join {
                /**
                 * 玩家名
                 */
                name?: string;
            }

            /**
             * 把已经终了的这一局放下、原班人马重开一局（没有参数；重建走 `Game.Restarted`）
             */
            export type Restart = Record<string, unknown>;

            /**
             * 要一份当前局面的全量快照（重连用；没有参数）
             */
            export type SnapShot = Record<string, unknown>;
        }

        export namespace Panel {
            /**
             * 客户端要把一张牌挪到某行的某个位置（一次一张；实际形状由随后的 `Panel.Update` 广播）
             */
            export interface Move {
                /**
                 * 面板ID
                 */
                id: number;
                /**
                 * 要挪的卡牌ID
                 */
                card: number;
                /**
                 * 放到第几行（1 起）
                 */
                row: number;
                /**
                 * 放到这一行的第几个位置（1 起）
                 */
                col: number;
            }
        }

        export namespace Skill {
            export interface ChangeAuto {
                /**
                 * 要改变自动状态的技能ID
                 */
                id: number;
                /**
                 * 新的自动状态
                 */
                auto: boolean;
            }
        }
    }

    export namespace Result {
        export namespace Ask {
            export interface Choice {
                /**
                 * 客户端选择的索引，对应 `options` 中的位置
                 */
                choice: number;
            }

            export interface Hero {
                /**
                 * 选中的武将全名（缺 = 取消）
                 */
                heroes?: string[];
            }

            export interface Panel {
                /**
                 * 选中的卡牌ID（缺 = 没选）
                 */
                card?: number[];
            }

            export interface Select {
                /**
                 * 被选中的玩家ID列表
                 */
                player?: number[];
                /**
                 * 被选中的卡牌ID列表
                 */
                card?: number[];
            }

            export interface Use {
                /**
                 * 被使用的卡牌ID
                 */
                usedCard?: number;
                /**
                 * 使用了第几个viewAs效果。和 card 互斥。
                 */
                usedViewAs?: number;
                /**
                 * 被选中的目标玩家ID列表
                 */
                targets?: number[];
                /**
                 * 被使用的卡牌ID列表。只有 useViewAs 时才有可能有值
                 */
                cards?: number[];
            }

            export interface UseSkill {
                /**
                 * 发动哪个技能（ID；缺 = 取消）
                 */
                usedSkill?: number;
                /**
                 * 这次发动带的牌
                 */
                cards?: number[];
                /**
                 * 这次发动指定的目标
                 */
                targets?: number[];
            }
        }

        export namespace Panel {
            export interface Move {
                /**
                 * 挪成了没有
                 */
                success: boolean;
            }
        }

        export namespace Skill {
            export interface ChangeAuto {
                /**
                 * 新的自动状态
                 */
                auto?: boolean;
            }
        }
    }

    export interface Skill {
        /**
         * 技能名
         */
        name: string;
        /**
         * 唯一ID
         */
        id: number;
        /**
         * 在哪个英雄身上
         */
        player: number;
        /**
         * 是否是自动技能以及自动技能开关状态
         */
        auto?: boolean;
        /**
         * 标签
         */
        tag?: string[];
        /**
         * 是否被禁用
         */
        disabled?: boolean;
    }

    /**
     * 一个可发动的技能：技能ID + 这次能挑的牌 / 目标（技能没声明就缺哪半）
     */
    export interface SkillPlan {
        /**
         * 技能ID
         */
        id: number;
        cards?: Proto.Plan.Card;
        targets?: Proto.Plan.Player;
    }

    export interface SnapShot {
        /**
         * 这条连接控制的是谁（还没入座就是空）
         */
        me?: number;
        /**
         * 玩家列表
         */
        players: Proto.Player[];
        /**
         * 局上所有的卡牌列表
         */
        cards: Proto.Card[];
        /**
         * 场上所有技能（重连用）
         */
        skills?: Proto.Skill[];
        /**
         * 场上现存的每块面板（重连用）
         */
        panels?: Proto.Panel[];
        /**
         * 当前回合角色（没人在回合就是空）
         */
        turnPlayer?: number;
        /**
         * 当前阶段名（不在阶段里就是空）
         */
        phase?: string;
        /**
         * 展示用文本（牌与技能各按裸名收一份）
         */
        texts: Proto.Text[];
    }

    export interface Text {
        /**
         * 裸名（牌名 / 技能名）
         */
        name: string;
        /**
         * 要显示的文本
         */
        text: string;
    }

    /**
     * 有时限的请求的基类（不给 `timeLimit` 就是不限时）
     */
    export interface Timelimit {
        /**
         * 秒（服务端多等 1 秒才判超时）
         */
        timeLimit?: number;
    }

    export interface ViewAs {
        /**
         * 要视为的卡牌
         */
        name: string;
        /**
         * 提供这个视为技的卡牌。和 sourceSkill 互斥
         */
        sourceCard?: number;
        /**
         * 提供这个视为技的技能名。和 sourceCard 互斥
         */
        sourceSkill?: number;
        /**
         * 作为素材的卡牌
         */
        card?: Proto.Plan.Card;
        /**
         * 作为目标的玩家
         */
        target?: Proto.Plan.Player;
    }
}
