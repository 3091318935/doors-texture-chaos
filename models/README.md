# models —— 从存档里重建出来的实体

> **只想快点看到效果？** 粘两次命令栏就够：
> 先 [ALL-IN-ONE.build.lua](ALL-IN-ONE.build.lua)（Figure / Seek / Glitch / Giggle / Rush），
> 再 [SHOP-PACK.build.lua](SHOP-PACK.build.lua)（ElGoblino / Bob / Timothy / FigureFull / FigureWelded）。

这里的每个 `.lua` 都是一份**可以直接粘进 Studio 命令栏**的构建脚本：粘完回车，
`Workspace.Monsters` 下就出现对应的模型，不需要你去开存档、找部件、复制粘贴。

数据全部来自 [Palayop7239/DoorsFiles](https://github.com/Palayop7239/DoorsFiles) 的 XML 存档，
用 `tools/extract-assets.ps1` 解析，再从原始 `CoordinateFrame` / `MeshId` 逐项还原。

---

## FigureRig.build.lua

DOORS 的 **Figure**，32 个部件里 31 个带网格。

| | |
| --- | --- |
| 来源 | `sewers 5 + figure.rbxmx`、`figure 1st appear.rbxlx` |
| 部件 | Torso / RibCage / Head / Gums / Teeth / Veins / Blisters / 四肢 12 件 / Blister 7 件 |
| 数据 | 每个部件的 `MeshId`、世界坐标、`R00..R22` 旋转矩阵、`Size`，全部来自原始 XML |
| 缺什么 | **没有贴图**（原 dump 里 `TextureID=0`、`Decal=0`），是素模 |

`Root` 部件没有 `MeshId`（碰撞根块），脚本会自动跳过。

## EntityRigs.build.lua

一次生成 **Seek**、**Glitch**、**Giggle** 三个实体，全都自带皮肤。

| | Seek | Glitch | Giggle |
| --- | --- | --- | --- |
| 来源 | `new halt floor 1.rbxlx` 的 `SeekRig` | `figure 1st appear.rbxlx` 的 `Glitch` | `figure 1st appear.rbxlx` 的 `GiggleCovering` |
| 部件 | 15 | 6 | 21 |
| 贴图 | 1 张 `6507084861`（Head） | 1 张 `10216168173`（Torso，原 dump 重复 24 次） | 2 张 `8829534246` / `10085378708`（Main / Eyes） |

Seek 的部件：UpperTorso / LowerTorso / Head / Black / Eye / 四肢 8 件 / SeekPuddle / ParticleHitbox。
Giggle 的部件：Main / Eyes / 上下牙龈·嘴唇·牙齿 6 件 / 12 根 Tentacle（上下左右各 3 段）。

没有 `CFrame` 的部件（Seek 的 `ParticleHitbox`、Glitch 的 `Torso`）会被放到该 rig 的重心 ——
否则它们会停在原点，跟其他部件差几百格。

## SHOP-PACK.build.lua + 单只实体

从 `jeff f1.rbxlx`（17.5 MB，504 个 Model 块）里用 XML DOM 精确抽出来的：

| 实体 | 部件 | 贴图 | 单文件 |
| --- | --- | --- | --- |
| **Figure（完整版）** | 53 | 3（同 id `2542432117`） | `FigureFull.build.lua` |
| Figure（welded 变体） | 32 | 2 | `FigureWelded.build.lua` |
| **El Goblino** | 31 | 0 | `ElGoblino.build.lua` |
| **Bob**（`SkellyFriend`） | 20 | 0 | `Bob.build.lua` |
| **Timothy**（`Spider`） | 11 | 0 | `Timothy.build.lua` |
| Figure2（`FigureRig` 精简版） | 31 | 0 | `Figure2.build.lua` |

`SHOP-PACK.build.lua` 是前五份的合并版，粘一次全出来。
`FigureFull` 是整只 Figure 的父模型（内嵌 `FigureAnimatedWelded` 33 件 + 顶层 23 件），
比 `FigureRig.build.lua` 那份 31 件的版本完整得多。

贴图会自动挂到名叫 `Head` / `FakeHead` 的部件上（不是随手挂第一件）。

## RushTextures.build.lua

DOORS 的 **Rush** 的三张贴图（Decal 名保留原样）：

```
EyesTexture   rbxassetid://6439010561
TryTexture    rbxassetid://8829361602
TryTexture2   rbxassetid://7807728404
```

来源：`new halt floor 1.rbxlx` 里的 `RushMoving` 模型（0 个网格，3 个 Decal）。

生成的是三块贴图板，正面朝前。之所以要它：FigureRig 没有皮，场上必须先有 Decal，
贴图乱斗才有东西可抢。

---

## 以后怎么加新实体（不用手抄数字）

拿到新的存档（`.rbxlx` / `.rbxmx`）后，先看里面有什么角色 rig：

```powershell
powershell -ExecutionPolicy Bypass -File tools\extract-assets.ps1
```

它会扫出所有带 `Humanoid` 的模型；如果目标实体没有 Humanoid（Glitch、Screech 这类），
用按名字扫的方式找：

```powershell
powershell -NoProfile -Command "Select-String -Path 'D:\DSH ROBLOX\doors_downloads\*.rbxmx' -Pattern 'CDATA\[Rush' -SimpleMatch | Select-Object -First 5"
```

找到名字之后，一条命令生成构建脚本：

```powershell
powershell -ExecutionPolicy Bypass -File tools\rig-to-lua.ps1 `
    -File "D:\DSH ROBLOX\doors_downloads\figure 1st appear.rbxlx" `
    -Rig GiggleCovering `
    -Name Giggle `
    -Out "models\Giggle.build.lua"
```

它自己会做：定位 rig → 切每个 MeshPart → 抽 `MeshId` / `CFrame` / `R00..R22` / `Size` / 贴图 id
→ 用重心处理没 `CFrame` 的部件 → 生成可直接粘的 Lua（含撤销记录）。

可选参数：`-Decal "PartName=rbxassetid://123"` 指定贴图挂哪个部件；
不传就自动挑 rig 里第一张贴图。

## 用法

1. Studio → View → Command Bar
2. 打开对应 `.lua`，全选复制，粘进去，回车
3. 出来后在 `Workspace.Monsters` 下
4. 再跑 `standalone/DoorsTextureChaos.lua`（或在插件面板点"扫描 → 乱斗"）

## 注意

- `MeshId` / `Texture` 都是别人上传的资产。Roblox 按 place 授权，**显示成方块或空白就是没权限**。
  换成你自己上传的网格/贴图即可，脚本逻辑不受影响。
- 这些是反编译存档里抠出来的数据，只保证几何与变换正确，不保证和游戏里 100% 一致
  （材质、颜色、透明度这些没一并还原）。
