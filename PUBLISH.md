# 发布到 GitHub（你只需要做这一步）

代码、文档、模型重建脚本、工具链**全部已经写好并验证过了**。剩下只有上传这一个动作需要你的 token。

---

## 一条命令

双击：

```
D:\DSH ROBLOX\doors-texture-chaos\tools\发布.cmd
```

然后：

1. 窗口停在 `Paste GitHub token (ghp_... or github_pat_...), input is masked:`
2. `Ctrl+V` 粘 token（**屏幕不显示字符是正常的**），回车
3. 等它刷完

正常输出结尾是：

```
uploaded : 40 file(s)
repo     : https://github.com/3091318935/doors-texture-chaos
raw      : https://raw.githubusercontent.com/.../standalone/DoorsTextureChaos.lua
```

仓库已经存在了（上一次推成功过），所以这次不会再走 `POST /user/repos`，
直接按文件覆盖更新。同一个脚本可以反复跑。

---

## 这次会推上去什么

| 分类 | 文件 |
| --- | --- |
| 引擎 | `standalone/DoorsTextureChaos.lua`、`plugin/DoorsTextureChaos.plugin.lua`、`src/**`（7 个模块 + 2 个脚本） |
| 模型重建 | `models/FigureRig.build.lua`、`models/EntityRigs.build.lua`（Seek + Glitch）、`models/RushTextures.build.lua`、`models/README.md` |
| 文档 | `README.md`、`docs/models.md`、`docs/entities.md`、`docs/assets-manifest.md`、`docs/field-notes.md`、`docs/asset-inventory.md` |
| 实测数据 | `assets.lua`、`assets-report.txt` |
| 工具 | `tools/fetch-and-extract.ps1`、`tools/extract-assets.ps1`、`tools/push-api.ps1` 等 5 个 |

---

## 本地已经有现成的 place 文件

`build\doors-texture-chaos.rbxlx`（28 KB，Rojo 7.7.1 构建）—— Studio 里
`File → Open from File` 直接打开，`ReplicatedStorage.DoorsTextureChaos`、
`ServerScriptService.TextureChaosServer`、`StarterPlayerScripts.ChaosHud` 都在里面，
不用装 Rojo 也不用连 serve。

这个目录被 `.gitignore` 挡着，不会推到 GitHub；需要重新生成就：

```powershell
cd "D:\DSH ROBLOX\doors-texture-chaos"
rojo build default.project.json -o build\doors-texture-chaos.rbxlx
```

---

## 如果失败

| 报错 | 处理 |
| --- | --- |
| `401 Bad credentials` | token 复制漏字符，重新复制整串（不带空格换行） |
| `403` 且提到 `resource not accessible` | token 缺 `Contents: Read and write`，重新生成 |
| `fetch failed` / 连接被重置 | GitHub 又被 DNS 劫持了，先跑 `tools/fix-dns.cmd` |

---

## 上传完成之后

**在 Studio 里用**：打开仓库里的 `standalone/DoorsTextureChaos.lua`，复制全文 → 命令栏回车。

**在执行器里用**（注意 `raw.githubusercontent.com` 在本机被 TLS 重置，必须走代理域名）：

```lua
loadstring(game:HttpGet("https://gh-proxy.com/https://raw.githubusercontent.com/3091318935/doors-texture-chaos/main/standalone/DoorsTextureChaos.lua"))()
```

**先把模型造出来**：命令栏依次粘
`models/FigureRig.build.lua` → `models/EntityRigs.build.lua` → `models/RushTextures.build.lua`，
`Workspace.Monsters` 下就有 Figure / Seek / Glitch / Rush 四组素材，再跑乱斗。
