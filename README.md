# DOORS 贴图乱斗 · DoorsTextureChaos

把一堆 DOORS 生物模型丢进一个文件夹，然后让它们的**贴图和建模互相随机乱换** ——
Rush 的脸长在 Figure 身上，Seek 的皮套在 Ambush 身上，Ambush 的网格贴了 Halt 的报纸。
换完一键还原，模型永远改不废。

- 一个单文件 Lua，粘进 Studio 命令栏立刻能看效果
- 一个 Studio 插件，带面板（扫描 / 乱斗 / 还原 / 导出清单），支持 `Ctrl+Z`
- 一份 Rojo 工程，能直接 `rojo build` 出 `.rbxlx`

---

## 先说清楚一件事：模型从哪来

DOORS 是服务器端体验，它的角色模型不会下发到客户端，**没有公开的官方下载地址**。
所以这个项目不是"帮你把 DOORS 的资产抓下来"，而是：

> **你自己导入到 place 里的模型，它负责把它们之间乱换。**

获取模型的几条正路写在 [docs/获取建模.md](docs/获取建模.md)：

- **社区解包仓库**：[Palayop7239/DoorsFiles](https://github.com/Palayop7239/DoorsFiles) —— 解包好的 `.rbxm` 直接 `Insert from File`；完整文件清单和直链见 [docs/资产清单.md](docs/资产清单.md)
- **Roblox 工具箱**：搜 `DOORS Rush` / `DOORS Figure` / `DOORS entity rig`
- **Sketchfab**：同人模型走 Studio 3D Importer
- **自己搭 rig**：规格统一，`perMonster` 换皮效果最好

模型进 Workspace 之后，剩下的全自动。

> 贴图变空白 = Roblox 资产权限问题（那张 `rbxassetid://` 不是公开资产、或不属于你这个 place），
> 跟脚本无关。换成你自己上传的贴图就正常了。

---

## 三种用法，挑一个

### A. 单文件版（最快，30 秒看效果）

1. Workspace 下新建文件夹，**必须叫 `Monsters`**
2. 把每只生物作为一个 Model 丢进去，命名 `Rush` / `Ambush` / `Figure` / `Seek` …
3. Studio → View → Command Bar，把 [standalone/DoorsTextureChaos.lua](standalone/DoorsTextureChaos.lua) 全文粘进去，回车
4. 想换一种乱法：改顶部的 `CONFIG.mode`，再粘一次
5. 后悔了：`Ctrl+Z`，或者把 `CONFIG.action` 改成 `"restore"` 再跑一次

### B. Studio 插件（可以反复点）

1. 把 [plugin/DoorsTextureChaos.plugin.lua](plugin/DoorsTextureChaos.plugin.lua) 重命名为 `DoorsTextureChaos.plugin.lua`
2. 丢进 `%LOCALAPPDATA%\Roblox\Plugins`（macOS：`~/Documents/Roblox/Plugins`）
3. 重启 Studio → 工具栏出现 **DOORS 贴图乱斗**
4. 面板里：填文件夹名 → 扫描 → 选模式 → 乱斗 / 还原

### C. Rojo 工程（长期维护 / 团队用）

```bash
rojo serve            # 在 Studio 里连 localhost:34872
rojo build -o build/DoorsTextureChaos.rbxlx
```

服务端脚本会自动每 45 秒乱一次、20 秒后还原，并在左上角 HUD 打出这一轮的"谁抢了谁的皮"。

---

## 四种乱法

| 模式 | 效果 | 适合 |
| --- | --- | --- |
| `cross` | 全局池错排。每张皮都可能跑到任意生物身上，且保证**不会原位不动** | 默认，最直观的"乱" |
| `rotate` | 环形传递：A 拿 B 的、B 拿 C 的…… 一圈下来 | 画面连续崩坏，适合做视频 |
| `perMonster` | **整只打包**。把 Rush 整套皮（身体网格 + 脸 decal）直接穿到 Figure 身上 | 最像"生物串味" |
| `chaos` | 每个贴图单元独立随机，同一只身上能同时出现四张不同来源的皮 | 最脏最花 |

加 `tint = true` 还会给每张 Decal/Texture 随机染色，糊得更彻底。

---

## 它到底换了什么

`Units.lua` 会把模型身上所有"皮"抽成单元（unit），整套逻辑就是把这些单元互搬：

| 实例类型 | 搬运的属性 |
| --- | --- |
| `MeshPart` | `MeshId` + `TextureID`（整块皮，连建模一起搬） |
| `Decal` / `Texture` | `Texture`（脸、贴纸、表面贴图） |
| `SpecialMesh` | `TextureId` |
| `SurfaceAppearance` | `ColorMap` / `NormalMap` / `RoughnessMap` / `MetalnessMap` |

- 写之前先把原值存进 `unit.origin`，`restore()` 一键还原
- 所有写入都走 `pcall`，只读属性、特殊网格、被锁的实例都不会把脚本打崩
- `Size` / `CFrame` / `Position` 永远不碰（搬 MeshId 会自己变形，那是视觉效果本身）

---

## 配置

`src/ReplicatedStorage/DoorsTextureChaos/Config.lua`：

```lua
Config.FolderName = "Monsters"     -- 生物文件夹
Config.Default.mode = "cross"      -- 默认模式
Config.Default.swapMesh = true     -- 连 MeshId 一起搬
Config.Default.tint = false        -- 随机染色
Config.Default.seed = nil          -- 固定数字 = 结果可复现

Config.SkipEntities = { ["Guiding Light"] = true, ["Void"] = true }  -- 光效别乱换

Config.Runtime = {
    enabled = true,
    interval = 45,       -- 每 45 秒乱一次
    restoreAfter = 20,   -- 20 秒后还原；0 = 不还原
    verbose = true,
}
```

---

## 目录结构

```
doors-texture-chaos/
├── default.project.json            Rojo 映射
├── standalone/
│   └── DoorsTextureChaos.lua       单文件版（命令栏 / ServerScriptService 通吃）
├── plugin/
│   └── DoorsTextureChaos.plugin.lua  Studio 插件
├── src/
│   ├── ReplicatedStorage/DoorsTextureChaos/
│   │   ├── init.lua                门面：scan / shuffle / restore
│   │   ├── Config.lua              参数
│   │   ├── Rng.lua                 可复现随机 + 错排
│   │   ├── Units.lua               贴图单元收割 / 回写 / 还原
│   │   ├── Shuffle.lua             四种乱斗策略（两段式 plan→apply）
│   │   └── Registry.lua            DOORS 生物名字登记 + 别名匹配
│   ├── ServerScriptService/
│   │   └── TextureChaosServer.server.lua   运行时自动乱斗 + 聊天指令
│   └── StarterPlayer/
│       └── ChaosHud.client.lua     左上角结果 HUD（F7 开关）
├── models/
│   └── FigureRig.build.lua         一键在 Studio 里重建 DOORS 的 Figure（32 部件，真实 MeshId + 姿态）
├── docs/
│   ├── 获取建模.md                  模型从哪来（解包仓库 / 工具箱 / Sketchfab / saveinstance）
│   ├── 资产清单.md                  解包仓库 69 个文件的完整清单 + 直链
│   ├── 实测记录.md                  实测扫出来的东西 + Roblox XML 的三个格式坑
│   └── 实体清单.md                  DOORS 实体名单与命名建议
└── tools/
    ├── fetch-and-extract.ps1       下存档（3 镜像重试 + 完整性校验）然后自动提取
    ├── extract-assets.ps1          从 .rbxlx/.rbxmx 里挖角色 rig 和资产 id
    ├── push-api.ps1                不需要 git 的 GitHub 发布（contents API）
    ├── push-to-github.ps1          git 流程（需要 Git for Windows）
    ├── repair-net.ps1              修 DNS 劫持 / 加速器残留
    └── build.ps1                   rojo build 打包
```

---

## 运行时手动触发

服务器控制台 / 命令栏：

```lua
_G.DOORS_TEXTURE_CHAOS.scan()                 -- 重新扫描
_G.DOORS_TEXTURE_CHAOS.shuffle("perMonster")  -- 整只换
_G.DOORS_TEXTURE_CHAOS.shuffle("chaos", 1234) -- 指定种子
_G.DOORS_TEXTURE_CHAOS.restore()              -- 还原
```

聊天指令（Studio 或体验创作者本人）：

```
!chaos              -- 用默认模式乱一次
!chaos rotate       -- 指定模式
!chaos off          -- 还原
```

---

## 常见问题

**贴图全白 / 报 "asset is not authorized"**
那张 `rbxassetid://` 不是公开资产，或不属于当前 place。Roblox 的资产权限是按 place 走的，
换自己上传的贴图就正常。脚本已经把原值存好了，`restore()` 一定能退回去。

**换了 MeshId 之后模型穿模 / 变形**
正常，这就是"把别人的建模套上来"的视觉结果。想只换皮不换骨，把 `swapMesh` 设成 `false`。

**模型是 R15 的，换完脸飘了**
Decal 位置由模型自己的 Head 部件决定，换贴图不改位置；飘了就是 donor 的脸 decal 尺寸不同，
用 `perMonster` 整只打包会好很多。

**扫不到东西**
确认文件夹名和 `Config.FolderName` 一致，且每个生物是 **Model**（不是散落的 Part）。

---

## 上传到 GitHub

这台机器上**没有装 git**，所以走 contents API 那条路，一个文件一个文件 PUT，不需要 git：

```powershell
# 双击也行：tools\发布.cmd
powershell -ExecutionPolicy Bypass -File tools\push-api.ps1
```

凭证会按顺序自动找：`$env:GITHUB_TOKEN` → 已登录的 `gh auth token` → 系统里的 git 凭证 → 都没有就掩码输入一次。
仓库不存在会自动建，已存在就按文件覆盖更新，最后验证 raw 链接能访问。

> 前提：GitHub 域名通。如果之前被 hosts 劫持过（全部指向 127.0.0.1），先跑一次
> `powershell -ExecutionPolicy Bypass -File tools\fix-hosts-github.ps1`（要管理员）。

想用正统 git 流程：`powershell -ExecutionPolicy Bypass -File tools\push-to-github.ps1`（需要先装 Git for Windows）。

## 许可

代码 MIT。仓库里**不含**任何 DOORS 美术资源；模型与贴图版权属于各自作者，
你导入什么、在哪用，由你负责。
