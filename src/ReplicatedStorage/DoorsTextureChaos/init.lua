--!strict
--[[
	DoorsTextureChaos/init.lua —— 门面

	在外面只需要：
		local Chaos = require(ReplicatedStorage.DoorsTextureChaos)

		Chaos.scan()                        -- 扫描 workspace.Monsters
		Chaos.shuffle({ mode = "perMonster" })  -- 乱一次
		Chaos.restore()                     -- 全部还原

	或者直接用模块：
		Chaos.Shuffle.plan(monsters, { mode = "chaos", seed = 12345 })
--]]

local Config = require(script.Config)
local Rng = require(script.Rng)
local Units = require(script.Units)
local Shuffle = require(script.Shuffle)
local Registry = require(script.Registry)

local Chaos = {}

Chaos.Config = Config
Chaos.Rng = Rng
Chaos.Units = Units
Chaos.Shuffle = Shuffle
Chaos.Registry = Registry

Chaos._monsters = nil

-- 扫描（默认 workspace.Monsters）
function Chaos.scan(folder: Instance?): { any }
	local target = folder or (game:GetService("Workspace"):FindFirstChild(Config.FolderName))
	if not target then
		warn(string.format("[DoorsTextureChaos] 找不到 Workspace.%s", Config.FolderName))
		Chaos._monsters = {}
		return Chaos._monsters
	end

	local skip = {}
	for name in pairs(Config.SkipEntities) do
		skip[string.lower(name)] = true
	end

	Chaos._monsters = Units.harvest(target, { skip = skip })
	local stats = Units.stats(Chaos._monsters)
	print(string.format(
		"[DoorsTextureChaos] 扫到 %d 只生物 / %d 个贴图单元 / %d 个带皮",
		stats.monsters, stats.units, stats.skinned
	))
	return Chaos._monsters
end

function Chaos.monsters(): { any }
	if not Chaos._monsters or #Chaos._monsters == 0 then
		Chaos.scan()
	end
	return Chaos._monsters
end

-- 乱一次，返回 plan
function Chaos.shuffle(opts: { [string]: any }?): any
	opts = opts or {}
	local monsters = Chaos.monsters()
	if #monsters == 0 then
		warn("[DoorsTextureChaos] 没有可乱斗的模型")
		return nil
	end

	local options = {
		mode = opts.mode or Config.Default.mode,
		seed = opts.seed or Config.Default.seed,
		tint = if opts.tint ~= nil then opts.tint else Config.Default.tint,
		swapMesh = if opts.swapMesh ~= nil then opts.swapMesh else Config.Default.swapMesh,
		blocked = opts.blocked,
	}

	local plan = Shuffle.plan(monsters, options)
	local changed = Shuffle.apply(plan)
	if Config.Runtime.verbose then
		print("[DoorsTextureChaos] 写入 " .. changed .. " 处\n" .. Shuffle.summary(plan, 16))
	end
	return plan
end

-- 还原
function Chaos.restore(): number
	local monsters = Chaos._monsters or Chaos.monsters()
	local changed = Units.restore(monsters)
	if Config.Runtime.verbose then
		print("[DoorsTextureChaos] 还原 " .. changed .. " 处")
	end
	return changed
end

return Chaos
