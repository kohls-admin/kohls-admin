---
title: "Donate - Kohl's Admin"
description: "Support Kohl's Admin development and unlock global VIP commands, donor particle trails, animated crowns and wings, and exclusive overhead titles."
layout: page
sidebar: false
editLink: false
lastUpdated: false
---

<script setup>
import { withBase } from "vitepress";

const TRY = "https://www.roblox.com/join/0e4i1";
const DISCORD = "https://discord.gg/kohl";

const tierGroups = [
	{
		accent: "perf",
		name: "Supporter Tiers",
		price: "10 – 100 R$",
		sub: "Start supporting Kohl's Admin and unlock a custom particle trail.",
		perks: [
			"Custom donor particle effect",
			"Toggleable in-game via the Market tab",
			"Active in all participating experiences",
		],
		tiers: [
			{ name: "Tip", price: "10 R$", color: "#9fd800", href: "https://www.roblox.com/game-pass/5391355/Tip" },
			{ name: "Gift", price: "50 R$", color: "#6ee000", href: "https://www.roblox.com/game-pass/5391356/Gift" },
			{ name: "Donor", price: "100 R$", color: "#00e640", href: "https://www.roblox.com/game-pass/933980650/Donor" },
		],
	},
	{
		accent: "auto",
		name: "Tribute",
		price: "200 R$",
		sub: "Unlock global VIP chat commands along with donor particle effects.",
		perks: [
			"Global VIP chat commands",
			"Custom donor particle effects",
			"Active in all participating experiences",
		],
		tiers: [
			{ name: "Tribute", price: "200 R$", color: "#00f088", href: "https://www.roblox.com/game-pass/933582848/Tribute" },
		],
	},
	{
		accent: "secure",
		name: "Patron",
		price: "400 R$",
		sub: "Add floating animated crowns and an exclusive overhead Patron title.",
		perks: [
			"Global VIP chat commands",
			"Animated Light, Dark & Gold Crowns",
			"Custom donor particle effects",
			"Exclusive overhead Patron title",
		],
		tiers: [
			{ name: "Patron", price: "400 R$", color: "#00e5ff", href: "https://www.roblox.com/game-pass/938480383/Patron" },
		],
	},
	{
		accent: "addons",
		name: "Elite – Eternal",
		price: "800 – 25,000 R$",
		sub: "Unlock every animated crown and wing accessory plus animated gradient titles.",
		perks: [
			"Global VIP chat commands",
			"All animated Crowns & Wings unlocked",
			"Custom donor particle effects",
			"Exclusive animated overhead title",
		],
		tiers: [
			{ name: "Elite", price: "800 R$", color: "#9b4dff", href: "https://www.roblox.com/game-pass/939618404/Elite" },
			{ name: "Epic", price: "1,600 R$", color: "#f04dff", href: "https://www.roblox.com/game-pass/936146448/Epic" },
			{ name: "Hero", price: "3,200 R$", color: "#ff3399", href: "https://www.roblox.com/game-pass/941076536/Hero" },
			{ name: "Legend", price: "6,400 R$", color: "#ff3b30", href: "https://www.roblox.com/game-pass/941162509/Legend" },
			{ name: "Mythic", price: "11,000 R$", color: "#ffb300", href: "https://www.roblox.com/game-pass/941006661/Mythic" },
			{ name: "Eternal", price: "25,000 R$", color: "#00e5ff", href: "https://www.roblox.com/game-pass/983235767/Eternal" },
		],
	},
];

const ugcGroups = [
	{
		accent: "money",
		name: "Animated Crowns",
		badge: "100 R$ · Included with Patron+",
		desc: "Floating crowns enhanced with custom fire effects, neon materials, and smooth spinning in games running Kohl's Admin.",
		items: [
			{ name: "Light Crown", price: "100 R$", href: "https://www.roblox.com/catalog/18966788838/White-Crown" },
			{ name: "Dark Crown", price: "100 R$", href: "https://www.roblox.com/catalog/106645613603989/Black-Crown" },
			{ name: "Gold Crown", price: "100 R$", href: "https://www.roblox.com/catalog/99317257118206/Gold-Crown" },
		],
	},
	{
		accent: "ui",
		name: "Animated Wings",
		badge: "200 R$ · Included with Elite+",
		desc: "Custom-rigged wings featuring bespoke flying animations and glowing neon materials in games running Kohl's Admin.",
		items: [
			{ name: "Light Wings", price: "200 R$", href: "https://www.roblox.com/catalog/133292294488871/White-Wings" },
			{ name: "Dark Wings", price: "200 R$", href: "https://www.roblox.com/catalog/110848154960799/Black-Wings" },
			{ name: "Gold Wings", price: "200 R$", href: "https://www.roblox.com/catalog/92807314389236/Gold-Wings" },
		],
	},
	{
		accent: "charts",
		name: "Global VIP Item",
		badge: "799 R$ · Avatar Asset",
		desc: "Unlock VIP chat commands and the global VIP title across participating experiences via a single catalog item.",
		items: [
			{ name: "Chat Commands", price: "799 R$", href: "https://www.roblox.com/catalog/110019084552349/Chat-Commands" },
			{ name: "Try in-game", price: "Demo Place", href: TRY },
		],
	},
];
</script>

<div class="ka-page">
	<section class="band band-first">
		<div class="shell">
			<div class="band-head">
				<span class="eyebrow">Support Development</span>
				<h1 class="band-title">
					Donate &amp; unlock <span class="hl-spectrum">global perks</span>.
				</h1>
				<p class="lede">
					We have poured thousands of hours into Kohl's Admin since 2010.
					Supporting the project funds continuous updates and unlocks global
					perks across participating experiences &mdash; and game creators earn
					up to <strong>40% commission</strong> on every in-game purchase.
				</p>
			</div>
			<div class="donate-tier-grid">
				<article
					v-for="group in tierGroups"
					:key="group.name"
					class="donate-tier-card"
					:class="`accent-${group.accent}`"
				>
					<div class="donate-tier-head">
						<h2 class="donate-tier-name">{{ group.name }}</h2>
						<span class="donate-tier-price">{{ group.price }}</span>
					</div>
					<p class="donate-tier-sub">{{ group.sub }}</p>
					<ul class="donate-tier-perks">
						<li v-for="perk in group.perks" :key="perk">{{ perk }}</li>
					</ul>
					<div class="donate-tier-pills">
						<a
							v-for="tier in group.tiers"
							:key="tier.name"
							:href="tier.href"
							target="_blank"
							rel="noopener noreferrer"
							class="donate-pill"
							:style="{ '--tier-color': tier.color }"
						>
							<b>{{ tier.name }}</b>
							<span>{{ tier.price }}</span>
						</a>
					</div>
				</article>
			</div>
		</div>
	</section>
	<section class="band" id="ugc">
		<div class="shell">
			<div class="band-head">
				<span class="eyebrow">Scripted Avatar Items</span>
				<h2 class="band-title">
					Interactive <span class="hl-spectrum-inv">UGC accessories</span>.
				</h2>
				<p class="lede">
					Wearable Roblox catalog accessories that come alive with custom
					animations, fire effects, and neon materials inside experiences
					running Kohl's Admin. You can also preview them for free inside the
					in-game Market tab.
				</p>
			</div>
			<div class="ugc-grid">
				<article
					v-for="ugc in ugcGroups"
					:key="ugc.name"
					class="ugc-card"
					:class="`accent-${ugc.accent}`"
				>
					<div class="ugc-head">
						<h3 class="ugc-name">{{ ugc.name }}</h3>
						<span class="ugc-badge">{{ ugc.badge }}</span>
					</div>
					<p class="ugc-desc">{{ ugc.desc }}</p>
					<div class="ugc-variants">
						<a
							v-for="item in ugc.items"
							:key="item.name"
							:href="item.href"
							target="_blank"
							rel="noopener noreferrer"
							class="donate-pill"
						>
							<b>{{ item.name }}</b>
							<span>{{ item.price }}</span>
						</a>
					</div>
				</article>
			</div>
		</div>
	</section>
	<section class="band">
		<div class="shell">
			<div class="cta">
				<span class="cta-status">
					<span class="pulse" aria-hidden="true"></span>try before you buy
				</span>
				<h2 class="cta-title">
					Want to preview <span class="hl-spectrum">perks</span> in-game?
				</h2>
				<p class="lede">
					Hop into the official Kohl's Admin testing place and open the Market
					tab to test animated crowns, wings, and commands live.
				</p>
				<div class="hero-actions cta-actions">
					<a :href="TRY" target="_blank" rel="noopener noreferrer" class="btn btn-primary">Try it live</a>
					<a :href="DISCORD" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Join the Discord</a>
					<a :href="withBase('/faq')" class="btn btn-secondary">Back to FAQ</a>
				</div>
			</div>
		</div>
	</section>
</div>
