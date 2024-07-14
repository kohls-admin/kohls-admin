-- "non-abusive" commands for game members

return {
	{
		name = "message",
		aliases = { "m", "msg" },
		description = "Sends a message to everyone in the server.",
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, message)
			local msgObject = Instance.new("Message")
			msgObject.Text = message
			msgObject.Parent = workspace
			task.delay(5, function()
				msgObject:Destroy()
			end)
		end,
	},
	{
		name = "hint",
		aliases = { "h" },
		description = "Sends a hint to everyone in the server.",
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.",
			},
		},

		run = function(context, message)
			local msgObject = Instance.new("Hint")
			msgObject.Text = message
			msgObject.Parent = workspace
			task.delay(5, function()
				msgObject:Destroy()
			end)
		end,
	},
}
