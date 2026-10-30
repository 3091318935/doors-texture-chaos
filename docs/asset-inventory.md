# 资产清查结果

从 `Palayop7239/DoorsFiles` 的解包存档里扫出来的东西。全部是实测数据，不是推测。

扫描范围：`D:\DSH ROBLOX\doors_downloads` 下 8 个 XML 存档，**3390 个 Model 块**。

---

## 已经拿到手的实体

| 实体 | 网格部件 | 贴图 | 来源文件 | 重建脚本 |
| --- | --- | --- | --- | --- |
| **Figure** | 31（`FigureRig`，32 个 MeshPart 里 `Root` 无 MeshId） | 0 | `sewers 5 + figure.rbxmx`、`figure 1st appear.rbxlx` | `models/FigureRig.build.lua` |
| **Figure（完整版）** | 32 | 2（同 id `2542432117`） | `jeff f1.rbxlx` 的 `FigureAnimatedWelded` | `models/FigureWelded.build.lua` |
| **Seek** | 15 | 1 | `new halt floor 1.rbxlx` | `models/EntityRigs.build.lua` |
| **Glitch** | 6 | 1（重复 24 次） | `figure 1st appear.rbxlx` | `models/EntityRigs.build.lua` |
| **Rush** | 0 | 3 | `new halt floor 1.rbxlx` | `models/RushTextures.build.lua` |
| **Giggle** | 21 | 2 | `figure 1st appear.rbxlx` | `models/EntityRigs.build.lua` |
| **El Goblino** | 31 | 0 | `jeff f1.rbxlx` | `models/ElGoblino.build.lua` |
| **Bob**（`SkellyFriend`） | 20 | 0 | `jeff f1.rbxlx` | `models/Bob.build.lua` |
| **Timothy**（`Spider`） | 11 | 0 | `jeff f1.rbxlx` | `models/Timothy.build.lua` |
| **ScreechRetro** | 7 | 0 | `figure 1st appear.rbxlx` | 未做：6 个相同 Cone + Shade，脸贴图 id 为空 |

> 上表数字是 **XML DOM 实测**（`tools/rig-to-lua.ps1` 现在用 `XmlDocument` + XPath 定位，
> 不再用正则切片）。早期的正则版本会因为嵌套 Model 或 `ProtectedString` 里的 `<Item`
> 字面量而截断，同一只 rig 数出来的部件数会偏 1–3 个 —— 以本表为准。

### 关键贴图 id

```
Rush    EyesTexture    rbxassetid://6439010561
        TryTexture     rbxassetid://8829361602
        TryTexture2    rbxassetid://7807728404
Seek    （1 张）        rbxassetid://6507084861
Glitch  （1 张）        rbxassetid://10216168173
Giggle  Main           rbxassetid://8829534246
        Eyes           rbxassetid://10085378708
```

---

## 看到了但没做成脚本的

这些 Model 在存档里存在，但**没有 MeshId 也没有 Decal**（纯 Part 拼装），扫出来是空壳：

`Dupe`、`SideroomDupe`、`Voids`、`Figure`（非 Rig 版）、`Figureold`、`Screech`

`GloomPile` / `GloomEgg`（gaz + gloombats）同理，只有碰撞体和贴花，没有网格。

---

## 判定逻辑（写清楚，避免下次再踩）

1. Roblox XML 里资产引用长这样：
   `<Content name="MeshId"><url><![CDATA[rbxassetid://12345]]></url></Content>`
   正则必须容忍 `<url><![CDATA[` 这一层。
2. `Name` 属性排在 `InitialSize` / `CFrame` / `PhysicalProperties` / 大段 base64 `AttributesSerialize` **之后**，
   固定长度切片切不到，必须以"下一个 `<Item class=`"为界。
3. **MeshPart 没有 `TextureID`**，贴图全在子级 `Decal` / `Texture` 的 `name="Texture"` 上。
4. 实体识别不能只看 `Humanoid`：Seek 的 `SeekRig` 有，Rush 的 `RushMoving` 也有，
   但 `Glitch`、`ScreechRetro` 这些是按名字才认出来的。按名字扫一遍是必须的。
5. 解包者自己的账号名会作为一个 Model 出现（`PalaCraft7239`），还有 `ViewModel` /
   `ViewModelOld`（第一人称手臂）—— 这些是噪声，要从结果里剔掉。

---

## 还要补的

- `jeff f1.rbxlx`（16.8 MB）正在下载 —— 里面应该有 **Jeff / El Goblino / Bob**，下完用
  `tools/rig-to-lua.ps1` 直接生成对应脚本
- Ambush 目前**完全没出现**在任何存档里 —— 它出现得太快，解包时大概没被抓到
- `ScreechRetro` 的脸贴图 id 在原始 dump 里就是空的，没有可补的
