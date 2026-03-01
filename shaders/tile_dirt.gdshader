shader_type canvas_item;

// ─────────────────────────────────────────────────────────────────────────────
// TILE DIRT SHADER — Renegade Lemonade
// ─────────────────────────────────────────────────────────────────────────────
// Technique: World-space UV sampling for seamless tile continuity.
//   Adjacent tiles share the same world-space coordinates at their shared
//   edge, so large-scale noise features flow continuously across tile borders.
//   Per-tile variation is derived from a hash of the tile's grid cell —
//   no per-tile data encoding from GDScript required.
//
// Noise textures used:
//   noise_perlin      → sprites/noise/Perlin/Perlin 3 - 256x256.png
//   noise_turbulence  → sprites/noise/Turbulence/Turbulence 5 - 256x256.png
//   noise_craters     → sprites/noise/Craters/Craters 2 - 256x256.png
//   noise_world       → sprites/noise/Super Perlin/Super Perlin 1 - 256x256.png
// ─────────────────────────────────────────────────────────────────────────────

// World-space pixel position — interpolated per fragment, set in vertex()
varying vec2 world_pos;

// ── Noise Samplers ────────────────────────────────────────────────────────────
uniform sampler2D noise_perlin     : source_color, repeat_enable;
uniform sampler2D noise_turbulence : source_color, repeat_enable;
uniform sampler2D noise_craters    : source_color, repeat_enable;
uniform sampler2D noise_world      : source_color, repeat_enable;

// ── Color Palette ─────────────────────────────────────────────────────────────
uniform vec4 color_dark  : source_color = vec4(0.220, 0.122, 0.059, 1.0); // deep earth
uniform vec4 color_mid   : source_color = vec4(0.380, 0.259, 0.157, 1.0); // mid dirt
uniform vec4 color_light : source_color = vec4(0.522, 0.376, 0.251, 1.0); // sandy topsoil

// ── Scale & Tuning ────────────────────────────────────────────────────────────
// tile_size_px: match your TileSet tile size (default 64 to match White_64x64.png)
uniform float tile_size_px    = 64.0;
// local_scale: how zoomed in the per-tile detail noise appears (higher = finer)
uniform float local_scale     = 2.2;
// world_scale: frequency of the world-space continuity noise (lower = bigger patches)
// Typical range: 0.002 (very large patches) to 0.008 (medium patches)
uniform float world_scale     = 0.003;
// crater_thresh: brightness above which crater pits appear [0..1]
uniform float crater_thresh   = 0.68;
// crater_strength: how dark the crater pits get [0..1]
uniform float crater_strength = 0.60;

// ── Room-Level Controls ───────────────────────────────────────────────────────
// room_seed: changes per-tile variation pattern between rooms (set per room)
uniform float room_seed  = 0.0;
// wear_level: 0 = fresh soil, 1 = heavily compacted/dark
uniform float wear_level = 0.2;

// ─────────────────────────────────────────────────────────────────────────────
void vertex() {
	// Lift local vertex position to world space.
	// VERTEX is in pixels in the TileMapLayer's local coordinate system.
	// MODEL_MATRIX transforms local → world.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// ─────────────────────────────────────────────────────────────────────────────
void fragment() {
	// ── Per-tile deterministic hash ───────────────────────────────────────────
	// Grid cell index from world position — no GDScript needed.
	vec2 tile_cell = floor(world_pos / tile_size_px);

	// Two independent hash values per tile for UV offsets
	float h1 = fract(sin(dot(tile_cell, vec2(127.1, 311.7))) * 43758.5453 + room_seed * 0.1);
	float h2 = fract(sin(dot(tile_cell, vec2(269.5, 183.3))) * 43758.5453 + room_seed * 0.1);

	// ── World-space continuity sample ─────────────────────────────────────────
	// Super Perlin sampled at very low frequency — patches span many tiles.
	// This is what makes dirt floors look seamless like Binding of Isaac.
	vec2 world_uv = world_pos * world_scale;
	float world_noise = texture(noise_world, world_uv).r;

	// ── Local per-tile detail samples ─────────────────────────────────────────
	// Offset UV by per-tile hash so each tile samples a different region of
	// the noise texture (variation without breaking continuity at edges).
	vec2 local_uv_a = UV * local_scale + vec2(h1 * 5.3, h2 * 4.1);
	vec2 local_uv_b = UV * local_scale * 1.6 + vec2(h2 * 3.7, h1 * 5.9);

	float perlin_val = texture(noise_perlin,     local_uv_a).r;
	float turb_val   = texture(noise_turbulence, local_uv_b).r;

	// Blend the two local layers: Perlin gives broad soil clumps, Turbulence
	// adds organic mid-frequency roughness
	float local_noise = mix(perlin_val, turb_val, 0.40);

	// ── Combine local + world ─────────────────────────────────────────────────
	// 40% world influence: enough for visible continuity without losing local
	// detail. Increase toward 0.6 for stronger seamlessness, decrease to 0.2
	// for more isolated tile appearance.
	float blended = mix(local_noise, world_noise, 0.40);

	// Per-tile brightness shift: subtle darkening/lightening per tile
	float brightness_shift = (h1 - 0.5) * 0.18;
	blended = clamp(blended + brightness_shift, 0.0, 1.0);

	// ── Color ramp: dark earth → mid dirt → sandy topsoil ────────────────────
	vec4 terrain_col;
	if (blended < 0.5) {
		terrain_col = mix(color_dark, color_mid, blended * 2.0);
	} else {
		terrain_col = mix(color_mid, color_light, (blended - 0.5) * 2.0);
	}

	// ── Crater/pit detail ─────────────────────────────────────────────────────
	// Craters add small dark depressions — pebbles, impacted areas, etc.
	// Sample at offset so craters don't align with Perlin pattern.
	vec2 crater_uv = UV * local_scale * 0.85 + vec2(h2 * 6.1, h1 * 4.7);
	float crater_val  = texture(noise_craters, crater_uv).r;
	float crater_mask = smoothstep(crater_thresh, 1.0, crater_val);
	terrain_col.rgb   = mix(terrain_col.rgb, color_dark.rgb * 0.55, crater_mask * crater_strength);

	// ── Wear/compaction ───────────────────────────────────────────────────────
	// Worn floors are darker and more uniform
	terrain_col.rgb = mix(terrain_col.rgb, color_dark.rgb, wear_level * 0.20);

	// ── Final output ──────────────────────────────────────────────────────────
	// Multiply by vertex COLOR so TileMapLayer modulate/tint still works
	COLOR = terrain_col * COLOR;
}
