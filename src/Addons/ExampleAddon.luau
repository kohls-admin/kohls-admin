export type ArgumentDefinition = {
	type: string,
	name: string,
	description: string,
	optional: boolean?,
	-- player type options
	lowerRank: boolean?,
	ignoreSelf: boolean?,
	shouldRequest: boolean?,
}

-- addons not ending in "Client" or "Server" will run in both contexts
return function(_K)
	print("Hello World from ExampleAddon! IsServer:", _K.IsServer)

	_K.Registry.registerCommand(_K, {
		name = "customcommand",
		aliases = { "customcommandalias", "customcommandalias2" },
		description = "Custom command description.",

		-- The command group to sort the command by, this is what roles use to easily assign groups of commands.
		-- Default groups in order of abusability are "Utility", "Environment", "General", "Fun", "Moderation", "Administration", and "Creator"
		group = "General", -- Command group to use.

		-- Argument definitions
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.", -- Description shown in command listings.
				-- If the command is optional, make sure to check if it's context.OPTIONAL
				optional = true,

				lowerRank = false,
				ignoreSelf = false,
				shouldRequest = false,
			},
		},

		-- Command environment

		env = function(_K)
			-- This will only run once on each server
			print("Hello world from ExampleAddon customcommand env! IsServer:", _K.IsServer)

			-- This table is passed to the `run` function as `context.env`
			return {
				countServer = 0,
			}
		end,

		envClient = function(_K)
			-- This will only run once on each client
			print("Hello world from ExampleAddon envClient! IsServer:", _K.IsServer)

			-- This table is passed to the `runClient` function as `context.env`
			return {
				countClient = 0,
			}
		end,

		-- Command execution

		-- Function that runs on the server
		run = function(context, message: string?)
			print("Custom command ran on server!", context, message)

			-- Create a simple Roblox message object
			local messageInstance = Instance.new("Message", workspace)

			-- Since our message is optional we need to check for context.OPTIONAL
			messageInstance.Text = if message == context.OPTIONAL then "Default message" else message

			-- This will destroy the message after 5 seconds
			task.delay(5, messageInstance.Destroy, messageInstance)

			-- Number of times the command has been used on this server
			context.env.countServer += 1
		end,

		-- Function that runs on the player's client
		runClient = function(context, message)
			print("Custom command ran on the client!", context, message)

			-- Number of times the command has been used on this client
			context.env.countClient += 1
		end,
	})
end
