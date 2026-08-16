#version 450 core

// Input block from the vertex shader (maps the glyph's quad bounds)
in vec2 pixel_coord; // The actual vector space coordinate of this pixel center

layout(location = 0) out vec4 frag_colour;

flat in int glyph_index;
flat in int curve_count;

uniform vec4 glyph_colour;

layout(std430, binding = 0) readonly buffer CurveBuffer {
    vec2 curves[];
};

// Solves the quadratic equation for a ray casting check along the X axis
// Evaluates at the pixel's exact Y coordinate to find structural curve crossings
float evaluateWinding(vec2 p, BezierCurve curve) {
    float winding = 0.0;
    
    // Translate curve relative to pixel origin to simplify math
    vec2 p0 = curve.p0 - p;
    vec2 p1 = curve.p1 - p;
    vec2 p2 = curve.p2 - p;
    
    // Formulate coefficients for parametric quadratic Bezier equation:
    // B(t) = (1-t)^2*P0 + 2(1-t)*t*P1 + t^2*P2 = A*t^2 + B*t + C
    float a = p0.y - 2.0 * p1.y + p2.y;
    float b = 2.0 * (p1.y - p0.y);
    float c = p0.y;
    
    // Ray crossing tracking variables
    float t1 = -1.0;
    float t2 = -1.0;
    
    if (abs(a) < 1e-5) {
        // Degenerate linear case (the curve section is nearly flat vertically)
        if (abs(b) > 1e-5) {
            t1 = -c / b;
        }
    } else {
        // Standard quadratic formula solver
        float discriminant = b * b - 4.0 * a * c;
        if (discriminant >= 0.0) {
            float sqrtD = sqrt(discriminant);
            t1 = (-b + sqrtD) / (2.0 * a);
            t2 = (-b - sqrtD) / (2.0 * a);
        }
    }
    
    // Evaluate validity of root 1
    if (t1 >= 0.0 && t1 <= 1.0) {
        float xIntersection = mix(mix(p0.x, p1.x, t1), mix(p1.x, p2.x, t1), t1);
        if (xIntersection > 0.0) { // Ray points right (+X direction)
            // Determine line direction to calculate signed winding contribution
            float tangentY = 2.0 * a * t1 + b;
            winding += (tangentY > 0.0) ? 1.0 : -1.0;
        }
    }
    
    // Evaluate validity of root 2
    if (t2 >= 0.0 && t2 <= 1.0) {
        float xIntersection = mix(mix(p0.x, p1.x, t2), mix(p1.x, p2.x, t2), t2);
        if (xIntersection > 0.0) {
            float tangentY = 2.0 * a * t2 + b;
            winding += (tangentY > 0.0) ? 1.0 : -1.0;
        }
    }
    
    return winding;
}

// Computes the approximate perpendicular distance from a pixel to a quadratic curve
// Used directly to drive the analytic anti-aliasing gradient
float getDistanceToCurve(vec2 p, BezierCurve curve) {
    // Basic Midpoint Approximation for performant distance evaluation
    vec2 p0 = curve.p0;
    vec2 p1 = curve.p1;
    vec2 p2 = curve.p2;
    
    // Midpoint derivative evaluation
    vec2 base = mix(mix(p0, p1, 0.5), mix(p1, p2, 0.5), 0.5);
    vec2 tangent = 2.0 * (mix(p1, p2, 0.5) - mix(p0, p1, 0.5));
    vec2 normal = vec2(-tangent.y, tangent.x);
    
    if (length(normal) > 0.0) {
        normal = normalize(normal);
    }
    
    // Project pixel point onto local normal plane
    return abs(dot(p - base, normal));
}

void main() {
    float totalWinding = 0.0;
    float minDistance = 9999.0;

	int end_curve_index = glyph_index + curve_count;

    // The core execution loop iterating over assigned glyph segments
    for (int i = glyph_index; i < end_curve_index; i++) {
        // Core analytic evaluation processing loop runs identical to before
		BezierCurve curve = curves[i];

        // 1. Accumulate signed winding entries
        totalWinding += evaluateWinding(pixel_coord, curve);

        // 2. Track nearest curve edge boundary
        float dist = getDistanceToCurve(pixel_coord, curve);
        minDistance = min(minDistance, dist);

    }

    // Check if the pixel sits firmly within a non-zero filled region
    bool isInside = (abs(totalWinding) > 0.01);
    
    // Compute screen space derivatives to figure out the pixel footprint size
    // This makes the text resolution and hardware scale independent
    float pixelWidth = length(vec2(dFdx(pixel_coord.x), dFdy(pixel_coord.y)));
    
    // Shape smooth mathematical edge mask 
    // Maps the distance field around the exact vector perimeter edge
    float edgeCoverage = smoothstep(pixelWidth * 0.5, -pixelWidth * 0.5, minDistance - (pixelWidth * 0.25));
    
    float finalAlpha = isInside ? 1.0 : 0.0;
    
    // Combine coverage to achieve flawless analytical anti-aliasing filter output
    if (minDistance < pixelWidth * 1.5) {
        finalAlpha = isInside ? edgeCoverage : (1.0 - edgeCoverage);
    }
    
    // Apply final layout coverage onto selected glyph properties
    frag_colour = vec4(glyph_color.rgb, glyph_colour.a * finalAlpha);
}
