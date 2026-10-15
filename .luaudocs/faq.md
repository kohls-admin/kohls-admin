---
title: "FAQ - Kohl's Admin"
description: "Frequently asked questions about Kohl's Admin: installing the model, donation perks, configuring roles, custom commands, and security."
layout: page
sidebar: false
editLink: false
lastUpdated: false
---

<script setup>
import { withBase } from "vitepress";

const DISCORD = "https://discord.gg/kohl";
const GITHUB = "https://github.com/kohls-admin/kohls-admin";
const TRY = "https://www.roblox.com/join/0e4i1";
const MODEL = "https://create.roblox.com/store/asset/172732271/Kohls-Admin";
</script>

<div class="ka-page">
	<section class="band band-first">
		<div class="shell">
			<div class="band-head">
				<span class="eyebrow">Support</span>
				<h1 class="band-title">
					Frequently asked <span class="hl-spectrum">questions</span>.
				</h1>
				<p class="lede">
					Everything you need to know about Kohl's Admin. Still stuck? Check the
					<a :href="withBase('/guide/intro')">Guide</a> or ask in
					<a :href="DISCORD" target="_blank" rel="noopener noreferrer">the Discord</a>.
				</p>
			</div>
			<div class="faq-list">
				<details class="faq" open>
					<summary>How can I donate?</summary>
					<div class="faq-body">
						<p>
							You can support Kohl's Admin and unlock global perks &mdash;
							including donor particle trails, VIP chat commands, animated
							crowns and wings, and exclusive overhead titles &mdash; across all
							participating experiences.
						</p>
						<p>
							See the full breakdown of current donation tiers and scripted UGC
							accessories on the
							<a :href="withBase('/donate')"><strong>Donate page</strong></a>.
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
							<li>Open your experience in Roblox Studio.</li>
							<li>
								Insert the loader into <strong>Workspace</strong> or
								<strong>ServerScriptService</strong> from your Toolbox Inventory.
							</li>
							<li>Publish your experience to Roblox.</li>
							<li>
								Test in a live server or follow the full
								<a :href="withBase('/guide/getting-started/installation')">Installation Guide</a>.
							</li>
						</ol>
						<div class="note">
							<p>
								There are many malicious copies of Kohl's Admin designed to
								trick you into adding a backdoor to your game. Always verify the
								model is created by
								<a href="https://www.roblox.com/users/44391621/profile" target="_blank" rel="noopener noreferrer"><strong>@Scripth</strong></a>
								using the official link above.
							</p>
						</div>
					</div>
				</details>
				<details class="faq">
					<summary>Is Kohl's Admin broken right now?</summary>
					<div class="faq-body">
						<p>
							Only if it is also broken in the
							<a :href="TRY" target="_blank" rel="noopener noreferrer">official testing place</a>.
							If it is, let us know in
							<a :href="DISCORD" target="_blank" rel="noopener noreferrer">the Discord</a>
							or open an issue on
							<a :href="`${GITHUB}/issues/new/choose`" target="_blank" rel="noopener noreferrer">GitHub</a>
							and we will pick it up.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>Can Kohl's Admin developers use commands in my game?</summary>
					<div class="faq-body">
						<p>
							Only the purchasable VIP commands, and only while you leave VIP
							benefits enabled. Nobody gets a hidden admin role in your
							experience &mdash; the source is
							<a :href="GITHUB" target="_blank" rel="noopener noreferrer">public</a>,
							so you can inspect every line yourself.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>How do I configure roles, admins, and the command prefix?</summary>
					<div class="faq-body">
						<p>
							Open the <code>Settings</code> ModuleScript inside the Kohl's Admin
							Loader in Roblox Studio. From there you can assign users, groups,
							game passes, and assets to any role (such as <code>admin</code>,
							<code>mod</code>, or custom roles) and customize your command
							<code>prefix</code>.
						</p>
						<p>
							You can also manage members, roles, and settings directly in-game
							through the dashboard, which saves automatically via DataStores.
							Read the
							<a :href="withBase('/guide/getting-started/configuration')">Configuration Guide</a>
							for a complete walkthrough.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>How do I disable global VIP commands or earn commission from them?</summary>
					<div class="faq-body">
						<p>
							When <code>vip</code> is enabled in your <code>Settings</code>
							module (the default) and <strong>Allow Third Party Sales</strong>
							is enabled in your Roblox Game Settings, your experience earns up
							to <strong>40% commission</strong> on every global VIP item,
							donation tier, or scripted UGC accessory purchased inside your
							game, and joins the global discovery charts.
						</p>
						<p>
							If you prefer to disable global VIP perks and commands in your
							experience, set <code>vip = false</code> in your
							<code>Settings</code> script or toggle it off in the in-game
							Settings panel.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>How do I create custom commands or addons?</summary>
					<div class="faq-body">
						<p>
							Place a ModuleScript inside the <code>Addons</code> folder of your
							Kohl's Admin Loader, or register commands directly through the
							<a :href="withBase('/api/Registry')"><code>Registry</code> API</a>
							using <code>_K.Registry.registerCommand</code>. Addons use the
							exact same argument parser, type system, and permission checks as
							built-in commands.
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
							Existing experiences using the classic Kohl's Admin Infinite
							loader can upgrade seamlessly. See the
							<a :href="withBase('/guide/getting-started/legacy_loader')">Legacy Loader Guide</a>
							for migrating your existing settings and admin lists to the new
							Kohl's Admin loader.
						</p>
					</div>
				</details>
				<details class="faq">
					<summary>What is Infinite Studios' relationship with Kohl's Admin?</summary>
					<div class="faq-body">
						<p>
							Infinite Studios is a development group founded by Kohl. Kohl's
							Admin is created solely by Kohl, under the Infinite branding.
						</p>
					</div>
				</details>
			</div>
		</div>
	</section>
</div>
