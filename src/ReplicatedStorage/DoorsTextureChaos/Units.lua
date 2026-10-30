--!strict
--[[
	Units.lua —— 贴图单元收割机

	把一只生物身上所有"能换的皮"抽成 unit：

		MeshPart          -> { MeshId, TextureID }   （整块皮，连建模一起搬）
		Decal / Texture   -> { Texture }             （脸、贴纸、表面贴图）
		SpecialMesh       -> { TextureId }           （旧版网格皮）
		SurfaceAppearance -> { ColorMap, NormalMap, RoughnessMap, MetalnessMap }

	每个 unit 在抓取时会把原值存进 unit.origin，
	所以任何时候都能一键还原，不会把模型改废。
--]]

local Units = {}

local SURFACE_MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
local nextId = 0

local function safeGet(inst: Instance, prop: string): any
	local ok, value = pcall(function()
		return (inst :: any)[prop]
	end)
	if ok then
		return value
	end
	return nil
end

local function setProp(inst: Instance, prop: string, value: any): boolean
	local ok = pcall(function()
		(inst :: any)[prop] = value
	end)
	return ok
end

local function copyTable(source: { [string]: any }): { [string]: any }
	local out = {}
	for key, value in pairs(source) do
		out[key] = value
	end
	return out
end

local function makeUnit(owner: string, inst: Instance, kind: string, props: { [string]: any }, primary: string)
	nextId = nextId + 1
	return {
		id = nextId,
		owner = owner,
		inst = inst,
		kind = kind,
		props = props,
		origin = copyTable(props),
		primary = primary,
		name = inst.Name,
		label = inst:GetFullName(),
	}
end

local function harvestModel(model: Instance, owner: string)
	local units = {}

	for _, inst in ipairs(model:GetDescendants()) do
		local cls = inst.ClassName

		if cls == "MeshPart" then
			local props = {}
			local meshId = safeGet(inst, "MeshId")
			local textureId = safeGet(inst, "TextureID")
			if type(meshId) == "string" and meshId ~= "" then
				props.MeshId = meshId
			end
			if type(textureId) == "string" and textureId ~= "" then
				props.TextureID = textureId
			end
			if next(props) ~= nil then
				local primary = props.TextureID or props.MeshId or ""
				units[#units + 1] = makeUnit(owner, inst, "mesh", props, primary)
			end
		elseif cls == "Decal" or cls == "Texture" then
			local value = safeGet(inst, "Texture")
			if type(value) == "string" and value ~= "" then
				units[#units + 1] = makeUnit(owner, inst, "decal", { Texture = value }, value)
			end
		elseif cls == "SpecialMesh" then
			local value = safeGet(inst, "TextureId")
			if type(value) == "string" and value ~= "" then
				units[#units + 1] = makeUnit(owner, inst, "specialmesh", { TextureId = value }, value)
			end
		elseif cls == "SurfaceAppearance" then
			local props = {}
			for _, prop in ipairs(SURFACE_MAPS) do
				local value = safeGet(inst, prop)
				if type(value) == "string" and value ~= "" then
					props[prop] = value
				end
			end
			if next(props) ~= nil then
				local primary = props.ColorMap or props.NormalMap or ""
				units[#units + 1] = makeUnit(owner, inst, "surface", props, primary)
			end
		end
	end

	return units
end

--[[
	root 可以是文件夹、模型，或模型数组。
	opts.skip: 小写名字集合，命中的子节点直接跳过（例如 guiding light）
	返回 { { name, model, units = {...} }, ... }
--]]
function Units.harvest(root: any, opts: { [string]: any }?): { any }
	opts = opts or {}
	local skip = opts.skip or {}
	local monsters = {}

	local candidates = {}
	if typeof(root) == "Instance" then
		candidates = root:GetChildren()
	elseif typeof(root) == "table" then
		candidates = root
	end

	for _, model in ipairs(candidates) do
		if typeof(model) == "Instance" and (model:IsA("Model") or model:IsA("Folder")) then
			if not skip[string.lower(model.Name)] then
				local units = harvestModel(model, model.Name)
				if #units > 0 then
					monsters[#monsters + 1] = {
						name = model.Name,
						model = model,
						units = units,
					}
				end
			end
		end
	end

	return monsters
end

function Units.hasAsset(unit: any): boolean
	return type(unit.primary) == "string" and unit.primary ~= ""
end

-- 读当前真实值（不要用 unit.props，那是抓取那一刻的快照）
function Units.read(unit: any): { [string]: any }
	local props = {}
	for prop in pairs(unit.props) do
		local value = safeGet(unit.inst, prop)
		if value ~= nil then
			props[prop] = value
		end
	end
	return props
end

-- 把一组属性刷到一个 unit 上
function Units.paint(unit: any, props: { [string]: any }, blocked: { [string]: boolean }?): number
	local changed = 0
	for prop, value in pairs(props) do
		if not (blocked and blocked[prop]) then
			if setProp(unit.inst, prop, value) then
				changed = changed + 1
			end
		end
	end
	return changed
end

-- 全部还原到抓取时的原样
function Units.restore(monsters: { any }): number
	local changed = 0
	for _, monster in ipairs(monsters) do
		for _, unit in ipairs(monster.units) do
			changed = changed + Units.paint(unit, unit.origin)
		end
	end
	return changed
end

function Units.stats(monsters: { any }): { monsters: number, units: number, skinned: number }
	local units = 0
	local skinned = 0
	for _, monster in ipairs(monsters) do
		for _, unit in ipairs(monster.units) do
			units = units + 1
			if Units.hasAsset(unit) then
				skinned = skinned + 1
			end
		end
	end
	return { monsters = #monsters, units = units, skinned = skinned }
end

return Units
