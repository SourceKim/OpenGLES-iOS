attribute vec4 position;
attribute vec2 texCoor;

varying vec2 outTexCoor;

void main (void) {
    gl_Position = position;
    outTexCoor = texCoor;
}


