---
layout: page
sidebar: false
editLink: false
lastUpdated: false
---

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from "vue";
import { withBase } from "vitepress";

const CHECK = "M382-240 154-468l57-57 171 171 367-367 57 57-424 424Z";
const CROSS = "m256-200-56-56 224-224-224-224 56-56 224 224 224-224 56 56-224 224 224 224-56 56-224-224-224 224Z";

const MODEL = "https://create.roblox.com/store/asset/172732271";
const TRY = "https://www.roblox.com/join/0e4i1";
const CHARTS = "https://www.roblox.com/join/f7tg3";
const DISCORD = "https://discord.gg/kohl";
const GITHUB = "https://github.com/kohls-admin/kohls-admin";

const PANELS = {
	admin: {
		label: ";admin me",
		cmd: ";admin",
		args: "me",
		name: "user(s)",
		type: "<userIds>",
		desc: "The user(s) to give the admin role to.",
		opts: [
			{ text: "me", hint: "you", on: true },
			{ text: "* [all]", hint: "everyone" },
		],
		phase: "valid",
		say: "argument resolved · enter to run",
	},
	fly: {
		label: ";fly",
		cmd: ";fly",
		args: "Player(s) Speed?",
		name: "fly",
		type: "<command>",
		desc: "Enables flight for one or more player(s).",
		opts: [
			{ text: "fly", hint: "on", on: true },
			{ text: "unfly", hint: "off" },
			{ text: "ff", hint: "forcefield" },
		],
		phase: "valid",
		say: "3 matches · tab to complete",
	},
	ban: {
		label: ";ban all",
		bad: true,
		cmd: ";ban",
		args: "all",
		name: "user(s)",
		type: "<allPlayers>",
		desc: "The player(s) or UserId(s) to ban.",
		opts: [{ text: "Can't target yourself", warn: true }],
		phase: "blocked",
		say: "guard tripped · the command never runs",
	},
};

const DEMO_SCENES = ["admin", "fly", "ban"];
const activeSceneId = ref(DEMO_SCENES[0]);
const activeScene = computed(() => PANELS[activeSceneId.value]);
const typedArgs = ref(PANELS[DEMO_SCENES[0]].args);

let typingTimer = null;

function selectScene(id) {
	if (id === activeSceneId.value || !PANELS[id]?.opts) return;
	activeSceneId.value = id;
	const target = PANELS[id].args;
	if (typingTimer) clearTimeout(typingTimer);

	if (typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
		typedArgs.value = target;
		return;
	}

	typedArgs.value = "";
	const tick = (i) => {
		typedArgs.value = target.slice(0, i);
		if (i < target.length) {
			typingTimer = setTimeout(() => tick(i + 1), 34);
		}
	};
	tick(0);
}

const LAUNCH = { year: 2010, month: 5, day: 14 };
function yearsSinceLaunch(now) {
	const year = now.getUTCFullYear();
	const month = now.getUTCMonth() + 1;
	const day = now.getUTCDate();
	const before = month < LAUNCH.month || (month === LAUNCH.month && day < LAUNCH.day);
	return year - LAUNCH.year - (before ? 1 : 0);
}

const stats = [
	{ target: 30, suffix: "M+", label: "Developers", accent: "ui" },
	{ target: 100, suffix: "K+", label: "Experiences", accent: "perf" },
	{ target: 200, suffix: "+", label: "Commands", accent: "auto" },
	{ target: yearsSinceLaunch(new Date()), suffix: "+", label: "Years", accent: "addons" },
];

const statValues = ref(stats.map((s) => `${s.target}${s.suffix}`));

const showcase = [
	{
		accent: "ui",
		kind: "interface",
		name: "Modern interface",
		desc: "A sleek, customizable panel that fits any game style. Pick a preset or build your own; every color, font, corner radius, and sound saves with your experience.",
		stat: "<b>Themeable</b> end to end",
		links: [
			{ href: TRY, label: "Try it live", external: true },
			{ href: "/guide/getting-started/using_uis", label: "UI guide" },
		],
		img: "/img/modern_ui.avif",
		width: 640,
		height: 480,
		posX: "0%",
		posY: "0%",
		alt: "The Kohl's Admin settings panel, showing theme, font, size, radius, padding, and transparency controls.",
	},
	{
		accent: "perf",
		kind: "runtime",
		name: "High performance",
		desc: "Optimized reactive UI and measured startup, so the admin system never shows up in your frame budget. Client and server log every initialization step in milliseconds.",
		stat: "<b>Zero</b> lag impact",
		links: [
			{ href: "/guide/intro", label: "Architecture" },
		],
		img: "/img/performance.avif",
		width: 640,
		height: 320,
		posX: "0%",
		posY: "0%",
		alt: "The log panel listing client and server startup steps with millisecond timings.",
	},
	{
		accent: "money",
		kind: "revenue",
		name: "Built-in monetization",
		desc: "Sell your own game-pass roles and commands, or earn from ours. Take up to 40% commission on every global VIP pass or scripted UGC accessory sold in your game.",
		stat: "<b>Up to 40%</b> commission",
		links: [
			{ href: "/donate", label: "VIP & perks" },
			{ href: "/guide/getting-started/configuration", label: "Configuration" },
		],
		img: "/img/profit.avif",
		width: 420,
		height: 420,
		posX: "0%",
		posY: "100%",
		alt: "The commands list with VIP-only entries and an Unlock VIP Commands button.",
	},
	{
		accent: "charts",
		kind: "discovery",
		name: "Global charts",
		desc: "Players browsing the charts from any participating experience can discover and join yours directly, turning the admin panel into a live discovery engine.",
		stat: "<b>Free</b> exposure",
		links: [
			{ href: CHARTS, label: "See charts", external: true },
		],
		img: "/img/charts.avif",
		width: 640,
		height: 360,
		posX: "50%",
		posY: "50%",
		alt: "The Kohl's Admin charts place, a wall of experience thumbnails behind the logo.",
	},
];

const pillars = [
	{
		accent: "auto",
		title: "Smart autocomplete",
		body: "Never guess a command syntax again. Arguments, player selectors, and enum options are suggested and type-checked on the client as you type, before anything runs.",
		receipt: "200+ built-in commands with real-time validation, fuzzy matching, and inline argument hints.",
		href: "/guide/getting-started/using_commands",
		link: "using commands",
	},
	{
		accent: "secure",
		title: "Secure architecture",
		body: "Role-based access control keeps your experience safe from abuse: every command and target is verified on the server against the caller's hierarchy rank before execution.",
		receipt: "Hierarchical roles, anti-abuse target guards, interactive command requests, and audit logs.",
		href: "/api/Auth",
		link: "the auth api",
	},
	{
		accent: "setup",
		title: "Effortless setup",
		body: "Drop the loader into ServerScriptService, publish, and you are done. Automatic live updates keep every server on the latest release without republishing your place.",
		receipt: "One model to install with persistent in-game DataStore settings and legacy KAI migration.",
		href: "/guide/getting-started/installation",
		link: "install guide",
	},
	{
		spectrum: true,
		title: "Limitless customization",
		body: "Extend functionality with community-made addons, or register your own commands, custom argument types, and reactive UI themes against the same API the built-ins use.",
		receipt: "MIT licensed source with a strictly versioned addon, hook, and type registry API.",
		href: "/guide/custom_commands",
		link: "custom commands",
	},
];

const contributions = [
	{
		accent: "ui",
		name: "In-game credits",
		desc: "Your name is featured directly inside the credits command across every participating experience running Kohl's Admin.",
	},
	{
		accent: "auto",
		name: "Inside access",
		desc: "Gain access to exclusive features, early previews, and private contributor channels within the community.",
	},
	{
		accent: "money",
		name: "In-game benefits",
		desc: "Enjoy special contributor perks and recognition inside participating experiences that use Kohl's Admin.",
	},
	{
		accent: "addons",
		name: "Monetary bounties",
		desc: "We value your time and engineering effort, with monetary compensation available for exceptional contributions.",
	},
];

const ocean = [
	{ hue: 300, x: "30%", y: "38%", w: "120%", h: "80%", a: "-15deg", dx: "4%", dy: "-3%", d: "48s", t: "-11s" },
	{ hue: 200, x: "70%", y: "32%", w: "110%", h: "85%", a: "20deg", dx: "-5%", dy: "3%", d: "61s", t: "-27s" },
	{ hue: 120, x: "55%", y: "72%", w: "130%", h: "70%", a: "-8deg", dx: "3%", dy: "5%", d: "54s", t: "-40s" },
	{ hue: 30, x: "24%", y: "78%", w: "100%", h: "75%", a: "12deg", dx: "-4%", dy: "-4%", d: "44s", t: "-5s" },
	{ hue: 250, x: "80%", y: "74%", w: "105%", h: "80%", a: "-20deg", dx: "5%", dy: "-2%", d: "70s", t: "-19s" },
];

let statsIO = null;
let sizeRO = null;
let stageCleanups = [];

onMounted(() => {
	const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

	const statsEl = document.querySelector(".ka-page .hero-readout");
	if (statsEl && !reduced) {
		statsIO = new IntersectionObserver(
			(entries) => {
				if (!entries.some((e) => e.isIntersecting)) return;
				statsIO.disconnect();
				stats.forEach((stat, index) => {
					const duration = 1200 + index * 220;
					const start = performance.now();
					const step = (now) => {
						const t = Math.min((now - start) / duration, 1);
						const value = Math.floor(Math.sqrt(1 - (t - 1) ** 2) * stat.target);
						statValues.value[index] = `${t < 1 ? value : stat.target}${stat.suffix}`;
						if (t < 1) requestAnimationFrame(step);
					};
					requestAnimationFrame(step);
				});
			},
			{ threshold: 0.4 },
		);
		statsIO.observe(statsEl);
	}

	const stages = [...document.querySelectorAll(".ka-page .stage-shot")];
	if (stages.length) {
		const measure = (stage) => {
			const img = stage.querySelector("img");
			const iw = Number(img?.getAttribute("width"));
			const ih = Number(img?.getAttribute("height"));
			const { width, height } = stage.getBoundingClientRect();
			if (!iw || !ih || !width || !height) return;
			const cover = Math.max(width / iw, height / ih);
			stage.style.setProperty("--zoom-max", Math.max(1, 1 / cover).toFixed(4));
		};

		sizeRO = new ResizeObserver((entries) => {
			for (const entry of entries) measure(entry.target);
		});
		stages.forEach((stage) => sizeRO.observe(stage));

		if (!reduced) {
			const clamp01 = (n) => Math.min(Math.max(n, 0), 1);
			for (const stage of stages) {
				let frame = null;
				const onMove = (event) => {
					if (event.pointerType === "touch") return;
					const { clientX, clientY } = event;
					cancelAnimationFrame(frame);
					frame = requestAnimationFrame(() => {
						const box = stage.getBoundingClientRect();
						const x = (clientX - box.left) / box.width;
						const y = (clientY - box.top) / box.height;
						stage.style.setProperty("--pan-x", `${(clamp01(x) * 100).toFixed(2)}%`);
						stage.style.setProperty("--pan-y", `${(clamp01(y) * 100).toFixed(2)}%`);
					});
				};
				const onLeave = () => {
					cancelAnimationFrame(frame);
					stage.style.removeProperty("--pan-x");
					stage.style.removeProperty("--pan-y");
				};
				stage.addEventListener("pointermove", onMove);
				stage.addEventListener("pointerleave", onLeave);
				stageCleanups.push(() => {
					cancelAnimationFrame(frame);
					stage.removeEventListener("pointermove", onMove);
					stage.removeEventListener("pointerleave", onLeave);
				});
			}
		}
	}
});

onBeforeUnmount(() => {
	if (typingTimer) clearTimeout(typingTimer);
	if (statsIO) statsIO.disconnect();
	if (sizeRO) sizeRO.disconnect();
	stageCleanups.forEach((fn) => fn());
});
</script>

<div class="ka-page">
	<header class="hero">
		<div class="shell">
			<div class="hero-grid">
				<div>
					<h1 class="hero-title">
						Embrace <span class="hl-spectrum">creativity</span>, not&nbsp;chaos
					</h1>
					<p class="hero-claim">
						One model, dropped into your experience, and every command you will
						ever need to run it.
					</p>
					<p class="hero-lede">
						Trusted across Roblox for over a decade and a half &mdash;
						<strong>battle-tested moderation</strong>,
						<strong>role-based access control</strong>, and live-ops tooling
						that scales from solo projects to front-page hits.
					</p>
					<div class="hero-actions">
						<a :href="MODEL" target="_blank" rel="noopener noreferrer" class="btn btn-primary">Get the model</a>
						<a :href="withBase('/guide/intro')" class="btn btn-secondary">Read the guide</a>
						<a :href="TRY" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Try it live</a>
					</div>
				</div>
				<div class="demo" :data-scene="activeSceneId">
					<div class="demo-head">
						<span class="demo-title">Command bar</span>
						<span class="demo-tag">try it</span>
					</div>
					<div class="cmdbar">
						<div class="pill" :class="{ bad: activeScene.bad }">
							<span class="pill-mark" aria-hidden="true">
								<svg class="glyph-check" viewBox="0 -960 960 960"><path :d="CHECK" /></svg>
								<svg class="glyph-x" viewBox="0 -960 960 960"><path :d="CROSS" /></svg>
							</span>
							<span class="pill-cmd">{{ activeScene.cmd }}</span>
							<span class="pill-args">{{ typedArgs }}</span>
							<span class="pill-caret" aria-hidden="true"></span>
						</div>
						<div v-if="activeScene.opts" class="menu">
							<div class="menu-head">
								<span class="menu-name">{{ activeScene.name }}</span>
								<span class="menu-type">{{ activeScene.type }}</span>
							</div>
							<p class="menu-desc">{{ activeScene.desc }}</p>
							<div
								v-for="opt in activeScene.opts"
								:key="opt.text"
								class="menu-opt"
								:class="{ on: opt.on, warn: opt.warn }"
							>
								<span>{{ opt.text }}</span>
								<span v-if="opt.hint" class="hint">{{ opt.hint }}</span>
							</div>
						</div>
					</div>
					<div class="demo-foot">
						<button
							v-for="id in DEMO_SCENES"
							:key="id"
							class="demo-btn"
							type="button"
							:aria-pressed="String(id === activeSceneId)"
							@click="selectScene(id)"
						>
							{{ PANELS[id].label }}
						</button>
					</div>
					<p class="demo-status" :data-phase="activeScene.phase" aria-live="polite">
						<span class="demo-phase">{{ activeScene.phase }}</span>
						<span class="demo-say">{{ activeScene.say }}</span>
					</p>
				</div>
			</div>
			<dl class="hero-readout" aria-label="Platform scale">
				<div
					v-for="(stat, i) in stats"
					:key="stat.label"
					class="hero-metric"
					:class="`accent-${stat.accent}`"
				>
					<dt>{{ stat.label }}</dt>
					<dd>{{ statValues[i] }}</dd>
				</div>
			</dl>
		</div>
	</header>
	<section class="band accent-auto" id="features">
		<div class="shell">
			<div class="band-head">
				<span class="eyebrow">Capabilities</span>
				<h2 class="band-title">
					Power meets <span class="hl-spectrum-inv">simplicity</span>.
				</h2>
				<p class="lede">
					Everything you need to run an experience, from the first insert to
					the hundred-thousandth session &mdash; engineered to stay out of your
					frame budget and fit right into your UI.
				</p>
			</div>
			<div class="showcase-grid">
				<article
					v-for="(item, i) in showcase"
					:key="item.accent"
					class="panel showcase-card"
					:class="`accent-${item.accent}`"
				>
					<i class="panel-shard" aria-hidden="true"></i>
					<span class="work-index" aria-hidden="true">
						{{ String(i + 1).padStart(2, "0") }}
					</span>
					<span class="work-kind">{{ item.kind }}</span>
					<h3 class="work-name">{{ item.name }}</h3>
					<p class="work-desc">{{ item.desc }}</p>
					<div
						class="stage stage-shot"
						:style="{ '--pos-x': item.posX, '--pos-y': item.posY }"
					>
						<img
							:src="withBase(item.img)"
							:width="item.width"
							:height="item.height"
							:alt="item.alt"
							loading="lazy"
							decoding="async"
						/>
					</div>
					<footer class="work-foot">
						<p class="work-stat" v-html="item.stat"></p>
						<div v-if="item.links.length > 0" class="work-links">
							<a
								v-for="link in item.links"
								:key="link.label"
								:href="link.external ? link.href : withBase(link.href)"
								:target="link.external ? '_blank' : undefined"
								:rel="link.external ? 'noopener noreferrer' : undefined"
							>
								{{ link.label }}
							</a>
						</div>
					</footer>
				</article>
			</div>
			<div class="ledger">
				<article
					v-for="(pillar, i) in pillars"
					:key="pillar.title"
					class="row"
					:class="pillar.spectrum ? 'row-spectrum' : `accent-${pillar.accent}`"
				>
					<span class="row-num" aria-hidden="true">
						{{ String(i + 1).padStart(2, "0") }}
					</span>
					<div class="row-main">
						<h3>{{ pillar.title }}</h3>
						<p>{{ pillar.body }}</p>
					</div>
					<footer class="row-receipt">
						<span class="receipt-label">receipt</span>
						<p>{{ pillar.receipt }}</p>
						<a :href="withBase(pillar.href)">
							<span>{{ pillar.link }}</span>
						</a>
					</footer>
				</article>
			</div>
			<div class="more">
				<p class="more-line">
					<span class="hl-spectrum">&hellip;and so much more</span>
				</p>
				<div class="more-links">
					<a :href="withBase('/guide/intro')">Read the guide</a>
					<a :href="withBase('/api/')">Explore the API</a>
					<a :href="withBase('/faq')">Browse the FAQ</a>
				</div>
			</div>
		</div>
	</section>
	<section class="band accent-addons" id="contributing">
		<div class="shell">
			<div class="band-head">
				<span class="eyebrow">Open Source &middot; MIT Licensed</span>
				<h2 class="band-title">
					Built with the <span class="hl-spectrum">community</span>.
				</h2>
				<p class="lede">
					We welcome and reward contributions from developers across the Roblox
					ecosystem. Check out our
					<a href="https://github.com/kohls-admin/kohls-admin/blob/master/CONTRIBUTING.md" target="_blank" rel="noopener noreferrer">Contributor Guidelines</a>
					to get involved.
				</p>
			</div>
			<div class="contrib-grid">
				<article
					v-for="item in contributions"
					:key="item.name"
					class="contrib-card"
					:class="`accent-${item.accent}`"
				>
					<h3 class="contrib-name">{{ item.name }}</h3>
					<p class="contrib-desc">{{ item.desc }}</p>
				</article>
			</div>
			<div class="contrib-actions">
				<p class="contrib-actions-copy">
					<strong>Found a bug or have a feature request?</strong> Let us know on GitHub or jump straight into a ready-to-code environment.
				</p>
				<div class="hero-actions">
					<a href="https://github.com/kohls-admin/kohls-admin/issues/new/choose" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Open an issue</a>
					<a href="https://codespaces.new/kohls-admin/kohls-admin?quickstart=1" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Open in Codespaces</a>
				</div>
			</div>
		</div>
	</section>
	<section class="band band-ocean accent-secure" id="get">
		<div class="ocean" aria-hidden="true">
			<i
				v-for="(s, idx) in ocean"
				:key="idx"
				class="swell"
				:style="`--hue:${s.hue}deg;--x:${s.x};--y:${s.y};--w:${s.w};--h:${s.h};--a:${s.a};--dx:${s.dx};--dy:${s.dy};--d:${s.d};--t:${s.t}`"
			></i>
		</div>
		<i class="grain" aria-hidden="true"></i>
		<div class="shell">
			<div class="cta">
				<span class="cta-status">
					<span class="pulse" aria-hidden="true"></span>actively maintained
				</span>
				<h2 class="cta-title">
					Ready to upgrade your <span class="hl-spectrum">game</span>?
				</h2>
				<p class="lede">
					Join millions of developers using the most trusted admin system on
					Roblox. It is free, it is open source, and it takes one insert.
				</p>
				<div class="hero-actions cta-actions">
					<a :href="MODEL" target="_blank" rel="noopener noreferrer" class="btn btn-primary">Get Kohl's Admin</a>
					<a :href="DISCORD" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Join the Discord</a>
				</div>
				<p class="cta-meta">
					Free <i>&middot;</i> MIT&nbsp;licensed <i>&middot;</i>
					Automatic&nbsp;updates <i>&middot;</i> 200+&nbsp;commands
				</p>
			</div>
		</div>
	</section>
</div>
