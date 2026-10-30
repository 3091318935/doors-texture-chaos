--!strict
--[[
	Config.lua —— 所有可调参数集中在这里
	改这个文件就够了，不用碰引擎代码。
--]]

local Config = {}

-- 生物模型放在 Workspace 下的哪个文件夹
Config.FolderName = "Monsters"

-- 默认乱斗参数
Config.Default = {
	mode = "cross",      -- cross | rotate | perMonster | chaos
	swapMesh = true,     -- 连 MeshId 一起搬（真正的"建模也跟着乱"）
	tint = false,        -- 额外给 Decal/Texture 随机染色，更脏更乱
	seed = nil,          -- 固定种子 = 每轮结果可复现
}

-- 可用模式
Config.Modes = { "cross", "rotate", "perMonster", "chaos" }

-- 不参与乱斗的实体（纯光效，换贴图直接崩画面）
Config.SkipEntities = {
	["Guiding Light"] = true,
	["Curious Light"] = true,
	["Void"] = true,
}

-- 永远不写的属性（写进去会坏结构 / 只读）
Config.ReadOnlyProps = {
	Size = true,
	Position = true,
	CFrame = true,
}

-- 运行时：服务器自动定时乱斗
Config.Runtime = {
	enabled = true,
	interval = 45,       -- 每 45 秒乱一次
	restoreAfter = 20,   -- 乱完 20 秒复原；设为 0 = 不复原，一直保持
	verbose = true,      -- 输出台打印每一轮
}

return Config
