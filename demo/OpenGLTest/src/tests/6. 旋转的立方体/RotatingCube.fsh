varying highp vec3 outVertexColor;

void main() {
    
    gl_FragColor = vec4(outVertexColor, 1.0);
}
