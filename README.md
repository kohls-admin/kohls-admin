<div align="right">
    <a href="https://admin.kohl.gg"><picture><source media="(prefers-color-scheme: dark)" srcset=".luaudocs/public/logo-load-dark.svg"><img  alt="Kohl's Admin" src=".luaudocs/public/logo-load.svg" align="left" width="128"></picture></a>
    <a href="https://admin.kohl.gg"><picture><source media="(prefers-color-scheme: dark)" srcset=".luaudocs/public/link-docs-dark.svg"><img alt="Docs" src=".luaudocs/public/link-docs.svg"></picture></a>
    <a href="https://github.com/kohls-admin/kohls-admin/releases"><picture><source media="(prefers-color-scheme: dark)" srcset=".luaudocs/public/link-download-dark.svg"><img alt="Download" src=".luaudocs/public/link-download.svg"></picture></a>
    <a href="https://create.roblox.com/store/asset/172732271"><picture><source media="(prefers-color-scheme: dark)" srcset=".luaudocs/public/link-creator-dark.svg"><img alt="Get it on the Creator Marketplace" src=".luaudocs/public/link-creator.svg"></picture></a>
</div>

<br/>
<br/>
<br/>
<br/>

<div align="center">
    <a href="https://admin.kohl.gg/"><img src="https://img.shields.io/badge/docs-admin.kohl.gg-222"></a>
    <a href="https://discord.gg/kohl"><img src="https://img.shields.io/discord/694630328064671775"></a>
    <a href="https://github.com/kohls-admin/kohls-admin/blob/main/LICENSE.txt"><img src="https://img.shields.io/github/license/kohls-admin/kohls-admin" alt="License"></a>
    <a href="https://github.com/kohls-admin/kohls-admin/graphs/contributors"><img src="https://img.shields.io/github/contributors/kohls-admin/kohls-admin" alt="Contributors"></a>
    <a href="https://github.com/kohls-admin/kohls-admin/issues"><img src="https://img.shields.io/github/issues/kohls-admin/kohls-admin" alt="GitHub issues"></a>
    <br/>
    <a href='https://codespaces.new/kohls-admin/kohls-admin?quickstart=1'><img src='https://github.com/codespaces/badge.svg' alt='Open in GitHub Codespaces' style='max-width: 100%;'></a>
</div>

<br/>
<h1 align="center">Kohl's Admin</h1>
<p align="center">An administration, moderation, and command suite for Roblox built on <a href="https://flux.kohl.gg">Flux</a> and <a href="https://github.com/kohltastrophe/Z">Z</a>. Taken by 30M+ creators since 2010 and running across 100K+ active games today.</p>

## Features

- **200+ Built-in Commands:** Run commands from chat or the command bar with live autocomplete, inline validation, and target selectors (`@role`, `%team`, `$friends`).
- **Role-Based Permissions:** Assign combinable roles by UserId, Group rank, GamePass, Asset, or Subscription with cross-server DataStore sync.
- **In-Game Dashboard:** Manage commands, bans, members, active servers, logs, and themes from a single window across PC, mobile, console, and VR.
- **Chat Integration:** Registers native `TextChatService` slash commands with server rate limits and per-viewer broadcast filtering.
- **Monetization and Discovery:** Sell custom GamePass roles, earn up to 40% commission on global VIP and UGC sales, and list your game on Kohl's Admin Charts.
- **Addons and Hooks:** Register custom commands, argument parsers, and lifecycle hooks through shared, server, or client addon modules.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _K = require(ReplicatedStorage.Packages.KohlsAdmin)

-- initialize with custom prefixes and admin UserIds
_K.initialize({
	prefix = { ";", ":" },
	userRoles = {
		admin = { 12345678 },
	},
})
```

## Installation

Install the [Official Creator Store Loader](https://create.roblox.com/store/asset/172732271), download the standalone `.rbxm` from [GitHub Releases](https://github.com/kohls-admin/kohls-admin/releases), or add `kohltastrophe/kohls-admin` via Wally. See the [Installation Guide](https://admin.kohl.gg/guide/getting-started/installation) and [Configuration Guide](https://admin.kohl.gg/guide/getting-started/configuration) for full setup details.

## Contributing

Read the [Contributor Guidelines](CONTRIBUTING.md) for local Rojo and Dev Container setup, architecture notes, and pull request workflow.

- **In-Game Credits:** Contributors are listed in the built-in `credits` command and `About` tab.
- **Early Access:** Preview upcoming releases and join contributor channels in the community Discord.
- **In-Game Perks:** Receive contributor perks across participating games running Kohl's Admin.
- **Bounties:** Sustained engineering contributions are eligible for monetary compensation. See [Compensation](CONTRIBUTING.md#compensation) for details.

## Support and Issues

Report bugs or request features through [GitHub Issues](https://github.com/kohls-admin/kohls-admin/issues/new/choose), or join the community on [Discord](https://discord.gg/kohl).

## License

This project is licensed under the [MIT License](LICENSE.txt).
