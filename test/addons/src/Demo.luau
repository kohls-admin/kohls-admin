local DEMO_PLACE = 2569622788
return function(_K)
	if game.PlaceId == DEMO_PLACE then
		_K.Data.settings.welcomeBadgeId = 2437061514247190
		if not table.find(_K.Data.settings.freeAdmin, "admin") then
			table.insert(_K.Data.settings.freeAdmin, "admin")
		end
		_K.Util.Table.merge(_K.Data.roles.admin.commands, {
			serverlock = false,
			btools = true,
		})
	end
end
