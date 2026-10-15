---
sidebar_position: 3
---

# Custom Commands

Custom commands let you extend Kohl's Admin with experience-specific tools, automate developer workflows, and create interactive player commands with full autocomplete and permission checks.

## Prerequisites

- **Kohl's Admin Installed**: Ensure Kohl's Admin is [installed in your experience](/guide/getting-started/installation).
- **`Config > Addons` Folder**: Locate the **`Addons`** folder inside `Kohl's Admin > Config` in the Roblox Studio Explorer.

## Creating a Command Addon

Custom commands are registered inside an **Addon**—a [ModuleScript](https://create.roblox.com/docs/reference/engine/classes/ModuleScript) placed in `Kohl's Admin > Config > Addons` (or tagged with `"Kohl's Admin Addon"` via `CollectionService`) that returns a `function(_K)`.

:::danger Keep Command Addons Shared
Do **not** include `"Server"` or `"Client"` in the `ModuleScript` name of an addon that registers commands!
Addons with `"Server"` or `"Client"` in their name only execute on that side. Commands **must** be registered on both the server and the client so the client's Command Bar autocomplete, validation, and Commands UI know the command exists.
:::

Create a `ModuleScript` named `CustomCommands` inside `Kohl's Admin > Config > Addons`:

```luau
return function(_K)
	_K.Registry.registerCommand(_K, {
		name = "shout",
		aliases = { "broadcast", "yell" },
		description = "Displays a temporary message on screen for all players.",
		group = "Administration",
		noLog = false,

		args = {
			{
				type = "string",
				name = "Message",
				description = "The message to display.",
				optional = false,
			},
		},

		run = function(context, message: string)
			-- Rate-limit player-authored broadcast messages (Roblox chat compliance)
			local err = context._K.Chat.cooldown(context.from, "shout")
			if err then
				return err -- Returning a string displays an error notification to the caller
			end

			context._K.Remote.Notify:FireAllClients({
				From = context.from,
				Text = message,
				Duration = 10,
			})
			return
		end,
	})
end
```

:::tip Multiple Commands in One Addon
You can call `_K.Registry.registerCommand(_K, ...)` as many times as you want inside a single addon function, or return an array of command definitions and load it with [`_K.Registry.registerCommandModule`](/api/Registry#registercommandmodule).
:::

---

## Command Definition Reference

Every command passed to [`_K.Registry.registerCommand`](/api/Registry#registercommand) follows the [`CommandDefinition`](/api/Registry#commanddefinition) schema:

```luau
type CommandDefinition = {
	name: string,                        -- Primary command name (lowercase recommended)
	aliases: { string }?,                -- Alternative names/shorthands for the command
	description: string,                 -- Shown in the Commands UI and Command Bar tooltip
	group: string,                       -- Command group used by roles for access control
	noLog: boolean?,                     -- When true, hides execution from command logs
	optionalPrefix: boolean?,            -- When true, allows running in chat without a prefix
	args: { ArgumentDefinition }?,       -- Ordered list of command arguments
	permissions: { [string]: boolean }?, -- Required role permissions (e.g. { saveRoles = true })
	env: ({} | (_K: any) -> {})?,        -- Server environment table or initializer function
	envClient: ({} | (_K: any) -> {})?,  -- Client environment table or initializer function
	run: (context: any, ...any) -> string?,       -- Server execution callback
	runClient: (context: any, ...any) -> string?, -- Client execution callback (runs on caller's client)
}
```

### Standard Command Groups (`group`)

The `group` field determines which roles have access to the command by default (configured in each role's `groups` list in `Config > Settings`, case-insensitive):

| Group | Default Minimum Role | Typical Use Case |
| :--- | :--- | :--- |
| `"Utility"` | `everyone` (Rank 0) | Safe informational or self-help commands (`help`, `cmds`, `info`, `version`, `ping`). |
| `"VIP"` | `vip` (Rank 1) | Cosmetic self-only perks (`headless`, `cape`, `fire`, `sparkles`, `trail`). |
| `"General"` | `mod` (Rank 2) | Standard character and camera utilities (`respawn`, `refresh`, `view`, `spectate`, `fly`). |
| `"Environment"` | `mod` (Rank 2) | Lighting, atmosphere, gravity, water, and world state (`time`, `fog`, `gravity`, `fix`). |
| `"Fun"` | `mod` (Rank 2) | Playful or potentially disruptive effects (`disco`, `explode`, `clone`, `zombie`, `spin`). |
| `"Moderation"` | `mod` (Rank 2) | Player management and discipline (`kick`, `ban`, `mute`, `jail`, `bring`, `tp`, `heal`). |
| `"Administration"` | `admin` (Rank 3) | High-trust server management (`announce`, `role`, `btools`, `gear`, `serverlock`, `place`). |
| `"SuperAdmin"` | `superadmin` (Rank 4) | Cross-server and permanent actions (`badge`, `reserve`, `shutdown`, `global`, `clearterrain`). |
| `"Creator"` | `creator` (`math.huge`) | Ultimate authority commands (`clearlogs`, `hidelogs`, `script`, `localscript`). |

---

## Argument Definitions (`args`)

Each entry in `args` defines one positional argument using [`ArgumentDefinition`](/api/Registry#argumentdefinition):

```luau
type ArgumentDefinition = {
	type: string,                        -- Registered argument type name, Enum, or union
	name: string,                        -- Display name in Command Bar and Commands UI
	description: string,                 -- Tooltip description shown while typing
	optional: boolean?,                  -- If true, argument may be omitted (check for nil!)
	permissions: { [string]: boolean }?, -- Hides/skips argument unless caller has these permissions

	-- Player / User argument options (applies to "player", "players", "userId", "userIds", "member", "members"):
	lowerRank: boolean?,                 -- Only allows targeting players with a strictly lower rank than the caller
	ignoreSelf: boolean?,                -- Prevents the caller from targeting themselves ("me")
	shouldRequest: boolean?,             -- Prompts equal/higher rank targets with a Command Request dialog
}
```

:::warning Optional Boolean Arguments
When `optional = true`, an omitted argument is passed to `run` / `runClient` as `nil`. Always check `if arg == nil` rather than `if not arg` when applying a default value to an optional `boolean` argument!
:::

### Built-In Argument Types

Kohl's Admin registers a rich set of built-in argument types in `src/Shared/DefaultTypes`. Most singular types also have a plural **listable** counterpart (accepting comma-separated lists like `arg1,arg2` and passing an array `{ T }` to `run`):

#### Primitives & Strings

| Type | Listable Type | Parsed Value | Notes |
| :--- | :--- | :--- | :--- |
| `"boolean"` | `"booleans"` | `boolean` | Accepts `true`/`false`, `yes`/`no`, `enabled`/`disabled`, `+`/`-` (or prefix match). |
| `"integer"` | `"integers"` | `number` | Whole numbers only (`math.floor(n) == n`). |
| `"number"` | `"numbers"` | `number` | Any valid number (integer or decimal). |
| `"string"` | `"strings"` | `string` | **Filtered by default** via `TextService` for safe public broadcast. If it is the last argument in `args`, consumes the remainder of the command text. |
| `"rawString"` | `"rawStrings"` | `string` | **Unfiltered** raw string. Use only for internal identifiers, asset names, or code—never display unfiltered `rawString` text to other players! |
| `"chatString"` | — | `string` | For player-to-player messages sent through `_K.Chat.send` (where `TextChatService` handles per-recipient filtering and abuse reporting). |

#### Players, Users & Roles

| Type | Listable Type | Parsed Value | Notes |
| :--- | :--- | :--- | :--- |
| `"player"` | `"players"` | `Player` | Online `Player` instance(s). Supports all [Target Selectors](/guide/getting-started/using_commands#player-target-selectors) (`me`, `*`, `others`, `@role`, `%team`, `~random`, `$special`). |
| `"userId"` | `"userIds"` | `number` | Online or recently-cached player `UserId`, or any raw numeric `UserId` for offline users. Also supports all Target Selectors! |
| `"member"` | `"members"` | `string` | Stringified `UserId` of a user in `_K.Data.members` (supports `me` and `*`/`all`). |
| `"ban"` | `"bans"` | `string` | Stringified `UserId` of a banned user in `_K.Data.bans` (supports `*`/`all`). |
| `"role"` | `"roles"` | `string` | Role ID (`_key`) in `_K.Data.roles` lower than the caller's rank. |
| `"team"` | `"teams"` | `Team` | `Team` instance in `game:GetService("Teams")`. |

#### Roblox DataTypes, Enums & Admin Objects

| Type | Listable Type | Parsed Value | Notes |
| :--- | :--- | :--- | :--- |
| `"color"` | — | `Color3` | Accepts color names (`red`, `cyan`), BrickColor names/IDs, hex (`#0ff`, `#ff00ff`), RGB (`255,0,128`), or `random`. |
| `"vector2"` | — | `Vector2` | Comma-separated pair of numbers (e.g. `10,20`). |
| `"vector3"` | — | `Vector3` | Comma-separated trio of numbers (e.g. `0,50,0`). |
| `"timeSimple"` | — | `number` | Duration in seconds. Accepts units like `30s`, `5m`, `2h`, `7d`, `1w`, `1y`, `0` (session), or `-1` (forever). |
| `"tool"` | `"tools"` | `Tool \| HopperBin` | Matches tools in `Lighting`, `ReplicatedStorage`, `ServerStorage`, or `StarterPack` (supports `all`). Exclude specific tools by adding the `"_K_Ignore"` CollectionService tag. |
| `"command"` | — | `CommandDefinition` | Matches any registered command or alias the caller is authorized to use. |
| `"reservedServer"` | `"reservedServers"` | `table` | Matches a saved reserved server code created via `;reserve`. |
| `"emote"` | `"emotes"` | `number` | Catalog emote name or asset ID, parsed into its animation ID. |
| `"image"` | `"images"` | `string` | Decal/Image asset ID, parsed into a resolved `rbxassetid://...` texture string. |

### Roblox Enum Types, Custom Inline Enums & Type Unions

You can define Enum arguments and type unions directly in the `type` string of an `ArgumentDefinition` without registering a separate custom type:

1. **Roblox Enums (`"Enum.<EnumName>"`)**:
   Use any Roblox `Enum` by name (add a trailing `s` for a comma-separated list of EnumItems):
   ```luau
   {
   	type = "Enum.Material", -- or "Enum.Materials" for a list!
   	name = "Material",
   	description = "The part material to apply.",
   }
   ```
2. **Custom Inline String Enums (`"OptionA,OptionB,OptionC"`)**:
   Provide a comma-separated list of choices with **no spaces** around the commas:
   ```luau
   {
   	type = "Sunny,Rainy,Foggy,Stormy",
   	name = "Weather",
   	description = "The weather preset to activate.",
   }
   ```
3. **Prefixed Type Unions (`"<type1> <prefix><type2>"`)**:
   Allow an argument to accept multiple types distinguished by a prefix character (must have spaces between tokens):
   ```luau
   {
   	-- Plain input ("me" or "Builderman") parses as a Player
   	-- Input prefixed with "#" ("#0,100,0") parses as a Vector3
   	type = "player # vector3",
   	name = "Destination",
   	description = "Target player or #X,Y,Z coordinates.",
   }
   ```

---

## Command Environments (`env` & `envClient`)

If your command needs persistent state, connections, or helper instances across executions, define `env` (for the server) and/or `envClient` (for the client).
- If `env` or `envClient` is a function `(_K) -> table`, Kohl's Admin calls it **once** when the command is registered and stores the returned table in `context.env`.

```luau
env = function(_K)
	local activeLoops = {}
	_K.Service.Players.PlayerRemoving:Connect(function(player)
		activeLoops[player] = nil
	end)
	return {
		activeLoops = activeLoops,
	}
end,
```

---

## Command Execution (`run` & `runClient`)

When a player executes a command:
1. Arguments are transformed, validated, and parsed on the client.
2. If `runClient` is defined on the command, `runClient(context, ...parsedArgs)` runs immediately on the caller's client.
3. If `run` is defined on the command, the raw command string is sent to the server, re-validated against server authority, rate limits, and target permissions, and `run(context, ...parsedArgs)` runs on the server.

### The `context` Object

The first parameter passed to both `run` and `runClient` is the command `context` object:

| Field | Type | Description |
| :--- | :--- | :--- |
| `context._K` | `_K` | Reference to the root [`MainModule` (`_K`)](/api/MainModule) API table. |
| `context.alias` | `string` | The exact command name or alias the player typed (e.g. `"unfly"`). |
| `context.undo` | `boolean` | `true` if `context.alias` starts with `"un"` (useful for sharing one `run` function between `fly` and `unfly`!). |
| `context.from` | `number` | `UserId` of the player who ran the command. |
| `context.fromPlayer` | `Player?` | `Player` instance of the caller (if currently in the server). |
| `context.fromRank` | `number` | Numeric authority rank of the caller (`0` to `math.huge`). |
| `context.fromRole` | `RoleData` | Highest role definition table held by the caller. |
| `context.env` | `table?` | The resolved `env` (on server) or `envClient` (on client) table for this command. |
| `context.definition` | `CommandDefinition` | Reference to the command's `CommandDefinition` table. |
| `context.text` | `string` | The full raw command message string. |
| `context.array` | `table` | Raw parsed token positions and strings for the command. |
| `context.global` | `boolean` | `true` if the command was broadcast from another server via `;global`. |

### Handling Undo Aliases & Returning Errors

A common idiom in Kohl's Admin is pairing a command and its `"un..."` alias in a single definition using `context.undo`, and returning a string whenever you want to abort and show an error toast to the caller:

```luau
return function(_K)
	_K.Registry.registerCommand(_K, {
		name = "lowgravity",
		aliases = { "unlowgravity" },
		description = "Toggles low gravity for one or more players.",
		group = "Fun",
		args = {
			{
				type = "players",
				name = "Players",
				description = "The player(s) to affect.",
				shouldRequest = true,
			},
		},

		run = function(context, players: { Player })
			for _, player in players do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root then
					continue
				end

				local existing = root:FindFirstChild("_KALowGravity")
				if existing then
					existing:Destroy()
				end

				if not context.undo then
					local attachment = root:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", root)
					local force = Instance.new("VectorForce")
					force.Name = "_KALowGravity"
					force.Attachment0 = attachment
					force.RelativeTo = Enum.ActuatorRelativeTo.World
					force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * 0.65, 0)
					force.Parent = root
				end
			end
			return
		end,
	})
end
```

---

## Overriding Built-In Commands

If you register a command whose `name` matches an existing built-in command (for example, `"kick"` or `"fly"`), Kohl's Admin cleanly replaces the built-in command in the [`Registry`](/api/Registry), clears its old aliases, and preserves its original `group` if you omit `group` in your new definition.
