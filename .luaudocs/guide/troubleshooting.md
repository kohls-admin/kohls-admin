---
sidebar_position: 7
---

# Troubleshooting

This guide covers solutions to the most common setup, permission, DataStore, and customization issues in Kohl's Admin.

---

## Sandboxed Model / `"lacking capability"` Error

### Symptom
When starting a test session in Roblox Studio, the Output window displays an error containing:
```text
[KOHL'S ADMIN PERMISSIONS FIX]
Select the Kohl's Admin folder in the Explorer and run this script in the command bar:
```
or an error mentioning `lacking capability` / `Sandboxed`.

### Cause
Roblox Studio's model sandboxing feature marked the inserted `Kohl's Admin` folder or its descendant scripts with `Sandboxed = true`, which restricts standard script capabilities.

### Solution
1. Select the **`Kohl's Admin`** folder in the Studio **Explorer** window.
2. In the **Properties** window, uncheck **`Sandboxed`** (or run the following one-liner in the Studio **Command Bar** while `Kohl's Admin` is selected):
   ```luau
   local obj = game.Selection:Get()[1] for _, v in obj:GetDescendants() do v.Sandboxed = false end while obj and obj ~= game do obj.Sandboxed = false obj = obj.Parent end
   ```

---

## `"DataStores failed to load!"` / Bans, Roles, or Settings Not Saving

### Symptom
A red error notification appears on join stating **`DataStores failed to load!`** (or **`Global save data failed to load`**), or permanent bans (`;ban`), saved roles (`;role`), and in-game settings reset when the server restarts.

### Cause & Solutions
1. **Experience Not Published**: Roblox DataStores require the place to be published to Roblox. Go to `File > Publish to Roblox` in Roblox Studio.
2. **Studio API Access Disabled**: When testing in Roblox Studio, open `File > Game Settings > Security` and enable **Enable Studio Access to API Services**, then click **Save**.
3. **Missing Role Permissions**:
   - To save bans across servers, the admin's role must have `permissions = { banasync = true }` (granted to `admin` and above by default). Moderators without `banasync` can only issue single-server session bans (`Duration = 0`).
   - To permanently save roles across servers, the admin's role must have `permissions = { saveRoles = true }` (`superadmin` and above by default).
   - To save settings across servers, the admin's role must have `permissions = { settings = true }` (`superadmin` and above by default), and `useSavedSettings` must be `true`.

---

## Kohl's Admin Games Hub / Charts Warning (`HTTP Requests are disabled`)

### Symptom
Admins receive a notification on join:
> *Your game is unable to participate in the Kohl's Admin Games Hub because HTTP Requests are disabled in your game settings.*

### Cause & Solutions
- **To participate in Kohl's Admin Charts (Recommended)**: Open `File > Game Settings > Security` in Roblox Studio, enable **Allow HTTP Requests**, and click **Save**.
- **To opt out of Charts**: Open `Kohl's Admin > Config > Settings` and set `addToCharts = false`.

---

## VIP or GamePass Purchases Failing in Game

### Symptom
Clicking a VIP command prompt or purchasing an item in the **Market** tab fails with a third-party sales error, or custom `gamepassRoles` are not granted.

### Cause & Solutions
- **For Global VIP & UGC Perks**: Open `File > Game Settings > Security` and enable **Allow Third Party Sales** (or set `vip = false` and `addToCharts = false` in `Config > Settings` if you wish to disable global VIP features).
- **For Custom `gamepassRoles`**: Verify that you used the **GamePassId** (from `roblox.com/game-pass/<ID>/...` or Creator Hub > Monetization > Passes) and **not** a Developer Product ID or Decal ID, and that the role `_key` string in `gamepassRoles` matches a valid role in `Settings.roles`.

---

## Commands Not Working in Chat

### Symptom
Typing `;fly` or `:cmds` in the Roblox chat sends the message without running the command, or does nothing.

### Checklist
1. **Check Your Prefix**: By default, prefixes are `;` and `:`. If an admin changed the server prefix in **Dashboard > Settings** or you set a custom personal prefix, check the **Settings** or **Commands** window via the topbar button to see the active prefix.
2. **Verify `chatCommands` is Enabled**: In `Kohl's Admin > Config > Settings` (and in-game **Dashboard > Settings**), ensure `chatCommands = true`.
3. **Check Custom Chat Systems**: Kohl's Admin supports both `TextChatService` and legacy chat out of the box. If your experience uses a fully custom chat system that disables `TextChatService.SendingMessage` and does not fire `Player.Chatted`, use the **Command Bar** (`;` key or long-press the topbar icon) or fire commands via [`_K.Process.runCommands`](/api/Process#runcommands).

---

## Custom Commands Not Showing in Autocomplete or Failing to Run

### Symptom
A custom command registered in `Config > Addons` either does not appear in the client Command Bar / Commands UI, or runs `runClient` without ever triggering `run` on the server.

### Cause & Solutions
1. **Addon Named with `"Server"` or `"Client"`**:
   - If your `ModuleScript` name contains `"Server"` (e.g. `CommandsServer`), it **only** runs on the server—the client never registers the command, so autocomplete and client validation reject it!
   - If your `ModuleScript` name contains `"Client"` (e.g. `CommandsClient`), the server never registers the command, so server execution (`run`) never happens!
   - **Fix**: Rename the `ModuleScript` so it does **not** contain `"Server"` or `"Client"` (e.g. `CustomCommands`). See [Addons & Hooks: Execution Contexts](/guide/addons#addon-execution-contexts-shared-server-client).
2. **Invalid Argument Type Name**:
   - Check the Studio Output window for `Invalid argument type ..., did it fail to register?`. Ensure argument types match the exact casing in [Built-In Argument Types](/guide/custom_commands#built-in-argument-types) (e.g. `"rawString"`, `"userIds"`, `"timeSimple"`, `"Enum.Material"`).
3. **Missing Command Group Access**:
   - Ensure the `group` field on your command matches one of the groups assigned to your role (`"Utility"`, `"VIP"`, `"General"`, `"Environment"`, `"Fun"`, `"Moderation"`, `"Administration"`, `"SuperAdmin"`, `"Creator"`).