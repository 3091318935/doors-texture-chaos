--!strict
--[[
	TextureChaosServer.server.lua —— 运行时乱斗

	行为：
	  1. 启动时扫描 workspace.Monsters
	  2. 每隔 Config.Runtime.interval 秒乱一次
	  3. 乱完 Config.Runtime.restoreAfter 秒自动还原（设 0 就永远不回滚）
	  4. 把每轮结果广播给客户端 HUD

	手动调（Studio 命令栏 / 服务器控制台）：
		_G.DOORS_TEXTURE_CHAOS.shuffle("perMonster")
		_G.DOORS_TEXTURE_CHAOS.restore()
		_G.DOORS_TEXTURE_CHAOS.scan()

	聊天指令（Studio 或创作者本人）：!chaos / !chaos rotate / !chaos off
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Chaos = require(ReplicatedStorage:WaitForChild("DoorsTextureChaos"))
local Config = Chaos.Config
local Units = Chaos.Units
local Shuffle = Chaos.Shuffle

local EVENT_NAME = "DoorsChaosReport"
local reportEvent = ReplicatedStorage:FindFirstChild(EVENT_NAME)
if not reportEvent then
	reportEvent = Instance.new("RemoteEvent")
	reportEvent.Name = EVENT_NAME
	reportEvent.Parent = ReplicatedStorage
end

local state = {
	monsters = {} :: { any },
	lastSeed = 0,
	lastMode = "",
	busy = false,
}

local function broadcast(payload: { [string]: any })
	;(reportEvent :: RemoteEvent):FireAllClients(payload)
end

local function scan(): { any }
	state.monsters = Chaos.scan()
	return state.monsters
end

local function shuffleOnce(seed: number?, mode: string?): any
	local monsters = state.monsters
	if #monsters == 0 then
		monsters = scan()
	end
	if #monsters == 0 then
		warn(string.format("[DoorsTextureChaos] Workspace.%s 下没有可用模型", Config.FolderName))
		return nil
	end

	local plan = Shuffle.plan(monsters, {
		mode = mode or Config.Default.mode,
		seed = seed or os.time(),
		tint = Config.Default.tint,
		swapMesh = Config.Default.swapMesh,
	})

	local changed = Shuffle.apply(plan)
	state.lastSeed = plan.seed
	state.lastMode = plan.mode

	local text = Shuffle.summary(plan, 18)
	if Config.Runtime.verbose then
		print("[DoorsTextureChaos] " .. text .. string.format("\n(写入 %d 处)", changed))
	end
	broadcast({ text = text, seed = plan.seed, mode = plan.mode, changed = changed })
	return plan
end

local function restore(): number
	local changed = Units.restore(state.monsters)
	if Config.Runtime.verbose then
		print("[DoorsTextureChaos] 还原 " .. changed .. " 处")
	end
	broadcast({ text = "已还原 " .. changed .. " 处贴图", restored = true })
	return changed
end

_G.DOORS_TEXTURE_CHAOS = {
	scan = scan,
	shuffle = shuffleOnce,
	restore = restore,
	state = state,
}

-- 启动
task.spawn(function()
	task.wait(1)
	scan()

	if not Config.Runtime.enabled then
		return
	end

	while true do
		task.wait(Config.Runtime.interval)
		if state.busy then
			continue
		end

		state.busy = true
		local ok, err = pcall(function()
			local plan = shuffleOnce(os.time())
			if plan and Config.Runtime.restoreAfter and Config.Runtime.restoreAfter > 0 then
				task.wait(Config.Runtime.restoreAfter)
				restore()
			end
		end)
		state.busy = false

		if not ok then
			warn("[DoorsTextureChaos] 本轮出错：" .. tostring(err))
		end
	end
end)

-- 聊天指令
local function isOperator(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	local ok, creatorId = pcall(function()
		return game.CreatorId
	end)
	return ok and creatorId == player.UserId
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message: string)
		if not isOperator(player) then
			return
		end

		local argument = string.match(message, "^!chaos%s*(.-)%s*$")
		if argument == nil then
			return
		end

		local sub = string.lower(argument)
		if sub == "" then
			shuffleOnce(os.time())
		elseif sub == "off" then
			restore()
		elseif table.find(Config.Modes, sub) then
			shuffleOnce(os.time(), sub)
		else
			warn("[DoorsTextureChaos] 未知模式：" .. sub .. "（可用：" .. table.concat(Config.Modes, " / ") .. "）")
		end
	end)
end)
