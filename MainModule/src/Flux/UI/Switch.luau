local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent)

local Switch = {}
Switch.__index = Switch
setmetatable(Switch, BaseClass)

function Switch.new(definition)
	local new = UI.makeStatefulDefaults({
		Value = false,
	}, definition)

	local backgroundTransparency = UI.tween(
		UI.Theme.NormalTween,
		UI.compute(function(use)
			return if use(new.Value) then 0 else use(UI.Theme.Transparency)
		end)
	)

	new._instance = UI.new "TextButton" {
		Name = "Switch",
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = UI.tween(
			UI.Theme.NormalTween,
			UI.compute(function(use)
				return if use(new.Value) then use(UI.Theme.Secondary) else use(UI.Theme.Border)
			end)
		),
		BackgroundTransparency = backgroundTransparency,
		Text = "",
		TextTransparency = 1,
		Size = UDim2.new(0, 48, 0, 24),

		[UI.Children] = {
			UICorner = UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerDiameter,
			},

			UIPadding = UI.new "UIPadding" {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			},

			Circle = UI.new "Frame" {
				BackgroundColor3 = UI.Theme.Primary,
				BackgroundTransparency = backgroundTransparency,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Position = UI.tween(
					UI.Theme.NormalTween,
					UI.compute(function(use)
						return UDim2.new(0, if use(new.Value) then 24 else 0, 0, 0)
					end)
				),

				[UI.Children] = {
					UICorner = UI.new "UICorner" {
						CornerRadius = UI.Theme.CornerDiameter,
					},
				},
			},
		},

		[UI.Event] = {
			Activated = function()
				new.Value:set(not UI.peek(new.Value))
			end,
		},
	}

	return setmetatable(new, Switch)
end

return Switch
