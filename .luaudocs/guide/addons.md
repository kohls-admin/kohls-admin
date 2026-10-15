---
sidebar_position: 4
---

# Addons & Hooks

Addons are the primary way to extend Kohl's Admin with custom logic, server integrations, event listeners, custom commands, custom argument types, and custom UI windows.

## How Addons Are Loaded

Every addon is a `ModuleScript` that returns a single initializer function accepting the root [`_K` (`MainModule`)](/api/MainModule) table:

```luau
return function(_K)
	-- Your addon code here!
end
```

Kohl's Admin discovers addons from two places:

1. **`Kohl's Admin > Config > Addons`**: Any `ModuleScript` inside the `Addons` folder (including inside nested subfolders) is automatically loaded.
2. **`CollectionService` Tag (`"Kohl's Admin Addon"`)**: You can keep your addon `ModuleScript`s anywhere in your project (such as `ServerStorage` or `ReplicatedStorage` in a Rojo project) and tag them with **`"Kohl's Admin Addon"`** (`_K._addonTag`).

---

## Addon Execution Contexts (Shared, Server, Client)

Kohl's Admin determines where an addon runs based on its **`ModuleScript.Name`**:

| Naming Pattern | Execution Context | Replication Behavior | Best Used For |
| :--- | :--- | :--- | :--- |
| **`MyAddon`** *(no `"Server"` or `"Client"` in name)* | **Shared (Server + Client)** | Parented to `ReplicatedStorage["Kohl's Admin Source"].Addons` and required on both Server and Client. | Registering [Custom Commands](/guide/custom_commands) and [Custom Argument Types](/guide/custom_types). |
| **`MyAddonServer`** *(contains `"Server"`)* | **Server Only** | Moved into `ServerStorage._KServerAddons` **before** the package replicates to clients. Clients cannot view or decompile its bytecode. | Secret webhooks, DataStore/MemoryStore integrations, server-only anti-cheat, and server hooks. |
| **`MyAddonClient`** *(contains `"Client"`)* | **Client Only** | Replicated to clients and required only on each player's client after `_K` finishes initializing. | Custom client UI windows ([`_K.UI`](/api/UI)), custom keybinds, and client-only visual effects. |

:::tip Checking Context Inside a Shared Addon
Inside a shared addon, you can branch on `_K.IsServer`, `_K.IsClient`, and `_K.IsStudio` whenever you need context-specific setup alongside shared command registrations.
:::

---

## Lifecycle & Event Hooks (`_K.Hook`)

[`_K.Hook`](/api/Hook) exposes [`Signal`](/api/Signal) objects that allow addons to observe or intercept commands, moderation actions, role changes, logs, and DataStore synchronization.

```luau
-- Example: MyAddonServer.luau
return function(_K)
	-- Log every command execution to a custom analytics service
	_K.Hook.postCommand:Connect(function(command)
		print(`Player {command.from} ran ;{command.alias} with text: {command.text}`)
	end)

	-- React whenever a user is banned
	_K.Hook.ban:Connect(function(userId, banData)
		local username, reason, duration, fromUserId = unpack(banData)
		print(`User {username} ({userId}) was banned by {fromUserId}: {reason}`)
	end)
end
```

### Available Hooks Reference

| Hook Signal | Fired On | Callback Arguments | Description |
| :--- | :--- | :--- | :--- |
| `_K.Hook.init` | Server & Client | `()` | Fires once Kohl's Admin has finished initializing. |
| `_K.Hook.commandRegistered` | Server & Client | `(commandObject: CommandDefinition)` | Fires whenever a command is registered via `Registry.registerCommand`. |
| `_K.Hook.runPreparedCommands` | Server & Client | `(from: number, commands: { Command }, rawText: string)` | Fires right before a batch of validated commands is executed. |
| `_K.Hook.preCommand` | Server & Client | `(command: Command)` | Fires immediately before an individual `Command:run()` executes. |
| `_K.Hook.postCommand` | Server & Client | `(command: Command)` | Fires immediately after an individual `Command:run()` finishes. |
| `_K.Hook.log` | Server & Client | `(logEntry: Log)` | Fires whenever a new log entry is recorded via `_K.log`. |
| `_K.Hook.ban` | Server | `(key: string, banSave: table)` | Fires when a user is banned via `_K.Auth.banUsers`. |
| `_K.Hook.unban` | Server | `(key: string, banSave: table)` | Fires when a user is unbanned via `_K.Auth.unbanUsers`. |
| `_K.Hook.roleAdded` | Server & Client | `(userId: number, role: Role)` | Fires when a role is granted to a user via `_K.Auth.userRoleAdd`. |
| `_K.Hook.roleRemoved` | Server & Client | `(userId: number, role: Role)` | Fires when a role is removed from a user via `_K.Auth.userRoleRemove`. |
| `_K.Hook.authChanged` | Client | `()` | Fires on the client when the local player's roles or permissions update. |
| `_K.Hook.initDataStore` | Server | `()` | Fires once the server DataStore connection initializes. |
| `_K.Hook.preSyncBans` / `postSyncBans` | Server | `()` | Fires before and after syncing the ban table with DataStores. |
| `_K.Hook.preSyncMain` / `postSyncMain` | Server | `()` | Fires before and after syncing members and settings with DataStores. |
| `_K.Hook.preSyncLogs` / `postSyncLogs` | Server | `()` | Fires before and after syncing logs with DataStores. |

---

## Core `_K` APIs for Addons

### 1. Authorization & Role Management (`_K.Auth`)

Use [`_K.Auth`](/api/Auth) to check player permissions or programmatically grant/revoke roles and bans:

```luau
-- Querying rank, roles, and permissions:
local rank, highestRole = _K.Auth.getRank(player.UserId)
local isMod = _K.Auth.hasRole(player.UserId, "mod")
local canBanAsync = _K.Auth.hasPermission(player.UserId, "banasync")
local canUseFly = _K.Auth.hasCommand(player.UserId, "fly")

-- Granting and removing roles on the server:
-- userRoleAdd(userId, roleId, persistToDataStore?)
_K.Auth.userRoleAdd(player.UserId, "vip", false) -- Temporary (current server)
_K.Auth.userRoleAdd(player.UserId, "mod", true)  -- Permanent (saved to DataStore)
_K.Auth.userRoleRemove(player.UserId, "vip")

-- Banning and unbanning users on the server:
-- duration: 0 = server ban, -1 = permanent ban, >0 = seconds duration (requires banasync if fromUserId is provided)
_K.Auth.banUsers({ targetUserId }, "Exploiting", -1, adminUserId)
_K.Auth.unbanUsers({ targetUserId }, adminUserId, true)
```

### 2. Running Commands Programmatically (`_K.Process`)

Use [`_K.Process.runCommands`](/api/Process#runcommands) to execute any command string on behalf of a `UserId` (or `nil` to run with `creator` authority):

```luau
-- Run as a specific player:
_K.Process.runCommands(_K, player.UserId, ";fly me ;sparkles me")

-- Run as the game creator (bypasses rank restrictions) without logging:
_K.Process.runCommands(_K, _K.creatorId, `;give {player.Name} Sword`, true)
```

### 3. Notifications, Alerts & Announcements

Send rich-text toast notifications or full-banner announcements from either the server or the client:

```luau
-- Quick alert helper (works on both Server and Client):
_K.alert(player, "You entered a restricted zone!", true) -- true = red error styling + sound

-- Custom toast notification from the Server:
_K.Remote.Notify:Fire(player, {
	Text = "<b>Quest Complete!</b>\nYou earned <b>+100 Coins</b>.",
	From = "_K", -- UserId, "_K", or "System"
	Duration = 8, -- Seconds (0 = stays until closed)
	Sound = "Notification_High",
})

-- Custom toast notification on the Client:
_K.Notify({
	Text = "Settings saved locally!",
	Duration = 5,
})

-- Full-screen banner announcement from the Server to all players:
_K.Remote.Announce:FireAllClients({
	Text = "Server maintenance in 5 minutes!",
	From = _K.creatorId,
	Duration = 30,
})
```

### 4. Logging (`_K.log`)

Record custom entries directly into the Dashboard **Logs** tab using [`_K.log`](/api/MainModule#log):

```luau
-- Log levels: "INFO", "WARN", "ERROR", "DEBUG", "COMMAND", "CHAT", "JOIN", "LEAVE", "KILL", "DEATH", "DAMAGE", "PURCHASE"
_K.log(`{player.Name} unlocked the secret vault.`, "INFO", player.UserId)
```
