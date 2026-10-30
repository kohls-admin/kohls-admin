local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local Tween = game:GetService("TweenService")

local DEFAULT = {
	--- A test property.
	Icon = "",
	IconProperties = {},
	IconRightAlign = false,
	Label = "",
	LabelProperties = {},
	ActiveSound = true,
	AutomaticSize = Enum.AutomaticSize.None,
	BackgroundColor3 = UI.Theme.Secondary,
	BackgroundTransparency = UI.Theme.TransparencyHeavy,
	HoverTransparency = 0.75,
	FontFace = UI.Theme.Font,
	TextSize = UI.Theme.FontSize,
	TextScaled = false,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	Padding = UI.Theme.Padding,
}

type Properties = typeof(DEFAULT) & TextButton

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	self.IconProperties, self.LabelProperties = {}, {}
	UI.makeStatefulDefaults(self, properties)

	local autoSize = UI.computed(function()
		local auto, x, y = self.AutomaticSize(), 1, 1
		if auto == Enum.AutomaticSize.XY then
			x, y = 0, 0
		elseif auto == Enum.AutomaticSize.X then
			x = 0
		elseif auto == Enum.AutomaticSize.Y then
			y = 0
		end
		return UDim2.fromScale(x, y)
	end)

	self._content = UI.new "Frame" {
		Name = "UIContent",
		AutomaticSize = self.AutomaticSize,
		BackgroundTransparency = 1,
		Size = autoSize,

		UI.list {
			direction = "x",
			verticalAlign = "center",
		},

		UI.edit(UI.new "TextLabel" {
			Name = "Label",
			LayoutOrder = 2,
			AutomaticSize = self.AutomaticSize,
			AutoLocalize = false,
			BackgroundTransparency = 1,
			Size = autoSize,
			FontFace = self.FontFace,
			RichText = true,
			Text = function()
				return tostring(self.Label())
			end,
			TextSize = self.TextSize,
			TextScaled = self.TextScaled,
			TextColor3 = UI.Theme.PrimaryText,
			TextStrokeColor3 = UI.Theme.Primary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextXAlignment = self.TextXAlignment,
			TextYAlignment = self.TextYAlignment,
			Visible = function()
				return self.Label() ~= ""
			end,

			UI.flex("fill"),
			UI.padding { x = self.Padding },
		})(self.LabelProperties:peek()),

		UI.new "Frame" {
			Name = "IconFrame",
			LayoutOrder = UI.pick(self.IconRightAlign, 9, -9),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Visible = function()
				return self.Icon() ~= ""
			end,

			UI.edit(UI.new "ImageLabel" {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Image = self.Icon,
				ScaleType = Enum.ScaleType.Fit,
			})(self.IconProperties:peek()),
		},
	} :: Frame & {
		UIListLayout: UIListLayout,
		Label: TextLabel & { UIFlexItem: UIFlexItem, UIPadding: UIPadding },
		IconFrame: Frame & { Icon: ImageLabel },
	}

	local ripple = UI.new "Frame" {
		Name = "Ripple",
		Active = false,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BackgroundColor3 = UI.Theme.Secondary,

		UI.corner(UI.Theme.CornerPadded),
	}

	local function onActivated()
		if self.ActiveSound:peek() then
			UI.Sound.Hover01:Play()
		end
	end

	local function onInputBegan(input, processed)
		if
			processed
			or (
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			)
		then
			return
		end
		local x = input.Position.X
		ripple.Size = UDim2.new(0, 0, 1, 0)
		ripple.Position = UDim2.new(0, x - self._instance.AbsolutePosition.x, 0, 0)
		Tween:Create(ripple, UI.Theme.TweenOut:peek(), {
			BackgroundTransparency = 0.9,
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
		}):Play()
	end

	local function onInputEnded(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			Tween:Create(ripple, UI.Theme.TweenOut:peek(), { BackgroundTransparency = 1 }):Play()
		end
	end

	local instance = UI.new "TextButton" {
		AutomaticSize = self.AutomaticSize,
		AutoLocalize = false,
		Name = "Button",
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = self.BackgroundColor3,
		ClipsDescendants = true,
		Text = "",
		TextTransparency = 1,
		Size = function()
			local auto = self.AutomaticSize()
			local x = if auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY then 0 else 1
			return UDim2.new(x, 0, 0, UI.Theme.FontSize() + UI.Theme.Padding().Offset * 2)
		end,

		UI.corner(UI.Theme.CornerPadded),
		UI.new "Stroke" {},

		self._content,
		ripple,

		Activated = onActivated,
		InputBegan = onInputBegan,
		InputEnded = onInputEnded,
	}
	local hovering = UI.Interact.hover(instance, { within = true })
	self._hovering = hovering
	UI.edit(instance)({
		BackgroundTransparency = UI.pick(hovering, self.HoverTransparency, self.BackgroundTransparency),
		__CLEAN = { hovering, autoSize },
	})
	self._instance = instance :: TextButton & {
		UICorner: UICorner,
		UIStroke: UIStroke,
		UIContent: typeof(self._content),
		Ripple: typeof(ripple) & { UICorner: UICorner },
	}

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
