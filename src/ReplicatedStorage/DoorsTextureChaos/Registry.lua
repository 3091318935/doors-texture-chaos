--!strict
--[[
	Registry.lua —— DOORS 生物登记表

	用途只有一个：把你导入的模型文件夹名认出来。
	模型命名可以写 "Rush" / "rush" / "Rush_New" / "A-60" / "a60"，都能对上。

	注意：这里只有名字，没有任何美术资源。
	模型需要你自己导入到 Workspace.Monsters 下（见 docs/获取建模.md）。
--]]

local Registry = {}

Registry.Families = {
	["主进程 · 常规实体"] = {
		"Rush",
		"Ambush",
		"Figure",
		"Seek",
		"Glitch",
		"Halt",
		"Screech",
		"Eyes",
		"Dupe",
		"Hide",
		"Jack",
		"Timothy",
		"Snare",
		"Shadow",
		"Rush_Alt",
	},
	["主进程 · 友善/环境"] = {
		"Guiding Light",
		"Curious Light",
		"Jeff",
		"El Goblino",
		"Bob",
		"Window",
		"Void",
	},
	["矿洞（Floor 2）"] = {
		"Grumble",
		"Giggle",
		"Gloom",
		"Seek_Mines",
		"Figure_Mines",
	},
	["Backdoor"] = {
		"Haste",
		"Lookman",
		"Blitz",
		"Backdoor_Void",
	},
	["Hardcore / 特殊"] = {
		"Dread",
		"Ripper",
		"Hatred",
		"DeerGod",
		"A-60",
		"A-90",
		"A-120",
		"A-333",
		"A-500",
		"A-1000",
	},
}

-- 归一化：小写 + 去空格/下划线/连字符
local function normalize(name: string): string
	local lowered = string.lower(name)
	local stripped = string.gsub(lowered, "[%s_%-%./]+", "")
	return stripped
end

Registry.normalize = normalize

-- 归一化名字 -> 标准名
local aliasMap: { [string]: string } = {}
local built = false

local function build()
	if built then
		return
	end
	built = true
	for _, family in pairs(Registry.Families) do
		for _, canonical in ipairs(family) do
			aliasMap[normalize(canonical)] = canonical
		end
	end
end

-- 手动补的别名：你模型文件夹怎么命名，就补在这里
Registry.ExtraAliases = {
	["a60"] = "A-60",
	["a90"] = "A-90",
	["a120"] = "A-120",
	["a333"] = "A-333",
	["a500"] = "A-500",
	["a1000"] = "A-1000",
	["gl"] = "Guiding Light",
	["guidinglight"] = "Guiding Light",
	["seeks"] = "Seek",
	["rushnew"] = "Rush",
	["rush1"] = "Rush",
}

function Registry.canonical(name: string): string
	build()
	local key = normalize(name)
	if Registry.ExtraAliases[key] then
		return Registry.ExtraAliases[key]
	end
	return aliasMap[key] or name
end

-- 判断一个模型名属于哪一支（方便按组单独乱斗）
function Registry.familyOf(name: string): string
	local canonical = Registry.canonical(name)
	for family, list in pairs(Registry.Families) do
		for _, item in ipairs(list) do
			if item == canonical then
				return family
			end
		end
	end
	return "未分类"
end

function Registry.allNames(): { string }
	local names = {}
	for _, family in pairs(Registry.Families) do
		for _, item in ipairs(family) do
			names[#names + 1] = item
		end
	end
	table.sort(names)
	return names
end

return Registry
