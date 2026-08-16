#version 450 core

// 1. Static attributes shared across all drawn glyphs (The Base Quad)
layout(location = 0) in vec2 quad_vertex; // Normalized positions: (0,0), (1,0), (0,1), (1,1)

// 2. Per-Instance structural attributes (Unique for every character)
layout(location = 1) in vec2 screen_pos;   // Screen rendering destination translation
layout(location = 2) in vec2 screen_size;  // Screen rendering destination dimensions
layout(location = 3) in vec2 glyph_pos;   // Raw local font coordinate source offset
layout(location = 4) in vec2 glyph_size;  // Raw local font coordinate source size
layout(location = 5) in uint glyph_index_in;  // Forwarded layout property link
layout(location = 6) in uint curve_count_in;  // Forwarded layout property link

// Uniforms for viewport projection
uniform mat4 projection_matrix; // Maps window pixel dimensions to GPU Normalized Device Coordinates

// Outputs bound for interpolation into the Fragment Shader stage
out vec2 pixel_coord;
flat out int glyph_index;
flat out int curve_count;

void main() {
    // Forward structural index pointers directly to the fragment shader.
    // 'flat' keyword prevents hardware interpolation between vertex points.
    glyph_index = int(glyph_index_in);
    curve_count = int(curve_count);

    // Calculate the precise point inside the mathematical vector font coordinate space.
    // Maps the normalized quad layout directly into local curve space.
    pixel_coord = a_vectorPos + (quad_vertex * glyph_size);

    // Compute the absolute screen target coordinates for this vertex.
    vec2 final_screen_pos = screen_pos + (quad_vertex * screen_size);

    // Project coordinates into standard WebGL/OpenGL Clip Space (-1.0 to 1.0)
    gl_Position = projection_matrix * vec4(final_screen_pos, 0.0, 1.0);
}
