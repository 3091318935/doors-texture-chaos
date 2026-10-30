--!strict
--[[
	Shuffle.lua —— 乱斗引擎

	四种玩法：

	  cross      全局池错排：每张皮都可能落到任何人身上，且保证没有原位不动的
	  rotate     环形位移：A 拿 B 的、B 拿 C 的……一圈传下去，画面最"连续崩坏"
	  perMonster 整只打包：把 Rush 整套皮（身体网格 + 脸 decal）直接穿到 Figure 身上
	  chaos      完全随机：同一只生物身上可以出现四张不同来源的皮，最脏

	流程固定为两段：先 plan（只读，算出所有目标值快照），再 apply（统一写）。
	这样即使 A 的皮搬给 B、B 的皮又搬给 C，也不会出现"链式污染"。
--]]

local Rng = require(script.Parent.Rng)
local Units = require(script.Parent.Units)
local Config = require(script.Parent.Config)

local Shuffle = {}

local KINDS = { "mesh", "decal", "specialmesh", "surface" }

local function collect(monsters: { any }, kind: string): { any }
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

local function mergeBlocked(base: { [string]: boolean }?, extra: { [string]: boolean }?): { [string]: boolean }
	local out = {}
	for key, value in pairs(Config.ReadOnlyProps) do
		out[key] = value
	end
	if base then
		for key, value in pairs(base) do
			out[key] = value
		end
	end
	if extra then
		for key, value in pairs(extra) do
			out[key] = value
		end
	end
	return out
end

local function addStep(plan: any, target: any, donor: any)
	local props = Units.read(donor)
	if next(props) == nil then
		return
	end
	plan.steps[#plan.steps + 1] = {
		target = target,
		donor = donor,
		props = props,
		same = (target.primary ~= nil and tostring(target.primary) == tostring(donor.primary)),
	}
end

local function planPerMonster(monsters: { any }, plan: any, rng: any)
	if #monsters < 2 then
		return
	end

	local perm = rng:derangement(#monsters)
	local buffer = {}
	for i = 1, #monsters do
		buffer[i] = monsters[i]
	end

	for i, target in ipairs(buffer) do
		local donor = buffer[perm[i]]
		for _, kind in ipairs(KINDS) do
			local targetUnits = collect({ target }, kind)
			local donorUnits = collect({ donor }, kind)
			if #targetUnits > 0 and #donorUnits > 0 then
				for index, unit in ipairs(targetUnits) do
					local donorUnit = donorUnits[((index - 1) % #donorUnits) + 1]
					addStep(plan, unit, donorUnit)
				end
			end
		end
	end
end

--[[
	opts:
		mode        cross | rotate | perMonster | chaos
		seed        数字，可选
		tint        布尔，可选
		swapMesh    布尔，false = 只换贴图不换 MeshId
		blocked     额外禁写属性
	返回 plan = { mode, seed, steps, tint, blocked }
--]]
function Shuffle.plan(monsters: { any }, opts: { [string]: any }?): any
	opts = opts or {}
	local mode = opts.mode or Config.Default.mode
	local rng = Rng.new(opts.seed)

	local plan = {
		mode = mode,
		seed = rng.seed,
		steps = {},
		tint = opts.tint == true,
		blocked = mergeBlocked(opts.blocked, nil),
	}

	if opts.swapMesh == false then
		plan.blocked.MeshId = true
	end

	if mode == "perMonster" then
		planPerMonster(monsters, plan, rng)
	else
		for _, kind in ipairs(KINDS) do
			local all = collect(monsters, kind)
			local donors = {}
			for _, unit in ipairs(all) do
				if Units.hasAsset(unit) then
					donors[#donors + 1] = unit
				end
			end

			if #donors >= 2 then
				if mode == "rotate" then
					local shift = rng:nextInt(1, #donors - 1)
					for index, unit in ipairs(donors) do
						local donor = donors[((index - 1 + shift) % #donors) + 1]
						addStep(plan, unit, donor)
					end
				elseif mode == "chaos" then
					for _, unit in ipairs(donors) do
						addStep(plan, unit, donors[rng:nextInt(1, #donors)])
					end
				else
					-- cross（默认）
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

local function applyTint(plan: any): number
	local rng = Rng.new(plan.seed + 7919)
	local changed = 0
	local seen = {}

	for _, step in ipairs(plan.steps) do
		local inst = step.target.inst
		if not seen[inst] and (inst:IsA("Decal") or inst:IsA("Texture")) then
			seen[inst] = true
			local color = Color3.fromHSV(rng:next(), 0.7, 1)
			local ok = pcall(function()
				(inst :: any).Color3 = color
			end)
			if ok then
				changed = changed + 1
			end
		end
	end

	return changed
end

function Shuffle.apply(plan: any): number
	local changed = 0
	for _, step in ipairs(plan.steps) do
		changed = changed + Units.paint(step.target, step.props, plan.blocked)
	end
	if plan.tint then
		changed = changed + applyTint(plan)
	end
	return changed
end

function Shuffle.revert(monsters: { any }): number
	return Units.restore(monsters)
end

function Shuffle.summary(plan: any, limit: number?): string
	local total = #plan.steps
	local lines = {
		string.format("模式=%s 种子=%d 替换=%d 处", plan.mode, plan.seed, total),
	}
	local maxLines = limit or 20

	for index, step in ipairs(plan.steps) do
		if index > maxLines then
			lines[#lines + 1] = string.format("……还有 %d 处", total - maxLines)
			break
		end
		lines[#lines + 1] = string.format(
			"  %s[%s]  <-  %s[%s]",
			tostring(step.target.owner),
			tostring(step.target.name),
			tostring(step.donor.owner),
			tostring(step.donor.name)
		)
	end

	return table.concat(lines, "\n")
end

return Shuffle
