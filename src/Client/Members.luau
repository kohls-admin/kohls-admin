local UI = require(script.Parent.UI)

local Members = {}
Members.__index = Members

function Members.new(_K)
	local escape = _K.Util.String.escapeRichText

	local inputSize = function()
		local size = UI.Theme.FontSize()
		local padding = UI.Theme.Padding().Offset
		return UDim2.fromOffset(0, size + padding)
	end

	local roleChoice = UI.state({ Id = "vip", Name = "VIP" })
	local roleChoices = UI.state({ { Id = "vip", Name = "VIP" } })
	local roleDialogTarget = UI.state()
	local roleDialogInput
	local function resetRoleTargetInput()
		roleDialogTarget(nil)
		roleDialogInput.Value("")
		roleDialogInput.Selected("")
	end

	roleDialogInput = UI.new "Input" {
		AutomaticSize = Enum.AutomaticSize.X,
		Font = UI.Theme.FontMono,
		FontSize = UI.Theme.FontSize,
		MaxChars = 20,
		Placeholder = "UserId or Username",
		Size = inputSize,
		Value = "",

		UI.new "UIFlexItem" {
			FlexMode = Enum.UIFlexMode.Shrink,
		},

		[UI.Hook] = {
			Selected = function(value)
				local userId
				if tonumber(value) then
					userId = tonumber(value)
				else
					local ok, result = pcall(_K.Service.Players.GetUserIdFromNameAsync, _K.Service.Players, value)
					userId = ok and result
				end

				local fauxArg = {
					_K = _K,
					definition = _K.Registry.commands.role.args[1],
					command = {
						from = _K.LocalPlayer.UserId,
						fromRank = _K.Auth.getRank(_K.LocalPlayer.UserId),
						fromRole = {},
						rank = _K.Auth.hasCommand(_K.LocalPlayer.UserId, "role") or 0,
					},
				}

				if userId and not _K.Auth.targetUserArgument(fauxArg, userId, userId) then
					userId = nil
					task.defer(resetRoleTargetInput)
				end

				local member = _K.Data.members[tostring(userId)] or {}
				local availableRoles = {}
				for rank, role in _K.Data.rolesList do
					if rank == 0 or (rank >= _K.client.rank._value and _K.creatorId ~= _K.LocalPlayer.UserId) then
						continue
					end
					local hasRole = if _K.Auth.hasPermission(_K.LocalPlayer.UserId, "saveRoles")
						then table.find(member.persist or {}, role._key)
						else table.find(member.roles or {}, role._key)
					if hasRole then
						continue
					end
					table.insert(availableRoles, { Id = role._key, Name = role.name })
				end
				if availableRoles then
					roleChoice(availableRoles[1])
					roleChoices(availableRoles)
				else
					roleChoice("")
					roleChoices({})
				end
				roleDialogTarget(userId)
			end,
		},
	}

	local newRoleDialog
	newRoleDialog = UI.new "Dialog" {
		Parent = UI.LayerTop,
		BackgroundTransparency = 0,
		Draggable = true,
		Title = "Add Role",
		Visible = false,
		ExitButton = true,
		Modal = true,
		Close = function()
			newRoleDialog.Visible(false)
		end,

		UI.new "UIPadding" {
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
		},

		UI.new "ListItem" {
			Text = "User",
			UI.new "ImageLabel" {
				BackgroundTransparency = UI.Theme.TransparencyHeavy,
				BackgroundColor3 = UI.Theme.PrimaryText,
				Size = inputSize,
				Image = function()
					return `rbxthumb://type=AvatarHeadShot&id={roleDialogTarget()}&w=48&h=48`
				end,
				UI.new "UIAspectRatioConstraint" {
					AspectType = Enum.AspectType.ScaleWithParentSize,
					DominantAxis = Enum.DominantAxis.Height,
				},
				UI.new "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},
			},
			roleDialogInput,
		},

		UI.new "ListItem" {
			Text = "Role",
			UI.new "Select" {
				Choice = roleChoice,
				Choices = roleChoices,
			},
			Visible = function()
				return roleDialogTarget() and #roleChoices() > 0
			end,
		},

		UI.new "Button" {
			Label = "Confirm",
			Activated = function()
				if roleDialogTarget._value then
					local save = _K.Registry.commands.role.LocalPlayerAuthorized
					local cmd =
						`{_K.getCommandPrefix()}{if save then "" else "temp"}role {roleDialogTarget()} {roleChoice().Id}`
					_K.Process.runCommands(_K, _K.LocalPlayer.UserId, cmd)
					newRoleDialog.Visible(false)
					resetRoleTargetInput()
				end
			end,
		},
	}

	local newRoleButton = UI.new "Button" {
		LayoutOrder = 3,
		ActiveSound = false,
		Icon = UI.Theme.Image.Add,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
			Size = UDim2.fromScale(0.625, 0.625),
		},
		Size = UDim2.new(1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		UI.new "UIPadding" {
			PaddingTop = UI.Theme.PaddingHalf,
			PaddingBottom = UI.Theme.PaddingHalf,
			PaddingLeft = UI.Theme.PaddingHalf,
			PaddingRight = UI.Theme.PaddingHalf,
		},

		Visible = function()
			_K.client.rank()
			return _K.Registry.commands.role.LocalPlayerAuthorized
				or _K.Registry.commands.temprole.LocalPlayerAuthorized
		end,

		Activated = function()
			if not newRoleDialog.Visible._value then
				roleDialogTarget(nil)
				roleDialogInput.Value("")
				UI.Sound.Hover03:Play()
			end
			newRoleDialog.Visible(not newRoleDialog.Visible._value)
		end,
	}
	UI.new "Tooltip" { Parent = newRoleButton, Text = "New Member", Hovering = newRoleButton._hovering }

	local itemSize = UI.compute(function()
		_K.client.rank()
		local font = UI.Theme.Font()
		local size = UI.Theme.FontSize()
		local padding = UI.Theme.Padding().Offset
		local maxWidth = size
		for _, role in _K.Data.roles do
			maxWidth = math.max(maxWidth, UI.TextService:GetTextSize(role.name, size, font, Vector2.zero).X)
		end

		local cloudWidth = if _K.Auth.hasPermission(_K.LocalPlayer.UserId, "saveRoles") then size + padding else 0
		return UDim2.fromOffset(maxWidth + padding * 3 + size + cloudWidth, math.round(size + padding))
	end)

	local roleMenu = UI.new "Menu" {
		AutomaticSize = Enum.AutomaticSize.XY,
		RightAlign = true,
		Size = UDim2.new(),
	}
	roleMenu._content.AutomaticSize = Enum.AutomaticSize.X

	local target = UI.state()

	local function hoverClick(value)
		if value then
			UI.Sound.Hover02:Play()
		end
	end

	for roleId, role in _K.Data.roles do
		if role._rank == 0 then
			continue
		end
		UI.new "Button" {
			Parent = roleMenu,
			LayoutOrder = math.min(1e9, role._rank),
			BackgroundTransparency = 1,
			Label = role.name,
			Icon = UI.Theme.Image.Circle,
			IconProperties = {
				ImageColor3 = Color3.fromHex(role.color),
				Size = UDim2.fromScale(0.5, 0.5),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = true,
			},
			Padding = UDim.new(),
			Size = itemSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = function()
				local member = target() or {}
				local hasCommand = _K.Registry.commands.role.LocalPlayerAuthorized
					or _K.Registry.commands.temprole.LocalPlayerAuthorized
				local hasRole = if _K.Auth.hasPermission(_K.LocalPlayer.UserId, "saveRoles")
					then table.find(member.persist or {}, roleId)
					else table.find(member.roles or {}, roleId)
				return (_K.client.rank() > role._rank or _K.creatorId == _K.LocalPlayer.UserId)
					and hasCommand
					and not hasRole
			end,

			UI.new "ImageLabel" {
				LayoutOrder = 9,
				BackgroundTransparency = 1,
				Image = UI.Theme.Image.Cloud_Save,
				ScaleType = Enum.ScaleType.Fit,
				Size = function()
					return UDim2.new(1, UI.Theme.Padding().Offset, 1, 0)
				end,
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = function()
					_K.client.rank()
					return _K.Auth.hasPermission(_K.LocalPlayer.UserId, "saveRoles")
				end,
			},

			Activated = function()
				UI.deactivateState(roleMenu.Visible, "floating")
				if _K.client.rank._value > role._rank or _K.creatorId == _K.LocalPlayer.UserId then
					local save = _K.Registry.commands.role.LocalPlayerAuthorized
					local cmd = `{_K.getCommandPrefix()}{if save then "" else "temp"}role {target().userId} {roleId}`
					_K.Process.runCommands(_K, _K.LocalPlayer.UserId, cmd)
				end
			end,
		}._hovering
			:Connect(hoverClick)
	end

	local function roleChip(roleId: string, member)
		local role = _K.Data.roles[roleId]
		local color = Color3.fromHex(role.color)

		local canRemove = UI.compute(function()
			return (_K.client.rank() > role._rank or _K.creatorId == _K.LocalPlayer.UserId)
				and _K.Registry.commands.unrole.LocalPlayerAuthorized
		end)

		local button = UI.new "Button" {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Icon = UI.Theme.Image.Close_Bold,
			IconProperties = {
				ImageColor3 = UI.Theme.PrimaryText,
				Size = UDim2.fromScale(0.5, 0.5),
			},
			Text = "",
			Visible = canRemove,

			Activated = function()
				if
					(_K.client.rank() > role._rank or _K.creatorId == _K.LocalPlayer.UserId)
					and _K.Registry.commands.unrole.LocalPlayerAuthorized
				then
					local target = member.name or member.userId
					if string.find(target, "%s") then
						target = `"{target}"`
					end
					local cmd = `{_K.getCommandPrefix()}unrole {target} {roleId}`
					_K.Process.runCommands(_K, _K.LocalPlayer.UserId, cmd)
				end
			end,
		}
		UI.new "Tooltip" { Parent = button, Text = "Remove Role", Hovering = button._hovering }
		button._instance.UIStroke:Destroy()

		return UI.new "Frame" {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.75,
			Size = UDim2.new(0, 0, 1, 0),

			UI.new "UICorner" {
				CornerRadius = UI.Theme.CornerRadius,
			},

			UI.new "UIPadding" {
				PaddingLeft = function()
					return if canRemove() then UI.Theme.PaddingHalf() else UI.Theme.Padding()
				end,
				PaddingRight = UI.Theme.Padding,
				PaddingTop = UI.Theme.PaddingHalf,
				PaddingBottom = UI.Theme.PaddingHalf,
			},

			UI.new "UIListLayout" {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.PaddingHalf,
			},

			button,

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				Font = UI.Theme.Font,
				Text = role.name,
				TextSize = function()
					return UI.Theme.FontSize() - UI.Theme.PaddingHalf().Offset
				end,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
			},

			UI.new "ImageLabel" {
				LayoutOrder = 9,
				BackgroundTransparency = 1,
				Image = UI.Theme.Image.Cloud_Done,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = function()
					return table.find(member.persist or {}, roleId)
				end,
			},
		}
	end

	local function createItem(self, log)
		local item = {
			roles = UI.state({}),
			target = UI.state(),
		}

		local addButton
		addButton = UI.new "Button" {
			ActiveSound = false,
			Icon = UI.Theme.Image.Add,
			IconProperties = {
				ImageColor3 = UI.Theme.PrimaryText,
				Size = UDim2.fromScale(0.5, 0.5),
			},
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Text = "",
			Visible = function()
				local _rank = _K.client.rank()
				return _K.Registry.commands.role.LocalPlayerAuthorized
					or _K.Registry.commands.temprole.LocalPlayerAuthorized
			end,

			Activated = function()
				target(item.target(), true)
				local count = 0
				for _, child in roleMenu._content:GetChildren() do
					if child:IsA("TextButton") and child.Visible then
						count += 1
					end
				end
				roleMenu._instance.Size = UDim2.fromOffset(0, math.min(count, 7.5) * itemSize().Y.Offset)
				roleMenu.Adornee(addButton._instance, true)
				UI.toggleState(roleMenu.Visible, "floating")
				local value = UI.raw(roleMenu.Visible)
				if value then
					UI.Sound.Hover03:Play()
				else
					UI.Sound.Hover01:Play()
				end
			end,
		}
		UI.new "Tooltip" { Parent = addButton, Text = "Add Role", Hovering = addButton._hovering }

		item._instance = UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = self.ItemSize,

			UI.new "UIPadding" {
				PaddingBottom = UI.Theme.Padding,
			},

			UI.new "UIListLayout" {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UI.Theme.Padding,
			},

			UI.new "ImageLabel" {
				BackgroundTransparency = UI.Theme.TransparencyHeavy,
				BackgroundColor3 = UI.Theme.PrimaryText,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,

				UI.new "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},
				UI.new "Stroke" {},
			},

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				RichText = true,
				Font = UI.Theme.FontMono,
				TextSize = UI.Theme.FontSize,
				TextColor3 = UI.Theme.PrimaryText,
				TextStrokeColor3 = UI.Theme.Primary,
				TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextXAlignment = Enum.TextXAlignment.Left,
			},

			UI.new "ScrollingFrame" {
				AutomaticSize = Enum.AutomaticSize.X,
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				Size = UDim2.new(0, 0, 1, 0),
				ScrollBarThickness = 0,
				UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Shrink },
				UI.new "UIListLayout" {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UI.Theme.Padding,
				},
				function()
					local chips = {}
					local target = item.target()
					for _, roleId in item.roles() do
						table.insert(chips, roleChip(roleId, target))
					end
					return chips
				end,
			},
			addButton,
		}

		return item
	end

	local function isDifferent(a: { string? }?, b: { string? }?)
		if not a ~= not b then
			return true
		end
		if a and b then
			if #a ~= #b then
				return true
			end
			for k, v in a do
				if b[k] ~= v then
					return true
				end
			end
		end
		return false
	end

	local function renderItem(self, item, userId)
		local member = _K.Data.members[userId]
		if member and member.renderText then
			local instance = item._instance
			instance.TextLabel.Text = member.renderText
			instance.ImageLabel.Image = `rbxthumb://type=AvatarHeadShot&id={member.userId}&w=48&h=48`
			item.target(member)
			if isDifferent(item.roles._value, member.roles) then
				item.roles(member.roles)
			end
		end
	end

	local scroller = UI.new "ScrollerFast" {
		Name = "Members",
		List = _K.client.members,
		Enabled = false,
		DictList = true,
		FilterInput = true,
		Visible = false,
		CreateItem = createItem,
		RenderItem = renderItem,
	}

	scroller._input._instance = UI.new "Frame" {
		Parent = scroller,
		Name = "FilterInput",

		BackgroundTransparency = 1,
		Size = UI.compute(function()
			return UDim2.new(1, 0, 0, UI.Theme.FontSize() + UI.Theme.PaddingDouble().Offset)
		end),

		UI.new "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UI.Theme.Padding,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		UI.edit(scroller._input, { UI.new "UIFlexItem" { FlexMode = Enum.UIFlexMode.Fill } }),
		newRoleButton,
	}

	local function updateCache(member)
		member.nameCache = member.name
		member.rolesCache = if member.roles then table.clone(member.roles) else nil
		member.persistCache = if member.persist then table.clone(member.persist) else nil

		if member.roles then
			local roles = {}
			for _, roleId in member.roles do
				table.insert(roles, _K.Data.roles[roleId].name)
			end

			member.roleString = table.concat(roles, " | ") or ""
		else
			member.roleString = ""
		end

		member.richText = `<b>{member.name or "UNKNOWN"}</b> [{member.userId}]`
		member.rawText = `{member.name or "UNKNOWN"} [{member.userId}]`
		member.filterText = string.lower(`{member.rawText} {member.roleString}`)
	end

	local function filterTest(self, list)
		local filter = string.lower(scroller._input._input.Text)
		self._filter = filter

		local noFilter = string.find(self._filter, "^%s*$")

		local new = {}
		for _, userId in list do
			local member = _K.Data.members[userId]
			if not member then
				continue
			end

			if
				member.name ~= member.nameCache
				or isDifferent(member.roles, member.rolesCache)
				or isDifferent(member.persist, member.persistCache)
			then
				member.userId = userId
				updateCache(member)
			end

			if noFilter then
				member.renderText = member.richText
				table.insert(new, userId)
			else
				local filterFound = string.find(member.filterText, filter, 1, true)
				if filterFound then
					local pre = escape(string.sub(member.rawText, 1, filterFound - 1))
					local query = escape(string.sub(member.rawText, filterFound, filterFound + #filter - 1))
					local post = escape(string.sub(member.rawText, filterFound + #filter))
					member.renderText =
						`<font transparency="0.5">{pre}</font><b>{query}</b><font transparency="0.5">{post}</font>`
					table.insert(new, userId)
				end
			end
		end
		return new
	end

	task.defer(scroller.filter, scroller, filterTest)

	return scroller
end

return Members
