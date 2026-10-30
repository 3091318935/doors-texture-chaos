# DOORS 实体清单与命名建议

`Registry.lua` 内置了这份名单，用来把模型文件夹名归一化到标准名。
模型叫什么其实都能用（认不出就按原名处理），但名字对齐了，`perMonster` 模式的日志读起来舒服很多。

---

## 主进程 · 常规实体

| 标准名 | 建议文件夹名 | 备注 |
| --- | --- | --- |
| Rush | `Rush` | 核心追逐实体，贴图最经典 |
| Ambush | `Ambush` | 反复来回，体积大 |
| Figure | `Figure` | 盲眼，靠听觉；多段模型，`perMonster` 效果最好 |
| Seek | `Seek` | 追逐段落，眼睛是 Emission 材质 |
| Glitch | `Glitch` | 半透明故障感，换皮后最出戏 |
| Halt | `Halt` | 报纸贴图，Decal 大户 |
| Screech | `Screech` | 黑雾 + 脸，只有头部有皮 |
| Eyes | `Eyes` | 一堆眼睛，适合 `chaos` |
| Dupe | `Dupe` | 假门，贴图简单 |
| Hide | `Hide` | 衣柜里的手 |
| Jack | `Jack` | 衣柜惊吓 |
| Timothy | `Timothy` | 蜘蛛，小模型 |
| Snare | `Snare` | 地板陷阱 |
| Shadow | `Shadow` | 纯黑剪影，换皮看不出来，建议跳过 |

## 主进程 · 友善 / 环境

| 标准名 | 建议文件夹名 | 备注 |
| --- | --- | --- |
| Guiding Light | `Guiding Light` | **纯光效，别换**（`Config.SkipEntities` 已排除） |
| Curious Light | `Curious Light` | 同上 |
| Void | `Void` | 同上 |
| Jeff | `Jeff` | 商店 NPC |
| El Goblino | `El Goblino` | 商店 NPC |
| Bob | `Bob` | 商店 NPC |
| Window | `Window` | 窗户实体 |

## 矿洞（Floor 2）

| 标准名 | 建议文件夹名 |
| --- | --- |
| Grumble | `Grumble` |
| Giggle | `Giggle` |
| Gloom | `Gloom` |
| Seek_Mines | `Seek_Mines` |
| Figure_Mines | `Figure_Mines` |

## Backdoor

| 标准名 | 建议文件夹名 |
| --- | --- |
| Haste | `Haste` |
| Lookman | `Lookman` |
| Blitz | `Blitz` |
| Backdoor_Void | `Backdoor_Void` |

## Hardcore / 特殊编号

| 标准名 | 建议文件夹名 | 备注 |
| --- | --- | --- |
| Dread | `Dread` | |
| Ripper | `Ripper` | |
| Hatred | `Hatred` | |
| DeerGod | `DeerGod` | |
| A-60 | `A-60` 或 `a60` | 别名表已覆盖 |
| A-90 | `A-90` | |
| A-120 | `A-120` | |
| A-333 | `A-333` | |
| A-500 | `A-500` | |
| A-1000 | `A-1000` | |

---

## 加自己的名字

打开 `src/ReplicatedStorage/DoorsTextureChaos/Registry.lua`：

```lua
Registry.Families["我的自制实体"] = {
    "MyMonster_A",
    "MyMonster_B",
}

Registry.ExtraAliases["mymonster1"] = "MyMonster_A"   -- 归一化后的小写别名
```

归一化规则：小写 + 去掉空格 / 下划线 / 连字符 / 点。
也就是 `My Monster-1`、`my_monster1`、`mymonster1` 都会落到同一个 key 上。

---

## 哪些实体建议排除

在 `Config.lua` 的 `SkipEntities` 里：

- **纯光效 / 纯剪影**：Guiding Light、Curious Light、Void、Shadow —— 换了看不出来，还可能因为透明度问题糊满屏
- **靠 Emission 做效果的**：Seek 的眼、Glitch 的故障感 —— 不是不能换，换完氛围直接崩，看你要不要

其余随便乱，越脏越好。
