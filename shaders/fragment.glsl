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
    fragColor = 1.0 - (0.8 - 0.5 * (sin(3.5 - 0.3 * (f.z) + vec4(1, 2, 3, 4)))) * f.w;
}
