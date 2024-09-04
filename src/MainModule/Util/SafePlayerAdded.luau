local Players = game:GetService("Players")

return function(callback)
	for _, player in Players:GetPlayers() do
		task.spawn(callback, player)
	end
	Players.PlayerAdded:Connect(callback)
end
