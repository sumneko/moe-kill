-- 先基类、再子类（子类要 Extends 父类）；卡牌下行的机制 + 视图与它们同层 —— 装载顺序只在这里负责
require 'user.user'
require 'user.card-sync'
require 'user.client-user'
