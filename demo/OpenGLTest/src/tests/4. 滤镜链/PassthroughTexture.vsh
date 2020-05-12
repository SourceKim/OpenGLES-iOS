attribute vec3 position;
attribute vec2 texCoor;

varying vec2 outTexCoor;

void main()
{
    gl_Position = vec4(position, 1.0);
    outTexCoor = texCoor;
}
