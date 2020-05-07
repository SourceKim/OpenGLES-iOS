attribute vec4 position;
attribute vec3 vColor;

varying highp vec3 outColor;

void main()
{
    outColor = vColor;
    gl_Position = position;
    
}
