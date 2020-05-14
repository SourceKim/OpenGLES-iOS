uniform sampler2D imageTexture;

varying highp vec2 outTexCoor;

void main() {
    
    gl_FragColor = texture2D(imageTexture, outTexCoor);
}
