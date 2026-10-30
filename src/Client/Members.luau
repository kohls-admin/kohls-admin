local UI = require(script.Parent:WaitForChild("UI"))

local Members = {}
Members.__index = Members

function Members.new(_K)
	local escape = _K.Util.String.escapeRichText

	local inputSize = function()
		local size = UI.Theme.FontSize()
		local padding = UI.Theme.Padding().Offset
		return UDim2.fromOffset(0, size + padding)
	end

	local roleChoice = UI.signal({ Id = "vip", Name = "VIP" })
	local roleChoices = UI.signal({ { Id = "vip", Name = "VIP" } })
	local roleDialogTarget = UI.signal(nil)
	local roleDialogInput
	local lookup = 0
	local function resetRoleTargetInput()
		roleDialogTarget:set(nil)
		roleDialogInput:SetValue("")
	end

	roleDialogInput = UI.new "Input" {
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = UI.Theme.FontMono,
		FontSize = UI.Theme.FontSize,
		MaxChars = 20,
		Placeholder = "UserId or Username",
		Size = inputSize,
		Value = "",

		UI.flex("shrink"),

		[UI.Hook] = {
			Value = function(value)
				-- the name lookup yields, so it runs off the reactive graph; a newer lookup drops this one
				-- clear the target until it resolves so actions can't hit the previous user
				lookup += 1
				local current = lookup
				roleDialogTarget:set(nil)
				if value == "" then
					UI.flush()
					return
				end
				task.spawn(function()
					local userId
					if tonumber(value) then
						userId = tonumber(value)
					else
						local ok, result = pcall(_K.Service.Players.GetUserIdFromNameAsync, _K.Service.Players, value)
						userId = ok and result
					end
					if current ~= lookup then
						return
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

					_K.Data.targetLimits[_K.LocalPlayer.UserId] = 0
					if userId and not _K.Auth.targetUserArgument(fauxArg, userId, userId) then
						userId = nil
						task.defer(resetRoleTargetInput)
					end

					local member = _K.Data.members[tostring(userId)] or {}
					local availableRoles = {}
					for rank, role in _K.Data.rolesList do
						if rank == 0 or (rank >= _K.client.rank:peek() and _K.creatorId ~= _K.LocalPlayer.UserId) then
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
					-- roleChoice stays a role table, Confirm reads its Id
					roleChoice(availableRoles[1] or { Id = "", Name = "" })
					roleChoices(availableRoles)
					roleDialogTarget:set(userId)
					UI.flush()
				end)
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

		UI.padding(UI.Theme.Padding),

		UI.new "ListItem" {
			Text = "User",
			UI.new "ImageLabel" {
				BackgroundTransparency = UI.Theme.TransparencyHeavy,
				BackgroundColor3 = UI.Theme.PrimaryText,
				Size = inputSize,
				Image = function()
					return `rbxthumb://type=AvatarHeadShot&id={roleDialogTarget()}&w=48&h=48`
				end,
				UI.aspectRatio(1, "scale", "height"),
				UI.corner(UI.Theme.CornerPadded),
			},
			roleDialogInput,
		},

		UI.new "ListItem" {
			Text = "Role",
			UI.new "Select" {
				Value = roleChoice,
				Choices = roleChoices,
			},
			Visible = function()
				return roleDialogTarget() and #roleChoices() > 0
			end,
		},

		UI.new "Button" {
			Label = "Confirm",
			Activated = function()
				if roleDialogTarget:peek() and roleChoice:peek().Id ~= "" then
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

	local newMemberButton = UI.new "Button" {
		LayoutOrder = 3,
		ActiveSound = false,
		Icon = UI.Theme.Image.Add,
		IconProperties = {
			ImageColor3 = UI.Theme.PrimaryText,
		},
		Size = UDim2.new(1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		UI.padding(UI.Theme.Padding),

		Visible = function()
			_K.client.rank()
			return _K.Registry.commands.role.LocalPlayerAuthorized
				or _K.Registry.commands.temprole.LocalPlayerAuthorized
		end,

		Activated = function()
			if not newRoleDialog.Visible:peek() then
				roleDialogTarget:set(nil)
				roleDialogInput:SetValue("")
				UI.Sound.Hover03:Play()
			end
			newRoleDialog.Visible(not newRoleDialog.Visible:peek())
		end,
	}
	UI.new "Tooltip" { Parent = newMemberButton, Text = "New Member", Hovering = newMemberButton._hovering }
	UI.edit(newMemberButton._instance.UICorner)({ CornerRadius = UI.Theme.CornerPadded })

	-- measured off the reactive graph: GetTextBoundsAsync yields and must never run inside a computed
	local roleTextWidth = UI.textWidth(function()
		_K.client.rank()
		local font = UI.Theme.Font()
		local size = UI.Theme.FontSize()
		local requests = {}
		for _, role in _K.Data.roles do
			table.insert(requests, { Text = role.name, Font = font, Size = size, RichText = true })
		end
		return requests
	end)

	local itemSize = UI.computed(function()
		_K.client.rank()
		local size = UI.Theme.FontSize()
		local padding = UI.Theme.Padding().Offset
		local maxWidth: number = math.max(size, roleTextWidth())

		local canSave = _K.Auth.hasPermission(_K.LocalPlayer.UserId, "saveRoles")
		local cloudWidth = canSave and (size + padding) or 0
		return UDim2.fromOffset(maxWidth + padding * 3 + size + cloudWidth, math.round(size + padding))
	end)

	local roleMenu = UI.new "Menu" {
		AutomaticSize = Enum.AutomaticSize.XY,
		RightAlign = true,
		Size = UDim2.new(),
	}
	roleMenu._content.AutomaticSize = Enum.AutomaticSize.X

	local target = UI.signal(nil)

	local function hoverClick(value)
		if value then
			UI.Sound.Hover02:Play()
		end
	end

	for roleId, role in _K.Data.roles do
		if not role._rank or role._rank == 0 then
			continue
		end
		local roleButton = UI.new "Button" {
			Parent = roleMenu,
			LayoutOrder = math.min(1e9, role._rank :: number),
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
				if _K.client.rank:peek() > role._rank or _K.creatorId == _K.LocalPlayer.UserId then
					local save = _K.Registry.commands.role.LocalPlayerAuthorized
					local cmd = `{_K.getCommandPrefix()}{if save then "" else "temp"}role {target().userId} {roleId}`
					_K.Process.runCommands(_K, _K.LocalPlayer.UserId, cmd)
				end
			end,
		}
		UI.effect(UI.on(roleButton._hovering, hoverClick, true)):get()
	end

	local function roleRemoveCornerRadius()
		local padding = UI.Theme.Padding()
		local radius = UI.Theme.CornerRadius()
		return UDim.new(radius.Scale, radius.Offset - padding.Offset * 0.75)
	end

	local function roleChip(index, roleId: string, item)
		local role = _K.Data.roles[roleId]
		local color = Color3.fromHex(role.color)

		local canRemove = UI.computed(function() -- TODO need to check the highest role chip
			local rank = 0
			for _, id in item.roles() do
				rank = math.max(rank, _K.Data.roles[id]._rank)
			end
			return (_K.client.rank() > rank or _K.creatorId == _K.LocalPlayer.UserId)
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
					local member = item.target:peek()
					local target = member.name or member.userId
					if string.find(target, "%s") then
						target = `"{target}"`
					end
					local cmd = `{_K.getCommandPrefix()}unrole {target} {roleId}`
					_K.Process.runCommands(_K, _K.LocalPlayer.UserId, cmd)
				end
			end,
		}
		local tooltip = UI.new "Tooltip" { Parent = button, Text = "Remove Role", Hovering = button._hovering }
		button._instance.UIStroke:Destroy()
		UI.cleanup({ button, tooltip })

		UI.edit(button._instance.UICorner)({ CornerRadius = roleRemoveCornerRadius })

		return UI.new "Frame" {
			__CLEAN = { button, tooltip },
			LayoutOrder = index,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.75,
			Size = UDim2.new(0, 0, 1, 0),

			UI.corner(UI.Theme.CornerPadded),

			UI.padding {
				left = function()
					return if canRemove() then UI.Theme.PaddingHalf() else UI.Theme.Padding()
				end,
				right = UI.Theme.Padding,
				y = UI.Theme.PaddingHalf,
			},

			UI.list {
				direction = "x",
				gap = UI.Theme.PaddingHalf,
				verticalAlign = "center",
			},

			button,

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				FontFace = UI.Theme.Font,
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
					local member = item.target()
					return if member and member.persist and table.find(member.persist, roleId) then true else false
				end,
			},
		}
	end

	local function createItem(self, lineData)
		local item = {
			roles = UI.signal({}),
			target = UI.signal(nil),
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
			Visible = function()
				local _rank = _K.client.rank()
				return _K.Registry.commands.role.LocalPlayerAuthorized
					or _K.Registry.commands.temprole.LocalPlayerAuthorized
			end,

			Activated = function()
				target(item.target:peek(), true)
				UI.flush()
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
		UI.edit(addButton._instance.UICorner)({ CornerRadius = UI.Theme.CornerPadded })

		item._instance = UI.new "Frame" {
			BackgroundTransparency = 1,
			Size = self.ItemSize,

			UI.padding {
				bottom = UI.Theme.Padding,
			},

			UI.list {
				direction = "x",
				gap = UI.Theme.Padding,
				verticalAlign = "center",
			},

			UI.new "ImageLabel" {
				BackgroundTransparency = UI.Theme.TransparencyHeavy,
				BackgroundColor3 = UI.Theme.PrimaryText,
				Size = UDim2.new(1, 0, 1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,

				UI.corner(UI.Theme.CornerPadded),
				UI.new "Stroke" {},
			},

			UI.new "TextLabel" {
				AutoLocalize = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				RichText = true,
				FontFace = UI.Theme.Font,
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
				UI.flex("shrink"),
				UI.list {
					direction = "x",
					gap = UI.Theme.Padding,
					verticalAlign = "center",
				},
				UI.forValue(item.roles, function(index, roleId)
					return roleChip(index, roleId, item)
				end),
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

	local function renderItem(self, itemData, lineData)
		local member = _K.Data.members[lineData]
		if member and member.renderText then
			local instance = itemData._instance
			instance.TextLabel.Text = member.renderText
			instance.ImageLabel.Image = `rbxthumb://type=AvatarHeadShot&id={member.userId}&w=48&h=48`
			itemData.target:set(member)
			if isDifferent(itemData.roles:peek(), member.roles) then
				itemData.roles:set(if member.roles then table.clone(member.roles) else {})
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
		LayoutOrder = -1,

		BackgroundTransparency = 1,
		Size = function()
			return UDim2.new(0, 0, 0, UI.Theme.FontSize() + UI.Theme.PaddingDouble().Offset)
		end,

		UI.list {
			direction = "x",
			gap = UI.Theme.PaddingWithStroke,
		},
		UI.edit(scroller._input)({ UI.flex("fill") }),
		newMemberButton,
	}

	local function updateCache(member)
		member.nameCache = member.name
		member.rolesCache = if member.roles then table.clone(member.roles) else nil
		member.persistCache = if member.persist then table.clone(member.persist) else nil

		if member.roles then
			local roles = {}
			for _, roleId in member.roles do
				local role = _K.Data.roles[roleId]
				if role then
					table.insert(roles, role.name)
				end
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
