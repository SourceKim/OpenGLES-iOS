attribute vec4 position;

uniform float pointSize;

void main (void) {
    gl_Position = position;
    gl_PointSize = pointSize;
}

