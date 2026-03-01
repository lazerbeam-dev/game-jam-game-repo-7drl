shader_type canvas_item;

// ─────────────────────────────────────────────────────────────────────────────
// TILE METAL SHADER — Renegade Lemonade
// ─────────────────────────────────────────────────────────────────────────────
// Brushed steel floor plates / metal walls. Grainy noise provides the
// anisotropic micro-surface texture characteristic of brushed metal. Milky
// noise adds soft broad highlight swaths simulating the low-angle reflectance
// of polished surfaces. Techno geometric patterns create panel seam lines
// (rivets, grooves) suggesting fabricated metal plating. Turbulence drives
// rust/corrosion blooms — intensity scales with wear_level, so deeper dungeon
// rooms can look far more corroded than fresh ones.
//
// Noise textures used:
//   noise_grainy     → sprites/noise/Grainy/Grainy 5 - 256x256.png
//   noise_milky      → sprites/noise/Milky/Milky 3 - 256x256.png
//   noise_techno     → sprites/noise/Techno/Techno 8 - 256x256.png
//   noise_turbulence → sprites/noise/Turbulence/Turbulence 7 - 256x256.png
//   noise_world      → sprites/noise/Manifold/Manifold 2 - 256x256.png
// ─────────────────────────────────────────────────────────────────────────────

varying vec2 world_pos;

// ── Noise Samplers ────────────────────────────────────────────────────────────
uniform sampler2D noise_grainy     : source_color, repeat_enable;
uniform sampler2D noise_milky      : source_color, repeat_enable;
uniform sampler2D noise_techno     : source_color, repeat_enable;
uniform sampler2D noise_turbulence : source_color, repeat_enable;
uniform sampler2D noise_world      : source_color, repeat_enable;

// ── Color Palette ─────────────────────────────────────────────────────────────
uniform vec4 color_shadow    : source_color = vec4(0.141, 0.145, 0.173, 1.0); // deep shadow
uniform vec4 color_steel     : source_color = vec4(0.408, 0.435, 0.486, 1.0); // mid steel grey
uniform vec4 color_highlight : source_color = vec4(0.729, 0.745, 0.788, 1.0); // bright specular
uniform vec4 color_rust      : source_color = vec4(0.529, 0.239, 0.063, 1.0); // rust orange-brown

// ── Scale & Tuning ────────────────────────────────────────────────────────────
uniform float tile_size_px     = 64.0;
// grain_scale: frequency of the micro-surface grain (higher = finer grain)
uniform float grain_scale      = 3.5;
// milky_scale: scale of the broad highlight swaths (lower = wider highlights)
uniform float milky_scale      = 1.8;
// scratch_thresh: Grainy values above this appear as fine scratch lines
uniform float scratch_thresh   = 0.84;
// scratch_strength: how visible the scratch lines are
uniform float scratch_strength = 0.20;
// panel_scale: scale of the Techno geometric pattern (1.0 = one pattern per tile)
uniform float panel_scale      = 1.0;
// panel_thresh: Techno values above this become dark panel seam grooves
uniform float panel_thresh     = 0.86;
// panel_depth: darkness of panel seam grooves
uniform float panel_depth      = 0.65;
// rust_thresh: Turbulence values above this start showing rust
uniform float rust_thresh      = 0.58;
// world_scale: low-frequency ambient variation across room
uniform float world_scale      = 0.003;

// ── Room-Level Controls ───────────────────────────────────────────────────────
uniform float room_seed  = 0.0;
// wear_level: 0 = pristine polished metal, 1 = heavily rusted/corroded
uniform float wear_level = 0.2;

// ─────────────────────────────────────────────────────────────────────────────
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// ─────────────────────────────────────────────────────────────────────────────
void fragment() {
	// ── Per-tile hashes ───────────────────────────────────────────────────────
	vec2 tile_cell = floor(world_pos / tile_size_px);
	float h1 = fract(sin(dot(tile_cell, vec2(127.1, 311.7))) * 43758.5453 + room_seed * 0.1);
	float h2 = fract(sin(dot(tile_cell, vec2(269.5, 183.3))) * 43758.5453 + room_seed * 0.1);

	// ── Grainy micro-surface ──────────────────────────────────────────────────
	// Grainy texture has fine anisotropic noise — like the tiny grooves from
	// a metal brush. Per-tile offset so grain direction varies slightly.
	vec2 grain_uv = UV * grain_scale + vec2(h1 * 5.1, h2 * 3.7);
	float grain   = texture(noise_grainy, grain_uv).r;

	// ── Milky highlight swaths ────────────────────────────────────────────────
	// Milky noise has soft, broad cloud-like regions. Simulates the way brushed
	// metal has wide low-angle reflection zones.
	vec2 milky_uv = UV * milky_scale + vec2(h2 * 2.9, h1 * 4.3);
	float milky   = texture(noise_milky, milky_uv).r;

	// ── World-space ambient (Manifold) ────────────────────────────────────────
	// Large-scale gradient that makes one section of floor slightly brighter/
	// darker than another — suggests ambient occlusion or environmental lighting.
	float world_val = texture(noise_world, world_pos * world_scale).r;

	// ── Compose metal surface brightness ─────────────────────────────────────
	// Grain: tight micro-surface (60%); Milky: broad highlight zones (40%)
	float surface = mix(grain, milky, 0.40);
	// Global ambient tilt
	surface = mix(surface, world_val, 0.18);

	// Per-tile warm/cool tint: slight shift in hue per tile
	float warmth_shift = (h1 - 0.5) * 0.10;
	float tile_brightness = (h2 - 0.5) * 0.10;
	surface = clamp(surface + tile_brightness, 0.0, 1.0);

	// ── Color ramp: shadow → steel → highlight ────────────────────────────────
	vec4 metal_col;
	if (surface < 0.42) {
		metal_col = mix(color_shadow, color_steel, surface / 0.42);
	} else {
		metal_col = mix(color_steel, color_highlight, (surface - 0.42) / 0.58);
	}

	// Per-tile warm/cool hue shift (slightly warmer or cooler steel per tile)
	metal_col.r += warmth_shift * 0.08;
	metal_col.b -= warmth_shift * 0.12;

	// ── Scratch lines ─────────────────────────────────────────────────────────
	// Very bright values in the grain texture become fine scratch lines
	float scratch_mask = smoothstep(scratch_thresh, 1.0, grain);
	metal_col.rgb -= scratch_mask * scratch_strength;

	// ── Panel seam lines (Techno) ─────────────────────────────────────────────
	// Techno geometric patterns create panel/plate construction lines.
	// NOT offset per tile: seams align with tile edges for a fabricated look.
	float techno_val  = texture(noise_techno, UV * panel_scale).r;
	float panel_seam  = smoothstep(panel_thresh, 1.0, techno_val);
	metal_col.rgb = mix(metal_col.rgb, color_shadow.rgb, panel_seam * panel_depth);

	// ── Rust / Corrosion (Turbulence) ─────────────────────────────────────────
	// Turbulence creates organic corrosion blooms that accumulate in corners
	// and around panel seams. Scaled by wear_level so pristine rooms have none.
	vec2 rust_uv  = UV * 2.8 + vec2(h2 * 6.0, h1 * 4.5);
	float rust_val  = texture(noise_turbulence, rust_uv).r;
	// Rust appears where turbulence > rust_thresh AND wear is significant
	float rust_mask = smoothstep(rust_thresh, 0.90, rust_val) * wear_level;
	// Rust is more concentrated near panel seams
	rust_mask *= mix(1.0, 1.4, panel_seam);
	rust_mask   = clamp(rust_mask, 0.0, 1.0);

	metal_col = mix(metal_col, color_rust, rust_mask * 0.85);

	// Heavily rusted areas lose their metallic sheen (get darker, more matte)
	metal_col.rgb = mix(metal_col.rgb, color_rust.rgb * 0.55, rust_mask * wear_level * 0.4);

	COLOR = metal_col * COLOR;
}
