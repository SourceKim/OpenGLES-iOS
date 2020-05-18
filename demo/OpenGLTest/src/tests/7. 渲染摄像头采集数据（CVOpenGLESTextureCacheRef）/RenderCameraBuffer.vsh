attribute vec3 position;
attribute vec2 texCoor;

uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;

varying vec2 outTexCoor;

void main() {
    
    gl_Position = projectionMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
    
    outTexCoor = texCoor;
}
