<div align="right">
<a href="https://admin.kohl.gg"><picture><source media="(prefers-color-scheme: dark)" srcset=".luaudocs/public/logo-load-dark.svg"><img align="left" src=".luaudocs/public/logo-load.svg" width="128" alt="Kohl's Admin"></picture></a>
<a href="https://admin.kohl.gg"><picture><source media="(prefers-color-scheme: dark)" srcset=".luaudocs/public/link-docs-dark.svg"><img alt="Docs" src=".luaudocs/public/link-docs.svg"></picture></a>
<a href="https://github.com/kohls-admin/kohls-admin/releases"><picture><source media="(prefers-color-scheme: dark)" srcset=".luaudocs/public/link-download-dark.svg"><img alt="Download" src=".luaudocs/public/link-download.svg"></picture></a>
<a href="https://create.roblox.com/store/asset/172732271"><picture><source media="(prefers-color-scheme: dark)" srcset=".luaudocs/public/link-creator-dark.svg"><img alt="Get it on the Creator Marketplace" src=".luaudocs/public/link-creator.svg"></picture></a>
</div>
<br/>
<br/>
<br/>
<br/>

<div align="center">

# Embrace creativity, not chaos.

_Kohl's Admin is an administration, moderation, and command suite for Roblox built on [Flux](https://flux.kohl.gg) and [Z](https://github.com/kohltastrophe/Z). Taken by 30M+ creators since 2010 and running across 100K+ active games today._

[![CI](https://img.shields.io/github/actions/workflow/status/kohls-admin/kohls-admin/lint.yml?style=for-the-badge)](https://github.com/kohls-admin/kohls-admin/actions/workflows/lint.yml) [![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/kohls-admin/kohls-admin/badges/coverage.json&style=for-the-badge)](https://github.com/kohls-admin/kohls-admin/actions/workflows/lint.yml) [![License](https://img.shields.io/github/license/kohls-admin/kohls-admin?style=for-the-badge)](LICENSE.txt) ![GitHub Release](https://img.shields.io/github/v/release/kohls-admin/kohls-admin?style=for-the-badge)

</div>

---

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _K = require(ReplicatedStorage.Packages.KohlsAdmin)

_K.initialize({
	prefix = { ";", ":" },
	userRoles = {
		admin = { 12345678 },
	},
})
```

Drop the loader into `ServerScriptService` or require the package from code to register 200+ commands, role checks, and the in-game dashboard. Commands run from chat or the command bar with live argument suggestions, type validation, and target guards verified on the server.

---

## Batteries Included

Kohl's Admin includes the tools you need to run and moderate a Roblox experience:

- **200+ Built-in Commands:** Run [commands](https://admin.kohl.gg/guide/getting-started/using_commands) from chat or the command bar with live autocomplete, inline validation, and target selectors (`@role`, `%team`, `$friends`).
- **Role-Based Permissions:** Assign combinable [roles](https://admin.kohl.gg/guide/getting-started/configuration) by UserId, Group rank, GamePass, Asset, or Subscription with cross-server `DataStore` sync.
- **In-Game Dashboard:** Manage commands, bans, members, active servers, logs, and [themes](https://admin.kohl.gg/guide/themes_and_ui) from a [single window](https://admin.kohl.gg/guide/getting-started/using_uis) across PC, mobile, console, and VR.
- **Chat Integration:** Registers native `TextChatService` slash commands with server rate limits and per-viewer broadcast filtering.
- **Monetization & Discovery:** Sell custom GamePass roles, earn up to 40% commission on [global VIP and UGC sales](https://admin.kohl.gg/donate), and list your game on Kohl's Admin Charts.
- **Addons & Hooks:** Register [custom commands](https://admin.kohl.gg/guide/custom_commands), [custom argument types](https://admin.kohl.gg/guide/custom_types), and lifecycle hooks through shared, server, or client [addon modules](https://admin.kohl.gg/guide/addons).

## Installation

Install the [Official Creator Store Loader](https://create.roblox.com/store/asset/172732271), download `KohlsAdmin.rbxm` from [Releases](https://github.com/kohls-admin/kohls-admin/releases), or add `kohltastrophe/kohls-admin` via Wally.

Read the **[Installation Guide](https://admin.kohl.gg/guide/getting-started/installation)** and **[Configuration Guide](https://admin.kohl.gg/guide/getting-started/configuration)** for full setup details.

## Contributing

Read the [Contributor Guidelines](CONTRIBUTING.md) for local Rojo and Dev Container setup, architecture notes, and pull request workflow.

- **In-Game Credits:** Contributors are listed in the built-in `credits` command and `About` tab.
- **Early Access:** Preview upcoming releases and join contributor channels in the community Discord.
- **In-Game Perks:** Receive contributor perks across participating games running Kohl's Admin.
- **Bounties:** Sustained engineering contributions are eligible for monetary compensation. See [Compensation](CONTRIBUTING.md#compensation) for details.

## Support

Report bugs or request features through [GitHub Issues](https://github.com/kohls-admin/kohls-admin/issues/new/choose), or join the community on [Discord](https://discord.gg/kohl).

## License

Kohl's Admin is released under the [MIT License](LICENSE.txt).
