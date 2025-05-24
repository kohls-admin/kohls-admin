local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Spacer = {}
Spacer.__index = Spacer
setmetatable(Spacer, BaseClass)

function Spacer.new(definition)
	local new = UI.makeStatefulDefaults({}, definition)
	new._instance = UI.new "Frame" {
		Name = "Spacer",
		BackgroundTransparency = 1,
		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Fill,
		},
	}
	return new
end

return Spacer
