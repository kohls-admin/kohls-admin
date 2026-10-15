---
sidebar_position: 2
---

# Configuration

All configuration for Kohl's Admin lives inside **`Kohl's Admin > Config > Settings`** in the Roblox Studio Explorer.

:::info Using the Legacy Loader?
There are two `Settings` scripts in the model:
- **`Kohl's Admin > Config > Settings`**: Used by the modern Kohl's Admin loader (documented on this page).
- **`Kohl's Admin > Config > Legacy > Settings`**: Used by the legacy *Kohl's Admin Infinite* loader (and automatically imported by the modern loader). See [Legacy Loader & Migration](/guide/getting-started/legacy_loader) for legacy configuration details.
:::

## Role Hierarchy & Multi-Role System

Unlike older admin systems where a player only has a single numeric rank, Kohl's Admin uses a **Role-Based Access Control (RBAC)** system:

- Players can hold **multiple roles simultaneously** (for example, both `vip` and `helper`).
- A player's effective **rank** is determined by the highest-ranked role they hold.
- Role ranks are determined automatically by their array order in `roles` (`rank = index - 1`), except for `creator` which is explicitly indexed at `[math.huge]`.
- Command groups and permissions are combined across all roles a player holds.

### Default Roles

| Rank | Role ID (`_key`) | Display Name | Default Capabilities |
| :--- | :--- | :--- | :--- |
| `math.huge` | `creator` | Game Creator | Bypasses all permission checks (`admin = true`). Automatically granted to the game or group owner. |
| `4` | `superadmin` | SuperAdmin | Can permanently assign roles (`saveRoles`), change saved game settings (`settings`), manage reserved servers, shut down servers, award badges, and run global commands. |
| `3` | `admin` | Administrator | Can permanently ban users across servers (`banasync`), assign temporary server roles, and use `administration` commands (`announce`, `btools`, `gear`, `serverlock`, etc.). |
| `2` | `mod` | Moderator | Can kick, server-ban, mute, jail, teleport, and use `moderation`, `general`, `environment`, `fun`, and `vip` commands. Can view server logs (`serverlogs`). |
| `1` | `vip` | VIP | Can use cosmetic `vip` commands (accessories, trails, particles, headless, etc.) on themselves only (`onlyTargetSelf = true`). |
| `0` | `everyone` | Player | Assigned to every player by default. Limited to safe `utility` commands (`help`, `cmds`, `info`, `version`, etc.) on themselves only. |

---

## Finding Roblox Identifiers

When configuring `Settings`, you can reference users, groups, and marketplace items by their IDs or names:

- **UserId**: Found in a user's profile URL: `https://www.roblox.com/users/44391621/profile` → `44391621`
- **Username**: The player's unique account name (e.g. `"Scripth"`), not their DisplayName. Prefer `UserId` when possible so roles persist if a user changes their username.
- **GroupId**: Found in a group's URL: `https://www.roblox.com/groups/3403354/Kohl` → `3403354`
- **Group Rank**: An integer from `0` to `255` configured on your group's **Roles** page.
- **AssetId**: Found in a catalog item's URL: `https://www.roblox.com/catalog/18966788838/Light-Crown` → `18966788838`
- **GamePassId**: Found in a pass's URL: `https://www.roblox.com/game-pass/5411126/VIP` → `5411126`
- **SubscriptionId**: Found on your experience's **Subscriptions** page in Creator Hub (e.g. `"EXP-1234567890"`).

---

## Assigning Roles

### User Roles (`userRoles`)

Assign roles directly to specific players by **UserId** or **Username**. By default, `game.PrivateServerOwnerId` is included in `vip` so private server owners receive VIP perks automatically.

```luau
userRoles = {
	vip = {
		156, -- Assign by UserId
		"Roblox", -- Assign by Username
		game.PrivateServerOwnerId, -- Grants "vip" to Private Server Owners
	},
	mod = {},
	admin = {},
	superadmin = {},
	creator = {},
},
```

:::tip Private Server DataStore Isolation
When `game.PrivateServerOwnerId` is listed under any role in `userRoles` (and the private server owner is not the game creator), Kohl's Admin automatically isolates the private server's DataStore scope so changes made in that private server never affect public servers!
:::

### Group Roles (`groupRoles`)

Grant one or more roles to members of a Roblox Group based on their group rank (`0`–`255`).
- Set `exactRank = true` to require the player's group rank to equal `rank` exactly.
- Set `exactRank = false` (or omit it) to grant the roles to anyone with a group rank **greater than or equal to** `rank`.

```luau
groupRoles = {
	[3403354] = {
		{ rank = 250, roles = { "superadmin" }, exactRank = false },
		{ rank = 200, roles = { "admin", "vip" }, exactRank = false },
		{ rank = 100, roles = { "mod" }, exactRank = true },
	},
},
```

### GamePass, Asset & Subscription Roles

Grant roles automatically when a player owns a GamePass, catalog Asset, or active Subscription. When a player purchases a configured GamePass in-game, Kohl's Admin immediately grants the role(s) and notifies them without requiring a rejoin.

```luau
-- 📦 Catalog Assets (hats, shirts, badges, etc.)
assetRoles = {
	[18966788838] = { "vip" },
},

-- 💵 GamePasses
gamepassRoles = {
	[5411126] = { "vip", "mod" },
},

-- 💳 Subscriptions
subscriptionRoles = {
	["EXP-1234567890"] = { "vip" },
},
```

### Friend Roles & Free Admin

- **`friendRoles`**: Grants the listed role(s) to anyone who is friends with the experience creator (or group owner).
- **`freeAdmin`**: Grants the listed role(s) to **every player** who joins the server.

```luau
-- 👥 Friends of the game/group creator
friendRoles = {
	"vip",
},

-- 👑 Every player in the game
freeAdmin = {
	-- "vip",
	-- "mod",
},
```

---

## Pre-Configured Bans (`bans`)

In addition to banning players in-game (which saves to DataStores when the caller has the `banasync` permission), you can hardcode bans in `Settings`:

- **Key**: Stringified `UserId` (e.g. `["123456"]`).
- **Value**: `{ Username?, Reason?, Duration, BannedByUserId? }`
  - `Duration = -1`: Permanent ban
  - `Duration = 0`: Current server session ban
  - `Duration > 0`: Temporary ban until the specified UTC Unix timestamp (in seconds)

```luau
bans = {
	["2"] = { "John Doe", "Server rule violation", 0, 44391621 }, -- Server ban
	["3"] = { "Jane Doe", "Cooling off", 1893456000, 44391621 }, -- Temp ban (UTC timestamp)
	["5"] = { nil, "Exploiting", -1, 44391621 }, -- Permanent ban (Username auto-fetched if nil)
},
```

---

## System Settings Reference

```luau
-- 📢 INITIAL ANNOUNCEMENTS & NOTIFICATIONS (shown to players on join)
announcements = {
	-- {
	-- 	From = "_K", -- UserId or "_K"
	-- 	Duration = 30, -- seconds (0 = pinned until dismissed)
	-- 	Text = "Welcome to our experience!",
	-- },
},

notifications = {
	-- {
	-- 	From = "_K", -- UserId, "_K", or "System"
	-- 	Duration = 30, -- seconds (0 = no auto-hide)
	-- 	Text = "Check out the new update!",
	-- },
},

-- 🔧 SYSTEM SETTINGS
prefix = { ";", ":" }, -- Command trigger character(s)
splitKey = " ", -- Command and argument separator

commandBarRank = 0, -- Minimum role rank to use the Command Bar (false = disable)
dashboardRank = 0, -- Minimum role rank to open the Dashboard (false = disable)
commandsButtonRank = 0, -- Minimum role rank to show the Topbar Commands button (false = disable)
dashboardButtonRank = 1, -- Minimum role rank to show the Topbar Dashboard button (false = disable)
joinNotificationRank = 1, -- Minimum role rank to show the role notification on join (false = disable)

onlyShowUsableCommands = true, -- Hide commands the player cannot use or purchase
chatCommandsNotification = true, -- Notify players about VIP chat commands on join (40% creator commission)
welcomeBadgeId = 0, -- Award this BadgeId to players when they join (0 = disabled)

addToCharts = true, -- List this experience on Kohl's Admin Charts (requires Allow HTTP Requests)
vip = true, -- Enable global VIP features & monetization (required if addToCharts is true)

chatCommands = true, -- Allow running commands via Roblox Chat
commandRequests = true, -- Prompt same/higher rank players for permission when targeted
getKohlsAdminPopup = true, -- Show the "Get Kohl's Admin" popup when prompted
wrongPrefixWarning = true, -- Warn players in chat if they type a known command with the wrong prefix
saveLogs = true, -- Save and sync command logs across servers via DataStore
saveChatLogs = false, -- Save and sync chat logs across servers via DataStore
saveLogsForAllRoles = false, -- Save command logs for all roles instead of only restricted (non-public) roles
useSavedSettings = true, -- Apply in-game saved settings from DataStore on top of module defaults

theme = "Default", -- Initial UI theme name (from Config > Themes)
changeThemeAuthority = "Client", -- Who can change themes: "Client", "Server", or "Studio"
```

### Per-Role Command Overrides (`commands`)

You can explicitly enable (`true`) or disable (`false`) individual commands by name or alias for any role without changing its command groups:

```luau
commands = {
	everyone = {
		help = true,
		rejoin = true,
		shutdown = false,
	},
	vip = {},
	mod = {
		ban = false, -- Prevent moderators from using the ban command
	},
	admin = {},
	superadmin = {},
	creator = {},
},
```

---

## Customizing & Creating Roles (`roles`)

The `roles` table defines every role in your experience. Roles placed later in the array have a higher authority rank (`_rank = index - 1`).

:::warning Default Role Keys
Do not rename the `_key` of the built-in roles (`everyone`, `vip`, `mod`, `admin`, `superadmin`, `creator`), as internal systems and legacy migrations reference them. You can freely change their `name`, `color`, `groups`, `limits`, and `permissions`, or insert new custom roles anywhere in the array!
:::

### Creating a Custom Role

To add a custom role (for example, a `helper` role ranked between `vip` and `mod`), insert a new table at the desired position in `roles`:

```luau
roles = {
	{ -- Rank 0: Default Role
		_key = "everyone",
		name = "Player",
		color = "#aaa",
		groups = { "utility" },
		limits = { cooldown = 4, commands = 4, targets = 1 },
		permissions = {
			admin = false,
			banasync = false,
			saveRoles = false,
			settings = false,
			serverlogs = false,
		},
		onlyTargetSelf = true,
	},

	{ -- Rank 1: VIP Role
		_key = "vip",
		name = "VIP",
		color = "#0ff",
		groups = { "vip" },
		limits = { cooldown = 4, commands = 16, targets = 1 },
		permissions = {},
		onlyTargetSelf = true,
	},

	{ -- Rank 2: Custom Helper Role (higher than VIP, lower than Moderator)
		_key = "helper",
		name = "Helper",
		color = "#080",
		groups = { "general", "vip" },
		limits = { cooldown = 4, commands = 24, targets = 5 },
		permissions = { serverlogs = true },
	},

	{ -- Rank 3: Moderator Role
		_key = "mod",
		name = "Moderator",
		color = "#0f0",
		groups = { "moderation", "general", "environment", "fun", "vip" },
		limits = { cooldown = 4, commands = 32, targets = math.huge },
		permissions = { serverlogs = true },
	},
	-- ... admin, superadmin, [math.huge] = creator
}
```

### Role Definition Reference

| Field | Type | Description |
| :--- | :--- | :--- |
| `_key` | `string` | Unique identifier used in `userRoles`, `groupRoles`, `gamepassRoles`, and `@role` target selectors. |
| `name` | `string` | Human-readable display name shown in the UI, notifications, and member lists. |
| `color` | `string` | Hex color string (e.g. `"#0ff"` or `"#00ffff"`) used for badges and rich-text notifications. |
| `groups` | `{ string }?` | Command groups granted to this role: `"utility"`, `"vip"`, `"general"`, `"environment"`, `"fun"`, `"moderation"`, `"administration"`, `"superadmin"`, `"creator"`. |
| `commands` | `{ [string]: boolean }?` | Per-command overrides (`true` to allow, `false` to deny) for this role. |
| `limits` | `{ cooldown: number, commands: number, targets: number }?` | Rate and target limits: max `commands` allowed per `cooldown` seconds, and max `targets` per command execution. |
| `onlyTargetSelf` | `boolean?` | When `true`, players with only this role can only target themselves (`me`). Sets `permissions.targetOthers = false`. |
| `permissions` | `{ [string]: boolean }?` | Special system permissions (see table below). |
| `gamepass` / `asset` / `subscription` | `number \| string?` | Optional shorthand to attach a single purchasable ID directly to the role definition. |

### Role Permissions (`permissions`)

| Permission Key | Description |
| :--- | :--- |
| `admin` | **Full Authority (`⚠️`)**: Bypasses all command, argument, and target permission checks. |
| `banasync` | **Permanent Bans (`⚠️`)**: Allows banning and unbanning users permanently or with custom durations saved to DataStores across all servers. Without `banasync`, bans only last for the current server session (`Duration = 0`). |
| `saveRoles` | **Permanent Roles (`⚠️`)**: Allows permanently assigning or removing lower-ranked roles across servers via DataStores. |
| `settings` | **Saved Settings (`⚠️`)**: Allows modifying global admin settings in the Dashboard Settings tab and syncing them across servers. |
| `serverlogs` | **Server Logs**: Allows viewing server-side command, chat, join/leave, damage/death, and purchase logs in the Dashboard Logs tab. |
| `targetOthers` | **Target Other Players**: Automatically set to `not onlyTargetSelf` if omitted. Controls whether the role can target players other than `me`. |
