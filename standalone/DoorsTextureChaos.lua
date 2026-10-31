--[[
================================================================================
	DOORS 贴图乱斗 · 单文件版  (DoorsTextureChaos v1.0.0)
================================================================================

	作用：把 Workspace 里一堆 DOORS 生物模型的贴图和建模互相随机乱换。
	      支持一键还原，永远不会把模型改废。

	【用法 A · Studio 里直接看效果（最快）】
	  1. 把模型拖进 Workspace 下面新建的文件夹，名字必须是 "Monsters"，
	     每个生物一个 Model，建议命名成 Rush / Ambush / Figure / Seek ...
	  2. View -> Command Bar 打开命令栏，把本文件全部内容粘进去，回车
	  3. 想换一种乱法：改下面 CONFIG.mode 再粘一次
	  4. 后悔了：Ctrl+Z，或者再粘一次把 CONFIG.action 改成 "restore"

	【用法 B · 挂在服务器上自动乱】
	  1. ServerScriptService 里新建 Script，把本文件内容粘进去
	  2. 它会自己每 CONFIG.runtime.interval 秒乱一次，然后自动还原
	  3. 控制台可以用 _G.DOORS_TEXTURE_CHAOS.shuffle("chaos") 手动触发

	【模式】
	  cross       全局池错排（默认）：每张皮都可能跑到任何人身上，保证不是原位
	  rotate      环形传递：A 拿 B 的、B 拿 C 的……一整圈
	  perMonster  整只打包：把某只生物整套皮（网格+脸）直接穿到另一只身上
	  chaos       完全随机：同一只身上能同时出现好几个不同来源的皮

	【说明】
	  * 只会在你"已经导入到本 place"的模型之间互搬，不联网、不抓别人资源。
	  * 如果搬完贴图变成空白，是 Roblox 的资产权限问题（那张贴图不是公开资产，
	    或者不属于你这个 place），跟本脚本无关。换自己上传的贴图即可。
================================================================================
--]]

local CONFIG = {
	-- 生物模型所在的文件夹（Workspace 下）
	folderName = "Monsters",

	-- "shuffle" 乱一次 / "restore" 全部还原
	action = "shuffle",

	-- cross | rotate | perMonster | chaos
	mode = "cross",

	-- 固定种子：填个数字，同一堆模型永远乱出同一个结果
	seed = nil,

	-- 连 MeshId 一起搬（true = 建模也跟着乱，可能穿模，这就是效果）
	swapMesh = true,

	-- 额外随机染色，更脏更花
	tint = false,

	-- 纯光效类实体别乱换，会直接白屏
	skipEntities = {
		["guiding light"] = true,
		["curious light"] = true,
		["void"] = true,
	},

	-- 挂 ServerScriptService 时的自动乱斗参数
	runtime = {
		enabled = true,
		interval = 45,
		restoreAfter = 20,   -- 0 = 不自动还原
	},

	-- 控制台最多打印多少行
	maxReportLines = 24,
}

--==============================================================================
-- 随机数（可复现）
--==============================================================================

local Rng = {}
Rng.__index = Rng

function Rng.new(seed)
	if seed == nil then
		seed = (os.time() * 1000 + math.floor(os.clock() * 1000)) % 2147483647
	end
	return setmetatable({ seed = seed, rng = Random.new(seed) }, Rng)
end

function Rng:next()
	return self.rng:NextNumber()
end

function Rng:int(lo, hi)
	if hi < lo then
		lo, hi = hi, lo
	end
	return self.rng:NextInteger(lo, hi)
end

function Rng:shuffle(list)
	for i = #list, 2, -1 do
		local j = self.rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- 错排：保证 perm[i] ~= i
function Rng:derangement(n)
	local perm = {}
	for i = 1, n do
		perm[i] = i
	end
	if n < 2 then
		return perm
	end
	self:shuffle(perm)
	for _ = 1, 3 do
		local fixed = false
		for i = 1, n do
			if perm[i] == i then
				fixed = true
				local j = self.rng:NextInteger(1, n)
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

--==============================================================================
-- 底层属性读写（全部 pcall 兜底，读不到的属性自动忽略）
--==============================================================================

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

--==============================================================================
-- 收割：把每只生物身上所有能换的"皮"抽出来
--==============================================================================

local SURFACE_MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
local unitCounter = 0

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
		label = inst:GetFullName(),
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
			if not CONFIG.skipEntities[string.lower(model.Name)] then
				local units = harvestModel(model)
				if #units > 0 then
					monsters[#monsters + 1] = { name = model.Name, model = model, units = units }
				end
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

--==============================================================================
-- 计划：先算出"谁拿谁的皮"，再统一写（两段式，避免链式污染）
--==============================================================================

local KINDS = { "mesh", "decal", "specialmesh", "surface" }

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

local function addStep(plan, target, donor)
	local props = readUnit(donor)
	if next(props) == nil then
		return
	end
	plan.steps[#plan.steps + 1] = { target = target, donor = donor, props = props }
end

local function planShuffle(monsters, opts)
	opts = opts or {}
	local mode = opts.mode or CONFIG.mode
	local rng = Rng.new(opts.seed or CONFIG.seed)
	local plan = { mode = mode, seed = rng.seed, steps = {}, tint = CONFIG.tint }

	if mode == "perMonster" and #monsters >= 2 then
		local perm = rng:derangement(#monsters)
		local buffer = {}
		for i = 1, #monsters do
			buffer[i] = monsters[i]
		end
		for i, target in ipairs(buffer) do
			local donor = buffer[perm[i]]
			for _, kind in ipairs(KINDS) do
				local tUnits = collectKind({ target }, kind)
				local dUnits = collectKind({ donor }, kind)
				if #tUnits > 0 and #dUnits > 0 then
					for index, unit in ipairs(tUnits) do
						addStep(plan, unit, dUnits[((index - 1) % #dUnits) + 1])
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
					local shift = rng:int(1, #donors - 1)
					for index, unit in ipairs(donors) do
						addStep(plan, unit, donors[((index - 1 + shift) % #donors) + 1])
					end
				elseif mode == "chaos" then
					for _, unit in ipairs(donors) do
						addStep(plan, unit, donors[rng:int(1, #donors)])
					end
				else
					local perm = rng:derangement(#donors)
					for index, unit in ipairs(donors) do
						addStep(plan, unit, donors[perm[index]])
					end
				end
			end
		end
	end

	return plan
end

local function applyPlan(plan)
	local blockedMesh = not CONFIG.swapMesh
	local changed = 0

	for _, step in ipairs(plan.steps) do
		local props = step.props
		if blockedMesh and props.MeshId ~= nil then
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

	if plan.tint then
		local rng = Rng.new(plan.seed + 7919)
		local seen = {}
		for _, step in ipairs(plan.steps) do
			local inst = step.target.inst
			if not seen[inst] and (inst:IsA("Decal") or inst:IsA("Texture")) then
				seen[inst] = true
				if set(inst, "Color3", Color3.fromHSV(rng:next(), 0.7, 1)) then
					changed = changed + 1
				end
			end
		end
	end

	return changed
end

local function report(plan)
	local lines = {
		string.format("DOORS 贴图乱斗 | 模式=%s | 种子=%d | 替换=%d 处", plan.mode, plan.seed, #plan.steps),
	}
	for index, step in ipairs(plan.steps) do
		if index > CONFIG.maxReportLines then
			lines[#lines + 1] = string.format("……还有 %d 处", #plan.steps - CONFIG.maxReportLines)
			break
		end
		lines[#lines + 1] = string.format(
			"  %s[%s]  <-  %s[%s]",
			tostring(step.target.owner), tostring(step.target.name),
			tostring(step.donor.owner), tostring(step.donor.name)
		)
	end
	return table.concat(lines, "\n")
end

--==============================================================================
-- 入口
--==============================================================================

-- 执行器里没有输出台，"没反应"和"跑了但没找到东西"看起来一模一样。
-- 所以关键节点直接在屏幕上弹一条，8 秒后自动消失。
local function notify(message)
	pcall(function()
		local player = game:GetService("Players").LocalPlayer
		if not player then
			return
		end
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local old = playerGui:FindFirstChild("DoorsChaosToast")
		if old then
			old:Destroy()
		end

		local screen = Instance.new("ScreenGui")
		screen.Name = "DoorsChaosToast"
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 90

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 520, 0, 64)
		label.Position = UDim2.new(0.5, -260, 0, 40)
		label.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		label.BackgroundTransparency = 0.12
		label.BorderSizePixel = 0
		label.TextColor3 = Color3.fromRGB(255, 200, 90)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 15
		label.TextWrapped = true
		label.Text = message
		label.Parent = screen

		screen.Parent = playerGui
		task.delay(8, function()
			pcall(function()
				screen:Destroy()
			end)
		end)
	end)
end

local function resolveFolder()
	local workspaceService = game:GetService("Workspace")
	local folder = workspaceService:FindFirstChild(CONFIG.folderName)
	if not folder then
		-- 兜底：Studio 里如果只选了一个模型，就直接用它
		local ok, selection = pcall(function()
			return game:GetService("Selection"):Get()
		end)
		if ok and selection and #selection > 0 then
			return selection[1]
		end
	end
	return folder
end

local function runOnce()
	local root = resolveFolder()
	if not root then
		notify(string.format("找不到 Workspace.%s（也没选中模型）", CONFIG.folderName))
		warn(string.format("[乱斗] 找不到 Workspace.%s，也没选中任何模型", CONFIG.folderName))
		return nil
	end

	local monsters = harvest(root)
	if #monsters == 0 then
		notify(string.format("%s 里没有带贴图的模型", root.Name))
		warn("[乱斗] 这个文件夹里没有带贴图的模型")
		return nil
	end

	local totalUnits = 0
	for _, monster in ipairs(monsters) do
		totalUnits = totalUnits + #monster.units
	end

	print(string.format("[乱斗] 扫到 %d 只生物 / %d 个贴图单元", #monsters, totalUnits))

	if CONFIG.action == "restore" then
		print(string.format("[乱斗] 已还原 %d 处", restoreAll(monsters)))
		return nil
	end

	local plan = planShuffle(monsters, {})
	local changed = applyPlan(plan)
	print(report(plan))
	print(string.format("[乱斗] 实际写入 %d 处。要还原：CONFIG.action = \"restore\" 再跑一次，或直接 Ctrl+Z。", changed))
	notify(string.format("乱斗完成：%d 只生物，%d 处替换（种子 %d）", #monsters, changed, plan.seed))

	return { monsters = monsters, plan = plan }
end

local mounted = false
do
	local ok, isScript = pcall(function()
		return typeof(script) == "Instance" and script:IsA("Script")
	end)
	mounted = ok and isScript
end

if mounted then
	-- 挂在服务器：定时乱斗
	local state = { monsters = {} }

	local function scan()
		local root = resolveFolder()
		state.monsters = root and harvest(root) or {}
		return state.monsters
	end

	local function shuffle(mode, seed)
		if #state.monsters == 0 then
			scan()
		end
		if #state.monsters == 0 then
			return nil
		end
		local plan = planShuffle(state.monsters, { mode = mode, seed = seed })
		local changed = applyPlan(plan)
		print(report(plan) .. string.format("\n[乱斗] 写入 %d 处", changed))
		return plan
	end

	local function restore()
		return restoreAll(state.monsters)
	end

	_G.DOORS_TEXTURE_CHAOS = {
		scan = scan,
		shuffle = shuffle,
		restore = restore,
		state = state,
	}

	task.spawn(function()
		task.wait(1)
		scan()
		if not CONFIG.runtime.enabled then
			return
		end
		while true do
			task.wait(CONFIG.runtime.interval)
			local ok, err = pcall(function()
				local plan = shuffle(CONFIG.mode, os.time())
				if plan and CONFIG.runtime.restoreAfter > 0 then
					task.wait(CONFIG.runtime.restoreAfter)
					restore()
				end
			end)
			if not ok then
				warn("[乱斗] 本轮出错：" .. tostring(err))
			end
		end
	end)
else
	-- 命令栏 / 一次性执行：包一层撤销点，Ctrl+Z 可以退
	local ok = pcall(function()
		game:GetService("ChangeHistoryService"):SetWaypoint("DOORS 贴图乱斗")
	end)
	if not ok then
		-- 某些环境没有 ChangeHistoryService，忽略即可
	end

	runOnce()

	pcall(function()
		game:GetService("ChangeHistoryService"):SetWaypoint("DOORS 贴图乱斗 · 完成")
	end)
end
