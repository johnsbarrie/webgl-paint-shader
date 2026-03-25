#version 300 es
precision highp float;

in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec4 u_mouse;
uniform int u_frame;
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
        vec4 a = texture(u_buffer, (U + u) / R);
        float f = 0.05 * a.w * ((a.w - 1.0) + 0.2);
        dQ.xy -= f * u;
    }

    Q += dQ;

    // Gravity
    Q.y -= 0.5 / R.y;

    // Mouse interaction
    vec2 M = 1.5 * R;
    if (u_mouse.z > 0.0) M = u_mouse.xy;
    if (length(U - M) < 0.02 * R.y)
        Q = vec4(0.1 * normalize(M - 0.5 * R), -1.0, 1.0);

    // Velocity clamp
    if (length(Q.xy) > 0.7) Q.xy = 0.7 * normalize(Q.xy);

    // Reset on first frame
    if (u_frame < 1) Q = vec4(0);

    // Fluid source (top-left strip)
    if (U.x < 4.0 && U.y > 0.98 * R.y && U.y < 0.975 * R.y) {
        Q.w = 1.0;
        Q.z = 10.0 * sin(0.1 * u_time);
    }

    // Obstacles (zero velocity)
    if (U.x < 0.05 * R.x && U.y < 0.8 * R.y && U.y > 0.7 * R.y) Q.xy *= 0.0;
    if (U.x < 0.2 * R.x && U.x > 0.1 * R.x && U.y < 0.7 * R.y && U.y > 0.6 * R.y) Q.xy *= 0.0;
    if (U.x < 0.7 * R.x && U.x > 0.3 * R.x && U.y < 0.6 * R.y && U.y > 0.55 * R.y) Q.xy *= 0.0;
    if (U.x < 0.45 * R.x && U.x > 0.4 * R.x && U.y < 0.64 * R.y && U.y > 0.48 * R.y) Q.xy *= 0.0;

    // Wavy floor
    //if (U.y < (0.2 - U.x / R.x * (0.1 + 0.1 * sin((1.0 - U.x / R.x) * (1.0 - U.x / R.x) * 150.0))) * R.y)
      //  Q.xy *= 0.0;

    // Boundary walls
    if (U.x < 1.0 || U.y < 1.0 || R.y - U.y < 1.0) Q.xy *= 0.0;
    if (R.x - U.x < 1.0) Q *= 0.0;

    fragColor = Q;
}
