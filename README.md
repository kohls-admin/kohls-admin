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
<p align="center"><b>Trusted by 30M+ developers across 100K+ games.</b> Kohl's Admin is a strictly typed administration, moderation, and command suite for Roblox built on <a href="https://flux.kohl.gg">Flux</a> and <a href="https://github.com/kohltastrophe/Z">Z</a>.</p>

## Features

- **200+ built-in commands:** Live syntax and target autocomplete, inline argument validation, command history, multi-command chaining, and shorthand target selectors (`me`, `all`, `others`, `@role`, `%team`, `~random`, `$friends`, `$distance<N`, `$group=ID>=RANK`).
- **Layered role hierarchy:** Role-based access control with combinable roles, per-role command groups, cooldown and target limits, automatic grants for GamePasses, Groups, Badges, Friends, Assets, and Subscriptions, and cross-server `DataStore` persistence (`bans`, `members`, `settings`, `logs`).
- **Reactive Flux dashboard:** Built-in `Commands`, `Bans`, `Members`, `Servers`, `Logs`, `Settings`, `Market`, and `About` tabs plus an in-game Instance Explorer (`;explorer`) and Building Tools (`;btools`), with custom Oklab themes and configurable keybinds across PC, Mobile, Console, and VR.
- **Platform-integrated chat:** Native `TextChatService` and `TextChatCommand` slash-alias registration with server-enforced rate limits and per-viewer broadcast filtering.
- **Monetization and discovery:** Sell custom GamePass, Asset, or Subscription roles, earn up to 40% creator commission on global VIP and scripted UGC purchases inside your experience, and list your place in the cross-game Kohl's Admin Charts hub.
- **Addons, hooks, and custom types:** Extend the system with shared, server-only, or client-only addons, custom commands, custom argument parsers, and `_K.Hook` lifecycle signals.

## Installation

Install the [Official Creator Store Loader](https://create.roblox.com/store/asset/172732271), download the standalone `.rbxm` from [GitHub Releases](https://github.com/kohls-admin/kohls-admin/releases), or add `kohltastrophe/kohls-admin` via Wally:

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

See the [Installation Guide](https://admin.kohl.gg/guide/getting-started/installation) and [Configuration Guide](https://admin.kohl.gg/guide/getting-started/configuration) for full setup details.

## Contributing

Read the [Contributor Guidelines](CONTRIBUTING.md) for local Rojo and Dev Container setup, architecture notes, and pull request workflow.

- **In-game credits:** Contributors are listed in the built-in `credits` command and `About` tab.
- **Inside access:** Preview upcoming releases and join contributor channels in the community Discord.
- **In-game perks:** Receive contributor benefits across participating experiences running Kohl's Admin.
- **Bounties:** Sustained or high-impact engineering contributions are eligible for monetary compensation; see [Compensation](CONTRIBUTING.md#compensation) for details.

## Support and Issues

Report bugs or request features through [GitHub Issues](https://github.com/kohls-admin/kohls-admin/issues/new/choose), or join the community on [Discord](https://discord.gg/kohl).

## License

This project is licensed under the [MIT License](LICENSE.txt).
