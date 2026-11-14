local DEMO_PLACE = 2569622788
return function(_K)
	if game.PlaceId == DEMO_PLACE then
		local function applyDemoSettings()
			for _, settings in { _K.Data.defaultSettings, _K.Data.savedSettings, _K.Data.settings } do
				if type(settings) == "table" then
					settings.welcomeBadgeId = 2437061514247190
					settings.freeAdmin = settings.freeAdmin or {}
					if not table.find(settings.freeAdmin, "admin") then
						table.insert(settings.freeAdmin, "admin")
					end
				end
			end
		end
		applyDemoSettings()
		_K.Hook.preSyncMain:Connect(function(data)
			local settings = type(data) == "table"
				and (data[2] or (type(data.settings) == "table" and (data.settings.set or data.settings)))
			if type(settings) == "table" and type(settings.freeAdmin) == "table" then
				if not table.find(settings.freeAdmin, "admin") then
					table.insert(settings.freeAdmin, "admin")
				end
			end
		end)
		_K.Hook.postSyncMain:Connect(applyDemoSettings)

		for _, role in { _K.Data.roles.mod, _K.Data.roles.admin } do
			if role then
				_K.Util.Table.merge(role.commands, {
					ban = false,
					kick = false,
					crash = false,
					serverlock = false,
				})
			end
		end
		_K.Util.Table.merge(_K.Data.roles.admin.commands, {
			btools = true,
		})
	end
end
