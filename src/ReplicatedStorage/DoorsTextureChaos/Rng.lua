--!strict
--[[
	Rng.lua —— 可复现随机数
	同一个 seed 永远给出同一条乱斗结果，方便截图、回滚、对拍。
--]]

local Rng = {}
Rng.__index = Rng

function Rng.new(seed)
	if seed == nil then
		seed = (os.time() * 1000 + math.floor(os.clock() * 1000)) % 2147483647
	end
	return setmetatable({
		seed = seed,
		rng = Random.new(seed),
	}, Rng)
end

function Rng:next()
	return self.rng:NextNumber()
end

function Rng:nextInt(min, max)
	if max < min then
		min, max = max, min
	end
	return self.rng:NextInteger(min, max)
end

function Rng:pick(list)
	if #list == 0 then
		return nil
	end
	return list[self.rng:NextInteger(1, #list)]
end

-- 原地 Fisher-Yates
function Rng:shuffle(list)
	for i = #list, 2, -1 do
		local j = self.rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- 错排：perm[i] ~= i，保证不会"换了个寂寞"
function Rng:derangement(n)
	local perm = {}
	for i = 1, n do
		perm[i] = i
	end
	if n < 2 then
		return perm
	end

	self:shuffle(perm)

	-- 修不动点：和另一个位置对调
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

	-- 兜底：整体循环位移一格
	for i = 1, n do
		if perm[i] == i then
			perm[i], perm[(i % n) + 1] = perm[(i % n) + 1], perm[i]
		end
	end

	return perm
end

return Rng
