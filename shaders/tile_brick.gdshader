shader_type canvas_item;

// ─────────────────────────────────────────────────────────────────────────────
// TILE BRICK SHADER — Renegade Lemonade
// ─────────────────────────────────────────────────────────────────────────────
// Voronoi cellular noise defines the brick cell structure. Cell interior
// brightness comes from the R channel; proximity to cell edges (mortar lines)
// is derived by thresholding. Cracks overlay surface fractures on brick faces.
// Turbulence adds per-brick age/staining variation.
//
// World-space sampling gives subtle color continuity across the room (slight
// color drift so one wall section looks different from another), while each
// brick remains visually distinct.
//
// Noise textures used:
//   noise_voronoi    → sprites/noise/Voronoi/Voronoi 4 - 256x256.png
//   noise_cracks     → sprites/noise/Cracks/Cracks 7 - 256x256.png
//   noise_turbulence → sprites/noise/Turbulence/Turbulence 3 - 256x256.png
//   noise_world      → sprites/noise/Perlin/Perlin 1 - 256x256.png
// ─────────────────────────────────────────────────────────────────────────────

varying vec2 world_pos;

// ── Noise Samplers ────────────────────────────────────────────────────────────
uniform sampler2D noise_voronoi    : source_color, repeat_enable;
uniform sampler2D noise_cracks     : source_color, repeat_enable;
uniform sampler2D noise_turbulence : source_color, repeat_enable;
uniform sampler2D noise_world      : source_color, repeat_enable;

// ── Color Palette ─────────────────────────────────────────────────────────────
uniform vec4 color_brick_dark  : source_color = vec4(0.329, 0.149, 0.098, 1.0); // dark terracotta
uniform vec4 color_brick_light : source_color = vec4(0.549, 0.290, 0.184, 1.0); // warm brick red
uniform vec4 color_mortar      : source_color = vec4(0.576, 0.529, 0.490, 1.0); // grey mortar

// ── Scale & Tuning ────────────────────────────────────────────────────────────
uniform float tile_size_px     = 64.0;
// brick_scale: how many voronoi cells fit across one tile (more = smaller bricks)
uniform float brick_scale      = 3.0;
// mortar_thresh: Voronoi values BELOW this become mortar. Adjust for mortar width.
// If bricks look inverted (mortar is bright), try setting this closer to 1.0
// and lowering brick_light brightness, or flip logic with 1.0 - voronoi.r.
uniform float mortar_thresh    = 0.35;
// mortar_smoothness: how sharp the brick/mortar boundary is (lower = sharper)
uniform float mortar_smoothness = 0.08;
// crack_thresh: Cracks texture values above this show as surface fractures
uniform float crack_thresh     = 0.78;
// crack_strength: darkness of crack lines [0..1]
uniform float crack_strength   = 0.40;
// world_scale: low-frequency world continuity (subtle color drift room-wide)
uniform float world_scale      = 0.0025;

// ── Room-Level Controls ───────────────────────────────────────────────────────
uniform float room_seed  = 0.0;
uniform float wear_level = 0.2; // 0 = fresh, 1 = old/damaged (more cracks)

// ─────────────────────────────────────────────────────────────────────────────
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// ─────────────────────────────────────────────────────────────────────────────
void fragment() {
	// ── Per-tile hash ─────────────────────────────────────────────────────────
	vec2 tile_cell = floor(world_pos / tile_size_px);
	float h1 = fract(sin(dot(tile_cell, vec2(127.1, 311.7))) * 43758.5453 + room_seed * 0.1);
	float h2 = fract(sin(dot(tile_cell, vec2(269.5, 183.3))) * 43758.5453 + room_seed * 0.1);

	// ── Voronoi brick cells ───────────────────────────────────────────────────
	// Offset per tile so each tile samples a different region → bricks don't
	// tile visibly, but within a tile the cell pattern is stable.
	vec2 voronoi_uv = UV * brick_scale + vec2(h1 * 7.3, h2 * 5.9);
	vec4 voronoi    = texture(noise_voronoi, voronoi_uv);

	// R channel: cell interior value — low = edge/mortar, high = brick center.
	// If this is inverted in your texture, swap: float cell_val = 1.0 - voronoi.r;
	float cell_val = voronoi.r;

	// Mortar mask: smoothstep from cell edge (dark) to brick interior (bright).
	// mortar_mask = 1.0 on mortar, 0.0 on brick face.
	float mortar_mask = 1.0 - smoothstep(mortar_thresh, mortar_thresh + mortar_smoothness, cell_val);

	// ── World-space tint ──────────────────────────────────────────────────────
	// Very subtle color drift across the room — one wall section slightly
	// warmer/cooler than another without looking tiled.
	float world_tint = texture(noise_world, world_pos * world_scale).r;

	// ── Turbulence: per-brick age and staining ────────────────────────────────
	// Sample within the brick's own UV space so staining follows the cell shape.
	vec2 turb_uv = UV * brick_scale * 1.8 + vec2(h2 * 4.0, h1 * 3.2);
	float turb_val = texture(noise_turbulence, turb_uv).r;

	// ── Brick face color ──────────────────────────────────────────────────────
	// Combine voronoi interior value with turbulence for staining variation.
	// cell_val: broad brick color; turb: local stain/age; world_tint: room drift.
	float brightness = mix(cell_val, turb_val, 0.35);
	brightness = mix(brightness, world_tint, 0.18);

	// Per-tile overall brightness offset
	float tile_brightness_shift = (h1 - 0.5) * 0.14;
	brightness = clamp(brightness + tile_brightness_shift, 0.0, 1.0);

	// Map to brick color ramp
	vec4 brick_col = mix(color_brick_dark, color_brick_light, brightness);

	// ── Crack overlay on brick face ───────────────────────────────────────────
	// Cracks only appear on brick faces (not in mortar), intensity scales with wear.
	vec2 crack_uv   = UV * 1.8 + vec2(h2 * 5.0, h1 * 3.8);
	float crack_val  = texture(noise_cracks, crack_uv).r;
	float crack_mask = smoothstep(crack_thresh, 1.0, crack_val);
	// Gate by inverse mortar mask and wear level
	crack_mask *= (1.0 - mortar_mask) * (crack_strength + wear_level * 0.3);
	brick_col.rgb -= crack_mask * 0.45;

	// ── Compose brick + mortar ────────────────────────────────────────────────
	// Hard blend: mortar_mask 0 = full brick, 1 = full mortar
	vec4 final_col = mix(brick_col, color_mortar, mortar_mask);

	// Darken mortar slightly with wear (old mortar gets grimier)
	final_col.rgb = mix(final_col.rgb, color_brick_dark.rgb, mortar_mask * wear_level * 0.25);

	COLOR = final_col * COLOR;
}
