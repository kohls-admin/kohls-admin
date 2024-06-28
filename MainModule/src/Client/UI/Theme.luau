--[[

	Usage

	Theme.Primary = Color3 / Number / {Color3, Number}
	Theme:Apply(Frame, {
		BackgroundColor = Theme.Primary;
		BackgroundTransparency = {Theme.Primary, -.1, true/false (mult/add)};
	})

--]]

local function Add(obj, k, v)
	local kType = type(v) == "table" and typeof(obj[k])
	if kType == "Color3" or kType == "number" then -- Apply theme color/transparency
		local mod, mult
		if type(v[2]) == "number" then
			mod, mult = v[2], v[3]
			v = v[1]
		end
		if not v.Objects[obj] then
			v.Objects[obj] = {}
		end
		v.Objects[obj][k] = { mod, mult }
		if kType == "Color3" then
			v = v.Color
			obj[k] = mod
					and (mult and Color3.new(v.r * mod, v.g * mod, v.b * mod) or Color3.new(
						v.r + mod,
						v.g + mod,
						v.b + mod
					))
				or v
		else
			v = v.Transparency
			obj[k] = mod and (mult and v * mod or v + mod) or v
		end
	end
end

local function Update(t, v)
	if typeof(v) == "Color3" then
		t.Color = v
		for obj, list in next, t.Objects do
			for k, p in next, list do
				local mod, mult = p[1], p[2]
				obj[k] = mod
						and (mult and Color3.new(v.r * mod, v.g * mod, v.b * mod) or Color3.new(
							v.r + mod,
							v.g + mod,
							v.b + mod
						))
					or v
			end
		end
	else
		t.Transparency = v
		for obj, list in next, t.Objects do
			for k, p in next, list do
				local mod, mult = p[1], p[2]
				obj[k] = mod and (mult and v * mod or v + mod) or v
			end
		end
	end
end

local Theme = {
	Vars = {
		BackgroundColor3 = true,
		BorderColor3 = true,
		ImageColor3 = true,
		TextColor3 = true,
		TextStrokeColor3 = true,
	},
}

Theme.Add = Add

Theme.__index = function(self, k)
	return Theme[k] or rawget(self, k) or rawget(self, "Data")[k]
end

Theme.__newindex = function(self, k, v)
	local data = self.Data[k]
	if data then
		local Type = typeof(v)
		if Type == "Color3" or Type == "number" then
			Update(data, v)
		elseif Type == "table" then
			Update(data, v[1])
			Update(data, v[2])
		end
	end
end

function Theme:Apply(obj, p, remove)
	for k, v in next, p do
		for _, t in next, self.Data do
			if v == t then
				Add(obj, k, v)
				if remove then
					p[k] = nil
				end
				break
			end
		end
	end
end

function Theme:Get(obj, p)
	for k, v in next, self.Data do
		local t = v.Objects[obj]
		if t and t[k] then
			local mod, mult = t[k][1], t[k][2]
			if typeof(obj[p]) == "Color3" then
				v = v.Color
				return mod
						and (mult and Color3.new(v.r * mod, v.g * mod, v.b * mod) or Color3.new(
							v.r + mod,
							v.g + mod,
							v.b + mod
						))
					or v
			else
				v = v.Transparency
				return mod and (mult and v * mod or v + mod) or v
			end
		end
	end
end

function Theme:Remove(obj, p)
	for k, v in next, self.Data do
		local t = v.Objects[obj]
		if t then
			t[k] = nil
		end
	end
end

function Theme:Strip(obj)
	for k, v in next, self.Data do
		v.Objects[obj] = nil
	end
	for k, v in next, obj:GetChildren() do
		Theme:Strip(v)
	end
end

function Theme.new(cfg)
	local obj = setmetatable({ Data = {} }, Theme)
	for i, v in next, cfg do
		if typeof(v) == "Color3" then
			v = { v, 0 }
		end
		obj.Data[i] = { Color = v[1], Transparency = v[2], Objects = {} }
	end
	return obj
end

return Theme
