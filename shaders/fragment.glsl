#version 300 es
precision highp float;

in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform sampler2D u_buffer;
uniform sampler2D u_obstacles;
uniform float u_debug_obstacles;
uniform float u_debug_instability;

void main() {
    vec2 R = u_resolution;
    vec2 U = gl_FragCoord.xy;
    vec4 f = texture(u_buffer, U / R);
    float obstacle = texture(u_obstacles, U / R).r;

    if (u_debug_instability > 0.5) {
        float speed = length(f.xy);
        bool bad = any(isnan(f)) || any(isinf(f));
        bool densitySpike = (f.w > 1.2 || f.w < -0.05);
        bool runawayVel = speed > 0.75;
        bool phaseSpike = abs(f.z) > 25.0;

        if (bad) {
            fragColor = vec4(1.0, 0.0, 1.0, 1.0);
            return;
        }
        if (densitySpike) {
            fragColor = vec4(1.0, 0.95, 0.0, 1.0);
            return;
        }
        if (runawayVel) {
            fragColor = vec4(1.0, 0.4, 0.0, 1.0);
            return;
        }
        if (phaseSpike) {
            fragColor = vec4(0.0, 1.0, 0.4, 1.0);
            return;
        }

        fragColor = vec4(vec3(clamp(f.w, 0.0, 1.0)), 1.0);
        return;
    }

    if (u_debug_obstacles > 0.5) {
        vec3 bg = vec3(1.0);
        vec3 solid = vec3(1.0, 0.15, 0.15);
        fragColor = vec4(mix(bg, solid, obstacle), 1.0);
        return;
    }

    float t = 0.5 + 0.5 * sin(3.5 - 0.3 * f.z);
    vec4 blue =     vec4(0.0, 0.40, 0.70, 1.0);
    vec4 turquoise = vec4(0.20, 0.60, 0.55, 1.0);
    fragColor = mix(blue, turquoise, t) * f.w;
}
