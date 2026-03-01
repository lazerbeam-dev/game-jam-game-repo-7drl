shader_type canvas_item;

// ─────────────────────────────────────────────────────────────────────────────
// TILE WOOD SHADER — Renegade Lemonade
// ─────────────────────────────────────────────────────────────────────────────
// Wood planks. Each tile gets a slightly different grain direction (±8°) so
// adjacent planks don't look perfectly parallel. Vein noise provides the long
// directional grain lines; Streak adds finer hairline detail. Marble creates
// concentric ring patterns for knots — only some tiles have knots (controlled
// by knot_probability). World-space Super Perlin gives moisture/age drift
// across groups of planks.
//
// Noise textures used:
//   noise_vein        → sprites/noise/Vein/Vein 3 - 256x256.png
//   noise_streak      → sprites/noise/Streak/Streak 5 - 256x256.png
//   noise_marble      → sprites/noise/Marble/Marble 6 - 256x256.png
//   noise_world       → sprites/noise/Super Perlin/Super Perlin 4 - 256x256.png
// ─────────────────────────────────────────────────────────────────────────────

varying vec2 world_pos;

// ── Noise Samplers ────────────────────────────────────────────────────────────
uniform sampler2D noise_vein   : source_color, repeat_enable;
uniform sampler2D noise_streak : source_color, repeat_enable;
uniform sampler2D noise_marble : source_color, repeat_enable;
uniform sampler2D noise_world  : source_color, repeat_enable;

// ── Color Palette ─────────────────────────────────────────────────────────────
uniform vec4 color_dark  : source_color = vec4(0.180, 0.098, 0.039, 1.0); // dark knot/grain
uniform vec4 color_mid   : source_color = vec4(0.420, 0.239, 0.094, 1.0); // oak brown
uniform vec4 color_light : source_color = vec4(0.659, 0.463, 0.208, 1.0); // blonde pine

// ── Scale & Tuning ────────────────────────────────────────────────────────────
uniform float tile_size_px    = 64.0;
// grain_scale: base scale for vein/streak textures (affects grain frequency)
uniform float grain_scale     = 1.6;
// grain_stretch: elongation along the plank direction (higher = longer grain lines)
uniform float grain_stretch   = 5.0;
// grain_angle_range: max per-tile rotation in radians (~0.28 = ±8°, ~0.52 = ±15°)
uniform float grain_angle_range = 0.28;
// knot_probability: fraction of tiles that get a knot [0..1]
uniform float knot_probability  = 0.30;
// knot_ring_scale: how spread out the knot rings are
uniform float knot_ring_scale   = 3.0;
// world_scale: moisture/age continuity across groups of planks
uniform float world_scale       = 0.0025;

// ── Room-Level Controls ───────────────────────────────────────────────────────
uniform float room_seed  = 0.0;
// wear_level: 0 = fresh wood, 1 = weathered (grain more pronounced, darker)
uniform float wear_level = 0.2;

// ─────────────────────────────────────────────────────────────────────────────
// Rotate a 2D UV by angle (radians)
vec2 rotate_uv(vec2 uv, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
}

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
	float h3 = fract(sin(dot(tile_cell, vec2(419.2, 371.9))) * 43758.5453 + room_seed * 0.1);
	// h3 drives whether this tile has a knot: yes if h3 < knot_probability
	float has_knot = step(h3, knot_probability);

	// ── Grain direction: per-tile rotation ───────────────────────────────────
	// Each plank is rotated slightly so they don't all run perfectly parallel
	float grain_angle = (h1 - 0.5) * grain_angle_range * 2.0;

	// Rotate UV around tile center, then stretch along grain direction
	vec2 centered_uv = UV - 0.5;
	vec2 rotated_uv  = rotate_uv(centered_uv, grain_angle);

	// Stretch along local x-axis (the plank's length direction)
	vec2 grain_uv = vec2(rotated_uv.x * grain_stretch, rotated_uv.y) * grain_scale;

	// Per-tile offset so adjacent tiles sample different grain regions
	grain_uv += vec2(h1 * 9.3, h2 * 6.1);

	// ── Grain sampling ────────────────────────────────────────────────────────
	// Vein: major grain rings and long lines (sampled at full grain stretch)
	float vein_val = texture(noise_vein, grain_uv).r;

	// Streak: fine micro-grain hairlines (slightly different scale for richness)
	vec2 streak_uv = grain_uv * vec2(1.0, 0.6) + vec2(h2 * 4.0, h1 * 2.5);
	float streak_val = texture(noise_streak, streak_uv).r;

	// Blend: Vein dominates, Streak adds fine detail
	float grain = mix(vein_val, streak_val, 0.32);

	// ── World-space moisture drift ────────────────────────────────────────────
	float world_val = texture(noise_world, world_pos * world_scale).r;
	// Blend in world continuity: planks in a wet area all look darker
	grain = mix(grain, world_val, 0.25);

	// Per-tile brightness shift
	float tile_shift = (h1 - 0.5) * 0.16;
	grain = clamp(grain + tile_shift, 0.0, 1.0);

	// ── Color ramp ────────────────────────────────────────────────────────────
	vec4 wood_col;
	if (grain < 0.42) {
		wood_col = mix(color_dark, color_mid, grain / 0.42);
	} else {
		wood_col = mix(color_mid, color_light, (grain - 0.42) / 0.58);
	}

	// ── Knot overlay ──────────────────────────────────────────────────────────
	// Knot center is at a random position within the tile (h1, h2 in [0,1])
	vec2 knot_center = vec2(h1, h2);
	float knot_dist  = distance(UV, knot_center);

	// Only render knot on tiles where has_knot == 1.0
	if (has_knot > 0.5) {
		// Sample Marble around the knot center to get concentric ring pattern
		vec2 knot_uv  = (UV - knot_center) * knot_ring_scale + 0.5;
		float marble  = texture(noise_marble, knot_uv).r;

		// Convert to ring pattern: peaks of a sine-like wave
		float ring_pattern = abs(sin(marble * TAU * 2.5));

		// Radial falloff: rings fade out far from knot center
		float knot_falloff = 1.0 - smoothstep(0.0, 0.38, knot_dist);

		float knot_mask = ring_pattern * knot_falloff;

		// Darken toward dark grain color in knot region
		wood_col.rgb = mix(wood_col.rgb, color_dark.rgb, knot_mask * 0.75);
	}

	// ── Weathering ────────────────────────────────────────────────────────────
	// Worn wood darkens and loses the lighter highlights
	wood_col.rgb = mix(wood_col.rgb, color_mid.rgb * 0.7, wear_level * 0.25);

	COLOR = wood_col * COLOR;
}
