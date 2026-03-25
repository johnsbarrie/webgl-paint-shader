#version 300 es
precision highp float;

in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec4 u_mouse;
uniform int u_frame;
uniform sampler2D u_buffer;
uniform sampler2D u_obstacles;

bool isObstacle(vec2 U, vec2 R) {
    return texture(u_obstacles, U / R).r > 0.5;
}

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

    // Oscillating hose injector: moving nozzle, sweeping direction, and pulsing speed.
    float t = u_time;
    // Tuning parameters.
    float nozzleVerticalCenter = 0.82;
    float nozzleVerticalAmp = 0.015;
    float nozzleVerticalFreq = 0.05;
    float nozzleRadius = 0.008 * R.y;
    float sweepPrimaryAmp = 0.005;
    float sweepPrimaryFreq = 0.01;
    float sweepSecondaryAmp = 0.04;
    float sweepSecondaryFreq = 0.01;
    float speedBase = 0.20;
    float speedPulseAmp = 0.15;
    float speedPulseFreq = 0.6;

    vec2 nozzle = vec2(
        3.0,
        (nozzleVerticalCenter + nozzleVerticalAmp * sin(nozzleVerticalFreq * t)) * R.y
    );
    float sweep = sweepPrimaryAmp * sin(sweepPrimaryFreq * t);
               // + sweepSecondaryAmp * sin(sweepSecondaryFreq * t);
    vec2 dir = normalize(vec2(cos(sweep), sin(sweep)));
    float speed = speedBase + speedPulseAmp * (0.5 + 0.5 * sin(speedPulseFreq * t));

    if (length(U - nozzle) < nozzleRadius) {
        Q.w = 1.0;
        Q.z = 8.0 * sin(0.3 * t + 0.7 * sin(0.5 * t));
        Q.xy = speed * dir;
    }

    // Obstacles: stop velocity but keep density/color state.
    if (isObstacle(U, R)) {
        Q.xy = vec2(0.0);
    }

    Q.z = clamp(Q.z, -20.0, 20.0);
    Q.w = clamp(Q.w, 0.0, 1.0);
    if (any(isnan(Q)) || any(isinf(Q))) Q = vec4(0.0);

    fragColor = Q;
}
