-- This addon is for the Kohl's Admin Demo place

return function(_K)
	if game.PlaceId == 18274376677 then
		if _K.IsServer then
			table.insert(_K.loaderSettings.freeAdmin, "creator")
		end
	end
end
