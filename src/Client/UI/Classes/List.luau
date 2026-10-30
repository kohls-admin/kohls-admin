local UI = require(script.Parent.Parent)
local BaseClass = require(script.Parent:WaitForChild("BaseClass"))

local DEFAULT = {
	Collapsible = false,
	Collapsed = false,
	Label = "",
	Padding = UI.Theme.Padding,
}

type Properties = typeof(DEFAULT) & Frame

local Class = {}
Class.__index = Class
setmetatable(Class, BaseClass)

function Class.new(properties: Properties?)
	local self = table.clone(DEFAULT)
	UI.makeStatefulDefaults(self, properties)

	local cleanup = {}

	local listLayout = UI.list {
		gap = self.Padding,
		horizontalAlign = "start",
		verticalAlign = "start",
	}

	local contentSize = UI.property(listLayout, "AbsoluteContentSize")
	table.insert(cleanup, contentSize)

	local headerTransparency = UI.tween(function()
		return if self.Collapsed() then 0.5 else 0
	end, UI.Theme.TweenOut)
	table.insert(cleanup, headerTransparency)

	-- motion nodes bound straight to a property are not owned by the instance: destroy them with it
	local listSize = UI.tween(function()
		local fontSize, padding = UI.Theme.FontSize(), UI.Theme.Padding().Offset
		local height = if self.Collapsed()
			then fontSize + padding * 4
			else contentSize().Y + (if self.Label() ~= "" then fontSize + padding * 6 else padding * 2)
		return UDim2.new(1, 0, 0, height)
	end, UI.Theme.TweenOut)
	table.insert(cleanup, listSize)

	local arrowRotation = UI.tween(function()
		return if self.Collapsed() then -90 else 0
	end, UI.Theme.TweenOut)
	table.insert(cleanup, arrowRotation)

	local contentFrameSize = UI.tween(function()
		local collapse = self.Collapsed()
		return UDim2.new(
			1,
			0,
			if collapse then 0 else 1,
			if collapse then 0 else -UI.Theme.FontSize() + self.Padding().Offset * 2
		)
	end, UI.Theme.TweenOut)
	table.insert(cleanup, contentFrameSize)
	local function onHeaderActivated()
		if self.Collapsible:peek() then
			self.Collapsed(not self.Collapsed:peek())
			if self.Collapsed:peek() then
				UI.Sound.Hover01:Play()
			else
				UI.Sound.Hover03:Play()
			end
		end
	end

	self._instance = UI.new "Frame" {
		Name = "List",
		BackgroundColor3 = UI.Theme.Secondary,
		BackgroundTransparency = UI.Theme.TransparencyMax,
		ClipsDescendants = true,
		Size = listSize,

		UI.corner(UI.Theme.CornerPadded),
		UI.new "Stroke" { Transparency = UI.Theme.TransparencyBalanced },

		UI.new "TextButton" {
			AutoLocalize = false,
			Name = "Header",
			Active = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextTransparency = 1,
			Text = "",
			Size = UDim2.new(1, 0, 0, 0),
			Visible = function()
				return self.Collapsible() or self.Label() ~= ""
			end,

			UI.padding(self.Padding),

			UI.new "ImageLabel" {
				Name = "Arrow",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0.75, 0, 0.75, 0),
				Image = UI.Theme.Image.Down,
				ImageColor3 = UI.Theme.PrimaryText,
				ImageTransparency = headerTransparency,
				Visible = self.Collapsible,
				Rotation = arrowRotation,

				UI.aspectRatio(1),
			},

			UI.new "TextLabel" {
				AutoLocalize = false,
				Name = "Label",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Position = function()
					return UDim2.new(
						0,
						if self.Collapsible() then UI.Theme.FontSize() else UI.Theme.Padding().Offset,
						0,
						0
					)
				end,
				Size = function()
					return UDim2.new(1, -UI.Theme.FontSize(), 0, 0)
				end,
				FontFace = UI.Theme.FontBold,
				Text = function()
					return string.upper(self.Label() :: string)
				end,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTransparency = headerTransparency,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = "Left",
			},

			Activated = onHeaderActivated,
		},
		__CLEAN = cleanup,
	} :: Frame & { UIListLayout: UIListLayout, UIPadding: UIPadding }

	self._content = UI.new "Frame" {
		Name = "UIContent",
		Parent = self._instance,
		BackgroundTransparency = 1,
		Position = function()
			local padding = self.Padding().Offset
			return UDim2.new(0, 0, 0, (if self.Label() ~= "" then UI.Theme.FontSize() + padding * 2 else padding))
		end,
		Size = contentFrameSize,
		ClipsDescendants = true,

		listLayout,
		UI.padding {
			x = self.Padding,
			y = UDim.new(0, 1),
		},
	} :: Frame & {
		UICorner: UICorner,
		UIStroke: UIStroke,
		Header: TextButton & {
			Arrow: ImageLabel & { UIAspectRatioConstraint: UIAspectRatioConstraint },
			Label: TextLabel,
			UIPadding: UIPadding,
		},
	}

	return setmetatable(self, Class) :: typeof(self) & typeof(Class)
end

return Class
