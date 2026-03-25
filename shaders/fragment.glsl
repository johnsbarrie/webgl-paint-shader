#version 300 es
precision highp float;

in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform sampler2D u_buffer;

void main() {
    vec2 R = u_resolution;
    vec2 U = gl_FragCoord.xy;
    vec4 f = texture(u_buffer, U / R);
    float t = 0.5 + 0.5 * sin(3.5 - 0.3 * f.z);
    vec4 blue =     vec4(0.0, 0.40, 0.70, 1.0);
    vec4 turquoise = vec4(0.20, 0.60, 0.55, 1.0);
    fragColor = mix(blue, turquoise, t) * f.w;
}
