--[[
================================================================================
	DOORS 贴图乱斗 · Studio 插件  (DoorsTextureChaos v1.0.0)
================================================================================

	安装：
	  1. 把本文件改名为  DoorsTextureChaos.plugin.lua
	  2. 丢进插件目录：
	       Windows: %LOCALAPPDATA%\Roblox\Plugins
	       macOS  : ~/Documents/Roblox/Plugins
	  3. 重启 Studio（或在 Plugins 标签页点 "Refresh"）
	  4. 工具栏会出现 "DOORS 贴图乱斗"

	面板功能：
	  扫描   读 workspace 下指定文件夹里的所有生物，统计可换的贴图单元
	  乱斗   按当前模式随机互搬（支持 Ctrl+Z 撤销）
	  还原   回到扫描时的原始状态
	  导出   把扫描结果打成 Lua 表输出到面板，方便存档/写文档

	和 standalone 版共用同一套逻辑：mesh / decal / specialmesh / surfaceAppearance
================================================================================
--]]

if not plugin then
	return
end

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MODES = { "cross", "rotate", "perMonster", "chaos" }
local SURFACE_MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
local KINDS = { "mesh", "decal", "specialmesh", "surface" }

local state = {
	folderName = "Monsters",
	mode = "cross",
	seed = nil,
	swapMesh = true,
	tint = false,
	monsters = {},
	scanned = false,
}

--==============================================================================
-- 引擎
--==============================================================================

local unitCounter = 0

local function get(inst, prop)
	local ok, value = pcall(function()
		return inst[prop]
	end)
	if ok then
		return value
	end
	return nil
end

local function set(inst, prop, value)
	return (pcall(function()
		inst[prop] = value
	end))
end

local function makeUnit(owner, inst, kind, props, primary)
	unitCounter = unitCounter + 1
	local origin = {}
	for k, v in pairs(props) do
		origin[k] = v
	end
	return {
		id = unitCounter,
		owner = owner,
		inst = inst,
		kind = kind,
		props = props,
		origin = origin,
		primary = primary,
		name = inst.Name,
	}
end

local function harvestModel(model)
	local units = {}
	local owner = model.Name

	for _, inst in ipairs(model:GetDescendants()) do
		local cls = inst.ClassName
		if cls == "MeshPart" then
			local props = {}
			local meshId = get(inst, "MeshId")
			local textureId = get(inst, "TextureID")
			if type(meshId) == "string" and meshId ~= "" then
				props.MeshId = meshId
			end
			if type(textureId) == "string" and textureId ~= "" then
				props.TextureID = textureId
			end
			if next(props) ~= nil then
				units[#units + 1] = makeUnit(owner, inst, "mesh", props, props.TextureID or props.MeshId or "")
			end
		elseif cls == "Decal" or cls == "Texture" then
			local value = get(inst, "Texture")
			if type(value) == "string" and value ~= "" then
				units[#units + 1] = makeUnit(owner, inst, "decal", { Texture = value }, value)
			end
		elseif cls == "SpecialMesh" then
			local value = get(inst, "TextureId")
			if type(value) == "string" and value ~= "" then
				units[#units + 1] = makeUnit(owner, inst, "specialmesh", { TextureId = value }, value)
			end
		elseif cls == "SurfaceAppearance" then
			local props = {}
			for _, prop in ipairs(SURFACE_MAPS) do
				local value = get(inst, prop)
				if type(value) == "string" and value ~= "" then
					props[prop] = value
				end
			end
			if next(props) ~= nil then
				units[#units + 1] = makeUnit(owner, inst, "surface", props, props.ColorMap or "")
			end
		end
	end

	return units
end

local function harvest(root)
	local monsters = {}
	for _, model in ipairs(root:GetChildren()) do
		if model:IsA("Model") or model:IsA("Folder") then
			local units = harvestModel(model)
			if #units > 0 then
				monsters[#monsters + 1] = { name = model.Name, model = model, units = units }
			end
		end
	end
	return monsters
end

local function readUnit(unit)
	local props = {}
	for prop in pairs(unit.props) do
		local value = get(unit.inst, prop)
		if value ~= nil then
			props[prop] = value
		end
	end
	return props
end

local function paint(unit, props)
	local changed = 0
	for prop, value in pairs(props) do
		if prop ~= "Size" and prop ~= "CFrame" then
			if set(unit.inst, prop, value) then
				changed = changed + 1
			end
		end
	end
	return changed
end

local function restoreAll(monsters)
	local changed = 0
	for _, monster in ipairs(monsters) do
		for _, unit in ipairs(monster.units) do
			changed = changed + paint(unit, unit.origin)
		end
	end
	return changed
end

local function collectKind(monsters, kind)
	local list = {}
	for _, monster in ipairs(monsters) do
		for _, unit in ipairs(monster.units) do
			if unit.kind == kind then
				list[#list + 1] = unit
			end
		end
	end
	return list
end

local function shuffleList(list, rng)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function derangement(n, rng)
	local perm = {}
	for i = 1, n do
		perm[i] = i
	end
	if n < 2 then
		return perm
	end
	shuffleList(perm, rng)
	for _ = 1, 3 do
		local fixed = false
		for i = 1, n do
			if perm[i] == i then
				fixed = true
				local j = rng:NextInteger(1, n)
				if j == i then
					j = (i % n) + 1
				end
				perm[i], perm[j] = perm[j], perm[i]
			end
		end
		if not fixed then
			break
		end
	end
	for i = 1, n do
		if perm[i] == i then
			perm[i], perm[(i % n) + 1] = perm[(i % n) + 1], perm[i]
		end
	end
	return perm
end

local function plan(monsters, mode, seed)
	local rng = seed and Random.new(seed) or Random.new()
	local planData = { mode = mode, seed = seed or rng:NextInteger(1, 2147483647), steps = {} }

	local function addStep(target, donor)
		local props = readUnit(donor)
		if next(props) == nil then
			return
		end
		planData.steps[#planData.steps + 1] = { target = target, donor = donor, props = props }
	end

	if mode == "perMonster" and #monsters >= 2 then
		local perm = derangement(#monsters, rng)
		local buffer = {}
		for i = 1, #monsters do
			buffer[i] = monsters[i]
		end
		for i, target in ipairs(buffer) do
			local donor = buffer[perm[i]]
			for _, kind in ipairs(KINDS) do
				local targetUnits = collectKind({ target }, kind)
				local donorUnits = collectKind({ donor }, kind)
				if #targetUnits > 0 and #donorUnits > 0 then
					for index, unit in ipairs(targetUnits) do
						addStep(unit, donorUnits[((index - 1) % #donorUnits) + 1])
					end
				end
			end
		end
	else
		for _, kind in ipairs(KINDS) do
			local donors = {}
			for _, unit in ipairs(collectKind(monsters, kind)) do
				if type(unit.primary) == "string" and unit.primary ~= "" then
					donors[#donors + 1] = unit
				end
			end

			if #donors >= 2 then
				if mode == "rotate" then
					local shift = rng:NextInteger(1, #donors - 1)
					for index, unit in ipairs(donors) do
						addStep(unit, donors[((index - 1 + shift) % #donors) + 1])
					end
				elseif mode == "chaos" then
					for _, unit in ipairs(donors) do
						addStep(unit, donors[rng:NextInteger(1, #donors)])
					end
				else
					local perm = derangement(#donors, rng)
					for index, unit in ipairs(donors) do
						addStep(unit, donors[perm[index]])
					end
				end
			end
		end
	end

	return planData
end

local function applyPlan(planData)
	local changed = 0
	for _, step in ipairs(planData.steps) do
		local props = step.props
		if not state.swapMesh and props.MeshId ~= nil then
			local copy = {}
			for k, v in pairs(props) do
				if k ~= "MeshId" then
					copy[k] = v
				end
			end
			props = copy
		end
		changed = changed + paint(step.target, props)
	end

	if state.tint then
		local rng = Random.new(planData.seed + 7919)
		local seen = {}
		for _, step in ipairs(planData.steps) do
			local inst = step.target.inst
			if not seen[inst] and (inst:IsA("Decal") or inst:IsA("Texture")) then
				seen[inst] = true
				if set(inst, "Color3", Color3.fromHSV(rng:NextNumber(), 0.7, 1)) then
					changed = changed + 1
				end
			end
		end
	end

	return changed
end

--==============================================================================
-- 插件 UI
--==============================================================================

local toolbar = plugin:CreateToolbar("DOORS 贴图乱斗")
local button = toolbar:CreateButton("乱斗面板", "扫描生物模型并随机互换贴图 / 建模", "rbxassetid://6031075931")
button.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	340,
	520,
	320,
	380
)
local widget = plugin:CreateDockWidgetPluginGui("DoorsTextureChaosPanel", widgetInfo)
widget.Title = "DOORS 贴图乱斗"

local function make(class, props)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

local root = make("ScrollingFrame", {
	Parent = widget,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
})

make("UIPadding", {
	Parent = root,
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
})

make("UIListLayout", {
	Parent = root,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local function label(text, size, bold)
	return make("TextLabel", {
		Parent = root,
		Size = UDim2.new(1, 0, 0, size or 18),
		BackgroundTransparency = 1,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		Text = text,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(226, 226, 232),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
end

local folderBox = make("TextBox", {
	Parent = root,
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = Color3.fromRGB(30, 30, 36),
	BorderSizePixel = 0,
	Font = Enum.Font.Code,
	Text = state.folderName,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(235, 235, 240),
	ClearTextOnFocus = false,
	PlaceholderText = "Workspace 下的文件夹名",
})

make("UICorner", { Parent = folderBox, CornerRadius = UDim.new(0, 6) })

local modeButton = make("TextButton", {
	Parent = root,
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundColor3 = Color3.fromRGB(52, 52, 62),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamMedium,
	Text = "模式：" .. state.mode,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(240, 240, 245),
	AutoButtonColor = true,
})

make("UICorner", { Parent = modeButton, CornerRadius = UDim.new(0, 6) })

local seedBox = make("TextBox", {
	Parent = root,
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = Color3.fromRGB(30, 30, 36),
	BorderSizePixel = 0,
	Font = Enum.Font.Code,
	Text = "",
	TextSize = 13,
	TextColor3 = Color3.fromRGB(235, 235, 240),
	PlaceholderText = "种子（留空 = 每轮随机）",
	ClearTextOnFocus = false,
})

make("UICorner", { Parent = seedBox, CornerRadius = UDim.new(0, 6) })

local swapButton = make("TextButton", {
	Parent = root,
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = Color3.fromRGB(52, 52, 62),
	BorderSizePixel = 0,
	Font = Enum.Font.Gotham,
	Text = "连建模一起换：开",
	TextSize = 13,
	TextColor3 = Color3.fromRGB(240, 240, 245),
})

make("UICorner", { Parent = swapButton, CornerRadius = UDim.new(0, 6) })

local tintButton = make("TextButton", {
	Parent = root,
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = Color3.fromRGB(52, 52, 62),
	BorderSizePixel = 0,
	Font = Enum.Font.Gotham,
	Text = "随机染色：关",
	TextSize = 13,
	TextColor3 = Color3.fromRGB(240, 240, 245),
})

make("UICorner", { Parent = tintButton, CornerRadius = UDim.new(0, 6) })

local actionRow = make("Frame", {
	Parent = root,
	Size = UDim2.new(1, 0, 0, 32),
	BackgroundTransparency = 1,
})

make("UIListLayout", {
	Parent = actionRow,
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local function actionButton(text, color, order, parent)
	local btn = make("TextButton", {
		Parent = parent,
		Size = UDim2.new(0.333, -4, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		LayoutOrder = order,
	})
	make("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 6) })
	return btn
end

local scanBtn = actionButton("扫描", Color3.fromRGB(58, 96, 160), 1, actionRow)
local shuffleBtn = actionButton("乱斗", Color3.fromRGB(170, 52, 52), 2, actionRow)
local revertBtn = actionButton("还原", Color3.fromRGB(58, 120, 82), 3, actionRow)

local exportBtn = make("TextButton", {
	Parent = root,
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundColor3 = Color3.fromRGB(46, 46, 54),
	BorderSizePixel = 0,
	Font = Enum.Font.Gotham,
	Text = "导出清单到日志",
	TextSize = 12,
	TextColor3 = Color3.fromRGB(220, 220, 228),
})

make("UICorner", { Parent = exportBtn, CornerRadius = UDim.new(0, 6) })

local logBox = make("TextBox", {
	Parent = root,
	Size = UDim2.new(1, 0, 0, 240),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	BorderSizePixel = 0,
	Font = Enum.Font.Code,
	Text = "就绪。把生物模型放进 Workspace 的文件夹里，点“扫描”。",
	TextSize = 12,
	TextColor3 = Color3.fromRGB(200, 240, 200),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	MultiLine = true,
	ClearTextOnFocus = false,
	TextEditable = true,
})

make("UICorner", { Parent = logBox, CornerRadius = UDim.new(0, 6) })
make("UIPadding", { Parent = logBox, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })

local logLines = {}

local function log(message)
	logLines[#logLines + 1] = tostring(message)
	while #logLines > 120 do
		table.remove(logLines, 1)
	end
	logBox.Text = table.concat(logLines, "\n")
end

--==============================================================================
-- 动作
--==============================================================================

local function resolveRoot()
	local workspaceService = game:GetService("Workspace")
	return workspaceService:FindFirstChild(folderBox.Text)
end

local function doScan()
	state.folderName = folderBox.Text
	local root = resolveRoot()
	if not root then
		log(string.format("找不到 Workspace.%s", folderBox.Text))
		state.monsters = {}
		state.scanned = false
		return nil
	end

	state.monsters = harvest(root)
	state.scanned = #state.monsters > 0

	local units = 0
	local skinned = 0
	for _, monster in ipairs(state.monsters) do
		for _, unit in ipairs(monster.units) do
			units = units + 1
			if type(unit.primary) == "string" and unit.primary ~= "" then
				skinned = skinned + 1
			end
		end
	end

	log(string.format("扫描完成：%d 只生物 / %d 个贴图单元 / %d 个带皮", #state.monsters, units, skinned))
	for _, monster in ipairs(state.monsters) do
		log(string.format("  · %s（%d 个单元）", monster.name, #monster.units))
	end
	return state.monsters
end

local function beginRecord(name)
	local ok, recording = pcall(function()
		return ChangeHistoryService:TryBeginRecording(name)
	end)
	if ok then
		return recording
	end
	return nil
end

local function endRecord(recording, commit)
	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(recording, commit and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
		end)
	else
		pcall(function()
			ChangeHistoryService:SetWaypoint("DOORS 贴图乱斗")
		end)
	end
end

local function parseSeed()
	local text = string.match(seedBox.Text, "%d+")
	if text then
		return tonumber(text)
	end
	return nil
end

local function doShuffle()
	if not state.scanned or #state.monsters == 0 then
		if not doScan() then
			return
		end
	end

	local seed = parseSeed()
	local planData = plan(state.monsters, state.mode, seed)
	if #planData.steps == 0 then
		log("没有可替换的单元（模型里可能只有一张贴图，或者都没贴图）")
		return
	end

	local recording = beginRecord("DOORS 贴图乱斗")
	local changed = applyPlan(planData)
	endRecord(recording, true)

	log(string.format("第 %d 轮 | 模式=%s | 种子=%d | 写入 %d 处", os.time() % 10000, planData.mode, planData.seed, changed))
	for index, step in ipairs(planData.steps) do
		if index > 12 then
			log(string.format("  ……还有 %d 处", #planData.steps - 12))
			break
		end
		log(string.format("  %s[%s] <- %s[%s]", step.target.owner, step.target.name, step.donor.owner, step.donor.name))
	end
end

local function doRevert()
	if not state.scanned or #state.monsters == 0 then
		log("还没扫描过，先点“扫描”")
		return
	end

	local recording = beginRecord("DOORS 贴图乱斗 · 还原")
	local changed = restoreAll(state.monsters)
	endRecord(recording, true)
	log(string.format("已还原 %d 处", changed))
end

local function doExport()
	if #state.monsters == 0 then
		log("没有数据，先扫描")
		return
	end

	local parts = { "return {" }
	for _, monster in ipairs(state.monsters) do
		parts[#parts + 1] = string.format("\t[%q] = {", monster.name)
		for _, unit in ipairs(monster.units) do
			parts[#parts + 1] = string.format("\t\t{ kind = %q, name = %q, asset = %q },", unit.kind, unit.name, tostring(unit.primary))
		end
		parts[#parts + 1] = "\t},"
	end
	parts[#parts + 1] = "}"
	log("— 清单开始（可直接全选复制）—")
	log(table.concat(parts, "\n"))
	log("— 清单结束 —")
end

--==============================================================================
-- 绑定
--==============================================================================

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

modeButton.MouseButton1Click:Connect(function()
	local index = table.find(MODES, state.mode) or 1
	state.mode = MODES[(index % #MODES) + 1]
	modeButton.Text = "模式：" .. state.mode
end)

swapButton.MouseButton1Click:Connect(function()
	state.swapMesh = not state.swapMesh
	swapButton.Text = "连建模一起换：" .. (state.swapMesh and "开" or "关")
end)

tintButton.MouseButton1Click:Connect(function()
	state.tint = not state.tint
	tintButton.Text = "随机染色：" .. (state.tint and "开" or "关")
end)

scanBtn.MouseButton1Click:Connect(function()
	pcall(doScan)
end)

shuffleBtn.MouseButton1Click:Connect(function()
	local ok, err = pcall(doShuffle)
	if not ok then
		log("出错：" .. tostring(err))
	end
end)

revertBtn.MouseButton1Click:Connect(function()
	local ok, err = pcall(doRevert)
	if not ok then
		log("出错：" .. tostring(err))
	end
end)

exportBtn.MouseButton1Click:Connect(function()
	pcall(doExport)
end)

log("插件已加载 v1.0.0")
