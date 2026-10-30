--!strict
--[[
	ChaosHud.client.lua —— 左上角小窗，显示这一轮谁抢了谁的皮

	F7 显示/隐藏整个 HUD。
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local reportEvent = ReplicatedStorage:WaitForChild("DoorsChaosReport", 30) :: RemoteEvent?

if not reportEvent then
	return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DoorsChaosHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.AnchorPoint = Vector2.new(0, 0)
frame.Position = UDim2.new(0, 16, 0, 16)
frame.Size = UDim2.fromOffset(360, 240)
frame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Visible = true
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 92, 92)
stroke.Thickness = 1
stroke.Transparency = 0.4
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.new(0, 8, 0, 6)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(255, 120, 120)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "DOORS 贴图乱斗"
title.Parent = frame

local body = Instance.new("TextLabel")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.new(0, 8, 0, 34)
body.Size = UDim2.new(1, -16, 1, -42)
body.Font = Enum.Font.Code
body.TextSize = 13
body.TextColor3 = Color3.fromRGB(228, 228, 232)
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextWrapped = true
body.Text = "等待第一轮……"
body.Parent = frame

reportEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local text = payload.text
	if typeof(text) ~= "string" then
		return
	end

	body.Text = text
	frame.BackgroundTransparency = 0.15

	if payload.restored then
		title.Text = "已还原"
		title.TextColor3 = Color3.fromRGB(140, 220, 160)
	else
		title.Text = string.format("第 %d 轮 · %s", os.time() % 10000, tostring(payload.mode or ""))
		title.TextColor3 = Color3.fromRGB(255, 120, 120)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F7 then
		frame.Visible = not frame.Visible
	end
end)
