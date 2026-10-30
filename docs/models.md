# 获取 DOORS 建模的三条路

先说结论：**DOORS 的角色模型没有官方公开下载**。它是服务器端体验，客户端只拿到运行时需要的部分，
没有"下载整个游戏资产"的官方入口。所以别去找"一键扒模型"的按钮，浪费时间的。

要玩贴图乱斗，模型只要**进得了你自己的 place** 就行，来源有这几条。

---

## 路线 0 · 现成的社区解包仓库（最快，直接就是 .rbxm）

GitHub 上有人把 DOORS 的资产解包整理成仓库，直接下模型文件拖进 Studio：

- [Palayop7239/DoorsFiles](https://github.com/Palayop7239/DoorsFiles) —— *"every DOORS files that ive decompiled"*，按目录分了模型 / 贴图 / 音频
- 同仓库的 [Content Update related files](https://github.com/Palayop7239/DoorsFiles/tree/main/Content%20Update%20related%20files) 子树，按版本更新拆开放在一起
- [DaRandomosity/Roblox-DOORS-Technical-Manifesto](https://github.com/DaRandomosity/Roblox-DOORS-Technical-Manifesto/wiki/) —— 不是模型，是实体的技术档案（机制、参数、判定），改数值时有用

用法：

1. 进仓库 → 找到模型目录 → 下载 `.rbxm` / `.rbxmx`（单个文件用 **Download raw file**，整个仓库用 **Code → Download ZIP**）
2. Studio 里 `Model → Insert from File`（或直接把文件拖进 Explorer）
3. 按实体名重命名，全部塞进 `Workspace.Monsters`
4. 回到本项目：`rojo serve` 或直接跑单文件版

> 这类仓库是第三方解包整理，模型和贴图的版权属于 DOORS 原作者，用途自己把握；
> 本仓库只提供"换皮工具"，不打包任何美术资源。

---

## 路线 0.1 · 用执行器 saveinstance 自己抓（客户端能看见的都能落盘）

这是"自己动手拿建模"最直接的一条，而且你机器上已经有工具：`D:\POT\bin\Potassium.exe`。

原理：实体在你屏幕上出现的时候，模型已经加载进**客户端**的 DataModel 了。
执行器的 `saveinstance` 会把当前客户端 DataModel 整个存成 `.rbxl` / `.rbxm`，模型、MeshId、贴图 asset id 全在里头。

步骤：

1. 进 DOORS，等目标实体**真的出现在你视野里**（Rush 冲过来、Figure 走到你面前、Seek 追逐段、商店里 Jeff/Goblino 站着）
   —— 没加载的东西存不下来，这是这条路的唯一限制
2. 执行器控制台跑：

```lua
saveinstance({
    FileName = "doors_dump",
    SavePlayers = false,
    SaveInstance = true,
    IgnoreScripts = true,      -- 只要模型，不要脚本，文件小很多
    IgnoreDefaultProps = true,
})
```

3. 在 `workspace` 目录（`D:\POT\workspace\` 或执行器设置里的目录）拿到 `doors_dump.rbxm`
4. Studio 里 `Insert from File` → 把里面的实体 Model 一个个挑出来，重命名，丢进 `Workspace.Monsters`

注意：

- `D:\POT\bin\Decompiler.exe` 是**反编译 Lua 脚本**的，导不出网格和贴图，别拿它找模型
- 抓下来的模型带的是原始 `rbxassetid://`，能不能显示取决于资产权限（见文末）
- 一次没抓全就多进几次游戏，按实体分批存

---

## 路线 0.5 · Sketchfab 上的单只模型

---

## 路线 0.5 · Sketchfab 上的单只模型

适合只想要一两只、或者想要非 Roblox 原生格式的场景：

- 搜索页：<https://sketchfab.com/search?q=roblox+doors&type=models>
- 现成例子：[Ambush from DOORS](https://sketchfab.com/3d-models/ambush-from-doors-cacc34fa5b724a55a50c12581db8b647)、[Creak（DOORS 联动模型）](https://sketchfab.com/3d-models/creak-doors-official-doors-roblox-3d-d944e59e26f042b0bca2fcf63d9bb11a)、[Honcho（The Archives）](https://sketchfab.com/3d-models/honcho-roblox-doors-the-archives-d1a4e93b97c94062b94dfa0d4df231d4)

下载 `.glb` / `.fbx` / `.obj` 后走 Studio 的 3D Importer，导入结果是 `MeshPart`，
`TextureID` 指向你账号下的资产 —— 正好是 `Units.lua` 处理得最干净的一类。


---

## 路线 1 · Roblox 工具箱里的公开复刻（最省事）
Studio → View → Toolbox → Models，搜这些关键词：

```
DOORS Rush          DOORS Ambush        DOORS Figure
DOORS Seek          DOORS Halt          DOORS Screech
DOORS entity        DOORS monster rig   DOORS A-60
```

技巧：

- 优先选 **带 rig（有 Humanoid + Head）** 的，这样脸 decal 是挂在 Head 上的，换起来最有效果
- 点开模型详情看一眼有没有 `MeshPart` / `Decal`，纯 Part 拼的模型换贴图没意义
- 工具箱模型的贴图多为上传者自己传的公开资产，通常能正常显示
- 同一个实体多下几个版本，`cross` 模式池子越大越好玩

导入后重命名成 `Rush` / `Ambush` / `Figure`… 丢进 `Workspace.Monsters`。

---

## 路线 2 · Sketchfab / 同人模型 + Studio 3D 导入器

Sketchfab 上搜 `DOORS`、`Roblox doors fan model`，能翻到同人做的实体模型（`.glb` / `.fbx` / `.obj`）。

导入：Studio → **Avatar** 或 **Home → 3D Importer** → 选文件 → 勾选 "Upload as Mesh"。
导入进来的模型通常是 `MeshPart`，`TextureID` 直接指向上传后的资产 —— 正好是 `Units.lua` 最擅长处理的那类。

注意：

- 需要 Roblox 账号有上传权限（部分账号的上传额度受限）
- 非官方模型的比例、骨骼各不相同，`perMonster` 整只打包时可能比例爆炸 —— 那也是效果
- 同人作品的授权自己看清楚，别把别人的模型直接公开分发

---

## 路线 3 · 自己搭 rig（最可控）

想稳定复现"贴图乱斗"的效果，最快的其实是自己搭 7~8 个同规格的生物：

1. 用 R6 或 R15 的 Dummy 当骨架
2. 每只换不同颜色的 `MeshPart` 身体 + 一张 `Decal` 脸（贴自己画的图）
3. 全部命名成 DOORS 实体名，丢进 `Workspace.Monsters`

因为规格统一，`perMonster` 模式能做到"整套皮完美互换"，做视频最出效果。

---

## 目录约定（工具认这个）

```
Workspace
└── Monsters                 ← 文件夹名必须和 Config.FolderName 一致
    ├── Rush                 ← Model
    │   ├── Humanoid
    │   ├── Head (MeshPart / Part)
    │   │   └── Face (Decal)  ← Texture 就是会被换走的东西
    │   └── Torso (MeshPart)
    ├── Ambush
    ├── Figure
    ├── Seek
    └── ...
```

命名不用精确匹配，`src/ReplicatedStorage/DoorsTextureChaos/Registry.lua` 会做归一化：
`Rush` / `rush` / `Rush_New` / `a-60` / `a60` 都能认出来。认不出的按原名处理，照样能换。

---

## 关于贴图显示不出来

Roblox 从 2024 年起对贴图资产做了权限隔离：一个 `rbxassetid://` 只有在
**公开资产** 或 **你/你的 place 被授权** 的情况下才会渲染。

所以你从工具箱拖进来的模型，如果贴图是别人私有上传的，可能一进 place 就是白的。
三种处理：

1. 换一个贴图正常的模型版本（最省事）
2. 右键贴图 → 另存/重新上传成自己的资产，再贴回去
3. 直接用自己的图 —— 反正这个项目的目的就是把它换乱

脚本这边不受影响：`restore()` 记录的是**原始 asset id 字符串**，
显示不显示是渲染层的事，逻辑层怎么换都能退回去。
