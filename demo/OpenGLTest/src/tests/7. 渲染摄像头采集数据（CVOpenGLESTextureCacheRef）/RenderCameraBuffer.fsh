uniform sampler2D imageTexture;

varying highp vec2 outTexCoor;

void main() {
    
    highp vec4 sampleColor = texture2D(imageTexture, outTexCoor); // BGRA
    gl_FragColor = vec4(sampleColor.b, sampleColor.g, sampleColor.r, sampleColor.a);
}
