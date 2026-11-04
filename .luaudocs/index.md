---
layout: page
description: "Administration, moderation, and command suite for Roblox."
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
	{ target: 30, suffix: "M+", label: "Installs", accent: "ui" },
	{ target: 100, suffix: "K+", label: "Active Games", accent: "perf" },
	{ target: 200, suffix: "+", label: "Commands", accent: "auto" },
	{ target: yearsSinceLaunch(new Date()), suffix: "+", label: "Years", accent: "addons" },
];

const statValues = ref(stats.map((s) => `${s.target}${s.suffix}`));

const featureCards = [
	{
		accent: "ui",
		badge: "Interface",
		name: "Modern interface",
		desc: "A reactive dashboard built on Flux that adapts to your game. Pick a preset or tune every color, font, corner radius, and sound to match your place.",
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
		alt: "The Kohl's Admin settings panel showing theme, font, size, radius, padding, and transparency controls.",
	},
	{
		accent: "perf",
		badge: "Runtime",
		name: "High performance",
		desc: "UI updates batch once per frame to stay out of your frame budget. Client and server startup steps log in milliseconds so slow loads are easy to spot.",
		stat: "<b>Zero</b> frame-budget bloat",
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
		badge: "Revenue",
		name: "Built-in monetization",
		desc: "Map your own game passes, groups, and assets to roles, or earn from ours. Take up to 40% commission on every VIP pass or scripted UGC item sold in your game.",
		stat: "<b>Up to 40%</b> creator commission",
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
		badge: "Discovery",
		name: "Global charts",
		desc: "Players browsing the charts from any participating experience can discover and join your game directly from the in-game dashboard.",
		stat: "<b>Free</b> cross-game discovery",
		links: [
			{ href: CHARTS, label: "See charts", external: true },
		],
		img: "/img/charts.avif",
		width: 640,
		height: 360,
		posX: "50%",
		posY: "50%",
		alt: "The Kohl's Admin charts place showing a wall of experience thumbnails behind the logo.",
	},
];

const pillars = [
	{
		accent: "auto",
		badge: "200+ Commands",
		title: "Smart autocomplete",
		desc: "Arguments, player selectors, and enum options resolve and type-check on the client as you type before a command ever runs.",
		code: `<span class="tok-cm">-- Inline selectors, durations, and multi-command batches</span>\n<span class="tok-fn">;fly</span> @others <span class="tok-num">80</span> <span class="tok-fn">;ff</span> @all\n<span class="tok-fn">;tempban</span> @trolls <span class="tok-num">7d</span> <span class="tok-str">Griefing spawn</span>`,
		stat: "<b>Live</b> client validation",
		links: [
			{ href: "/guide/getting-started/using_commands", label: "Using commands" },
		],
	},
	{
		accent: "secure",
		badge: "Role Guards",
		title: "Secure architecture",
		desc: "Role-based access control protects your game from abuse. Every command and target is verified on the server against the caller's rank before running.",
		code: `<span class="tok-cm">-- Server-side permission and rank verification</span>\n<span class="tok-kw">if</span> _K.Auth.<span class="tok-fn">hasCommand</span>(from, <span class="tok-str">"ban"</span>) <span class="tok-kw">then</span>\n    _K.Auth.<span class="tok-fn">targetUserArgument</span>(arg, userId, value)\n<span class="tok-kw">end</span>`,
		stat: "<b>Server-verified</b> permissions",
		links: [
			{ href: "/api/Auth", label: "Auth API" },
		],
	},
	{
		accent: "setup",
		badge: "Zero Config",
		title: "One-model setup",
		desc: "Drop the loader into ServerScriptService and publish. Automatic live updates keep every server on the latest release without republishing your place.",
		code: `<span class="tok-cm">-- ServerScriptService/Kohl's Admin Loader</span>\n<span class="tok-cm">-- Auto-updates from the official Creator Store package</span>\n<span class="tok-kw">local</span> _K = <span class="tok-fn">require</span>(game.ReplicatedStorage.KohlsAdmin)`,
		stat: "<b>Single-model</b> install",
		links: [
			{ href: "/guide/getting-started/installation", label: "Install guide" },
		],
	},
	{
		spectrum: true,
		badge: "Addons & API",
		title: "Extensible architecture",
		desc: "Drop scripts into the Addons folder or register custom commands, argument types, and Flux UI themes through the same API the built-ins use.",
		code: `_K.Registry.<span class="tok-fn">registerCommand</span>(_K, {\n    name = <span class="tok-str">"launch"</span>,\n    args = { { type = <span class="tok-str">"players"</span>, name = <span class="tok-str">"Target"</span> } },\n    run = <span class="tok-kw">function</span>(context, players) <span class="tok-kw">end</span>,\n})`,
		stat: "<b>MIT-licensed</b> addon API",
		links: [
			{ href: "/guide/custom_commands", label: "Custom commands" },
			{ href: "/guide/addons", label: "Addons" },
		],
	},
];

const contributions = [
	{
		accent: "ui",
		badge: "Recognition",
		name: "In-game credits",
		desc: "Your name appears in the credits command and About tab across every participating game running Kohl's Admin.",
	},
	{
		accent: "auto",
		badge: "Community",
		name: "Early access",
		desc: "Preview upcoming releases and join contributor channels in the community Discord.",
	},
	{
		accent: "money",
		badge: "Rewards",
		name: "In-game perks",
		desc: "Receive contributor perks and recognition inside participating games that run Kohl's Admin.",
	},
	{
		accent: "addons",
		badge: "Bounties",
		name: "Monetary bounties",
		desc: "Sustained or high-impact engineering contributions are eligible for monetary compensation.",
	},
];

const FULLSCREEN_VS = `
	attribute vec2 a_pos;
	void main() {
		gl_Position = vec4(a_pos, 0.0, 1.0);
	}
`;

const CONTACT_CLOUD_FS = `
	precision highp float;
	uniform vec2 u_res;
	uniform float u_time;
	uniform vec2 u_p1;
	uniform vec2 u_p2;
	uniform vec2 u_p3;
	uniform float u_active;
	uniform float u_dark;

	float ign(vec2 p) {
		return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
	}

	vec3 hash32(vec2 p) {
		vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
		p3 += dot(p3, p3.yxz + 33.33);
		return fract((p3.xxy + p3.yzz) * p3.zyx);
	}

	vec3 dither8(vec3 c, vec2 p) {
		vec2 f = floor(p);
		float b1 = ign(f);
		float b2 = ign(f + vec2(37.0, 17.0));
		vec3 h = hash32(f);
		vec3 u1 = fract(b1 + (h - 0.5) * 0.22);
		vec3 u2 = fract(b2 + (h.yzx - 0.5) * 0.22);
		vec3 x = max(c, 0.0) * 255.0;
		vec3 beta = clamp(x, 0.0, 0.75);
		vec3 d = (u1 - 0.5) + (u2 - 0.5) * beta;
		return clamp((x + d) * (1.0 / 255.0), 0.0, 1.0);
	}

	vec3 linearToSrgb(vec3 c) {
		vec3 lo = 12.92 * c;
		vec3 hi = 1.055 * pow(max(c, 0.0), vec3(1.0 / 2.4)) - 0.055;
		return mix(lo, hi, step(vec3(0.0031308), c));
	}

	vec3 oklabToLinearSrgb(vec3 lab) {
		float l_ = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
		float m_ = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
		float s_ = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
		float l = l_ * l_ * l_;
		float m = m_ * m_ * m_;
		float s = s_ * s_ * s_;
		return vec3(
			+4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
			-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
			-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
		);
	}

	vec3 spectrumLinearSrgb(float phase) {
		float h = phase * 6.2831853072;
		vec3 lin = oklabToLinearSrgb(vec3(0.80, 0.195 * cos(h), 0.195 * sin(h)));
		return 0.5 * (lin + sqrt(lin * lin + vec3(0.0004)));
	}

	void main() {
		vec3 h = hash32(floor(gl_FragCoord.xy));
		vec2 uv = (gl_FragCoord.xy + (h.xy - 0.5) * 2.0) / u_res;
		vec2 u = vec2(uv.x - 0.5, uv.y);

		vec2 flowCoord = vec2((u.x - u_p2.x * 0.28) * 1.85, (u.y - u_p2.y * 0.22) * 1.45);
		vec2 f1 = vec2(
			sin(flowCoord.y * 1.25 + u_time * 0.20) + cos(flowCoord.x * 1.05 - u_time * 0.16),
			cos(flowCoord.x * 1.30 - u_time * 0.18) + sin(flowCoord.y * 1.10 + u_time * 0.22)
		);
		vec2 wu = u + vec2(0.042, 0.052) * f1;

		vec2 c1 = vec2(u_p1.x * 0.54 - 0.26 + 0.15 * cos(u_time * 0.16), u_p1.y * 0.28 - 0.04 + 0.06 * sin(u_time * 0.20));
		vec2 c2 = vec2(u_p2.x * 0.48 + 0.26 - 0.15 * cos(u_time * 0.18 + 1.2), u_p2.y * 0.25 - 0.03 + 0.06 * cos(u_time * 0.19));
		vec2 c3 = vec2(u_p3.x * 0.42 + 0.13 * sin(u_time * 0.21 - 0.8), u_p3.y * 0.26 + 0.04 + 0.05 * cos(u_time * 0.15));

		vec2 d1 = (wu - c1) / vec2(0.76, 0.58);
		vec2 d2 = (wu - c2) / vec2(0.76, 0.58);
		vec2 d3 = (wu - c3) / vec2(0.72, 0.64);

		float p1 = exp(-dot(d1, d1) * 1.15);
		float p2 = exp(-dot(d2, d2) * 1.15);
		float p3 = exp(-dot(d3, d3) * 1.10);

		vec2 cursorCenter = vec2(u_p1.x * 0.92, clamp(u_p1.y * 0.72 + 0.12, -0.04, 0.54));
		vec2 dh = (wu - cursorCenter) / vec2(0.50, 0.46);
		float halo = exp(-dot(dh, dh) * 1.35) * 0.58 * u_active;

		float ambient = 1.0 - (1.0 - 0.54 * p1) * (1.0 - 0.54 * p2) * (1.0 - 0.58 * p3);
		float combined = 1.0 - (1.0 - ambient) * (1.0 - halo);

		float wisps = 0.5 + 0.5 * sin(flowCoord.x * 0.95 + f1.x * 0.50 + u_time * 0.15)
			* cos(flowCoord.y * 0.95 + f1.y * 0.50 - u_time * 0.13);

		float y = clamp(uv.y, 0.0, 1.0);
		float topVanish = 1.0 - y * y;
		float vEnvelope = exp(-y * y * 2.25) * (topVanish * topVanish * topVanish);
		float strength = combined * (0.90 + 0.10 * wisps) * vEnvelope;

		vec2 rel = wu - u_p1 * 0.44;
		float phase = rel.x * 0.54 - rel.y * 0.24
			+ (f1.x - f1.y) * 0.045
			- u_time * 0.022
			+ (h.z - 0.5) * 0.005;

		vec3 specSrgb = linearToSrgb(spectrumLinearSrgb(phase));
		vec3 darkOut = min(vec3(8.0, 9.0, 11.0) / 255.0 + dither8(specSrgb * (strength * 0.24), gl_FragCoord.xy), 1.0);
		vec3 lightOut = max(vec3(1.0) - dither8((vec3(1.0) - specSrgb) * (strength * 0.42), gl_FragCoord.xy), 0.0);

		gl_FragColor = vec4(mix(lightOut, darkOut, u_dark), 1.0);
	}
`;

let statsIO = null;
let ambientIO = null;
let sizeRO = null;
let stageCleanups = [];
let cloudCleanup = null;

function initContactCloud(reduced) {
	const section = document.getElementById("get");
	const cloudCanvas = section?.querySelector(".contact-cloud");
	if (!section || !(cloudCanvas instanceof HTMLCanvasElement)) return null;

	const gl =
		cloudCanvas.getContext("webgl", {
			alpha: false,
			depth: false,
			stencil: false,
			antialias: false,
			powerPreference: "low-power",
		}) || cloudCanvas.getContext("experimental-webgl");
	if (!gl) return null;

	const compile = (type, src) => {
		const s = gl.createShader(type);
		if (!s) return null;
		gl.shaderSource(s, src);
		gl.compileShader(s);
		return gl.getShaderParameter(s, gl.COMPILE_STATUS) ? s : null;
	};
	const vs = compile(gl.VERTEX_SHADER, FULLSCREEN_VS);
	const fs = compile(gl.FRAGMENT_SHADER, CONTACT_CLOUD_FS);
	const prog = gl.createProgram();
	if (!vs || !fs || !prog) return null;
	gl.attachShader(prog, vs);
	gl.attachShader(prog, fs);
	gl.linkProgram(prog);
	if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return null;

	cloudCanvas.style.background = "none";
	gl.useProgram(prog);

	const buf = gl.createBuffer();
	gl.bindBuffer(gl.ARRAY_BUFFER, buf);
	gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
	const aPos = gl.getAttribLocation(prog, "a_pos");
	gl.enableVertexAttribArray(aPos);
	gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);

	const uRes = gl.getUniformLocation(prog, "u_res");
	const uTime = gl.getUniformLocation(prog, "u_time");
	const uP1 = gl.getUniformLocation(prog, "u_p1");
	const uP2 = gl.getUniformLocation(prog, "u_p2");
	const uP3 = gl.getUniformLocation(prog, "u_p3");
	const uActive = gl.getUniformLocation(prog, "u_active");
	const uDark = gl.getUniformLocation(prog, "u_dark");

	let sectionRect = section.getBoundingClientRect();
	let canvasRect = cloudCanvas.getBoundingClientRect();

	const resize = () => {
		sectionRect = section.getBoundingClientRect();
		canvasRect = cloudCanvas.getBoundingClientRect();
		const dpr = Math.min(window.devicePixelRatio || 1, 2);
		const w = Math.max(1, Math.min(2560, Math.round(canvasRect.width * dpr)));
		const h = Math.max(1, Math.min(1440, Math.round(canvasRect.height * dpr)));
		if (cloudCanvas.width !== w || cloudCanvas.height !== h) {
			cloudCanvas.width = w;
			cloudCanvas.height = h;
			gl.viewport(0, 0, w, h);
		}
	};
	resize();

	const ro = typeof ResizeObserver !== "undefined" ? new ResizeObserver(resize) : null;
	ro?.observe(cloudCanvas);

	const wake = {
		clientX: window.innerWidth * 0.5,
		clientY: window.innerHeight * 0.5,
		pointerInside: false,
		active: 0,
		p1x: 0,
		p1y: 0,
		p2x: 0,
		p2y: 0,
		p3x: 0,
		p3y: 0,
	};

	let raf = 0;
	let visible = true;
	let last = performance.now();
	let elapsed = 12;
	let isDark = document.documentElement.classList.contains("dark") ? 1 : 0;

	const onPointerMove = (e) => {
		if (!visible) return;
		wake.clientX = e.clientX;
		wake.clientY = e.clientY;
		wake.pointerInside = true;
	};
	const onPointerLeave = () => {
		wake.pointerInside = false;
	};
	window.addEventListener("pointermove", onPointerMove, { passive: true });
	document.addEventListener("pointerleave", onPointerLeave, { passive: true });

	const render = (now) => {
		raf = 0;
		const dt = Math.min(0.05, Math.max(0.001, (now - last) * 0.001));
		last = now;
		if (!reduced) elapsed += dt;

		sectionRect = section.getBoundingClientRect();
		const rawPx = (wake.clientX - sectionRect.left) / Math.max(sectionRect.width, 1) - 0.5;
		const rawPy = 0.85 - (wake.clientY - sectionRect.top) / Math.max(sectionRect.height, 1);
		const inBounds =
			wake.pointerInside &&
			rawPx >= -0.52 &&
			rawPx <= 0.52 &&
			rawPy >= -0.25 &&
			rawPy <= 0.9;

		wake.active += ((inBounds ? 1 : 0) - wake.active) * (1 - Math.exp(-dt * 5.2));
		const tx = inBounds ? Math.tanh(rawPx * 1.85) * 0.5 : 0;
		const ty = inBounds ? Math.tanh(rawPy * 1.85) * 0.36 : 0;

		const r1 = 1 - Math.exp(-dt * 7.0);
		const r2 = 1 - Math.exp(-dt * 3.4);
		const r3 = 1 - Math.exp(-dt * 1.7);

		wake.p1x += (tx - wake.p1x) * r1;
		wake.p1y += (ty - wake.p1y) * r1;
		wake.p2x += (wake.p1x - wake.p2x) * r2;
		wake.p2y += (wake.p1y - wake.p2y) * r2;
		wake.p3x += (wake.p2x - wake.p3x) * r3;
		wake.p3y += (wake.p2y - wake.p3y) * r3;

		gl.uniform2f(uRes, cloudCanvas.width, cloudCanvas.height);
		gl.uniform1f(uTime, elapsed);
		gl.uniform2f(uP1, wake.p1x, wake.p1y);
		gl.uniform2f(uP2, wake.p2x, wake.p2y);
		gl.uniform2f(uP3, wake.p3x, wake.p3y);
		gl.uniform1f(uActive, wake.active);
		gl.uniform1f(uDark, isDark);
		gl.drawArrays(gl.TRIANGLES, 0, 3);

		if (!reduced && visible && !document.hidden) {
			raf = requestAnimationFrame(render);
		}
	};

	const start = () => {
		if (!raf && !reduced && visible && !document.hidden) {
			last = performance.now();
			raf = requestAnimationFrame(render);
		}
	};
	const stop = () => {
		if (!raf) return;
		cancelAnimationFrame(raf);
		raf = 0;
	};

	render(performance.now());

	const io =
		!reduced && "IntersectionObserver" in window
			? new IntersectionObserver(
					(entries) => {
						for (const entry of entries) {
							visible = entry.isIntersecting;
							if (entry.isIntersecting) start();
							else stop();
						}
					},
					{ rootMargin: "80px" },
				)
			: null;
	io?.observe(cloudCanvas);

	const onVis = () => {
		if (document.hidden) stop();
		else start();
	};
	document.addEventListener("visibilitychange", onVis);

	const themeMO = new MutationObserver(() => {
		const nextDark = document.documentElement.classList.contains("dark") ? 1 : 0;
		if (nextDark !== isDark) {
			isDark = nextDark;
			render(performance.now());
		}
	});
	themeMO.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });

	return () => {
		stop();
		ro?.disconnect();
		io?.disconnect();
		themeMO.disconnect();
		window.removeEventListener("pointermove", onPointerMove);
		document.removeEventListener("pointerleave", onPointerLeave);
		document.removeEventListener("visibilitychange", onVis);
	};
}

onMounted(() => {
	const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

	if (!reduced && "IntersectionObserver" in window) {
		ambientIO = new IntersectionObserver(
			(entries) => {
				for (const entry of entries) {
					entry.target.classList.toggle("anim-off", !entry.isIntersecting);
				}
			},
			{ rootMargin: "120px" },
		);
		for (const el of document.querySelectorAll(".ka-page .poster, .ka-page .band")) {
			ambientIO.observe(el);
		}
	}

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

	cloudCleanup = initContactCloud(reduced);
});

onBeforeUnmount(() => {
	if (typingTimer) clearTimeout(typingTimer);
	if (statsIO) statsIO.disconnect();
	if (ambientIO) ambientIO.disconnect();
	if (sizeRO) sizeRO.disconnect();
	stageCleanups.forEach((fn) => fn());
	if (cloudCleanup) cloudCleanup();
});
</script>

<div class="ka-page">
	<header class="poster hero">
		<div class="shell">
			<div class="hero-grid">
				<div>
					<h1 class="hero-title">
						Embrace <span class="hl-spectrum">creativity</span>, not&nbsp;chaos.
					</h1>
					<p class="hero-claim">
						Drop one model into your place for 200+ commands, role permissions,
						and live moderation tools.
					</p>
					<p class="hero-lede">
						Installed by <strong>30M+ creators</strong> since 2010 and running across
						<strong>100K+ active games</strong> today. Built for everything from
						solo projects to front-page experiences.
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
						<span class="demo-tag">interactive</span>
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
	<section class="poster band accent-auto" id="features">
		<div class="shell">
			<div class="section-head rise">
				<h2 class="section-title">
					Power meets <span class="hl-spectrum-inv">simplicity</span>.
				</h2>
				<p class="lede">
					Built to stay out of your frame budget and match your game's UI from
					the first insert.
				</p>
			</div>
			<div class="bento-grid">
				<article
					v-for="item in featureCards"
					:key="item.name"
					class="bento-card bento-span-6 rise"
					:class="`accent-${item.accent}`"
				>
					<div class="bento-head">
						<h3 class="bento-title">{{ item.name }}</h3>
						<span class="bento-badge">{{ item.badge }}</span>
					</div>
					<p class="bento-desc">{{ item.desc }}</p>
					<div
						class="stage stage-shot"
						:style="{ '--pos-x': item.posX, '--pos-y': item.posY }"
					>
						<img
							:src="withBase(item.img)"
							:width="item.width"
							:height="item.height"
							:alt="item.alt"
							decoding="async"
						/>
					</div>
					<footer class="bento-foot">
						<p class="bento-stat" v-html="item.stat"></p>
						<div v-if="item.links.length > 0" class="bento-links">
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
				<article
					v-for="pillar in pillars"
					:key="pillar.title"
					class="bento-card bento-span-6 rise"
					:class="pillar.spectrum ? 'bento-spectrum' : `accent-${pillar.accent}`"
				>
					<div class="bento-head">
						<h3 class="bento-title">{{ pillar.title }}</h3>
						<span class="bento-badge">{{ pillar.badge }}</span>
					</div>
					<p class="bento-desc">{{ pillar.desc }}</p>
					<div class="code-block" aria-label="Luau example">
						<pre class="code-pre"><code v-html="pillar.code"></code></pre>
					</div>
					<footer class="bento-foot">
						<p class="bento-stat" v-html="pillar.stat"></p>
						<div class="bento-links">
							<a
								v-for="link in pillar.links"
								:key="link.label"
								:href="withBase(link.href)"
							>
								{{ link.label }}
							</a>
						</div>
					</footer>
				</article>
			</div>
			<div class="more rise">
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
	<section class="poster band accent-addons" id="contributing">
		<div class="shell">
			<div class="section-head rise">
				<h2 class="section-title">
					Built with the <span class="hl-spectrum">community</span>.
				</h2>
				<p class="lede">
					Kohl's Admin is MIT-licensed and shaped by developers across Roblox.
					Read the
					<a href="https://github.com/kohls-admin/kohls-admin/blob/main/CONTRIBUTING.md" target="_blank" rel="noopener noreferrer">Contributor Guidelines</a>
					to get involved.
				</p>
			</div>
			<div class="bento-grid">
				<article
					v-for="item in contributions"
					:key="item.name"
					class="bento-card bento-span-6 rise"
					:class="`accent-${item.accent}`"
				>
					<div class="bento-head">
						<h3 class="bento-title">{{ item.name }}</h3>
						<span class="bento-badge">{{ item.badge }}</span>
					</div>
					<p class="bento-desc">{{ item.desc }}</p>
				</article>
				<article class="bento-card bento-span-12 rise accent-ui" id="sponsors">
					<div class="bento-split">
						<div class="bento-main">
							<div class="bento-head">
								<h3 class="bento-title">Sponsors</h3>
								<span class="bento-badge">Open Source</span>
							</div>
							<p class="bento-desc">
								Kohl's Admin is free, open-source software maintained for the Roblox community.
								Sponsors fund ongoing development, documentation, and infrastructure.
							</p>
							<div class="hero-actions">
								<a :href="SPONSORS" target="_blank" rel="noopener noreferrer" class="btn btn-primary">GitHub Sponsors</a>
								<a :href="KOFI" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Support on Ko-fi</a>
							</div>
							<footer class="bento-foot">
								<p class="bento-stat"><b>100%</b> free &amp; MIT licensed</p>
								<div class="bento-links">
									<a :href="withBase('/donate')">In-game VIP &amp; perks</a>
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
			<div class="contrib-actions rise">
				<p class="contrib-actions-copy">
					<strong>Found a bug or have a feature request?</strong> Open an issue on GitHub or launch a preconfigured development environment in Codespaces.
				</p>
				<div class="hero-actions">
					<a href="https://github.com/kohls-admin/kohls-admin/issues/new/choose" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Open an issue</a>
					<a href="https://codespaces.new/kohls-admin/kohls-admin?quickstart=1" target="_blank" rel="noopener noreferrer" class="btn btn-secondary">Open in Codespaces</a>
				</div>
			</div>
		</div>
	</section>
	<section class="poster band band-cloud accent-secure" id="get">
		<canvas class="contact-cloud" aria-hidden="true"></canvas>
		<i class="grain" aria-hidden="true"></i>
		<div class="shell">
			<div class="cta rise">
				<span class="cta-status">
					<span class="pulse" aria-hidden="true"></span>actively maintained
				</span>
				<h2 class="cta-title">
					Ready to upgrade your <span class="hl-spectrum">game</span>?
				</h2>
				<p class="lede">
					Join millions of developers running Kohl's Admin on Roblox. Free,
					open source, and ready in a single model.
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
