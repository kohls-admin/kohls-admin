---
title: "Donate - Kohl's Admin"
description: "Sponsor Kohl's Admin on GitHub or Ko-fi, or support via Roblox passes and UGC accessories to get global VIP commands, donor trails, crowns, and wings."
layout: page
sidebar: false
editLink: false
lastUpdated: false
---

<script setup>
import { ref } from "vue";
import { withBase } from "vitepress";

const TRY = "https://www.roblox.com/join/0e4i1";
const DISCORD = "https://discord.gg/kohl";
const SPONSORS = "https://github.com/sponsors/kohltastrophe";
const KOFI = "https://ko-fi.com/kohltastrophe";
const SPONSORS_SVG = "https://raw.githubusercontent.com/kohltastrophe/kohltastrophe/badges/sponsors.svg";
const GH_HEART_PATH = "M7.655 14.916v-.001h-.002l-.006-.003-.018-.01a22.066 22.066 0 0 1-3.744-2.584C2.045 10.731 0 8.35 0 5.5 0 2.836 2.086 1 4.25 1 5.797 1 7.153 1.802 8 3.02 8.847 1.802 10.203 1 11.75 1 13.914 1 16 2.836 16 5.5c0 2.85-2.044 5.231-3.886 6.818a22.094 22.094 0 0 1-3.433 2.414 7.152 7.152 0 0 1-.31.17l-.018.01-.008.004a.75.75 0 0 1-.69 0Z";
const KOFI_CUP_PATH = "M1 3.5A1 1 0 0 1 2 2.5h9.5a1 1 0 0 1 1 1V4.5h1.25a2.75 2.75 0 0 1 0 5.5H12.4A4.5 4.5 0 0 1 8 13.75H5.5A4.5 4.5 0 0 1 1 9.25V3.5ZM12.5 6v2.5h1.25a1.25 1.25 0 0 0 0-2.5H12.5ZM6.75 10.9c.38-.24 2.85-1.85 2.85-3.7 0-1.05-.8-1.82-1.75-1.82-.48 0-.86.24-1.1.6-.24-.36-.62-.6-1.1-.6-.95 0-1.75.77-1.75 1.82 0 1.85 2.47 3.46 2.85 3.7Z";

const hasSponsorsRoster = ref(false);
function onSponsorsLoad(event) {
	const img = event?.target;
	if (img && img.naturalWidth > 1) {
		hasSponsorsRoster.value = true;
	}
}

const tierGroups = [
	{
		accent: "perf",
		name: "Supporter Tiers",
		price: "10 – 100 R$",
		sub: "Support Kohl's Admin and get a custom donor particle trail.",
		perks: [
			"Custom donor particle effect",
			"Toggleable in-game via the Market tab",
			"Active across participating experiences",
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
		sub: "Includes global VIP chat commands and donor particle effects.",
		perks: [
			"Global VIP chat commands",
			"Custom donor particle effects",
			"Active across participating experiences",
		],
		tiers: [
			{ name: "Tribute", price: "200 R$", color: "#00f088", href: "https://www.roblox.com/game-pass/933582848/Tribute" },
		],
	},
	{
		accent: "secure",
		name: "Patron",
		price: "400 R$",
		sub: "Adds floating animated crowns and an overhead Patron title.",
		perks: [
			"Global VIP chat commands",
			"Animated Light, Dark & Gold Crowns",
			"Custom donor particle effects",
			"Overhead Patron title",
		],
		tiers: [
			{ name: "Patron", price: "400 R$", color: "#00e5ff", href: "https://www.roblox.com/game-pass/938480383/Patron" },
		],
	},
	{
		accent: "addons",
		name: "Elite – Eternal",
		price: "800 – 25,000 R$",
		sub: "Includes every animated crown and wing accessory plus animated gradient titles.",
		perks: [
			"Global VIP chat commands",
			"All animated Crowns & Wings included",
			"Custom donor particle effects",
			"Animated overhead title",
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
		badge: "100 R$ · Patron+",
		desc: "Floating crowns with custom fire effects, neon materials, and smooth rotation in games running Kohl's Admin.",
		items: [
			{ name: "Light Crown", price: "100 R$", href: "https://www.roblox.com/catalog/18966788838/White-Crown" },
			{ name: "Dark Crown", price: "100 R$", href: "https://www.roblox.com/catalog/106645613603989/Black-Crown" },
			{ name: "Gold Crown", price: "100 R$", href: "https://www.roblox.com/catalog/99317257118206/Gold-Crown" },
		],
	},
	{
		accent: "ui",
		name: "Animated Wings",
		badge: "200 R$ · Elite+",
		desc: "Custom-rigged wings with flight animations and neon materials in games running Kohl's Admin.",
		items: [
			{ name: "Light Wings", price: "200 R$", href: "https://www.roblox.com/catalog/133292294488871/White-Wings" },
			{ name: "Dark Wings", price: "200 R$", href: "https://www.roblox.com/catalog/110848154960799/Black-Wings" },
			{ name: "Gold Wings", price: "200 R$", href: "https://www.roblox.com/catalog/92807314389236/Gold-Wings" },
		],
	},
	{
		accent: "charts",
		name: "Global VIP Item",
		badge: "799 R$ · Catalog",
		desc: "Grants VIP chat commands and the global VIP title across participating games from a single catalog item.",
		items: [
			{ name: "Chat Commands", price: "799 R$", href: "https://www.roblox.com/catalog/110019084552349/Chat-Commands" },
			{ name: "Try in-game", price: "Demo Place", href: TRY },
		],
	},
];
</script>

<div class="ka-page">
	<section class="poster band band-first accent-perf">
		<div class="shell">
			<div class="section-head rise">
				<h1 class="section-title">
					Donate &amp; get <span class="hl-spectrum">global perks</span>.
				</h1>
				<p class="lede">
					Supporting Kohl's Admin funds ongoing development and grants cosmetic perks
					across participating games. Game creators also earn up to
					<strong>40% commission</strong> on every in-game purchase.
				</p>
			</div>
			<div class="bento-grid">
				<article
					v-for="group in tierGroups"
					:key="group.name"
					class="bento-card bento-span-6 rise"
					:class="`accent-${group.accent}`"
				>
					<div class="bento-head">
						<h2 class="bento-title">{{ group.name }}</h2>
						<span class="bento-badge">{{ group.price }}</span>
					</div>
					<p class="bento-desc">{{ group.sub }}</p>
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
	<section class="poster band accent-money" id="ugc">
		<div class="shell">
			<div class="section-head rise">
				<h2 class="section-title">
					Interactive <span class="hl-spectrum-inv">UGC accessories</span>.
				</h2>
				<p class="lede">
					Wearable Roblox catalog accessories with custom animations, fire
					effects, and neon materials in games running Kohl's Admin. Preview
					them for free in the in-game Market tab.
				</p>
			</div>
			<div class="bento-grid">
				<article
					v-for="ugc in ugcGroups"
					:key="ugc.name"
					class="bento-card bento-span-4 rise"
					:class="`accent-${ugc.accent}`"
				>
					<div class="bento-head">
						<h3 class="bento-title">{{ ugc.name }}</h3>
						<span class="bento-badge">{{ ugc.badge }}</span>
					</div>
					<p class="bento-desc">{{ ugc.desc }}</p>
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
	<section class="poster band accent-ui" id="sponsors">
		<div class="shell">
			<div class="section-head rise">
				<h2 class="section-title">
					Open-source <span class="hl-spectrum">sponsors</span>.
				</h2>
				<p class="lede">
					Prefer supporting open-source work directly outside Roblox? Sponsor
					on GitHub Sponsors or Ko-fi to fund development, documentation, and
					infrastructure.
				</p>
			</div>
			<div class="bento-grid">
				<article class="bento-card bento-span-12 rise accent-ui">
					<div class="bento-split">
						<div class="bento-main">
							<div class="bento-head">
								<h3 class="bento-title">GitHub Sponsors &amp; Ko-fi</h3>
								<span class="bento-badge">MIT Licensed</span>
							</div>
							<p class="bento-desc">
								Every sponsorship goes straight toward maintaining Kohl's Admin,
								Flux, and open-source Roblox tooling. Active GitHub sponsors are
								featured automatically on the project roster.
							</p>
							<div class="hero-actions">
								<a :href="SPONSORS" target="_blank" rel="noopener noreferrer" class="btn btn-primary">GitHub Sponsors</a>
								<a :href="KOFI" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Support on Ko-fi</a>
							</div>
							<footer class="bento-foot">
								<p class="bento-stat"><b>Direct</b> creator support</p>
								<div class="bento-links">
									<a :href="withBase('/guide/support')">Support guide</a>
								</div>
							</footer>
						</div>
						<div class="sponsors-side">
							<div class="sponsors-platforms">
								<a
									:href="SPONSORS"
									target="_blank"
									rel="noopener noreferrer"
									class="sponsor-platform-card"
								>
									<span class="sponsor-slot sponsor-slot-github" aria-hidden="true">
										<svg viewBox="0 0 16 16"><path :d="GH_HEART_PATH" /></svg>
									</span>
									<span class="sponsor-platform-copy">
										<span class="sponsor-platform-title">GitHub Sponsors</span>
										<span class="sponsor-platform-sub">Monthly &amp; one-time tiers &middot; Featured across every repo</span>
									</span>
									<span class="sponsor-platform-pill sponsor-platform-pill-github">Sponsor</span>
								</a>
								<a
									:href="KOFI"
									target="_blank"
									rel="noopener noreferrer"
									class="sponsor-platform-card"
								>
									<span class="sponsor-slot sponsor-slot-kofi" aria-hidden="true">
										<svg viewBox="0 0 16 16"><path fill-rule="evenodd" :d="KOFI_CUP_PATH" /></svg>
									</span>
									<span class="sponsor-platform-copy">
										<span class="sponsor-platform-title">Ko-fi</span>
										<span class="sponsor-platform-sub">0% platform fee &middot; Tag @github to list your avatar</span>
									</span>
									<span class="sponsor-platform-pill sponsor-platform-pill-kofi">Support</span>
								</a>
							</div>
							<div v-show="hasSponsorsRoster" class="sponsors-roster">
								<a
									:href="SPONSORS"
									target="_blank"
									rel="noopener noreferrer"
									aria-label="View Kohl's Admin sponsors on GitHub"
								>
									<img
										:src="SPONSORS_SVG"
										alt="Kohl's Admin sponsors"
										loading="lazy"
										decoding="async"
										@load="onSponsorsLoad"
									/>
								</a>
							</div>
						</div>
					</div>
				</article>
			</div>
		</div>
	</section>
	<section class="poster band accent-secure">
		<div class="shell">
			<div class="cta rise">
				<span class="cta-status">
					<span class="pulse" aria-hidden="true"></span>try before you buy
				</span>
				<h2 class="cta-title">
					Want to preview <span class="hl-spectrum">perks</span> in-game?
				</h2>
				<p class="lede">
					Join the official Kohl's Admin testing place and open the Market
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
