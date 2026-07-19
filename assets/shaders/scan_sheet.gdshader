// scan_sheet.gdshader — "barcode scanner" construction beam sheet.
// A translucent light-plane fanned from a spire fin's leading edge to the scan point;
// thin bright lines scroll fast along the edge axis (UV.y) so the sheet reads as a
// rapidly-sweeping beam projecting a line pattern. Unshaded + emissive so it blooms.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec3  tint : source_color = vec3(0.30, 0.75, 1.00);
uniform float stripes    = 22.0;  // line count across the sheet's tall axis
uniform float scroll     = 6.0;   // stripe scroll speed (the "fast scan" motion)
uniform float base_alpha = 0.10;  // faint body of the sheet between lines

void fragment() {
	float s = pow(abs(sin((UV.y * stripes - TIME * scroll) * PI)), 8.0);
	// fade slightly toward the target end so the convergence point stays readable
	float taper = mix(1.0, 0.75, UV.x);
	ALBEDO = tint * (0.35 + 1.1 * s);
	EMISSION = tint * (0.55 + 2.4 * s) * taper;
	ALPHA = (base_alpha + 0.55 * s) * taper;
}
