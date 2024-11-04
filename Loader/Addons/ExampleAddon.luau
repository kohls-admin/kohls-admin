-- addons not containing in "Client" or "Server" will run in both contexts (shared)
return function(_K)
	_K.log(`Hello World from ExampleAddon!`, "INFO")

	_K.Registry.registerCommand(_K, {
		name = "customcommand",
		aliases = { "customcommandalias", "customcommandalias2" },
		description = "Custom command description.",

		-- The command group to sort the command by, this is what roles use to easily assign groups of commands.
		-- Default groups in order of abusability are "Utility", "Environment", "General", "Fun", "Moderation", "Administration", and "Creator"
		group = "General", -- Command group to use.

		--[[ Argument definitions

		Default Argument Types
			"boolean" "booleans"
			"integer" "integers"
			"number" "numbers"
			"string" "strings"
			"stringGreedy" Uses ALL text after the argument position, this argument should always be last!

			"ban" "bans"
			"color"
			"command"
			"member" "members"
			"player" "players"
			"userId" "userIds"
			"role" "roles"
			"team" "teams"
			"timeSimple"
			"tool" "tools"

		Roblox Enum Types: Use any Roblox Enum as a type, for example:
			"Enum.Font" for a single Font enum
			"Enum.Fonts" for a list of Font enums

		Creating Custom Types:
			Check Kohl's Admin > MainModule > DefaultTypes for examples

		]]
		args = {
			{
				type = "stringGreedy",
				name = "Message",
				description = "The message to send.", -- Description shown in command list.
				-- If the command is optional, make sure to check if it's nil and not false!
				optional = true,

				lowerRank = false,
				ignoreSelf = false,
				shouldRequest = false,
			},
		},

		-- Command environment

		env = function(_K)
			-- This will only run once on each server
			_K.log(`Hello World from ExampleAddon customcommand env!`, "INFO")

			-- This table is passed to the `run` function as `context.env`
			return {
				countServer = 0,
			}
		end,

		envClient = function(_K)
			-- This will only run once on each client
			_K.log(`Hello World from ExampleAddon customcommand envClient!`, "INFO")

			-- This table is passed to the `runClient` function as `context.env`
			return {
				countClient = 0,
			}
		end,

		--[[ Command execution

		Command context fields:
			_K         - reference to _K toplevel API
			alias      - alias used for this command
			array      - raw command string array result
			definition - reference to the command definition used in registerCommand
			env        - command environment
			from       - userId of the command caller
			fromPlayer - Player Instance of the command caller
			fromRank   - rank of the command caller
			text       - full command text
			undo       - if the alias starts with "un"

		]]

		-- Function that runs on the server when the command is called
		run = function(context, message: string?)
			-- Create a simple Roblox message object
			local messageInstance = Instance.new("Message", workspace)

			-- Since our message is optional we need to check nil for a default value
			messageInstance.Text = if message == nil then "Default message" else message

			-- Destroy the message after 5 seconds
			task.delay(5, messageInstance.Destroy, messageInstance)

			-- Number of times the command has been used on this server
			context.env.countServer += 1

			print("Custom command ran on server!", message, context.env.countServer)
		end,

		-- Function that runs on the player's client when the command is called
		runClient = function(context, message)
			-- Number of times the command has been used on this client
			context.env.countClient += 1
			print("Custom command ran on the client!", message, context.env.countClient)
		end,
	})
end
