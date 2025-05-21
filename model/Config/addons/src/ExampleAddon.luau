-- addons not containing in "Client" or "Server" will run in both contexts (shared)
return function(_K)
	if _K.DEBUG then
		_K.log(`Hello World from ExampleAddon!`, "INFO")
	end

	_K.Registry.registerCommand(_K, {
		name = "customcommand",
		aliases = { "customcommandalias", "customcommandalias2" },
		description = "Custom command description.",

		-- The command group to sort the command by, this is what roles use to easily assign groups of commands.
		-- Default groups in order of abusability are "Utility", "Environment", "General", "Fun", "Moderation", "Administration", and "Creator"
		group = "General", -- Command group to use.
		noLog = false, -- If the command is not logged when used.

		--[[ ARGUMENT DEFINITIONS

		Default Argument Types
			"boolean" "booleans"
			"integer" "integers"
			"number" "numbers"
			"string" "strings"        - normal strings are filtered by default!
			"rawString" "rawStrings" - use rawStrings for commands that require an unfiltered input
			"vector2"
			"vector3"

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

		Custom Enum Types: Create your own Enum types, for example:
			"Sunny,Rainy,Foggy" --IMPORTANT: NO SPACES

		Types can be unioned with a prefix, for example:
			"player # vector3" --IMPORTANT: MUST HAVE SPACES | Usage: "me" = Player, "#0,1,0" = Vector3

		Creating Custom Types:
			Check Kohl's Admin > Loader > MainModule > DefaultTypes for examples

		]]
		args = {
			{
				type = "string",
				name = "Message",
				description = "The message to send.", -- Description shown in command list.
				optional = true, -- If the command is optional, make sure to check if it's nil and not false!

				permissions = {}, -- Permission restrictions, hidden from users without the permissions and returns nil, see Kohl's Admin > Config > Settings for every permission

				-- player type options
				lowerRank = false, -- Only allows selecting players of a lower rank
				ignoreSelf = false, -- Only allows selecting other players
				shouldRequest = false, -- If the command should be requested on same rank or higher
			},
		},
		permissions = {}, -- Command permission restrictions, see Kohl's Admin > Config > Settings for every permission

		-- COMMAND ENVIRONMENTS

		env = function(_K)
			-- This will only run once on each server while in studio or in the demo place
			if _K.DEBUG or _K.IsStudio then
				_K.log(`Hello World from ExampleAddon customcommand env!`, "INFO")
			end

			-- This table is passed to the `run` function as `context.env`
			return {
				countServer = 0,
			}
		end,

		envClient = function(_K)
			-- This will only run once on each client while in studio or in the demo place
			if _K.DEBUG or _K.IsStudio then
				_K.log(`Hello World from ExampleAddon customcommand envClient!`, "INFO")
			end

			-- This table is passed to the `runClient` function as `context.env`
			return {
				countClient = 0,
			}
		end,

		--[[ COMMAND EXECUTION

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
