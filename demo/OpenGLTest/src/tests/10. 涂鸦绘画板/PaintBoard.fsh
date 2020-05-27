precision highp float;

uniform vec3 color;

void main (void) {
    vec4 mask = texture2D(Texture, vec2(gl_PointCoord.x, 1.0 - gl_PointCoord.y));
    gl_FragColor = A * vec4(R, G, B, 1.0) * mask;
}

