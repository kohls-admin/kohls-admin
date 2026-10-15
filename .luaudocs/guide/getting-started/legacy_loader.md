---
sidebar_position: 5
---

# Legacy Loader & Migration

Kohl's Admin includes built-in support for experiences upgrading from **Kohl's Admin Infinite (KAI)**—both through **automatic migration** into the modern loader and an optional **Legacy Loader** mode.

<Tabs>
	<TabItem value="new" label="Modern Loader (Default)" default>
		The modern Kohl's Admin loader receives all new features, UI updates, security hardening, and performance optimizations. It **automatically imports** your existing settings, bans, ranks, and custom commands from `Config > Legacy` and migrates saved KAI DataStore entries!
	</TabItem>
	<TabItem value="legacy" label="Legacy Loader (KAI)">
		The Legacy Loader runs the classic *Kohl's Admin Infinite* interface and script engine. It no longer receives new content updates, but remains available for experiences that require the classic UI.
	</TabItem>
</Tabs>

---

## Automatic Migration to the Modern Loader

When you keep the **`Legacy`** attribute set to **`false`** on `Kohl's Admin > Config`, the built-in Legacy compatibility addon (`src/Shared/DefaultAddons/Legacy.luau`) and DataStore migrator (`src/Shared/Data/Migrate/KAI.luau`) automatically bridge your old configuration:

1. **Legacy Role Commands**: Registers classic role-granting commands for every default role:
   - Permanent (requires `saveRoles` permission): `;vip`, `;mod`, `;admin`, `;superadmin`, `;creator`
   - Temporary (current server session): `;tempvip`, `;tempmod`, `;tempadmin`, `;tempsuperadmin`
   - Removal: `;unvip`, `;unmod`, `;unadmin`, `;unsuperadmin`
2. **Legacy `Settings` Import**: Automatically reads `Config > Legacy > Settings` and imports:
   - `Banned` users (as server bans)
   - `Owners`, `SuperAdmins`, `Admins`, `Mods`, and `VIP` user lists
   - `GroupAdmin` rank mappings and `VIPAdmin` GamePass/Asset mappings
   - `AdminCredit`, `CommandBar`, `JoinMessage`, `PublicLogs`, `Prefix`, `FreeAdmin`, and `Permissions`
3. **Legacy `Custom_Commands` Import**: Automatically converts command definitions in `Config > Legacy > Custom_Commands` and registers them in the modern [`Registry`](/api/Registry).
4. **Saved DataStore Migration**: Automatically migrates saved bans and admin ranks from classic `"KAI"` DataStore keys into the modern DataStore format on first server start.

---

## Switching Between Modern and Legacy Loaders

To switch loaders in Roblox Studio:

1. Expand the **`Kohl's Admin`** folder in the **Explorer** window.
2. Select **`Config`**.
3. In the **Properties** window, scroll down to the **Attributes** section:
   - Set **`Legacy`** to **`true`** (checked) to use the **Legacy Loader**.
   - Set **`Legacy`** to **`false`** (unchecked) to use the **Modern Loader**.

---

## Configuring the Legacy Loader (`Config > Legacy > Settings`)

If you enable `Legacy = true` (or maintain your config inside `Config > Legacy > Settings`), below is the reference for the classic settings script.

### Hierarchy of Legacy Admin Powers

```text
0   Player          Default player rank
1   VIP             Can use non-abusive commands only on self
2   Moderator       Can kick, mute, & use most commands
3   Administrator   Can ban, crash, & set Moderators/VIP
4   SuperAdmin      Can grant permanent powers & shutdown the game
5   Owner           Can set SuperAdmins & use all commands
6   Game Creator    Can set Owners & use all commands
```

### Admin Lists & Bans

Add Usernames or UserIds to the corresponding tables in `Config > Legacy > Settings`:

```luau
local Owners = { "Roblox", 1234567 } -- Can set SuperAdmins, & use all the commands
local SuperAdmins = {} -- Can set permanent admins, & shutdown the game
local Admins = {} -- Can ban, crash, & set Moderators/VIP
local Mods = {} -- Can kick, mute, & use most commands
local VIP = {} -- Can use nonabusive commands only on self
local Banned = { "someoneyoudislike", 9876543 } -- Blocked from joining the server
```

### Legacy Basic & Style Settings

```luau
-- Style Options
Flat = true, -- Enables Flat theme / Disables Aero theme
ForcedColor = false, -- Forces everyone to have set color & transparency
Color = Color3.new(0, 0, 0), -- Changes the Color of the user interface
ColorTransparency = 0.75, -- Changes the Transparency of the user interface
Chat = false, -- Enables the custom chat
BubbleChat = false, -- Enables the custom bubble chat

-- Basic Settings
AdminCredit = true, -- Enables the credit GUI in the bottom right
AutoClean = false, -- Enables automatic cleaning of hats & tools in the Workspace
AutoCleanDelay = 60, -- The delay between each AutoClean routine
CommandBar = true, -- Enables the Command Bar | GLOBAL KEYBIND: \
FunCommands = true, -- Enables fun yet unnecessary commands
FreeAdmin = false, -- Set to 1-5 to grant admin powers to all, otherwise set to false
JoinMessage = true, -- Shows an admin message on join with the prefix and your current rank
PublicLogs = false, -- Allows all users to see the command & chat logs
Prefix = ";", -- Character to begin a command
```

### Group Admin & VIP Perks

```luau
GroupAdmin = {
	-- [GROUP_ID] = { [RANK] = ADMIN_POWER };
	[12345] = { [254] = 4, [253] = 3 },
},

VIPAdmin = {
	-- Negative item_id (-12345) indicates a GamePass
	-- Positive item_id (12345) indicates a catalog asset (shirt, pants, hat, etc.)
	[-12345] = 3,
	[12345] = 3,
},
```

### Command Limits & Permissions

```luau
-- [ADMIN_POWER] = { COMMAND_LIMIT, COOLDOWN_SECONDS }
CommandLimits = {
	[0] = { 1, 10 },
	[1] = { 16, 5 },
	[2] = { 32, 1 },
	[3] = { 64, 1 },
	[4] = { 128, 1 },
	[5] = { math.huge, 0 },
	[6] = { math.huge, 0 },
	[7] = { math.huge, 0 },
},

Permissions = {
	-- fly = 0; -- Uncomment to allow everyone (rank 0+) to use fly
},
```

---

## Legacy Loader's UIs

When running with `Legacy = true`, the classic system provides 6 window UIs opened via chat or command bar commands (and closed/minimized via the `X` and `-` buttons):

| Command | Window Description |
| :--- | :--- |
| `;help` | Displays the command prefix, basic usage instructions, developer configuration tips, and community links. |
| `;cmds` | Lists available commands and their required rank. |
| `;admins` | Lists online and saved admins with their rank. Use `;vip`, `;mod`, `;admin`, `;superadmin` (or prefix with `temp`, e.g. `;tempmod`) to rank players, and `;unvip`, `;unmod`, etc. to unrank. |
| `;bans` | Lists banned users and their ban duration. Run `;unban <player>` to unban. |
| `;tools` | Lists tools stored in `ServerStorage`. Run `;give <player> <tool>` to equip them. |
| `;settings` | Displays in-game settings (editable by `SuperAdmin` and above). |
| `;credit` | Displays credits, the official model link, and donation perks. |
