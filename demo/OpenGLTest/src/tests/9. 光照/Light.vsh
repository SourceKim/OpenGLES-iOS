attribute vec3 position;
attribute vec3 normal;

uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;

varying vec3 outNormal; // 输出的法向量
varying vec3 outFragmentPosition; // 输出的片段位置

void main() {
    
    gl_Position = projectionMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
    outNormal = vec3(modelMatrix * vec4(normal, 0.0));
    outFragmentPosition = vec3(modelMatrix * vec4(position, 1.0));
}
