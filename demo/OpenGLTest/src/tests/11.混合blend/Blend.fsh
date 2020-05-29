precision highp float;

varying vec2 outTexCoor;

uniform sampler2D tex;

void main (void) {
    vec4 textureColor = texture2D(tex, outTexCoor);
    gl_FragColor = textureColor;
}

