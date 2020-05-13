varying highp vec2 outTexCoor;

uniform sampler2D tmpBufferTexture;
uniform lowp float brightness;

void main()
{
    highp vec4 sampleColor = texture2D(tmpBufferTexture, outTexCoor);
    gl_FragColor = vec4(sampleColor.rgb + brightness, 1);
}
