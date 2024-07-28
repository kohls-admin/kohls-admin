-- addons not ending in "Client" or "Server" will run in both contexts
return function(_K)
	-- print("Hello World from ExampleAddon! IsServer:", _K.IsServer)

	-- _K.Registry.registerCommand({
	-- 	name = "customcommand",
	-- 	aliases = { "customcommandalias" },
	-- 	description = "Custom command description.",
	-- 	group = "General", -- command group to use
	-- 	args = {
	-- 		{
	-- 			type = "stringGreedy",
	-- 			name = "Message",
	-- 			description = "The message to send. Argument Description for the custom command",
	-- 		},
	-- 	},
	-- 	runClient = function(context, message)
	-- 		print("Custom command ran on the client!", context, message)
	-- 	end,
	-- 	run = function(context, message)
	-- 		print("Custom command ran on server!", context, message)
	-- 		local msgObject = Instance.new("Message")
	-- 		msgObject.Text = message
	-- 		msgObject.Parent = workspace
	-- 		task.delay(5, function()
	-- 			msgObject:Destroy()
	-- 		end)
	-- 	end,
	-- })
end
