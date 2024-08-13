local CREDITS = require(script.Parent.Parent.Credits)
local UserFrame = require(script.Parent.UserFrame)

local Credit = {}
Credit.__index = Credit

function Credit.new(_K)
	local UI = _K.client.UI
	local image = "rbxassetid://10650688076"

	local scroller = UI.new "Scroller" {
		Name = "Credit",
	}

	UI.edit(scroller._instance.UIListLayout, {
		Padding = UI.Theme.PaddingDouble,
		HorizontalAlignment = "Center",
	})

	local order = 1
	for _, group in CREDITS do
		UI.new "TextLabel" {
			Parent = scroller,
			LayoutOrder = order,
			Name = group.Title,
			BackgroundTransparency = 1,
			FontFace = UI.Theme.FontHeavy,
			TextTruncate = Enum.TextTruncate.SplitWord,
			TextSize = UI.Theme.FontSizeLargest,
			TextColor3 = UI.Theme.PrimaryText,
			Size = UDim2.new(1, 0, 0, 24),
			Text = `<sc>{string.lower(group.Title)}</sc>`,
			TextTransparency = 0.5,
			RichText = true,
		}
		order += 1
		local flexFrame = UI.new "Frame" {
			Parent = scroller,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),

			UI.new "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UI.Theme.PaddingDouble,
				Wraps = true,
			},
		}
		order += 1
		task.spawn(function()
			for i, user in group.Users do
				local userType = type(user)
				if userType == "number" then
					local userFrame = UserFrame(user, nil, nil, false)
					userFrame.LayoutOrder = i
					userFrame.Parent = flexFrame
				elseif userType == "table" then
					local userFrame = UserFrame(user.Id, nil, nil, false)
					userFrame.LayoutOrder = i
					userFrame.Parent = flexFrame
					if user.Tooltip then
						UI.new "Tooltip" {
							Parent = userFrame,
							Text = user.Tooltip,
						}
					end
				end
			end
		end)
	end

	return scroller._instance
end

return Credit
