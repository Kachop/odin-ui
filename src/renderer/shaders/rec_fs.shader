#version 330 core

layout(origin_upper_left) in vec4 gl_FragCoord;

out vec4 FragColour;

uniform vec2 origin;
uniform vec2 size;
uniform vec4 radius;
uniform vec4 colour;
uniform float border_thickness;
uniform vec4 border_colour;

float roundedBoxSDF(vec2 center_position, vec2 size, vec4 radius) {
	radius.xy = (center_position.x > 0.0) ? radius.xy : radius.zw;
	radius.x  = (center_position.y > 0.0) ? radius.x  : radius.y;

	vec2 q = abs(center_position) - size + radius.x;
	return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - radius.x;
}

void main()
{
	float edge_softness   = 1.0; // How soft the edges should be (in pixels). Higher values could be used to simulate a drop shadow.

	// Border
	float border_softness  = 1.0; // How soft the (internal) border should be (in pixels)

	// =========================================================================
	vec2 half_size = (size / 2.0); // Rectangle extents (half of the size)

	vec2 center = origin + half_size;
	// -------------------------------------------------------------------------

	// Calculate distance to edge.   
	float distance = roundedBoxSDF(gl_FragCoord.xy - center, half_size, radius);

	// Smooth the result (free antialiasing).
	float smooth_alpha = 1.0 - smoothstep(0.0, edge_softness, distance);
	// -------------------------------------------------------------------------
	// Border.

	vec4 bg_colour = vec4(0, 0, 0, 0.0);

	float border_alpha   = 1.0 - smoothstep(border_thickness - border_softness, border_thickness, abs(distance));
	//float border_alpha = 1.0;

	vec4 res_bg_fg_colours = vec4(mix(bg_colour, colour, smooth_alpha).rgb, min(colour.a, smooth_alpha));

	FragColour = mix(res_bg_fg_colours, border_colour, min(border_colour.a, min(border_alpha, smooth_alpha)));
}
