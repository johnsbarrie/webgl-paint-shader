#version 300 es
precision highp float;

in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform sampler2D u_buffer;

void main() {
    vec2 R = u_resolution;
    vec2 U = gl_FragCoord.xy;
    vec4 Q = texture(u_buffer, U / R);
    vec4 dQ = vec4(0);

    // Von Neumann stencil (4 cardinal neighbors)
    for (int x = -1; x <= 1; x++)
    for (int y = -1; y <= 1; y++)
    if (abs(x) != abs(y)) {
        vec2 u = vec2(float(x), float(y));
        vec4 q = texture(u_buffer, (U + u) / R);
        vec2 a = Q.xy;
        vec2 b = q.xy + u;
        float ab = dot(u, b - a);
        if (abs(ab) < 1e-10) continue;
        float i = dot(u, (0.5 * u - a)) / ab;
        float j = 0.5;
        float k = 0.5;
        float wa = 0.25 * Q.w * min(i, j) / j;
        float wb = 0.25 * q.w * max(k + i - 1.0, 0.0) / k;
        dQ.xyz += Q.xyz * wa + q.xyz * wb;
        dQ.w += wa + wb;
    }

    if (dQ.w > 0.0) dQ.xyz /= dQ.w;
    Q = dQ;

    if (length(Q.xy) > 0.7) Q.xy = 0.7 * normalize(Q.xy);
    Q.z = clamp(Q.z, -20.0, 20.0);
    Q.w = clamp(Q.w, 0.0, 1.0);
    if (any(isnan(Q)) || any(isinf(Q))) Q = vec4(0.0);

    fragColor = Q;
}
