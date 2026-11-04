local _K = require(script.Parent.Parent)
local UI = require(script.Parent:WaitForChild("UI"))

return function(
	from: (number | string)?,
	name: string?,
	image: string?,
	badgeEnabled: boolean?,
	initialUsername: string?
)
	local fromK = from == "_K"
	if type(from) == "string" then
		if name == nil and from ~= "_K" then
			name = from
		end
		from = nil
	end

	local displayName = if name then `<b>{name}</b>` else ""

	if badgeEnabled == nil then
		badgeEnabled = true
	end

	local userName = initialUsername
	local badge
	local color = "#fff"

	if from then
		if not name then
			displayName = "Loading..."
		end
		if not userName then
			userName = "Unknown"
		end
		badge = "?"
	end

	local imageLabel
	if image or fromK or tonumber(from) then
		imageLabel = if from
			then UI.new "ImageLabel" {
				Name = "Icon",
				BackgroundTransparency = UI.Theme.TransparencyHeavy,
				BackgroundColor3 = UI.Theme.PrimaryText,
				Size = function()
					return UDim2.fromOffset(UI.Theme.FontSizeDouble(), UI.Theme.FontSizeDouble())
				end,
				Image = if image
					then image
					elseif from then `rbxthumb://type=AvatarHeadShot&id={from}&w=48&h=48`
					else "rbxassetid://10650688076",

				UI.corner(UI.Theme.CornerPadded),
				UI.new "Stroke" {},
			}
			else UI.new "Frame" {
				BackgroundTransparency = 1,
				Size = function()
					return UDim2.fromOffset(UI.Theme.FontSizeLarger(), UI.Theme.FontSizeLarger())
				end,
				UI.new "ImageLabel" {
					Name = "Icon",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = function()
						return UDim2.fromOffset(UI.Theme.FontSize(), UI.Theme.FontSize())
					end,
					Image = "rbxassetid://71961243872230",
				},
			}
	end

	local displayNameLabel = UI.new "TextLabel" {
		AutoLocalize = false,
		Name = "From",
		BackgroundTransparency = 1,
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		Text = displayName,
		TextSize = if from then UI.Theme.FontSizeLarge else UI.Theme.FontSizeLarger,
		TextXAlignment = "Left",
		FontFace = UI.Theme.FontHeavy,
		RichText = true,

		AutomaticSize = Enum.AutomaticSize.XY,
	}

	local userNameLabel = if userName or from
		then UI.new "TextLabel" {
			AutoLocalize = false,
			Name = "FromBottom",
			BackgroundTransparency = 1,
			TextColor3 = UI.Theme.PrimaryText,
			TextStrokeColor3 = UI.Theme.Primary,
			TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			Text = `<font transparency="0.5"><b>@{userName}</b></font>`,
			TextSize = UI.Theme.FontSizeSmall,
			TextXAlignment = "Left",
			FontFace = UI.Theme.Font,
			RichText = true,

			AutomaticSize = Enum.AutomaticSize.XY,
			Position = function()
				return UDim2.fromOffset(0, UI.Theme.FontSizeLarge())
			end,
		}
		else nil

	local badgeLabel
	if badgeEnabled and badge then
		local displaySize = UI.property(displayNameLabel, "AbsoluteSize")
		badgeLabel = UI.new "TextLabel" {
			__CLEAN = { displaySize },
			AutoLocalize = false,
			Name = "Badge",
			BackgroundColor3 = Color3.fromHex(color),
			TextColor3 = UI.Color.readable(Color3.fromHex(color)),
			Text = `<b>{string.upper(badge)}</b>`,
			TextSize = function()
				return UI.Theme.FontSizeLarge() - 8
			end,
			TextXAlignment = "Left",
			FontFace = UI.Theme.FontMono,
			RichText = true,

			AutomaticSize = Enum.AutomaticSize.X,
			Size = function()
				return UDim2.fromOffset(0, UI.Theme.FontSizeLarge())
			end,
			Position = function()
				return UDim2.fromOffset(displaySize().X + 4, 0)
			end,

			UI.corner(UI.Theme.CornerPadded),
			UI.padding(4),
		}
	end

	task.spawn(function()
		if not from then
			return
		end

		-- role badge
		if badgeLabel then
			local _rank, role = _K.Auth.getRank(from)
			local roleColor = if role and role.color then Color3.fromHex(role.color) else Color3.new(1, 1, 1)
			badgeLabel.BackgroundColor3 = roleColor
			badgeLabel.Text = `<b>{string.upper(if role then role.name else "Unknown")}</b>`
			badgeLabel.TextColor3 = UI.Color.readable(roleColor)
		end

		-- name
		local info = _K.Util.getUserInfo(from)
		displayNameLabel.Text = `<b>{name or info.DisplayName}</b>`
		if userNameLabel then
			userNameLabel.Text = `<font transparency="0.5"><b>@{info.Username}</b></font>`
		end
	end)

	return UI.new "Frame" {
		Name = "Header",
		LayoutOrder = -3,
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,

		imageLabel,
		UI.new "Frame" {
			Name = "From",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = function()
				return UDim2.fromOffset(UI.Theme.FontSizeDouble() + 4, 0)
			end,

			UI.flex("shrink"),
			UI.padding(UI.Theme.PaddingStroke),

			displayNameLabel,
			if userNameLabel then userNameLabel else nil,
			if badge then badgeLabel else nil,
		},
	}
end
