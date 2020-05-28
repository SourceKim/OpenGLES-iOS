attribute vec4 position;

void main (void) {
    gl_Position = position;
    gl_PointSize = 5.0; // Todo: from uniform
}

