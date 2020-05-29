precision highp float;

uniform vec3 color;
uniform sampler2D brushTexture;

void main (void) {
    vec4 textureColor = texture2D(brushTexture, gl_PointCoord);
    gl_FragColor = vec4(color, 1.0) * textureColor;
}

