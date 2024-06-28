local Class = require(script.Class)
local Theme = require(script.Theme).new({
	Primary = { Color3.fromRGB(0, 0, 0), 0.3 },
	PrimaryText = { Color3.fromRGB(255, 255, 255), 0 },
	Secondary = { Color3.fromRGB(255, 255, 255), 0.3 },
	SecondaryText = { Color3.fromRGB(0, 0, 0), 0 },
	-- Font?
	-- FontSize???
	-- BasePixelHeight 32?
})

local themeVars = Theme.Vars

return {
	Class = Class,
	Theme = Theme,

	new = function(obj, cfg, children)
		cfg = cfg or {}
		local parent = cfg.Parent
		cfg.Parent = nil
		local theme = cfg.Theme or Theme
		cfg.Theme = nil

		obj = (typeof(obj) == "Instance" or Class.metaTables[obj]) and obj:Clone()
			or Class.new(obj)
			or Instance.new(obj)
		theme:Apply(obj, cfg, true)
		if Class.metaTables[obj] then
			obj.Theme = theme
		end

		for k, v in next, cfg do
			if children == nil and (typeof(v) == "Instance" or Class.metaTables[v]) then
				v.Name = k
				v.Parent = Class.metaTables[obj] and (obj._parentTo or obj._rbx) or obj
			elseif typeof(obj[k]) == "RBXScriptSignal" or (typeof(obj[k]) == "table" and obj[k].Connect) then
				obj[k]:Connect(function(...)
					v(obj, ...)
				end)
			else
				if themeVars[k] then
					theme:Remove(obj, k)
				end
				obj[k] = v
			end
		end

		if children then
			for k, v in next, children do
				v.Name = k
				v.Parent = Class.metaTables[obj] and (obj._parentTo or obj._rbx) or obj
			end
		end

		if parent then
			obj.Parent = parent
		end

		return obj
	end,
}
