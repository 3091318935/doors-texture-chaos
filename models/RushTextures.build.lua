--[[
================================================================================
	RushTextures.build.lua —— 把解包出来的 Rush 贴图做成可换的测试皮
================================================================================

	这三个 asset id 是从 `new halt floor 1.rbxlx` 里的 `RushMoving` 模型上抠出来的
	（Decal 名原样保留）：

		EyesTexture   rbxassetid://6439010561
		TryTexture    rbxassetid://8829361602
		TryTexture2   rbxassetid://7807728404

	用法：Studio → Command Bar → 粘这段 → 回车
	      生成 Workspace.Monsters.Rush，三块板各贴一张，正面朝你。

	为什么需要它：
	  FigureRig 那 31 个网格**没有皮肤**（TextureID=0、Decal=0）。
	  要玩"贴图乱改到不同生物身上"，场上得先有 Decal 才有皮可抢。
	  这三张就是目前挖到的唯一真实 DOORS 贴图。

	注意：这些 id 属于别人上传的资产，Roblox 按 place 授权。
	      贴图空白 = 没渲染权限，换你自己上传的图即可，脚本逻辑不受影响。
================================================================================
--]]

local CONFIG = {
	folderName = "Monsters",
	modelName = "Rush",
	basePosition = Vector3.new(-12, 10, 0),
	spacing = 6,
	boardSize = 5,
}

local TEXTURES = {
	{ name = "EyesTexture", id = "rbxassetid://6439010561" },
	{ name = "TryTexture",  id = "rbxassetid://8829361602" },
	{ name = "TryTexture2", id = "rbxassetid://7807728404" },
}

local Workspace = game:GetService("Workspace")

local Selection = nil
pcall(function()
	Selection = game:GetService("Selection")
end)
local ChangeHistoryService = nil
pcall(function()
	ChangeHistoryService = game:GetService("ChangeHistoryService")
end)

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("Build Rush textures")
end)

local folder = Workspace:FindFirstChild(CONFIG.folderName)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = CONFIG.folderName
	folder.Parent = Workspace
end

local old = folder:FindFirstChild(CONFIG.modelName)
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = CONFIG.modelName

for index, entry in ipairs(TEXTURES) do
	local board = Instance.new("Part")
	board.Name = entry.name
	board.Size = Vector3.new(CONFIG.boardSize, CONFIG.boardSize, 0.2)
	board.Position = CONFIG.basePosition + Vector3.new((index - 1) * CONFIG.spacing, 0, 0)
	board.Anchored = true
	board.CanCollide = false
	board.Material = Enum.Material.SmoothPlastic
	board.Color = Color3.fromRGB(255, 255, 255)
	board.TopSurface = Enum.SurfaceType.Smooth
	board.BottomSurface = Enum.SurfaceType.Smooth

	local decal = Instance.new("Decal")
	decal.Name = entry.name
	decal.Face = Enum.NormalId.Front
	decal.Texture = entry.id
	decal.Parent = board

	-- 备份：原始 id 存在属性里，随时能查/还原
	board:SetAttribute("OriginalTexture", entry.id)

	board.Parent = model
end

model.Parent = folder

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
end

pcall(function() Selection:Set({ model }) end)

print(string.format("[RushTextures] 生成 %d 块贴图板 -> %s", #TEXTURES, model:GetFullName()))
print("[RushTextures] 贴图空白 = 资产没权限；三张 id 已写进 OriginalTexture 属性")
print("[RushTextures] 下一步：跑 standalone/DoorsTextureChaos.lua，模式用 chaos 最能看出效果")
