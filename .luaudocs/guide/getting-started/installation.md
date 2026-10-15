---
sidebar_position: 1
---

# Installation

Before using Kohl's Admin, install it in your Roblox experience using the **Official Creator Store Loader Model**, a standalone **GitHub Release (`.rbxm`)**, or **Wally & Rojo**.

:::danger Beware of Impersonators
Always verify that the Creator Store model is published by **[@Scripth](https://www.roblox.com/users/44391621/profile)** (`UserId: 44391621`). Unofficial copies may contain backdoors, malicious scripts, or outdated code.
:::

## Choose an Installation Method

<Tabs>
	<TabItem value="creatorstore" label="Creator Store Model (Recommended)" default>

### 1. Acquire the Official Loader Model

1. Visit the [Kohl's Admin Official Loader](https://create.roblox.com/store/asset/172732271/Kohls-Admin) page on the Roblox Creator Store (or test it live in the [KA Demo Place](https://www.roblox.com/games/2569622788/KA-Demo)).
2. Click **Get Model** to add it to your Roblox inventory.

### 2. Insert into Roblox Studio

1. Open your experience in **Roblox Studio**.
2. Open the **Toolbox** (`View > Toolbox`) and switch to the **Inventory** tab.
3. Click the **Kohl's Admin** model to insert it into your place, and click **OK** if prompted about scripts.
4. Move the **`Kohl's Admin`** folder into **`ServerScriptService`** in the Explorer window (if left in `Workspace`, the loader will automatically move itself to `ServerScriptService` at runtime).

	</TabItem>
	<TabItem value="github" label="GitHub Release (.rbxm)">

### Install from GitHub Releases

If you prefer a self-contained model file or want to pin a specific release version:

1. Download the latest `.rbxm` file from [GitHub Releases](https://github.com/kohls-admin/kohls-admin/releases).
2. Open your experience in **Roblox Studio**.
3. Drag and drop the `.rbxm` file into Studio (or right-click **`ServerScriptService`** in the Explorer and select **Insert from File...**).
4. Ensure the **`Kohl's Admin`** folder is parented to **`ServerScriptService`**.

	</TabItem>
	<TabItem value="wally" label="Wally & Rojo">

### Install via Wally

Kohl's Admin is published to the Wally package registry as `kohltastrophe/kohls-admin`.

1. Add `kohls-admin` to your `wally.toml` dependencies:

```toml
[dependencies]
KohlsAdmin = "kohltastrophe/kohls-admin@0.2.3"
```

2. Run `wally install` to fetch the package.
3. Require the module from a server `Script` in `ServerScriptService` and call `_K.initialize` with either a `Configuration` instance, a settings `ModuleScript`, or a settings table:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _K = require(ReplicatedStorage.Packages.KohlsAdmin)

-- Pass a settings table, a Settings ModuleScript, or a Config Folder/Configuration:
_K.initialize({
	prefix = { ";", ":" },
	userRoles = {
		admin = { 12345678 },
	},
})
```

	</TabItem>
</Tabs>

## Recommended Studio & Game Settings

To unlock all features of Kohl's Admin—including persistent bans, saved roles, cross-server logs, Charts discovery, and VIP sales—publish your experience (`File > Publish to Roblox`) and configure the following options under **`File > Game Settings > Security`**:

| Setting | Purpose |
| :--- | :--- |
| **Enable Studio Access to API Services** | **Required for DataStores in Studio.** Allows permanent bans (`banasync`), saved roles (`saveRoles`), in-game saved settings (`settings`), reserved servers, and cross-server command/chat logs (`saveLogs`) to persist during Studio testing. |
| **Allow HTTP Requests** | **Required for Kohl's Admin Charts.** Allows your experience to participate in the [Kohl's Admin Charts](https://www.roblox.com/games/17873329124/Kohls-Admin-Charts) discovery hub for free player traffic when `addToCharts = true`. |
| **Allow Third Party Sales** | **Required for Global VIP & Donations.** Allows players to purchase global VIP perks and UGC items in your experience when `vip = true` (earning the game creator a **40% commission** on every sale). |

## Loader Attributes (`Config`)

When you select **`Kohl's Admin > Config`** in the Explorer, you will find two boolean attributes in the **Properties** window (under **Attributes**):

- **`AutoUpdate`** (`boolean`, default `true`): When enabled, the loader automatically fetches the latest `MainModule` release from Roblox on server startup and falls back to a bundled local module if the network request fails. Disable this only if you are bundling a custom fork of `MainModule` inside `Loader`.
- **`Legacy`** (`boolean`, default `false`): When enabled, switches to the legacy *Kohl's Admin Infinite* loader using `Config > Legacy > Settings`. Leave this **`false`** to use the modern Kohl's Admin system (which also automatically migrates settings and commands from `Config > Legacy`).

:::tip Studio Sandboxed Models
If Roblox Studio inserts the model with the experimental **`Sandboxed`** property enabled on the folder or scripts, you may see a `[KOHL'S ADMIN PERMISSIONS FIX]` message in the Output window. See [Troubleshooting: Sandboxed / Lacking Capability Error](/guide/troubleshooting#sandboxed-model-lacking-capability-error) for a one-line fix.
:::

## Verify Installation

1. Press **Play** (`F5`) in Roblox Studio to start a test session.
2. As the creator of the experience, you are automatically granted the **`creator`** role (highest authority).
3. Press `;` on your keyboard to open the **Command Bar**, or click the **Kohl's Admin** icon in the topbar to open the **Dashboard**.
4. Next, head to the [Configuration Guide](/guide/getting-started/configuration) to set up your roles, admins, and game settings!
