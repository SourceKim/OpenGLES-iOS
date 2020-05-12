varying highp vec2 outTexCoor;

uniform sampler2D tex;

void main()
{
    highp vec4 sampleColor = texture2D(tex, outTexCoor);
    gl_FragColor = vec4(vec3(sampleColor), 1);
}
