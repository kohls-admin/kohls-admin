---
title: "FAQ - Kohl's Admin"
description: "Frequently asked questions about Kohl's Admin: installing the model, donation perks, sponsors, configuring roles, custom commands, and security."
layout: page
sidebar: false
editLink: false
lastUpdated: false
---

<script setup>
import { withBase } from "vitepress";

const DISCORD = "https://discord.gg/kohl";
const GITHUB = "https://github.com/kohls-admin/kohls-admin";
const SPONSORS = "https://github.com/sponsors/kohltastrophe";
const KOFI = "https://ko-fi.com/kohltastrophe";
const TRY = "https://www.roblox.com/join/0e4i1";
const MODEL = "https://create.roblox.com/store/asset/172732271/Kohls-Admin";
</script>

<div class="ka-page">
	<section class="poster band band-first accent-auto">
		<div class="shell">
			<div class="section-head rise">
				<h1 class="section-title">
					Frequently asked <span class="hl-spectrum">questions</span>.
				</h1>
				<p class="lede">
					Answers to common questions about installing, configuring, and extending
					Kohl's Admin. Need more help? Read the
					<a :href="withBase('/guide/intro')">Guide</a> or ask in
					<a :href="DISCORD" target="_blank" rel="noopener noreferrer">the Discord</a>.
				</p>
			</div>
			<div class="faq-list">
				<details class="faq" open>
					<summary>How can I donate or sponsor Kohl's Admin?</summary>
					<div class="faq-body">
						<p>
							Grab a supporter pass or scripted UGC item on the
							<a :href="withBase('/donate')"><strong>Donate page</strong></a>
							or from the in-game Market tab. Roblox supporter tiers grant particle
							trails, VIP chat commands, animated crowns and wings, and overhead
							titles across participating games.
						</p>
						<p>
							You can also sponsor open-source development directly on
							<a :href="SPONSORS" target="_blank" rel="noopener noreferrer"><strong>GitHub Sponsors</strong></a>
							or <a :href="KOFI" target="_blank" rel="noopener noreferrer"><strong>Ko-fi</strong></a>.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>How do I add Kohl's Admin to my game?</summary>
					<div class="faq-body">
						<ol>
							<li>
								Get the official model on the Creator Store:
								<a :href="MODEL" target="_blank" rel="noopener noreferrer">Kohl's Admin</a>.
							</li>
							<li>Open your place in Roblox Studio.</li>
							<li>
								Insert the loader into <strong>Workspace</strong> or
								<strong>ServerScriptService</strong> from your Toolbox Inventory.
							</li>
							<li>Publish your place to Roblox.</li>
							<li>
								Test in a live server or follow the
								<a :href="withBase('/guide/getting-started/installation')">Installation Guide</a>.
							</li>
						</ol>
						<div class="note">
							<p>
								Always verify the model is published by
								<a href="https://www.roblox.com/users/44391621/profile" target="_blank" rel="noopener noreferrer"><strong>@Scripth</strong></a>
								using the official link above. Unofficial copies on the Creator
								Store often contain backdoors.
							</p>
						</div>
					</div>
				</details>
				<details class="faq">
					<summary>Is Kohl's Admin broken right now?</summary>
					<div class="faq-body">
						<p>
							Join the
							<a :href="TRY" target="_blank" rel="noopener noreferrer">official testing place</a>
							first to check if the issue reproduces there. If it does, report it in
							<a :href="DISCORD" target="_blank" rel="noopener noreferrer">the Discord</a>
							or open an issue on
							<a :href="`${GITHUB}/issues/new/choose`" target="_blank" rel="noopener noreferrer">GitHub</a>.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>Can Kohl's Admin developers use commands in my game?</summary>
					<div class="faq-body">
						<p>
							No one gets a hidden admin role in your game. Donors and developers
							can only use cosmetic VIP commands when you leave <code>vip = true</code>
							enabled. The full source is
							<a :href="GITHUB" target="_blank" rel="noopener noreferrer">public on GitHub</a>.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>How do I configure roles, admins, and the command prefix?</summary>
					<div class="faq-body">
						<p>
							Open the <code>Settings</code> ModuleScript inside the Kohl's Admin
							Loader in Roblox Studio to set your command <code>prefix</code> and
							assign users, groups, game passes, or assets to roles. You can also
							manage members, roles, and settings in-game from the dashboard,
							which saves to DataStores automatically.
						</p>
						<p>
							See the
							<a :href="withBase('/guide/getting-started/configuration')">Configuration Guide</a>
							for a full walkthrough.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>How do I disable global VIP commands or earn commission from them?</summary>
					<div class="faq-body">
						<p>
							Keep <code>vip = true</code> in <code>Settings</code> and enable
							<strong>Allow Third Party Sales</strong> in your Roblox Game
							Settings. Your game earns up to <strong>40% commission</strong>
							on every global VIP item, donation pass, or UGC accessory bought
							in-game.
						</p>
						<p>
							To disable global VIP perks and commands instead, set
							<code>vip = false</code> in <code>Settings</code> or toggle it off
							in the in-game Settings tab.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>How do I create custom commands or addons?</summary>
					<div class="faq-body">
						<p>
							Add a ModuleScript inside the <code>Addons</code> folder of your
							loader and call <code>_K.Registry.registerCommand</code>. Custom
							commands use the same argument parser, type checker, and permission
							checks as built-in commands.
						</p>
						<p>
							See the
							<a :href="withBase('/guide/custom_commands')">Custom Commands Guide</a>
							and the <a :href="withBase('/api/')">API Reference</a> for examples.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>How do I migrate from Kohl's Admin Infinite (KAI)?</summary>
					<div class="faq-body">
						<p>
							The modern loader automatically imports your settings, admin lists,
							and saved DataStore entries from classic Kohl's Admin Infinite. See
							the
							<a :href="withBase('/guide/getting-started/legacy_loader')">Legacy Loader Guide</a>
							for migration details.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>What is Infinite Studios' relationship with Kohl's Admin?</summary>
					<div class="faq-body">
						<p>
							Infinite Studios is Kohl's development group. Kohl's Admin is
							created by Kohl under the Infinite brand.
						</p>
					</div>
				</details>
			</div>
		</div>
	</section>
</div>
