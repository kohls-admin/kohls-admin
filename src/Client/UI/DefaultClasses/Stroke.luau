local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Stroke = {}
Stroke.__index = Stroke
setmetatable(Stroke, BaseClass)

function Stroke.new(definition)
	local new = UI.makeStatefulDefaults({}, definition)
	new._instance = UI.new "UIStroke" {
		Enabled = UI.Theme.StrokeEnabled,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency = UI.Theme.TransparencyClamped,
		Color = UI.Theme.Border,
	}
	return new
end

return Stroke
