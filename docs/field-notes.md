# 从存档里挖实体 · 实测记录

> 全部数据来自实际跑通的结果，不是推测。文件在 `D:\DSH ROBLOX\doors_downloads`。

---

## 一、仓库真相

`Palayop7239/DoorsFiles` 里**没有按实体打包的模型**，全是整间房/整层的 saveinstance 存档（`.rbxlx` / `.rbxmx`，XML 明文）。实体模型只存在于"它当时正好在场景里"的那些存档中。

实测扫了 5 个文件（1328 个 Model 块）：

| 文件 | Model 块 | 角色 rig | 说明 |
| --- | --- | --- | --- |
| `halt floor 2.rbxmx` | 192 | 0 | 纯房间：Door / Fence / BigDoorframe / Rails / Cables / MineLight / Locker / WoodenCrate |
| `seek start f2.rbxmx` | 317 | 0 | 追逐场景，Seek 本体不在存档里 |
| `sewers 5 + figure.rbxmx` | 363 | **1（FigureRig）** | 唯一抓到实体 rig 的文件 |
| `new halt floor 1.rbxlx` | 456 | 0 | 下载被截断，数据不全 |
| `gaz + gloombats.rbxmx` | — | — | 下载中断，0 字节 `.part` |

**结论：这个仓库只适合取"房间"，实体几乎抓不到。** 想要 Rush / Ambush / Seek，得自己在游戏里 `saveinstance`（见 [models.md](models.md) 路线 0.1）。

---

## 二、XML 格式（写解析器必看）

Roblox XML 存档里，资产引用是这么存的：

```xml
<Content name="MeshId"><url><![CDATA[rbxassetid://12983944254]]></url></Content>
<string name="Name"><![CDATA[74]]></string>
```

三个坑，全踩过：

1. **`MeshId` 外面套 `<url><![CDATA[ ... ]]>`**，不是 `<url>rbxassetid://...`。正则必须写成
   `<Content name="MeshId"><url>(?:<!\[CDATA\[)?(?:rbxassetid://)?(\d+)`
2. **`Name` 属性排在很后面**（前面有 `InitialSize`、`CFrame`、`PhysicalProperties`、大段 base64 `AttributesSerialize`），固定 1500 字符窗口切不到。切片必须以"下一个 `<Item class=`"为界。
3. **MeshPart 没有 `TextureID`**。贴图全在子级 `Decal` / `Texture` 的 `name="Texture"` 上。要拿到"部件的脸贴图"，必须按文档顺序遍历，遇到 Decal 就挂到它前面那个 MeshPart 上。

另外：`MeshPart` 用 `Color3uint8` 存颜色，`Transparency` 是 float，`Tags` 是被 base64 编码的 CollectionService 标签（`RmlndXJlUmln` = `FigureRig`）—— 标签是识别实体的最好线索。

---

## 三、抓到的东西

`sewers 5 + figure.rbxmx` 里的 `FigureRig`：32 个 MeshPart，Tag = `FigureRig`。
完整部件表见 `assets.lua`（自动生成，含每个部件的 `MeshId` 和脸贴图 id）。

---

## 四、怎么用

1. Studio → `File → Open from File` 打开 `.rbxlx`（或 `Insert from File` 插 `.rbxmx`）
2. Explorer 里找带 `FigureRig` 标签的 Model（或直接按 MeshPart 找）
3. 整个 Model 复制进你自己 place 的 `Workspace.Monsters`，重命名成实体名
4. 跑 [../standalone/DoorsTextureChaos.lua](../standalone/DoorsTextureChaos.lua) 开乱斗

> 存档作者提醒：打开后镜头锁死就把 Camera 设 Custom、删掉 `StarterPlayerScripts\PlayerModule`；这些文件是反编译产物，只用来取模型和房间。
