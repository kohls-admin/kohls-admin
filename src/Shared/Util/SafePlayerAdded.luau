--!strict

local Players = game:GetService("Players")

type PlayerSet = { [Player]: boolean }

local cache: { [PlayerSet]: RBXScriptConnection } = {}

Players.PlayerRemoving:Connect(function(player)
	for processed, connection in cache do
		if connection and connection.Connected then
			processed[player] = nil
		else
			cache[processed] = nil
			table.clear(processed)
		end
	end
end)

return function(callback): RBXScriptConnection
	local processed: PlayerSet = {}

	local function playerAdded(player)
		if processed[player] then
			return
		end
		processed[player] = true
		callback(player)
	end

	local connection = Players.PlayerAdded:Connect(playerAdded)
	cache[processed] = connection

	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end

	return connection
end
